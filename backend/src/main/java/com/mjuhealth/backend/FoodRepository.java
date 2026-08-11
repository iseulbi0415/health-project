package com.mjuhealth.backend;

import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

public interface FoodRepository extends JpaRepository<Food, Long>{
    // OrderByRecordedAtDesc: 정렬을 안 주면 DB가 삽입 순서로 돌려줘서 최신 기록이 목록 뒤로
    // 밀리는 문제가 있었음(Run과 동일). 끼니(아침/점심/저녁/간식) 순서는 고정 카테고리라 이 컬럼
    // 정렬로는 못 맞추므로 여전히 iOS(DietTimerView.groupedTodayFoods)에서 처리함.
    // 2차 키 IdDesc: recordedAt이 동률(즐겨찾기 연속 추가 등)이면 DB가 순서를 보장 안 해서, 화면마다
    // (DietTimerView vs DayDetailView) 다른 순서로 보이는 문제가 있었음 — id로 항상 고정시킴
    List<Food> findByUserIdOrderByRecordedAtDescIdDesc(Long userId);

    // 하루 필터링(GET ?date=)과 달력 월별 요약 양쪽에서 재사용
    List<Food> findByUserIdAndRecordedAtGreaterThanEqualAndRecordedAtLessThanOrderByRecordedAtDescIdDesc(Long userId, LocalDateTime start, LocalDateTime end);

    // 같은 날짜·같은 끼니·같은 이름의 기존 기록을 찾아 중복 추가 시 합치기 위한 조회 (FoodController.createFood 참고)
    Optional<Food> findByUserIdAndNameAndMealAndRecordedAtGreaterThanEqualAndRecordedAtLessThan(
            Long userId, String name, String meal, LocalDateTime start, LocalDateTime end);

    // 회원 탈퇴 시 User 삭제 전에 먼저 지워야 함(FK 제약) — AccountDeletionService 참고
    void deleteByUserId(Long userId);
}
