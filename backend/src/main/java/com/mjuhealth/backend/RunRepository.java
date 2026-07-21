package com.mjuhealth.backend;

import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDateTime;
import java.util.List;

public interface RunRepository extends JpaRepository<Run, Long> {
    List<Run> findByUserId(Long userId);

    // 하루 필터링(GET ?date=)과 달력 월별 요약 양쪽에서 재사용
    List<Run> findByUserIdAndRecordedAtGreaterThanEqualAndRecordedAtLessThan(Long userId, LocalDateTime start, LocalDateTime end);
}
