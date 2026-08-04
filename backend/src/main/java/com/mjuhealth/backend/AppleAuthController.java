package com.mjuhealth.backend;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

// 네이티브 앱 전용 Apple Sign-In 진입점. 카카오 로그인과는 완전히 분리된 별도 경로 —
// SecurityConfig에도 이 경로만 permitAll로 한 줄 추가돼있음(로그인 전 호출이라 필요)
@RestController
@RequestMapping("/api/auth/apple")
public class AppleAuthController {

    private final AppleAuthService appleAuthService;

    public AppleAuthController(AppleAuthService appleAuthService) {
        this.appleAuthService = appleAuthService;
    }

    @PostMapping("/native")
    public ResponseEntity<Map<String, Object>> login(@RequestBody AppleLoginRequest requestBody,
                                                       HttpServletRequest request, HttpServletResponse response) {
        try {
            User user = appleAuthService.login(requestBody.identityToken(), requestBody.fullName(), request, response);
            return ResponseEntity.ok(Map.of("loggedIn", true, "nickname", user.getNickname()));
        } catch (BadCredentialsException e) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(Map.of("loggedIn", false));
        }
    }
}
