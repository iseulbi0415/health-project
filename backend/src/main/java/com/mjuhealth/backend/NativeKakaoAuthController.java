package com.mjuhealth.backend;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import java.util.Map;

// 네이티브 앱 전용 카카오 로그인 진입점. 웹 브라우저 리다이렉트 로그인(AuthController, SecurityConfig의
// oauth2Login)과는 완전히 분리된 별도 경로 — SecurityConfig에도 이 경로만 permitAll로 한 줄 추가돼있음
// (로그인 전 상태에서 호출되어야 하므로)
@RestController
@RequestMapping("/api/auth/kakao")
public class NativeKakaoAuthController {

    private final NativeKakaoAuthService nativeKakaoAuthService;

    public NativeKakaoAuthController(NativeKakaoAuthService nativeKakaoAuthService) {
        this.nativeKakaoAuthService = nativeKakaoAuthService;
    }

    @PostMapping("/native")
    public ResponseEntity<Map<String, Object>> login(@RequestBody NativeKakaoLoginRequest requestBody,
                                                       HttpServletRequest request, HttpServletResponse response) {
        try {
            User user = nativeKakaoAuthService.login(requestBody.accessToken(), request, response);
            return ResponseEntity.ok(Map.of("loggedIn", true, "nickname", user.getNickname()));
        } catch (BadCredentialsException e) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).body(Map.of("loggedIn", false));
        }
    }
}
