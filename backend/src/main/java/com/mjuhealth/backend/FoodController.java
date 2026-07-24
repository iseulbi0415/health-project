package com.mjuhealth.backend;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

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

        Long userId = principal.getInternalUserId();
        LocalDate day = food.getRecordedAt().toLocalDate();
        // 같은 날짜·같은 끼니에 동일한 음식을 또 추가한 경우, 새 행을 쌓는 대신
        // 기존 행에 수량/칼로리를 합쳐서 "오늘 먹은 음식" 리스트가 중복으로 늘어나지 않게 함
        Optional<Food> existing = foodRepository.findByUserIdAndNameAndMealAndRecordedAtGreaterThanEqualAndRecordedAtLessThan(
                userId, food.getName(), food.getMeal(), day.atStartOfDay(), day.plusDays(1).atStartOfDay());
        if (existing.isPresent()) {
            Food merged = existing.get();
            merged.setQuantity(merged.getQuantity() + 1);
            merged.setCalorie(merged.getCalorie() + food.getCalorie());
            merged.setFatGrams(sumNullableFat(merged.getFatGrams(), food.getFatGrams()));
            return foodRepository.save(merged);
        }

        food.setUser(userRepository.findById(userId).orElseThrow());
        return foodRepository.save(food);
    }

    // 지방(g)은 검색으로 추가한 음식만 값이 있어서, 병합 시 둘 다 없으면 null 유지하고
    // 하나라도 있으면 있는 값만 더함 — 지방 미상 즐겨찾기와 정확값 있는 검색 음식이 같은 끼니에
    // 섞여 병합돼도 끼니 단위 합산(app.js)이 깨지지 않게 함
    private Double sumNullableFat(Double a, Double b) {
        if (a == null && b == null) return null;
        return (a == null ? 0 : a) + (b == null ? 0 : b);
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
