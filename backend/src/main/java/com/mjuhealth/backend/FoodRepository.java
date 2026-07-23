package com.mjuhealth.backend;

import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

public interface FoodRepository extends JpaRepository<Food, Long>{
    List<Food> findByUserId(Long userId);

    // 하루 필터링(GET ?date=)과 달력 월별 요약 양쪽에서 재사용
    List<Food> findByUserIdAndRecordedAtGreaterThanEqualAndRecordedAtLessThan(Long userId, LocalDateTime start, LocalDateTime end);

    // 같은 날짜·같은 끼니·같은 이름의 기존 기록을 찾아 중복 추가 시 합치기 위한 조회 (FoodController.createFood 참고)
    Optional<Food> findByUserIdAndNameAndMealAndRecordedAtGreaterThanEqualAndRecordedAtLessThan(
            Long userId, String name, String meal, LocalDateTime start, LocalDateTime end);
}
