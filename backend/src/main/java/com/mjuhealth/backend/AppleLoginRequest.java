package com.mjuhealth.backend;

// fullName은 Apple이 최초 로그인 시에만 클라이언트로 내려주므로 nullable
public record AppleLoginRequest(String identityToken, String fullName) {}
