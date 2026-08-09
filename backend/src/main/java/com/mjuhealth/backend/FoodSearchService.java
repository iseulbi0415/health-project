package com.mjuhealth.backend;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;

@Slf4j
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
    // API 응답 자체는 관련성 순 정렬이 아니라서, 우리 쪽에서 재정렬할 여유분을 확보하려고
    // 실제 필요한 것보다 넉넉하게 받아옴 — 정렬 후 상위 MAX_RESULTS개만 잘라서 씀.
    // 500은 이 API가 허용하는 numOfRows 최댓값(curl로 직접 확인 — 초과 요청 시 파라미터 오류 응답)
    private static final int FETCH_ROWS = 500;

    @Value("${food.api.service-key}")
    private String serviceKey;

    private final RestClient restClient = RestClient.create();

    public List<FoodSearchResult> search(String keyword) {
        return fetchSortedCandidates(keyword).stream()
                .map(this::toResult)
                .toList();
    }

    // FoodAutoMatchService(음식 자동 매칭)가 AI 후보 선택 프롬프트에 분류(음식/가공식품/원재료성)도 같이
    // 넣어야 해서 필요한 조회. FoodSearchResult(웹/iOS로 나가는 응답)엔 분류 필드가 없고(그쪽엔 불필요한
    // 정보라 의도적으로 뺐음, FoodSafetyResponse.java 주석 참고) 그 계약을 건드리지 않기 위해 별도로 둠
    public record CandidateWithCategory(FoodSearchResult result, String category) {}

    public List<CandidateWithCategory> searchWithCategory(String keyword) {
        return fetchSortedCandidates(keyword).stream()
                .map(item -> new CandidateWithCategory(toResult(item), item.dbGrpNm()))
                .toList();
    }

    private List<FoodSafetyResponse.Item> fetchSortedCandidates(String keyword) {
        List<FoodSafetyResponse.Item> results = fetchSortedCandidatesForLiteralKeyword(keyword);
        // 식약처 DB에 등록된 이름엔 공백이 거의 없음(예: "까르보불닭맛팝콘") — API가 단순 문자열
        // 포함검색이라 검색어에 공백이 섞이면("까르보 불닭") 매칭을 아예 못 찾는 경우가 있어서,
        // 그대로 조회해 0건이면 공백만 지우고 한 번 더 시도함. 원래 결과가 있던 검색어는 여기 안 옴
        if (results.isEmpty() && keyword != null && keyword.contains(" ")) {
            String withoutSpaces = keyword.replaceAll("\\s+", "");
            if (!withoutSpaces.isEmpty()) {
                results = fetchSortedCandidatesForLiteralKeyword(withoutSpaces);
            }
        }
        return results;
    }

    private List<FoodSafetyResponse.Item> fetchSortedCandidatesForLiteralKeyword(String keyword) {
        // [PERF-TEMP] 음식 검색 20초 지연 원인 측정용 임시 로그 — 원인 파악 후 제거 예정
        long perfStart = System.currentTimeMillis();
        String encodedKeyword = URLEncoder.encode(keyword, StandardCharsets.UTF_8);

        try {
            FoodSafetyResponse firstPage = fetchPage(encodedKeyword, 1);
            log.info("[PERF-TEMP] 식약처 1페이지 조회: keyword={}, 소요={}ms", keyword, System.currentTimeMillis() - perfStart);
            // resultCode "00"이 정상. 검색결과 0건일 때도 "00"은 오지만 이땐 body.items 자체가 응답에서
            // 빠지므로(null) 어느 경우든 화면은 "검색결과 없음"으로 처리하면 충분해 예외 없이 빈 리스트로 통일
            if (firstPage == null || firstPage.header() == null
                    || !"00".equals(firstPage.header().resultCode())
                    || firstPage.body() == null || firstPage.body().items() == null) {
                log.info("[PERF-TEMP] 식약처 조회 종료(결과없음): keyword={}, 총소요={}ms", keyword, System.currentTimeMillis() - perfStart);
                return List.of();
            }

            List<FoodSafetyResponse.Item> items = new ArrayList<>(firstPage.body().items());

            // 원재료성(생것 등 순수 식재료) 항목이 등록순 마지막 페이지 쪽에 몰려있는 경우가 많음 — curl로
            // 직접 여러 키워드("사과"/"바나나"/"닭가슴살")를 확인해서 실제로 그런 경향을 확인함. 검색어에 따라
            // 총 건수가 수천 건까지 나와서 전체를 다 받기엔 비용이 크므로, 첫 페이지 + 마지막 페이지만 받아서
            // 절충함 (완벽하진 않지만 — "돼지고기"처럼 첫 페이지에도 원재료성이 꽤 섞여 나오는 키워드도 있었음)
            Integer totalCount = firstPage.body().totalCount();
            if (totalCount != null && totalCount > FETCH_ROWS) {
                int lastPageNo = (totalCount + FETCH_ROWS - 1) / FETCH_ROWS;
                if (lastPageNo > 1) {
                    long secondPageStart = System.currentTimeMillis();
                    FoodSafetyResponse lastPage = fetchPage(encodedKeyword, lastPageNo);
                    log.info("[PERF-TEMP] 식약처 마지막 페이지({}) 조회: keyword={}, totalCount={}, 소요={}ms",
                            lastPageNo, keyword, totalCount, System.currentTimeMillis() - secondPageStart);
                    if (lastPage != null && lastPage.body() != null && lastPage.body().items() != null) {
                        items.addAll(lastPage.body().items());
                    }
                }
            }

            List<FoodSafetyResponse.Item> result = sortByRelevance(items, keyword).stream()
                    .limit(MAX_RESULTS)
                    .toList();
            log.info("[PERF-TEMP] 식약처 조회+정렬 종료: keyword={}, 총소요={}ms, 결과={}건", keyword, System.currentTimeMillis() - perfStart, result.size());
            return result;
        } catch (Exception e) {
            // 식약처 API 장애(네트워크 오류, 응답 포맷 변경 등)로 우리 앱 전체가 죽으면 안 되므로
            // 실패 시에도 빈 리스트만 반환 — 사용자는 "검색결과 없음"으로 보고 즐겨찾기/직접추가로 대체 가능
            log.warn("[PERF-TEMP] 식약처 조회 실패: keyword={}, 총소요={}ms", keyword, System.currentTimeMillis() - perfStart, e);
            return List.of();
        }
    }

    private FoodSafetyResponse fetchPage(String encodedKeyword, int pageNo) {
        String url = String.format("%s?serviceKey=%s&pageNo=%d&numOfRows=%d&type=json&FOOD_NM_KR=%s",
                ENDPOINT, serviceKey, pageNo, FETCH_ROWS, encodedKeyword);
        // [PERF-TEMP] restClient에 타임아웃이 없어서 식약처 API가 응답을 안 주면 여기서 무한정
        // 대기할 수 있음 — 이 로그 다음에 "호출 완료" 로그가 안 찍히면 바로 여기서 멈춘 것
        log.info("[PERF-TEMP] 식약처 API 호출 시작: pageNo={}", pageNo);
        long callStart = System.currentTimeMillis();
        FoodSafetyResponse response = restClient.get().uri(url).retrieve().body(FoodSafetyResponse.class);
        log.info("[PERF-TEMP] 식약처 API 호출 완료: pageNo={}, 소요={}ms", pageNo, System.currentTimeMillis() - callStart);
        return response;
    }

    // "사과" 검색 시 사과잼/사과과자 같은 가공식품이 순수 재료보다 먼저 나오는 문제 대응 —
    // API 응답 자체엔 관련성 정렬이 없어서 우리 쪽에서 3단계로 재정렬함:
    // ① 검색어와 이름이 얼마나 정확히 일치하는지(완전일치 > 접두일치 > 단순포함)
    // ② 같은 순위 안에서는 원재료성(생것 등 순수 식재료)을 음식/가공식품보다 앞에 둠
    // ③ 그다음으로 품목대표(순수 재료/일반 음식)를 상용제품(브랜드 가공식품)보다 앞에 둠
    private List<FoodSafetyResponse.Item> sortByRelevance(List<FoodSafetyResponse.Item> items, String keyword) {
        return items.stream()
                .sorted(Comparator
                        .<FoodSafetyResponse.Item>comparingInt(item -> matchRank(item.foodNmKr(), keyword))
                        .thenComparingInt(item -> "원재료성".equals(item.dbGrpNm()) ? 0 : 1)
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
