package com.mjuhealth.backend;

import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDateTime;
import java.util.List;

public interface RunRepository extends JpaRepository<Run, Long> {
    // OrderByRecordedAtDesc: 정렬을 안 주면 DB가 삽입 순서로 돌려줘서, 달력에서 과거 날짜로
    // 기록을 추가하면 최신순 목록의 맨 아래에 붙는 버그가 있었음 — recordedAt 기준 내림차순으로 고정.
    // 2차 키 IdDesc: recordedAt이 동률(연속 추가 등)이면 DB가 순서를 보장 안 해서 화면마다 다른
    // 순서로 보이는 문제가 있었음(Food와 동일) — id로 항상 고정시킴
    List<Run> findByUserIdOrderByRecordedAtDescIdDesc(Long userId);

    // 하루 필터링(GET ?date=)과 달력 월별 요약 양쪽에서 재사용
    List<Run> findByUserIdAndRecordedAtGreaterThanEqualAndRecordedAtLessThanOrderByRecordedAtDescIdDesc(Long userId, LocalDateTime start, LocalDateTime end);

    // 회원 탈퇴 시 User 삭제 전에 먼저 지워야 함(FK 제약) — AccountDeletionService 참고
    void deleteByUserId(Long userId);
}
