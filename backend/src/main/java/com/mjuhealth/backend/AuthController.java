package com.mjuhealth.backend;

import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final UserRepository userRepository;

    public AuthController(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    // "/api/auth/me"는 SecurityConfig에서 permitAll이라 principal이 null일 수 있음(로그아웃 상태)
    @GetMapping("/me")
    public Map<String, Object> me(@AuthenticationPrincipal KakaoOAuth2User principal) {
        if (principal == null) {
            return Map.of("loggedIn", false);
        }
        User user = userRepository.findById(principal.getInternalUserId()).orElseThrow();
        return Map.of("loggedIn", true, "nickname", user.getNickname());
    }

    // "/api/auth/logout"은 SecurityConfig의 .logout(...)이 이미 처리하므로 여기엔 코드 없음
}
