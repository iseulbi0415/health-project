package com.mjuhealth.backend;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpHeaders;
import org.springframework.http.client.JdkClientHttpRequestFactory;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContext;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.oauth2.core.user.DefaultOAuth2User;
import org.springframework.security.web.context.HttpSessionSecurityContextRepository;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestClientResponseException;

import java.net.http.HttpClient;
import java.time.Duration;
import java.util.List;
import java.util.Map;

// 네이티브 앱(카카오 SDK)이 카카오톡 앱 전환으로 발급받은 액세스 토큰을 검증하고 로그인 처리하는 전용 서비스.
// 웹 브라우저 리다이렉트 로그인(KakaoOAuth2UserService, SecurityConfig의 oauth2Login)과는 완전히 분리된
// 별도 경로 — 기존 웹 로그인 코드는 이 기능을 위해 한 줄도 수정하지 않음(요구사항). 그래서 닉네임 추출 등
// 일부 로직이 KakaoOAuth2UserService와 겹치지만 의도적으로 복제함(파일 하단 extractNickname 참고)
@Slf4j
@Service
public class NativeKakaoAuthService {

    private final UserRepository userRepository;
    // 연결 3초/읽기 10초 — 카카오·애플 OAuth 단건 호출(응답이 작고 보통 1초 내 완료)이라
    // 식약처(대량 조회)·AI(복잡한 생성)보다 짧게 잡음. 2026-08-09 식약처 타임아웃 미설정
    // 장애(RestClient.create(), 무제한 대기)와 같은 패턴이 로그인/탈퇴 경로에도 있어 동일 조치
    private final RestClient restClient = RestClient.builder()
            .requestFactory(timeoutRequestFactory())
            .build();

    private static JdkClientHttpRequestFactory timeoutRequestFactory() {
        HttpClient httpClient = HttpClient.newBuilder()
                .connectTimeout(Duration.ofSeconds(3))
                .build();
        JdkClientHttpRequestFactory factory = new JdkClientHttpRequestFactory(httpClient);
        factory.setReadTimeout(Duration.ofSeconds(10));
        return factory;
    }

    public NativeKakaoAuthService(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    public User login(String accessToken, HttpServletRequest request, HttpServletResponse response) {
        Map<String, Object> attributes = fetchKakaoUserInfo(accessToken);

        String kakaoId = String.valueOf(attributes.get("id"));
        String nickname = extractNickname(attributes);

        User user = userRepository.findByKakaoId(kakaoId).orElseGet(User::new);
        user.setKakaoId(kakaoId);
        user.setNickname(nickname);
        userRepository.save(user);

        establishSession(attributes, user, request, response);
        return user;
    }

    // 앱이 보낸 토큰이 진짜 카카오가 발급한 유효한 토큰인지는 서버가 직접 확인할 방법이 없으므로,
    // 그 토큰으로 카카오 서버에 사용자 정보를 요청해봄 — 성공하면 진짜 토큰이라는 뜻이고, 응답으로
    // 웹 로그인 때와 동일한 사용자 정보(id, kakao_account, properties)를 그대로 얻을 수 있음
    // (application.properties의 spring.security.oauth2.client.provider.kakao.user-info-uri와 같은 주소)
    @SuppressWarnings("unchecked")
    private Map<String, Object> fetchKakaoUserInfo(String accessToken) {
        try {
            Map<String, Object> attributes = restClient.get()
                    .uri("https://kapi.kakao.com/v2/user/me")
                    .header(HttpHeaders.AUTHORIZATION, "Bearer " + accessToken)
                    .retrieve()
                    .body(Map.class);
            if (attributes == null) {
                // 카카오가 200을 주면서도 빈 바디를 내려준 경우 — 실무에서는 거의 발생하지 않음
                log.warn("카카오 /v2/user/me 응답 바디가 비어있음 (200 응답인데 사용자 정보가 없음)");
                throw new BadCredentialsException("카카오 사용자 정보 응답이 비어있음");
            }
            return attributes;
        } catch (RestClientResponseException e) {
            // 토큰이 가짜/만료/다른 앱 키로 발급된 경우 카카오가 4xx를 내려주는데, 진짜 원인은 이
            // 응답 바디 안에 있음(예: {"msg":"this access token does not exist","code":-401}) —
            // 이걸 그냥 버리면 "무슨 토큰을 보냈길래 실패했는지" 알 수 없어서 콘솔에 그대로 남김
            log.warn("카카오 토큰 검증 실패: HTTP {} - {}", e.getStatusCode(), e.getResponseBodyAsString());
            throw new BadCredentialsException("카카오 액세스 토큰 검증 실패", e);
        } catch (RestClientException e) {
            // 위 분기와 달리 카카오 서버 응답 자체를 못 받은 경우(네트워크 오류, 타임아웃 등) — 원인이
            // 다르므로 구분해서 남김. 스택트레이스까지 남겨서 어디서 끊겼는지(DNS/연결/타임아웃) 확인 가능
            log.warn("카카오 /v2/user/me 호출 자체가 실패함 (네트워크 문제로 추정)", e);
            throw new BadCredentialsException("카카오 액세스 토큰 검증 실패", e);
        }
    }

    // kakao_account.profile.nickname이 기본 위치인데, 카카오 앱/동의항목 설정에 따라
    // properties.nickname(예전 방식)에만 값이 들어오는 경우도 있어서 둘 다 확인함
    // (KakaoOAuth2UserService.extractNickname()과 동일 — 클래스 상단 주석 참고)
    @SuppressWarnings("unchecked")
    private String extractNickname(Map<String, Object> attributes) {
        Map<String, Object> kakaoAccount = (Map<String, Object>) attributes.get("kakao_account");
        if (kakaoAccount != null) {
            Map<String, Object> profile = (Map<String, Object>) kakaoAccount.get("profile");
            if (profile != null && profile.get("nickname") != null) {
                return (String) profile.get("nickname");
            }
        }
        Map<String, Object> properties = (Map<String, Object>) attributes.get("properties");
        if (properties != null) {
            return (String) properties.get("nickname");
        }
        return null;
    }

    // 이 컨트롤러는 oauth2Login 필터를 안 거치는 평범한 @RestController라서, 로그인 성공 후에도
    // Spring Security가 세션에 자동으로 인증 정보를 저장해주지 않음 — 그래서 웹 로그인과 동일한
    // JSESSIONID 세션 인증 방식을 쓰기 위해 SecurityContext를 직접 만들어 세션에 명시적으로 저장함.
    // 이렇게 해두면 이후 /api/auth/me, /api/food 등 기존 API가 전혀 수정 없이 그대로 이 로그인을 인식함
    private void establishSession(Map<String, Object> attributes, User user,
                                   HttpServletRequest request, HttpServletResponse response) {
        List<GrantedAuthority> authorities = List.of(new SimpleGrantedAuthority("OAUTH2_USER"));
        DefaultOAuth2User delegate = new DefaultOAuth2User(authorities, attributes, "id");
        KakaoOAuth2User principal = new KakaoOAuth2User(delegate, user.getId());

        Authentication authentication = new UsernamePasswordAuthenticationToken(principal, null, authorities);
        SecurityContext context = SecurityContextHolder.createEmptyContext();
        context.setAuthentication(authentication);
        SecurityContextHolder.setContext(context);
        new HttpSessionSecurityContextRepository().saveContext(context, request, response);
    }
}
