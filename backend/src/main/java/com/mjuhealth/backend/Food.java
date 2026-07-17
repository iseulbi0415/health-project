package com.mjuhealth.backend;

import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import lombok.Getter;
import lombok.Setter;

import java.time.LocalDateTime;

@Entity
@Getter
@Setter

public class Food {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    private String name;
    private  int calorie;
    private String digestTime;
    // Lombok이 boolean 필드 isTrigger에 대해 getter는 isTrigger(), setter는 setTrigger()로
    // 비대칭 생성하는 바람에 Jackson이 JSON 프로퍼티명을 "trigger"로 유도하는 문제가 있어
    // 프론트(app.js)와 맞추기 위해 JSON 프로퍼티명을 isTrigger로 고정함
    @JsonProperty("isTrigger")
    private boolean isTrigger;
    // 저장 시각: POST 때는 서버가 항상 자동으로 채우고, PUT 때만 값이 오면 갱신 (FoodController 참고)
    private LocalDateTime recordedAt;
}
