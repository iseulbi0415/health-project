package com.mjuhealth.backend;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import lombok.Getter;
import lombok.Setter;

@Entity
@Getter
@Setter
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(unique = true, nullable = false)
    private String kakaoId;

    private String nickname;

    // "내 정보"(BMR/목표 칼로리 계산용 입력값) — 예전엔 iOS에서 UserDefaults에만 저장해서 앱 삭제 시
    // 같이 사라지는 문제가 있었음. 이제 로그인 시 서버에서 복원할 수 있도록 User에 같이 저장함
    private Double heightCm;
    private Double weightKg;
    private Integer age;
    private String gender;
    private Integer activityLevel;
    // 입력값만 채워져 있고 "계산" 버튼을 안 눌렀으면 목표 칼로리를 안 보여주는 정책이라, 값 존재
    // 여부와 별개로 이 플래그를 명시적으로 둠(iOS ProfileView의 hasCalculatedGoal과 동일한 의미)
    private boolean hasCalculatedGoal;
}
