package com.mjuhealth.backend;

import org.springframework.stereotype.Service;

import java.util.Comparator;
import java.util.List;
import java.util.Optional;

// /api/food-search/auto 오케스트레이션 — 기존 FoodSearchService.searchWithCategory()를 재사용하고
// (관련도순 정렬 + 최대 15개는 이미 완전일치를 0순위로 두므로 이 기능에도 충분), 그 위에
// "여러 후보 중 하나를 자동으로 확정"하는 로직만 얹음. FoodSearchService.search()/Controller는 무수정
@Service
public class FoodAutoMatchService {

    private static final int AI_CANDIDATE_LIMIT = 10; // AI에게 보여줄 상위 후보 개수(요구사항의 5~10개 중 상한)
    private static final int DEFAULT_SERVING_GRAMS = 100; // 그램수 추정 실패 시 폴백값
    // exactMatches 중 가공식품 비율이 이 값 이상이면 표준화 제품으로 판단. 실측 데이터(진라면/신라면
    // 100%, 짬뽕 ~17%, 김치찌개 ~67%)로 세 사례 모두 의도대로 갈라지는 지점으로 정함
    private static final double STANDARDIZED_PRODUCT_RATIO_THRESHOLD = 0.8;

    private final FoodSearchService foodSearchService;
    private final AnthropicService anthropicService;

    public FoodAutoMatchService(FoodSearchService foodSearchService, AnthropicService anthropicService) {
        this.foodSearchService = foodSearchService;
        this.anthropicService = anthropicService;
    }

    public Optional<FoodAutoMatchResult> autoMatch(String keyword) {
        List<FoodSearchService.CandidateWithCategory> candidates = foodSearchService.searchWithCategory(keyword);
        if (candidates.isEmpty()) {
            return Optional.empty();
        }

        List<FoodSearchService.CandidateWithCategory> exactMatches = candidates.stream()
                .filter(c -> c.result().name() != null && c.result().name().equalsIgnoreCase(keyword)
                        && c.result().calorie() != null)
                .toList();

        FoodSearchService.CandidateWithCategory chosenCandidate;
        String matchType;
        boolean isStandardizedProduct;
        if (!exactMatches.isEmpty()) {
            chosenCandidate = pickClosestToMedian(exactMatches);
            matchType = "exact";
            // 대표값 하나의 분류만 보면 우연히 뽑힌 항목에 좌우되기 쉬움 — 예를 들어 "김치찌개"는
            // 정확일치 후보 중 가공식품(레토르트 제품)이 음식(가정식)보다 많아서, 중앙값 선택이
            // 하필 가공식품 쪽을 대표값으로 고르는 경우가 실제로 있었음. 그래서 정확일치 후보군
            // "전체"의 가공식품 비율로 판단함(FoodSafetyResponse.java 주석 참고 — DB_GRP_NM은
            // "음식"/"가공식품"/"원재료성" 3종류뿐)
            isStandardizedProduct = isStandardizedByRatio(exactMatches);
        } else {
            List<FoodSearchService.CandidateWithCategory> aiCandidates = candidates.stream()
                    .limit(AI_CANDIDATE_LIMIT)
                    .toList();
            List<AnthropicService.Candidate> aiInput = aiCandidates.stream()
                    .map(c -> new AnthropicService.Candidate(c.result().name(), c.category()))
                    .toList();
            Optional<Integer> aiIndex = anthropicService.selectBestMatchIndex(keyword, aiInput);

            if (aiIndex.isPresent()) {
                chosenCandidate = aiCandidates.get(aiIndex.get());
                matchType = "ai-selected";
            } else {
                // AI 선택이 실패해도 검색 자체가 막히면 안 되므로, 기존 검색과 동일하게 관련도순 1위로 폴백
                chosenCandidate = candidates.get(0);
                matchType = "fallback";
            }
            // 이 경로는 애초에 서로 다른 이름의 후보 중 하나를 고른 것이라(예: "아이스크림" 검색에
            // "돼지바"/"메로나" 등) "비율"이라는 개념이 성립하지 않음 — 선택된 후보 하나의 분류를 그대로 씀
            isStandardizedProduct = "가공식품".equals(chosenCandidate.category());
        }

        FoodSearchResult chosen = chosenCandidate.result();
        Optional<Integer> estimatedGrams = anthropicService.estimateServingGrams(chosen.name(), isStandardizedProduct);
        int servingGrams = estimatedGrams.orElse(DEFAULT_SERVING_GRAMS);

        // 100g 기준값 × 추정 1인분 그램수 ÷ 100 — 소화 타이머(안전 기능)에 들어가는 계산이라 웹/iOS가
        // 각자 하지 않도록 여기서 한 번만 계산해서 내려줌. calorie/fat이 null이면(파싱 실패 등) 같이 null로 둠
        Integer calorie = chosen.calorie();
        Double fat = chosen.fat();
        Integer estimatedServingCalorie = calorie == null ? null : Math.round(calorie * servingGrams / 100f);
        // 지방은 정수/1자리로 반올림하지 않음 — iOS DietTimerView의 소화 타이머가 지방 10g/25g 임계값으로
        // 분류하는데, 여기서 손실 반올림하면 그 경계가 밀릴 수 있어서 부동소수점 잡음만 정리하는 수준(소수 2자리)으로 둠
        Double estimatedServingFatGrams = fat == null ? null : Math.round(fat * servingGrams / 100.0 * 100) / 100.0;

        return Optional.of(new FoodAutoMatchResult(
                chosen.name(),
                calorie,
                fat,
                servingGrams,
                estimatedServingCalorie,
                estimatedServingFatGrams,
                matchType,
                estimatedGrams.isEmpty()
        ));
    }

    private boolean isStandardizedByRatio(List<FoodSearchService.CandidateWithCategory> exactMatches) {
        long processedCount = exactMatches.stream().filter(c -> "가공식품".equals(c.category())).count();
        return (double) processedCount / exactMatches.size() >= STANDARDIZED_PRODUCT_RATIO_THRESHOLD;
    }

    // 완전일치 그룹의 칼로리 중앙값(짝수 개면 중간 두 값의 평균)에 가장 가까운 항목을 대표값으로 선정.
    // 동률이면 칼로리가 더 높은 쪽을 택함 — 이 기능 전체가 "섭취 칼로리를 과소평가하지 않는다"는
    // 원칙(4번 그램수 추정과 동일한 맥락)을 따르도록 일관되게 맞춤
    private FoodSearchService.CandidateWithCategory pickClosestToMedian(List<FoodSearchService.CandidateWithCategory> exactMatches) {
        List<Integer> sortedCalories = exactMatches.stream()
                .map(c -> c.result().calorie())
                .sorted()
                .toList();
        int size = sortedCalories.size();
        double median = size % 2 == 1
                ? sortedCalories.get(size / 2)
                : (sortedCalories.get(size / 2 - 1) + sortedCalories.get(size / 2)) / 2.0;

        return exactMatches.stream()
                .min(Comparator
                        .comparingDouble((FoodSearchService.CandidateWithCategory c) -> Math.abs(c.result().calorie() - median))
                        .thenComparing(Comparator.comparingInt((FoodSearchService.CandidateWithCategory c) -> c.result().calorie()).reversed()))
                .orElseThrow();
    }
}
