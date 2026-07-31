package com.mjuhealth.backend;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

// 기존 /api/food-search(웹이 의존 중)는 그대로 두고, 완전히 별도 엔드포인트로 추가한 자동 매칭 API.
// 인증은 SecurityConfig의 "/api/**" -> authenticated() 규칙에 자동으로 걸림(별도 어노테이션 불필요)
@RestController
@RequestMapping("/api/food-search/auto")
public class FoodAutoMatchController {

    private final FoodAutoMatchService foodAutoMatchService;

    public FoodAutoMatchController(FoodAutoMatchService foodAutoMatchService) {
        this.foodAutoMatchService = foodAutoMatchService;
    }

    @GetMapping(produces = "application/json;charset=UTF-8")
    public ResponseEntity<FoodAutoMatchResult> search(@RequestParam String keyword) {
        return foodAutoMatchService.autoMatch(keyword)
                .map(ResponseEntity::ok)
                .orElseGet(() -> ResponseEntity.noContent().build());
    }
}
