package com.mjuhealth.backend;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpStatus;
import org.springframework.security.config.Customizer;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.HttpStatusEntryPoint;
import org.springframework.security.web.servlet.util.matcher.PathPatternRequestMatcher;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

import java.util.List;

@Configuration
public class SecurityConfig {

    private final KakaoOAuth2UserService kakaoOAuth2UserService;

    public SecurityConfig(KakaoOAuth2UserService kakaoOAuth2UserService) {
        this.kakaoOAuth2UserService = kakaoOAuth2UserService;
    }

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        // Spring Security 7부터 AntPathRequestMatcher가 삭제되어 PathPatternRequestMatcher로 대체됨
        PathPatternRequestMatcher.Builder mvc = PathPatternRequestMatcher.withDefaults();
        var apiMatcher = mvc.matcher("/api/**");

        http
            // 프론트가 fetch로만 호출하는 REST API라 CSRF 토큰을 다루는 코드가 없음 — 로컬 데모 범위라 비활성화
            // (세션+쿠키 인증에서 CSRF를 끄면 이론상 다른 사이트발 요청에 취약해질 수 있음 — 배포 전엔 토큰 방식 보호 추가 필요, CLAUDE.md 백로그 참고)
            .csrf(csrf -> csrf.disable())
            .cors(Customizer.withDefaults())
            .authorizeHttpRequests(auth -> auth
                .requestMatchers(mvc.matcher("/api/auth/me")).permitAll()
                .requestMatchers(apiMatcher).authenticated()
                .anyRequest().permitAll()
            )
            // 로그인 안 한 채로 /api/**를 호출하면 기본 동작은 카카오 로그인 페이지로 302 리다이렉트인데,
            // fetch는 그 리다이렉트를 그대로 따라가 로그인 HTML을 응답으로 받아버려서 response.json()이 깨짐
            // → API 경로는 401만 내려주고 프론트가 로그인 필요 상태를 판단하게 함
            .exceptionHandling(ex -> ex.defaultAuthenticationEntryPointFor(
                new HttpStatusEntryPoint(HttpStatus.UNAUTHORIZED), apiMatcher))
            .oauth2Login(oauth2 -> oauth2
                .userInfoEndpoint(userInfo -> userInfo.userService(kakaoOAuth2UserService))
                // 로그인 처리는 백엔드(8080)에서 일어나지만 화면은 프론트(5500)에 있어서
                // 로그인 성공 후 프론트 주소로 명시적으로 돌려보내야 함(기본값은 8080 루트라 빈 화면이 뜸)
                .successHandler((req, res, auth) -> res.sendRedirect("http://localhost:5500/index.html"))
            )
            .logout(logout -> logout
                .logoutUrl("/api/auth/logout")
                // 로그아웃은 프론트가 fetch로 호출 → 여기서 리다이렉트를 보내면 fetch가 그 리다이렉트를
                // 그대로 따라가다 Live Server(정적 파일 서버, CORS 헤더 없음) 응답을 못 읽어서 fetch 자체가 실패함
                // (로그인 때와 달리 화면 전환은 프론트 JS가 reload()로 직접 처리하므로 리다이렉트 자체가 불필요)
                .logoutSuccessHandler((req, res, auth) -> res.setStatus(HttpStatus.OK.value()))
                .invalidateHttpSession(true)
                .deleteCookies("JSESSIONID")
            );

        return http.build();
    }

    // @CrossOrigin은 Spring MVC 핸들러(@RequestMapping)에만 적용되는데, /api/auth/logout처럼
    // 실제 컨트롤러 메서드 없이 Security의 LogoutFilter가 직접 처리하는 경로는 @CrossOrigin이 안 먹혀서
    // 응답에 CORS 헤더가 안 붙는다 — 그래서 이 빈으로 CORS 설정을 한 곳에 모아 모든 경로에 일괄 적용
    @Bean
    public CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration config = new CorsConfiguration();
        config.setAllowedOrigins(List.of("http://localhost:5500"));
        config.setAllowedMethods(List.of("GET", "POST", "PUT", "DELETE", "OPTIONS"));
        config.setAllowedHeaders(List.of("*"));
        config.setAllowCredentials(true);

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", config);
        return source;
    }
}
