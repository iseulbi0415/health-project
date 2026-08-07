package com.mjuhealth.backend;

import com.nimbusds.jose.JOSEException;
import com.nimbusds.jose.JWSAlgorithm;
import com.nimbusds.jose.JWSHeader;
import com.nimbusds.jose.crypto.ECDSASigner;
import com.nimbusds.jwt.JWTClaimsSet;
import com.nimbusds.jwt.SignedJWT;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;

import java.security.KeyFactory;
import java.security.PrivateKey;
import java.security.interfaces.ECPrivateKey;
import java.security.spec.PKCS8EncodedKeySpec;
import java.time.Instant;
import java.util.Base64;
import java.util.Date;
import java.util.Map;
import java.util.Optional;

// Apple의 client_secret(ES256 JWT)을 생성하고 /auth/token(authorizationCode -> refresh_token 교환)을
// 호출하는 전용 클래스. 계정 삭제 시 필요한 /auth/revoke 호출은 이 클래스에 메서드를 추가해서
// client_secret 생성 로직을 그대로 재사용할 예정(회원 탈퇴 커밋에서 작업).
@Slf4j
@Component
public class AppleTokenClient {

    private static final String TOKEN_URL = "https://appleid.apple.com/auth/token";
    private static final String APPLE_AUDIENCE = "https://appleid.apple.com";
    // client_secret JWT는 호출마다 새로 만들어 쓰는 단기 토큰이라 유효기간을 길게 둘 이유가 없음
    private static final long CLIENT_SECRET_TTL_SECONDS = 300;

    private final String teamId;
    private final String keyId;
    private final String bundleId;
    private final ECPrivateKey privateKey;
    private final RestClient restClient = RestClient.create();

    public AppleTokenClient(
            @Value("${auth.apple.team-id}") String teamId,
            @Value("${auth.apple.key-id}") String keyId,
            @Value("${apple.bundle-id}") String bundleId,
            @Value("${auth.apple.private-key-base64}") String privateKeyBase64) {
        this.teamId = teamId;
        this.keyId = keyId;
        this.bundleId = bundleId;
        this.privateKey = parsePrivateKey(privateKeyBase64);
    }

    // .p8 파일 내용(PEM, 여러 줄)을 그대로 환경변수에 넣을 수 없어서 base64로 한 줄로 감싸 둔 값을
    // 여기서 원래 PEM 텍스트로 복원한 뒤, PKCS#8 DER 바이트를 뽑아 EC 개인키로 파싱함.
    // Nimbus 10.9엔 PEM을 바로 읽는 공개 API가 없어서(package-private + Bouncy Castle 의존) 표준
    // JDK(KeyFactory)만으로 처리 — 설정값이 잘못됐으면 기동 시점에 바로 실패해서 원인을 알 수 있게 함
    private static ECPrivateKey parsePrivateKey(String privateKeyBase64) {
        try {
            String pem = new String(Base64.getDecoder().decode(privateKeyBase64.trim()));
            String base64Der = pem
                    .replace("-----BEGIN PRIVATE KEY-----", "")
                    .replace("-----END PRIVATE KEY-----", "")
                    .replaceAll("\\s", "");
            byte[] der = Base64.getDecoder().decode(base64Der);
            PrivateKey key = KeyFactory.getInstance("EC").generatePrivate(new PKCS8EncodedKeySpec(der));
            return (ECPrivateKey) key;
        } catch (Exception e) {
            throw new IllegalStateException(
                    "Apple private key(.p8) 파싱 실패 — auth.apple.private-key-base64 값을 확인할 것", e);
        }
    }

    private String generateClientSecret() throws JOSEException {
        Instant now = Instant.now();
        JWSHeader header = new JWSHeader.Builder(JWSAlgorithm.ES256).keyID(keyId).build();
        JWTClaimsSet claims = new JWTClaimsSet.Builder()
                .issuer(teamId)
                .subject(bundleId)
                .audience(APPLE_AUDIENCE)
                .issueTime(Date.from(now))
                .expirationTime(Date.from(now.plusSeconds(CLIENT_SECRET_TTL_SECONDS)))
                .build();
        SignedJWT jwt = new SignedJWT(header, claims);
        jwt.sign(new ECDSASigner(privateKey));
        return jwt.serialize();
    }

    // 로그인 흐름 전용 — authorizationCode는 5분 내 만료되므로 로그인 요청 처리 중 바로 호출해야 함.
    // 여기서 실패해도 예외를 밖으로 던지지 않고 Optional.empty()로 삼켜서, 호출자(AppleAuthService)가
    // 로그인 자체를 막지 못하게 함(요구사항: 이 교환이 실패해도 로그인은 항상 성공해야 함)
    @SuppressWarnings("unchecked")
    public Optional<String> exchangeAuthorizationCode(String authorizationCode) {
        try {
            String clientSecret = generateClientSecret();
            MultiValueMap<String, String> form = new LinkedMultiValueMap<>();
            form.add("grant_type", "authorization_code");
            form.add("code", authorizationCode);
            form.add("client_id", bundleId);
            form.add("client_secret", clientSecret);

            Map<String, Object> body = restClient.post()
                    .uri(TOKEN_URL)
                    .contentType(MediaType.APPLICATION_FORM_URLENCODED)
                    .body(form)
                    .retrieve()
                    .body(Map.class);

            Object refreshToken = body != null ? body.get("refresh_token") : null;
            if (refreshToken instanceof String token && !token.isBlank()) {
                return Optional.of(token);
            }
            log.warn("Apple 토큰 교환 응답에 refresh_token이 없음: {}", body);
            return Optional.empty();
        } catch (RestClientException | JOSEException e) {
            log.warn("Apple authorizationCode -> refresh_token 교환 실패(로그인 자체는 계속 진행됨)", e);
            return Optional.empty();
        }
    }
}
