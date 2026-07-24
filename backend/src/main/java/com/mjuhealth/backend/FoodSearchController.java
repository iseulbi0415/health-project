package com.mjuhealth.backend;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/food-search")
public class FoodSearchController {

    private final FoodSearchService foodSearchService;

    public FoodSearchController(FoodSearchService foodSearchService) {
        this.foodSearchService = foodSearchService;
    }

    // 프론트가 식약처 API를 직접 호출하지 않고 이 엔드포인트를 거치게 해서, 인증키가
    // 프론트 코드나 브라우저 네트워크 탭에 노출되지 않게 함(카카오 키를 백엔드에만 두는 것과 같은 이유).
    // 인증은 SecurityConfig의 기존 "/api/**" → authenticated() 규칙에 자동으로 걸림
    @GetMapping(produces = "application/json;charset=UTF-8")
    public List<FoodSearchResult> search(@RequestParam String keyword) {
        return foodSearchService.search(keyword);
    }
}
