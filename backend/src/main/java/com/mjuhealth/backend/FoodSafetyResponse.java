package com.mjuhealth.backend;

import com.fasterxml.jackson.annotation.JsonProperty;

import java.util.List;

// 식약처 식품영양성분DB정보 오픈API(apis.data.go.kr, 데이터ID 15127578)의 JSON 응답 구조를
// 그대로 옮긴 매핑용 record. data.go.kr 문서 템플릿엔 보통 response.header/response.body로
// 한 겹 더 감싸는 경우가 많지만, 이 API는 response 래퍼 없이 header/body가 바로 최상위에 옴
// (실제 curl 호출로 확인 — 예전에 쓰던 I2790 서비스는 폐지되어 새로 조사함)
public record FoodSafetyResponse(Header header, Body body) {

    public record Header(String resultCode, String resultMsg) {}

    // 검색결과가 0건이면 items 자체가 응답에서 빠짐(null) — FoodSearchService에서 null 체크 필요
    public record Body(Integer totalCount, List<Item> items) {}

    public record Item(
            @JsonProperty("FOOD_NM_KR") String foodNmKr,
            @JsonProperty("AMT_NUM1") String amtNum1,
            @JsonProperty("AMT_NUM4") String amtNum4,
            @JsonProperty("SERVING_SIZE") String servingSize,
            // 품목대표(순수 재료/일반 음식) vs 상용제품(특정 브랜드 가공식품) 구분 — 검색 결과 정렬에만 쓰고
            // 프론트로 내려가는 FoodSearchResult엔 안 들어감 (FoodSearchService.sortByRelevance 참고)
            @JsonProperty("DB_CLASS_NM") String dbClassNm
    ) {}
}
