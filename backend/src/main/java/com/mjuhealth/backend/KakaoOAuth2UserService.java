package com.mjuhealth.backend;

import org.springframework.security.oauth2.client.userinfo.DefaultOAuth2UserService;
import org.springframework.security.oauth2.client.userinfo.OAuth2UserRequest;
import org.springframework.security.oauth2.core.OAuth2AuthenticationException;
import org.springframework.security.oauth2.core.user.OAuth2User;
import org.springframework.stereotype.Service;

import java.util.Map;

@Service
public class KakaoOAuth2UserService extends DefaultOAuth2UserService {

    private final UserRepository userRepository;

    public KakaoOAuth2UserService(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    @Override
    public OAuth2User loadUser(OAuth2UserRequest request) throws OAuth2AuthenticationException {
        OAuth2User oAuth2User = super.loadUser(request);

        String kakaoId = String.valueOf(oAuth2User.getAttributes().get("id"));
        String nickname = extractNickname(oAuth2User.getAttributes());

        User user = userRepository.findByKakaoId(kakaoId).orElseGet(User::new);
        user.setKakaoId(kakaoId);
        user.setNickname(nickname);
        userRepository.save(user);

        return new KakaoOAuth2User(oAuth2User, user.getId());
    }

    // kakao_account.profile.nickname이 기본 위치인데, 카카오 앱/동의항목 설정에 따라
    // properties.nickname(예전 방식)에만 값이 들어오는 경우도 있어서 둘 다 확인함
    // (출처: Kakao Developers 문서 - 카카오 로그인 > 이해하기 > 사용자 정보)
    @SuppressWarnings("unchecked")
    private String extractNickname(Map<String, Object> attributes) {
        Map<String, Object> kakaoAccount = (Map<String, Object>) attributes.get("kakao_account");
        if (kakaoAccount != null) {
            Map<String, Object> profile = (Map<String, Object>) kakaoAccount.get("profile");
            if (profile != null && profile.get("nickname") != null) {
                return (String) profile.get("nickname");
            }
        }
        Map<String, Object> properties = (Map<String, Object>) attributes.get("properties");
        if (properties != null) {
            return (String) properties.get("nickname");
        }
        return null;
    }
}
