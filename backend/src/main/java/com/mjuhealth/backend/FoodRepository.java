package com.mjuhealth.backend;

import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDateTime;
import java.util.List;

public interface FoodRepository extends JpaRepository<Food, Long>{
    List<Food> findByUserId(Long userId);

    // 하루 필터링(GET ?date=)과 달력 월별 요약 양쪽에서 재사용
    List<Food> findByUserIdAndRecordedAtGreaterThanEqualAndRecordedAtLessThan(Long userId, LocalDateTime start, LocalDateTime end);
}
