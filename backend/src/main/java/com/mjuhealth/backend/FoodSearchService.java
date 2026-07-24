package com.mjuhealth.backend;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.Comparator;
import java.util.List;

@Service
public class FoodSearchService {

    // 식품의약품안전처_식품영양성분DB정보(데이터ID 15127578)의 실제 엔드포인트.
    // 예전에 쓰던 openapi.foodsafetykorea.go.kr/I2790은 폐지된 구버전이라(2026-07-24 curl로 직접 확인),
    // apis.data.go.kr 공통 게이트웨이 경유 주소로 교체함. 배포 환경과 무관하게 항상 같은 공개 주소라
    // 카카오 URL들과 달리 환경변수로 안 뺌
    private static final String ENDPOINT = "https://apis.data.go.kr/1471000/FoodNtrCpntDbInfo02/getFoodNtrCpntDbInq02";
    // 같은 음식명이 가공식품 제품 단위로 수백 건씩 잡히는 데이터 특성상,
    // 전부 보여주면 리스트가 지나치게 길어져서 앞쪽 결과만 자름
    private static final int MAX_RESULTS = 15;
    // API 응답 자체는 관련성 순 정렬이 아니라서(등록순으로 보임), 우리 쪽에서 재정렬할 여유분을 확보하려고
    // 실제 필요한 것보다 넉넉하게 받아옴 — 정렬 후 상위 MAX_RESULTS개만 잘라서 씀
    private static final int FETCH_ROWS = 30;

    @Value("${food.api.service-key}")
    private String serviceKey;

    private final RestClient restClient = RestClient.create();

    public List<FoodSearchResult> search(String keyword) {
        String encodedKeyword = URLEncoder.encode(keyword, StandardCharsets.UTF_8);
        String url = String.format("%s?serviceKey=%s&pageNo=1&numOfRows=%d&type=json&FOOD_NM_KR=%s",
                ENDPOINT, serviceKey, FETCH_ROWS, encodedKeyword);

        try {
            FoodSafetyResponse response = restClient.get().uri(url).retrieve().body(FoodSafetyResponse.class);
            // resultCode "00"이 정상. 검색결과 0건일 때도 "00"은 오지만 이땐 body.items 자체가 응답에서
            // 빠지므로(null) 어느 경우든 화면은 "검색결과 없음"으로 처리하면 충분해 예외 없이 빈 리스트로 통일
            if (response == null || response.header() == null
                    || !"00".equals(response.header().resultCode())
                    || response.body() == null || response.body().items() == null) {
                return List.of();
            }
            return sortByRelevance(response.body().items(), keyword).stream()
                    .limit(MAX_RESULTS)
                    .map(this::toResult)
                    .toList();
        } catch (Exception e) {
            // 식약처 API 장애(네트워크 오류, 응답 포맷 변경 등)로 우리 앱 전체가 죽으면 안 되므로
            // 실패 시에도 빈 리스트만 반환 — 사용자는 "검색결과 없음"으로 보고 즐겨찾기/직접추가로 대체 가능
            return List.of();
        }
    }

    // "사과" 검색 시 사과잼/사과과자 같은 가공식품이 순수 재료보다 먼저 나오는 문제 대응 —
    // API 응답 자체엔 관련성 정렬이 없어서 우리 쪽에서 2단계로 재정렬함:
    // ① 검색어와 이름이 얼마나 정확히 일치하는지(완전일치 > 접두일치 > 단순포함)
    // ② 같은 순위 안에서는 품목대표(순수 재료/일반 음식)를 상용제품(브랜드 가공식품)보다 앞에 둠
    private List<FoodSafetyResponse.Item> sortByRelevance(List<FoodSafetyResponse.Item> items, String keyword) {
        return items.stream()
                .sorted(Comparator
                        .<FoodSafetyResponse.Item>comparingInt(item -> matchRank(item.foodNmKr(), keyword))
                        .thenComparingInt(item -> "품목대표".equals(item.dbClassNm()) ? 0 : 1))
                .toList();
    }

    private int matchRank(String foodName, String keyword) {
        if (foodName == null) return 3;
        if (foodName.equalsIgnoreCase(keyword)) return 0;
        if (foodName.startsWith(keyword)) return 1;
        return 2;
    }

    private FoodSearchResult toResult(FoodSafetyResponse.Item item) {
        return new FoodSearchResult(item.foodNmKr(), parseIntSafe(item.amtNum1()), parseDoubleSafe(item.amtNum4()),
                item.servingSize());
    }

    private Integer parseIntSafe(String value) {
        try {
            return value == null || value.isBlank() ? null : (int) Double.parseDouble(value);
        } catch (NumberFormatException e) {
            return null;
        }
    }

    private Double parseDoubleSafe(String value) {
        try {
            return value == null || value.isBlank() ? null : Double.parseDouble(value);
        } catch (NumberFormatException e) {
            return null;
        }
    }
}
