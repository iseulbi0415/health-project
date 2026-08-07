package com.mjuhealth.backend;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface MemoRepository extends JpaRepository<Memo, Long> {
    // OrderByDateDesc: 정렬을 안 주면 DB가 삽입 순서로 돌려줘서 최신 기록이 목록 뒤로 밀리는
    // 문제가 있었음(Run/Food와 동일). date는 "yyyy-MM-dd" 문자열 고정 형식이라 사전순 정렬이
    // 곧 날짜순 정렬과 같음
    List<Memo> findByUserIdOrderByDateDesc(Long userId);

    // date는 String이지만 항상 "yyyy-MM-dd" ISO 형식으로 저장되므로 문자열 비교/범위로도 정상 동작
    List<Memo> findByUserIdAndDate(Long userId, String date);
    List<Memo> findByUserIdAndDateBetween(Long userId, String start, String end);

    // 회원 탈퇴 시 User 삭제 전에 먼저 지워야 함(FK 제약) — AccountDeletionService 참고
    void deleteByUserId(Long userId);
}
