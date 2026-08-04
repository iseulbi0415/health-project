package com.mjuhealth.backend;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContext;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.oauth2.core.user.DefaultOAuth2User;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtException;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
import org.springframework.security.web.context.HttpSessionSecurityContextRepository;
import org.springframework.stereotype.Service;

import java.util.List;
import java.util.Map;

// Apple Sign-In(네이티브 iOS) 전용 로그인 서비스. 카카오 로그인과는 완전히 분리된
// 별도 경로 — 기존 카카오 코드는 이 기능을 위해 한 줄도 수정하지 않음. 세션 발급
// 패턴은 NativeKakaoAuthService.establishSession()과 동일하게 재사용(principal
// 래퍼도 KakaoOAuth2User를 그대로 씀 — 이름은 카카오지만 실제로는 "internalUserId를
// 들고 다니는 OAuth2User 래퍼"일 뿐이라 provider 무관하게 범용으로 재사용 가능)
@Slf4j
@Service
public class AppleAuthService {

    // 네이티브(ASAuthorizationAppleIDProvider) 플로우라 identity token의 audience는
    // Services ID가 아니라 앱 Bundle ID 그대로 찍힘
    private static final String APPLE_ISSUER = "https://appleid.apple.com";
    private static final String APPLE_BUNDLE_ID = "kje.HealthProject";

    private final UserRepository userRepository;
    private final JwtDecoder appleJwtDecoder =
            NimbusJwtDecoder.withJwkSetUri("https://appleid.apple.com/auth/keys").build();

    public AppleAuthService(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    public User login(String identityToken, String fullName, HttpServletRequest request, HttpServletResponse response) {
        Jwt jwt = verify(identityToken);

        String appleId = jwt.getSubject();
        if (appleId == null) {
            throw new BadCredentialsException("Apple identity token에 sub 클레임이 없음");
        }

        User user = userRepository.findByAppleId(appleId).orElseGet(User::new);
        user.setAppleId(appleId);
        // Apple은 이름을 최초 로그인 시에만 클라이언트로 내려주고 토큰 자체엔 안 실어줌 —
        // fullName은 iOS가 최초 1회만 실어 보내므로, 기존 닉네임이 없을 때만 채워서
        // 재로그인(fullName == null) 시 기존 값이 지워지지 않게 함
        if (user.getNickname() == null && fullName != null && !fullName.isBlank()) {
            user.setNickname(fullName);
        }
        userRepository.save(user);

        establishSession(user, request, response);
        return user;
    }

    private Jwt verify(String identityToken) {
        Jwt jwt;
        try {
            jwt = appleJwtDecoder.decode(identityToken);
        } catch (JwtException e) {
            log.warn("Apple identity token 서명/형식 검증 실패", e);
            throw new BadCredentialsException("Apple identity token 검증 실패", e);
        }
        if (jwt.getIssuer() == null || !APPLE_ISSUER.equals(jwt.getIssuer().toString())) {
            log.warn("Apple identity token issuer 불일치: {}", jwt.getIssuer());
            throw new BadCredentialsException("Apple identity token issuer 불일치");
        }
        if (jwt.getAudience() == null || !jwt.getAudience().contains(APPLE_BUNDLE_ID)) {
            log.warn("Apple identity token audience 불일치: {}", jwt.getAudience());
            throw new BadCredentialsException("Apple identity token audience 불일치");
        }
        return jwt;
    }

    // NativeKakaoAuthService.establishSession()과 동일 패턴 — DefaultOAuth2User의
    // 이름 attribute key만 카카오의 "id" 대신 Apple의 "sub"로 바꿔서 재사용
    private void establishSession(User user, HttpServletRequest request, HttpServletResponse response) {
        List<GrantedAuthority> authorities = List.of(new SimpleGrantedAuthority("OAUTH2_USER"));
        Map<String, Object> attributes = Map.of("sub", user.getAppleId());
        DefaultOAuth2User delegate = new DefaultOAuth2User(authorities, attributes, "sub");
        KakaoOAuth2User principal = new KakaoOAuth2User(delegate, user.getId());

        Authentication authentication = new UsernamePasswordAuthenticationToken(principal, null, authorities);
        SecurityContext context = SecurityContextHolder.createEmptyContext();
        context.setAuthentication(authentication);
        SecurityContextHolder.setContext(context);
        new HttpSessionSecurityContextRepository().saveContext(context, request, response);
    }
}
