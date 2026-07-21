package com.mjuhealth.backend;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface MemoRepository extends JpaRepository<Memo, Long> {
    List<Memo> findByUserId(Long userId);

    // date는 String이지만 항상 "yyyy-MM-dd" ISO 형식으로 저장되므로 문자열 비교/범위로도 정상 동작
    List<Memo> findByUserIdAndDate(Long userId, String date);
    List<Memo> findByUserIdAndDateBetween(Long userId, String start, String end);
}
