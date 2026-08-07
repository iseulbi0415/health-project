package com.mjuhealth.backend;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final UserRepository userRepository;
    private final AccountDeletionService accountDeletionService;

    public AuthController(UserRepository userRepository, AccountDeletionService accountDeletionService) {
        this.userRepository = userRepository;
        this.accountDeletionService = accountDeletionService;
    }

    // "/api/auth/me"는 SecurityConfig에서 GET만 permitAll이라 principal이 null일 수 있음(로그아웃 상태)
    @GetMapping("/me")
    public Map<String, Object> me(@AuthenticationPrincipal KakaoOAuth2User principal) {
        if (principal == null) {
            return Map.of("loggedIn", false);
        }
        User user = userRepository.findById(principal.getInternalUserId()).orElseThrow();
        return Map.of("loggedIn", true, "nickname", user.getNickname());
    }

    // "/api/auth/logout"은 SecurityConfig의 .logout(...)이 이미 처리하므로 여기엔 코드 없음

    // 회원 탈퇴(App Store 5.1.1(v)). GET과 달리 permitAll이 아니라 SecurityConfig의 apiMatcher.authenticated()에
    // 걸려 principal 없이는 이 메서드에 도달하기 전에 이미 401이 남 — 아래 null 체크는 방어적으로만 유지
    @DeleteMapping("/me")
    public ResponseEntity<Void> deleteMe(@AuthenticationPrincipal KakaoOAuth2User principal,
                                          HttpServletRequest request, HttpServletResponse response) {
        if (principal == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }
        accountDeletionService.deleteAccount(principal.getInternalUserId(), request, response);
        return ResponseEntity.noContent().build();
    }
}
