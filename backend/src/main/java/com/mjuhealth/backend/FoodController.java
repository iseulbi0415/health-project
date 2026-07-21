package com.mjuhealth.backend;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

@RestController
@RequestMapping("/api/foods")
public class FoodController {

    @Autowired
    private FoodRepository foodRepository;
    @Autowired
    private UserRepository userRepository;

    @PostMapping(produces = "application/json;charset=UTF-8")
    public Food createFood(@RequestBody Food food, @AuthenticationPrincipal KakaoOAuth2User principal) {
        // 요청에 recordedAt이 이미 있으면(달력에서 과거 날짜 지정) 그 값을 존중하고,
        // 없으면(평소처럼 즐겨찾기 pill로 "지금 먹었어요") 서버 현재 시각을 기본값으로 채움
        if (food.getRecordedAt() == null) {
            food.setRecordedAt(LocalDateTime.now());
        }
        food.setUser(userRepository.findById(principal.getInternalUserId()).orElseThrow());
        return foodRepository.save(food);
    }

    @GetMapping(produces = "application/json;charset=UTF-8")
    public List<Food> getAllFoods(@RequestParam(required = false) String date, @AuthenticationPrincipal KakaoOAuth2User principal) {
        if (date != null) {
            LocalDate day = LocalDate.parse(date);
            return foodRepository.findByUserIdAndRecordedAtGreaterThanEqualAndRecordedAtLessThan(
                    principal.getInternalUserId(), day.atStartOfDay(), day.plusDays(1).atStartOfDay());
        }
        return foodRepository.findByUserId(principal.getInternalUserId());
    }

    @PutMapping(value = "/{id}", produces = "application/json;charset=UTF-8")
    public Food updateFood(@PathVariable Long id, @RequestBody Food food, @AuthenticationPrincipal KakaoOAuth2User principal) {
        Food existing = foodRepository.findById(id).orElseThrow();
        // id만 바꿔서 남의 기록에 접근하는 걸 막는 소유권 확인
        if (!existing.getUser().getId().equals(principal.getInternalUserId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN);
        }
        food.setId(id);
        // 요청 바디의 user 값은 무시하고 기존 소유자로 고정 — 안 그러면 body에 다른 user를 넣어 소유권을 넘길 수 있음
        food.setUser(existing.getUser());
        // 요청 바디에 recordedAt이 없으면(null) 기존 값 유지 — 프론트가 아직 이 값을 안 보내므로
        // 그대로 두면 수정할 때마다 시각이 null로 덮어써짐
        if (food.getRecordedAt() == null) {
            food.setRecordedAt(existing.getRecordedAt());
        }
        return foodRepository.save(food);
    }

    @DeleteMapping("/{id}")
    public void deleteFood(@PathVariable Long id, @AuthenticationPrincipal KakaoOAuth2User principal) {
        Food existing = foodRepository.findById(id).orElseThrow();
        if (!existing.getUser().getId().equals(principal.getInternalUserId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN);
        }
        foodRepository.deleteById(id);
    }
}
