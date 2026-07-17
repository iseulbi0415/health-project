package com.mjuhealth.backend;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.List;

@RestController
@RequestMapping("/api/foods")
@CrossOrigin(origins = "*")
public class FoodController {

    @Autowired
    private FoodRepository foodRepository;

    @PostMapping(produces = "application/json;charset=UTF-8")
    public Food createFood(@RequestBody Food food) {
        // 저장 시각은 클라이언트가 보내도 무시하고 서버 기준 현재 시각으로 고정
        food.setRecordedAt(LocalDateTime.now());
        return foodRepository.save(food);
    }

    @GetMapping(produces = "application/json;charset=UTF-8")
    public List<Food> getAllFoods() {
        return foodRepository.findAll();
    }

    @PutMapping(value = "/{id}", produces = "application/json;charset=UTF-8")
    public Food updateFood(@PathVariable Long id, @RequestBody Food food) {
        Food existing = foodRepository.findById(id).orElseThrow();
        food.setId(id);
        // 요청 바디에 recordedAt이 없으면(null) 기존 값 유지 — 프론트가 아직 이 값을 안 보내므로
        // 그대로 두면 수정할 때마다 시각이 null로 덮어써짐
        if (food.getRecordedAt() == null) {
            food.setRecordedAt(existing.getRecordedAt());
        }
        return foodRepository.save(food);
    }

    @DeleteMapping("/{id}")
    public void deleteFood(@PathVariable Long id) {
        foodRepository.deleteById(id);
    }
}


