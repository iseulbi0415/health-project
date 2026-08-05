package com.mjuhealth.backend;

import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import lombok.Getter;
import lombok.Setter;

@Entity
@Getter
@Setter
public class Favorite {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    private String name;
    private int calorie;
    // iOS DigestCategory의 rawValue(2=가벼움/3=보통/4=무거움)를 그대로 저장
    private int digestCategory;
    private boolean isTrigger;
    // 즐겨찾기 수동 등록은 null, 검색/자동매칭에서 등록한 건 실측값
    private Double fatGrams;

    @ManyToOne(optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;
}
