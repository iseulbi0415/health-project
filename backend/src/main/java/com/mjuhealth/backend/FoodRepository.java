package com.mjuhealth.backend;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface FoodRepository extends JpaRepository<Food, Long>{
    List<Food> findByUserId(Long userId);
}
