package com.mjuhealth.backend;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface FavoriteRepository extends JpaRepository<Favorite, Long> {
    List<Favorite> findByUserId(Long userId);

    // 회원 탈퇴 시 User 삭제 전에 먼저 지워야 함(FK 제약) — AccountDeletionService 참고
    void deleteByUserId(Long userId);
}
