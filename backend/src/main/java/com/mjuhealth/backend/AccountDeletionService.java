package com.mjuhealth.backend;

import com.nimbusds.jose.JOSEException;
import jakarta.servlet.http.Cookie;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.client.JdkClientHttpRequestFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;

import java.net.http.HttpClient;
import java.time.Duration;

// 회원 탈퇴(DELETE /api/auth/me) 실제 로직. Food/Run/Memo/Favorite를 먼저 지우고(FK 제약) User를
// 지운 뒤, 외부 연동(Apple revoke/Kakao unlink)은 best-effort로만 시도한다 — 여기서 실패해도
// 이미 끝난 로컬 삭제는 되돌리지 않고 로그만 남긴다(App Store 5.1.1(v) 요건상 계정 삭제 자체가
// 외부 서비스 상태에 발목 잡히면 안 됨).
@Slf4j
@Service
public class AccountDeletionService {

    private static final String KAKAO_UNLINK_URL = "https://kapi.kakao.com/v1/user/unlink";

    private final UserRepository userRepository;
    private final FoodRepository foodRepository;
    private final RunRepository runRepository;
    private final MemoRepository memoRepository;
    private final FavoriteRepository favoriteRepository;
    private final AppleTokenClient appleTokenClient;
    private final String kakaoAdminKey;
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

    public AccountDeletionService(
            UserRepository userRepository,
            FoodRepository foodRepository,
            RunRepository runRepository,
            MemoRepository memoRepository,
            FavoriteRepository favoriteRepository,
            AppleTokenClient appleTokenClient,
            @Value("${auth.kakao.admin-key}") String kakaoAdminKey) {
        this.userRepository = userRepository;
        this.foodRepository = foodRepository;
        this.runRepository = runRepository;
        this.memoRepository = memoRepository;
        this.favoriteRepository = favoriteRepository;
        this.appleTokenClient = appleTokenClient;
        this.kakaoAdminKey = kakaoAdminKey;
    }

    @Transactional
    public void deleteAccount(Long userId, HttpServletRequest request, HttpServletResponse response) {
        User user = userRepository.findById(userId).orElseThrow();
        // User row 삭제 후에도 detached 엔티티 getter로 읽을 순 있지만, 의도를 명확히 하려고
        // 삭제 전에 로컬 변수로 먼저 빼둠
        String appleId = user.getAppleId();
        String appleRefreshToken = user.getAppleRefreshToken();
        String kakaoId = user.getKakaoId();

        foodRepository.deleteByUserId(userId);
        runRepository.deleteByUserId(userId);
        memoRepository.deleteByUserId(userId);
        favoriteRepository.deleteByUserId(userId);
        userRepository.delete(user);

        if (appleId != null) {
            if (appleRefreshToken == null) {
                log.info("userId={}: Apple refreshToken 없음(구가입자, 재로그인 전으로 추정) — revoke 스킵", userId);
            } else {
                try {
                    appleTokenClient.revokeRefreshToken(appleRefreshToken);
                } catch (RestClientException | JOSEException e) {
                    log.warn("userId={}: Apple revoke 실패 — 로컬 계정 삭제는 이미 완료됨", userId, e);
                }
            }
        }
        if (kakaoId != null) {
            try {
                unlinkKakao(kakaoId);
            } catch (RestClientException e) {
                log.warn("userId={}: 카카오 unlink 실패 — 로컬 계정 삭제는 이미 완료됨", userId, e);
            }
        }

        invalidateSession(request, response);
    }

    private void unlinkKakao(String kakaoId) {
        MultiValueMap<String, String> form = new LinkedMultiValueMap<>();
        form.add("target_id_type", "user_id");
        form.add("target_id", kakaoId);

        restClient.post()
                .uri(KAKAO_UNLINK_URL)
                .header(HttpHeaders.AUTHORIZATION, "KakaoAK " + kakaoAdminKey)
                .contentType(MediaType.APPLICATION_FORM_URLENCODED)
                .body(form)
                .retrieve()
                .toBodilessEntity();
    }

    // SecurityConfig의 로그아웃과 동일한 이유로 리다이렉트 없이 호출자가 직접 200/204를 내려주게 함
    // (fetch가 리다이렉트를 따라가다 정적 파일 서버 응답을 못 읽어 실패하는 문제 — README 참고)
    private void invalidateSession(HttpServletRequest request, HttpServletResponse response) {
        HttpSession session = request.getSession(false);
        if (session != null) {
            session.invalidate();
        }
        Cookie cookie = new Cookie("JSESSIONID", null);
        cookie.setPath("/");
        cookie.setMaxAge(0);
        response.addCookie(cookie);
    }
}
