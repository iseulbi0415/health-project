package com.mjuhealth.backend;

import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

// "내 정보"(BMR 계산용 키/체중/나이/성별/활동량) 저장/조회 — 예전엔 iOS UserDefaults에만 있어서
// 앱 삭제 시 사라지던 데이터를 User 테이블에 같이 저장해서 로그인 시 복원 가능하게 함.
// Food/Run처럼 여러 건을 다루는 게 아니라 사용자당 1건이라 id 기반 CRUD 없이 GET/PUT만 있음
@RestController
@RequestMapping("/api/users/me/profile")
public class UserProfileController {

    private final UserRepository userRepository;

    public UserProfileController(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    public record ProfileDto(Double heightCm, Double weightKg, Integer age, String gender,
                              Integer activityLevel, boolean hasCalculatedGoal) {}

    @GetMapping(produces = "application/json;charset=UTF-8")
    public ProfileDto getProfile(@AuthenticationPrincipal KakaoOAuth2User principal) {
        User user = userRepository.findById(principal.getInternalUserId()).orElseThrow();
        return new ProfileDto(user.getHeightCm(), user.getWeightKg(), user.getAge(),
                user.getGender(), user.getActivityLevel(), user.isHasCalculatedGoal());
    }

    @PutMapping(produces = "application/json;charset=UTF-8")
    public ProfileDto updateProfile(@RequestBody ProfileDto body, @AuthenticationPrincipal KakaoOAuth2User principal) {
        User user = userRepository.findById(principal.getInternalUserId()).orElseThrow();
        user.setHeightCm(body.heightCm());
        user.setWeightKg(body.weightKg());
        user.setAge(body.age());
        user.setGender(body.gender());
        user.setActivityLevel(body.activityLevel());
        user.setHasCalculatedGoal(body.hasCalculatedGoal());
        userRepository.save(user);
        return body;
    }
}
