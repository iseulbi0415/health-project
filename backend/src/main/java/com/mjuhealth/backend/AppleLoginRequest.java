package com.mjuhealth.backend;

// fullName은 Apple이 최초 로그인 시에만 클라이언트로 내려주므로 nullable.
// authorizationCode는 로그인마다 매번 새로 발급되지만(5분 내 만료, refresh_token 교환용),
// 옛 버전 클라이언트는 아직 안 보낼 수 있어 nullable — 없으면 교환을 그냥 스킵함
public record AppleLoginRequest(String identityToken, String fullName, String authorizationCode) {}
