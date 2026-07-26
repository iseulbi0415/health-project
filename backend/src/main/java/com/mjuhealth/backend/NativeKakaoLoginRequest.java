package com.mjuhealth.backend;

// 네이티브 앱(카카오 SDK)이 카카오톡 로그인 후 발급받은 액세스 토큰을 이 필드에 담아 보냄
public record NativeKakaoLoginRequest(String accessToken) {}
