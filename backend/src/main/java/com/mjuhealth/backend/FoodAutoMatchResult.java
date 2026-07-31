package com.mjuhealth.backend;

// /api/food-search/auto 응답 — 검색어에 대해 자동으로 확정된 음식 하나.
// calorie/fatGrams는 FoodSearchResult와 동일하게 100g 기준값 그대로(환산하지 않음).
// estimatedServingCalorie/estimatedServingFatGrams는 100g 기준값 × estimatedServingGrams ÷ 100으로
// 백엔드에서 미리 계산한 실제 1인분 값 — 소화 타이머(안전 기능)에 들어가는 값이라 웹/iOS가 각자
// 계산하지 않고 여기서 한 번만 계산해서 내려줌(FoodAutoMatchService 참고)
// matchType: "exact"(완전일치 중 칼로리 중앙값 최근접 선택) / "ai-selected"(AI가 후보 중 선택)
//          / "fallback"(AI 선택 실패 → 관련도순 1위 사용)
public record FoodAutoMatchResult(
        String name,
        Integer calorie,
        Double fatGrams,
        Integer estimatedServingGrams,
        Integer estimatedServingCalorie,
        Double estimatedServingFatGrams,
        String matchType,
        boolean isServingEstimateFallback
) {}
