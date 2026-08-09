package com.mjuhealth.backend;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.http.client.JdkClientHttpRequestFactory;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestClientResponseException;

import java.net.http.HttpClient;
import java.time.Duration;
import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.stream.Collectors;
import java.util.stream.IntStream;

// Claude Haiku 호출 전용 서비스 — 음식 자동 매칭(후보 선택)과 1인분 그램수 추정에 씀.
// 모든 호출이 항상 스키마에 맞는 구조화된 응답만 받도록 tool_choice로 강제함(auto는 안 씀 —
// AI가 최종 tool 호출을 가끔 빼먹는 실패율이 실측으로 확인돼서, 강제 가능한 곳은 항상 강제함).
// 표준화 제품 그램수 추정만 예외적으로 "web_search 강제 호출 → 그 결과를 대화에 이어붙여서
// estimate_serving 강제 호출"의 2단계로 나눠서, 검색과 최종 응답 둘 다 각자 강제되게 함.
// 어떤 이유로 실패하든(네트워크/HTTP 오류/응답 파싱 실패/범위 밖 값) 예외를 던지지 않고
// Optional.empty()로 귀결시킴 — 호출부(FoodAutoMatchService)가 검색 자체를 막지 않고 항상
// 폴백할 수 있어야 하기 때문
@Slf4j
@Service
public class AnthropicService {

    private static final String MODEL = "claude-haiku-4-5-20251001";
    private static final String ENDPOINT = "https://api.anthropic.com/v1/messages";
    private static final String ANTHROPIC_VERSION = "2023-06-01";
    private static final int MAX_SERVING_GRAMS = 5000; // 이보다 크면 AI가 이상한 값을 준 것으로 간주하고 폐기

    @Value("${claude.api.key}")
    private String apiKey;

    // 연결 3초/읽기 15초 — 이 코드베이스 최초의 타임아웃 설정. AI 호출이 오래 걸리거나 멈춰도
    // 음식 검색 자체(FoodAutoMatchService)가 무한정 블로킹되면 안 되기 때문에 짧게 잡음.
    // 읽기 타임아웃은 원래 8초였으나, estimateServingGrams()에 web_search가 추가되면서
    // 검색이 걸리는 요청은 응답이 더 오래 걸릴 수 있어 15초로 상향함
    private final RestClient restClient = RestClient.builder()
            .requestFactory(timeoutRequestFactory())
            .build();

    private static JdkClientHttpRequestFactory timeoutRequestFactory() {
        HttpClient httpClient = HttpClient.newBuilder()
                .connectTimeout(Duration.ofSeconds(3))
                .build();
        JdkClientHttpRequestFactory factory = new JdkClientHttpRequestFactory(httpClient);
        factory.setReadTimeout(Duration.ofSeconds(15));
        return factory;
    }

    // AI 후보 선택에 이름과 함께 넘기는 분류 — FoodSearchService.CandidateWithCategory의 category(DB_GRP_NM:
    // "음식"/"가공식품"/"원재료성")를 그대로 옮겨 담는 용도
    public record Candidate(String name, String category) {}

    // 완전일치가 없을 때, 관련도순 후보 목록 중 검색어와 가장 관련 있는 항목 하나를 AI가 고르게 함.
    // 새 값을 만들지 못하게 목록 인덱스만 답하도록 tool로 강제. 분류는 참고용 힌트로만 프롬프트에 넣음 —
    // "매운짬뽕" 검색 시 즉석식품이 선택된 사례를 조사해보니 실제로 그 키워드엔 조리식 후보가 아예
    // 없었던 것으로 확인됨(강제 규칙으로 만들면 조리식이 없는 검색어에서 억지로 왜곡될 수 있어 소프트 힌트로만 둠)
    public Optional<Integer> selectBestMatchIndex(String keyword, List<Candidate> candidates) {
        String numberedList = IntStream.range(0, candidates.size())
                .mapToObj(i -> i + ": " + candidates.get(i).name() + " (" + candidates.get(i).category() + ")")
                .collect(Collectors.joining("\n"));
        String prompt = "사용자가 '" + keyword + "'를 찾고 있습니다. 아래 후보 목록 중 이 검색어와 가장 관련 있는 "
                + "음식 하나를 select_food 도구로 골라주세요. 목록에 없는 새로운 값은 절대 만들지 말고, "
                + "반드시 아래 번호 중 하나만 고르세요.\n\n"
                + "각 후보 옆 괄호는 분류입니다 — '음식'은 일반 조리식(가정식·외식), '가공식품'은 즉석식품·브랜드 제품, "
                + "'원재료성'은 가공 안 된 재료입니다. 검색어가 특정 제품명이 아니라 일반적인 음식 이름처럼 보인다면 "
                + "'음식' 분류를 우선 고려해보되, 이건 참고용 힌트일 뿐 절대 규칙은 아니니 검색어와 후보 이름의 실제 "
                + "관련성을 최우선으로 판단해주세요.\n\n" + numberedList;

        Map<String, Object> tool = Map.of(
                "name", "select_food",
                "description", "후보 목록 중 검색어와 가장 관련 있는 음식 하나를 고른다",
                "input_schema", Map.of(
                        "type", "object",
                        "properties", Map.of(
                                "index", Map.of("type", "integer", "description", "가장 관련 있는 후보의 0부터 시작하는 인덱스")
                        ),
                        "required", List.of("index")
                )
        );

        return callTool(prompt, tool, "select_food")
                .flatMap(input -> extractInt(input, "index"))
                .filter(index -> index >= 0 && index < candidates.size());
    }

    private static final int ESTIMATION_ATTEMPTS = 3;
    // 블로킹 I/O(RestClient HTTP 호출) fan-out 전용 — Java 17이라 virtual thread(21+)는
    // 못 쓰고, 요청마다 새로 만들지 않도록 서비스 필드로 한 번만 생성해 재사용함
    private final ExecutorService estimationExecutor = Executors.newCachedThreadPool();

    // estimateServingGramsOnce()를 3번 병렬로 실행해서, 성공한 값들의 중앙값을 최종 결과로 씀
    // (자기일관성/self-consistency) — 아래 estimateServingGramsOnce() 주석 참고
    public Optional<Integer> estimateServingGrams(String foodName, boolean isStandardizedProduct) {
        long startedAt = System.currentTimeMillis();
        List<CompletableFuture<Optional<Integer>>> attempts = IntStream.range(0, ESTIMATION_ATTEMPTS)
                .mapToObj(i -> CompletableFuture.supplyAsync(() -> {
                    // [PERF-TEMP] 3회 시도가 실제로 병렬로 도는지 확인용 — 시작 시각이 서로 겹치고
                    // 스레드명이 다르면 병렬, 시작 시각이 앞 시도 종료 시각과 맞물리면 순차 실행 의심
                    long attemptStart = System.currentTimeMillis();
                    log.info("[PERF-TEMP] 그램수추정 시도{} 시작: food={}, thread={}, startedAt+{}ms",
                            i, foodName, Thread.currentThread().getName(), attemptStart - startedAt);
                    Optional<Integer> result = estimateServingGramsOnce(foodName, isStandardizedProduct);
                    log.info("[PERF-TEMP] 그램수추정 시도{} 종료: food={}, thread={}, 소요={}ms, 성공={}, 값={}",
                            i, foodName, Thread.currentThread().getName(),
                            System.currentTimeMillis() - attemptStart, result.isPresent(), result.orElse(null));
                    return result;
                }, estimationExecutor))
                .toList();

        List<Integer> successes = attempts.stream()
                .map(CompletableFuture::join)
                .flatMap(Optional::stream)
                .toList();

        log.info("estimateServingGrams({}): {}/{} 성공, {}ms 소요", foodName, successes.size(),
                ESTIMATION_ATTEMPTS, System.currentTimeMillis() - startedAt);

        if (successes.isEmpty()) {
            return Optional.empty();
        }
        return Optional.of(median(successes));
    }

    // 짝수 개일 때 중간 두 값의 평균(반올림) — FoodAutoMatchService.pickClosestToMedian()의
    // 중앙값 계산 방식과 동일한 관례를 그대로 따름(이 프로젝트에서 이미 확립된 패턴)
    private Integer median(List<Integer> values) {
        List<Integer> sorted = new ArrayList<>(values);
        Collections.sort(sorted);
        int size = sorted.size();
        if (size % 2 == 1) {
            return sorted.get(size / 2);
        }
        return Math.round((sorted.get(size / 2 - 1) + sorted.get(size / 2)) / 2f);
    }

    // 그램수 추정은 매 요청마다 값이 흔들리는 문제(예: 시리얼이 40g/50g/60g로 갈리는 사례)가
    // 있어서, 캐싱 대신 자기일관성(self-consistency) 방식을 씀 — 아래 estimateServingGrams()가
    // 이 메서드를 3번 병렬로 호출해서 성공한 값들의 중앙값을 최종 결과로 씀. temperature는
    // 일부러 낮추지 않음(그대로 API 기본값) — 3번의 시도가 서로 다른 값을 낼 수 있어야
    // 자기일관성 방식 자체가 의미가 있기 때문
    //
    // 확정된 음식 하나의 1인분(1회 제공량)을 그램(g) 단위로 추정. GERD 케어 앱이라 섭취 칼로리를
    // 과소평가하지 않는 게 더 안전하므로, 보수적으로(상한선에 가깝게) 추정하도록 명시적으로 지시함.
    //
    // isStandardizedProduct(호출부에서 exactMatches 중 DB_GRP_NM=="가공식품" 비율로 판단)일 때만
    // web_search 2단계 호출(callToolWithWebSearch)을 씀 — 조리식/원재료는 애초에 표준화된 포장
    // 단위가 없어서 검색이 무의미함. 표준화 제품이 아닐 땐 기존처럼 단일 강제 호출로 100% 구조화된
    // 응답을 보장함
    private Optional<Integer> estimateServingGramsOnce(String foodName, boolean isStandardizedProduct) {
        Map<String, Object> tool = Map.of(
                "name", "estimate_serving",
                "description", "특정 음식 1인분의 예상 중량을 그램(g) 단위로 추정한다",
                "input_schema", Map.of(
                        "type", "object",
                        "properties", Map.of(
                                "grams", Map.of("type", "number", "description", "1인분 예상 중량(g), 보수적으로(상한선에 가깝게) 추정")
                        ),
                        "required", List.of("grams")
                )
        );

        Optional<Map<String, Object>> toolInput;
        if (isStandardizedProduct) {
            // "공식 1회 제공량"을 그대로 물으면 안 됨 — 새우깡 같은 여러 번 나눠 먹는 스낵류는
            // 영양성분표의 "1회 제공량"이 법적/규제상 정의라 포장 전체보다 작게 표기되어 있어서
            // (예: 90g 봉지인데 라벨상 1회 제공량은 30g), 이 값을 그대로 쓰면 실제 섭취 칼로리를
            // 크게 과소평가하게 됨(새우깡 실측: 465kcal/봉지인데 181kcal로 나온 사례). 그래서
            // "실제로 한 번에 먹는 양"(작은 포장류는 보통 포장 전체)을 명시적으로 요청함.
            //
            // 반대로 "포장 전체"를 무조건 기준으로 하면 오레오처럼 낱개 소포장 여러 개가 박스
            // 하나에 들어있는 제품에서 박스 전체 칼로리(500kcal대)를 답해버리는 과대평가가 생김
            // (실측 사례). 박스/멀티팩과 낱개 소포장을 구분하라고 지시해도, "오레오"처럼 실제로
            // 미니 낱개(~20g대)/일반 스낵(~50g)/패밀리 박스(~180g대)가 전부 실존하는 제품은
            // web_search가 그때그때 다른 크기의 페이지를 찾아와서 답이 크게 들쭉날쭉함(실측:
            // 22g~180g). 이런 모호한 경우, 우연히 걸린 대용량 결과에 안 휩쓸리도록 "가장 흔하게
            // 파는 기본 사이즈"를 명시적으로 우선하게 함 — 완전히 결정론적이 되진 않지만 180g대
            // 같은 명백한 과대평가는 줄어들 것으로 기대함
            String searchPrompt = "'" + foodName + "' 제품을 웹에서 검색해서, 영양성분표의 공식 '1회 제공량'이 아니라 "
                    + "사람들이 실제로 한 번에 먹는 양과 그 칼로리를 찾아주세요. 봉지/팩 하나가 곧 판매 단위인 "
                    + "제품(예: 라면 1개, 과자 1봉지)이면 그 포장 전체가 기준입니다. 박스나 멀티팩처럼 낱개 소포장 "
                    + "여러 개가 한 세트로 들어있는 제품이면, 박스 전체가 아니라 낱개 소포장 하나를 기준으로 "
                    + "해주세요. 같은 제품이라도 미니/일반/대용량 패밀리팩 등 여러 크기로 팔리고 있다면, "
                    + "대용량·패밀리팩·기프트박스가 아니라 편의점이나 마트에서 가장 흔하게 파는 기본 사이즈를 "
                    + "기준으로 해주세요.";
            String followUpPrompt = "위 검색 결과를 바탕으로 '" + foodName + "'을 한 번에 먹을 때의 실제 섭취량을 "
                    + "그램(g) 단위로 추정해주세요. 영양성분표의 공식 1회 제공량이 아니라, 실제로 한 번에 먹는 양 "
                    + "기준입니다 — 봉지/팩 하나가 판매 단위면 포장 전체, 박스·멀티팩 안에 낱개 소포장이 여러 개 "
                    + "들어있는 구조면 박스 전체가 아니라 낱개 소포장 하나 기준입니다. 여러 크기(미니/일반/대용량 "
                    + "패밀리팩 등)가 있다면 대용량이 아니라 가장 흔하게 파는 기본 사이즈를 기준으로 하세요. "
                    + "이 값은 역류성 식도염(GERD) 케어 앱에서 섭취 칼로리를 계산하는 데 쓰입니다. 실제보다 적게 "
                    + "잡으면 위험하니, (기본 사이즈 기준 안에서) 상한선에 가깝게 보수적으로 추정해서 "
                    + "estimate_serving 도구로 답하세요. 검색 결과가 불충분하면 일반적인 지식으로 보수적으로 "
                    + "추정하세요.";

            toolInput = callToolWithWebSearch(searchPrompt, followUpPrompt, tool, "estimate_serving");
        } else {
            String prompt = "'" + foodName + "' 1인분(1회 제공량)은 보통 몇 g인가요? 이 값은 역류성 식도염(GERD) 케어 "
                    + "앱에서 섭취 칼로리를 계산하는 데 쓰입니다. 실제보다 적게 잡으면 위험하니, 일반적인 제공량 범위 중 "
                    + "상한선에 가깝게 보수적으로 추정해서 estimate_serving 도구로만 답해주세요.";

            toolInput = callTool(prompt, tool, "estimate_serving");
        }

        return toolInput
                .flatMap(input -> extractInt(input, "grams"))
                .filter(grams -> grams > 0 && grams <= MAX_SERVING_GRAMS);
    }

    // 단일 강제 호출 — tool_choice를 처음부터 toolName으로 고정해서 100% 구조화된 응답을 받음
    private Optional<Map<String, Object>> callTool(String prompt, Map<String, Object> tool, String toolName) {
        Map<String, Object> requestBody = new LinkedHashMap<>();
        requestBody.put("model", MODEL);
        requestBody.put("max_tokens", 200);
        requestBody.put("tools", List.of(tool));
        requestBody.put("tool_choice", Map.of("type", "tool", "name", toolName));
        requestBody.put("messages", List.of(Map.of("role", "user", "content", prompt)));

        return postMessages(requestBody).flatMap(this::extractToolUseInput);
    }

    // web_search를 쓰는 2단계 강제 호출. 예전엔 tool_choice: auto 하나로 "검색 후 정리"를 AI에게
    // 맡겼는데, AI가 정리(toolName 호출) 단계를 종종(실측 약 50%) 빼먹어서 조용히 폴백되는 문제가
    // 있었음 — 검색과 최종 응답을 각각 별도로 강제하는 두 번의 호출로 쪼개서 각자 100%에 가깝게
    // 안정적이게 함.
    // web_search 결과(encrypted_content 등)는 이 코드가 직접 읽을 수 없는 형태라(모델만 해석
    // 가능), 1차 응답의 content를 그대로 assistant 턴으로 대화에 이어붙여서 모델이 자기가 찾은
    // 검색 결과를 2차 호출에서도 계속 참조하게 함
    private Optional<Map<String, Object>> callToolWithWebSearch(String searchPrompt, String followUpPrompt, Map<String, Object> tool, String toolName) {
        Map<String, Object> webSearchTool = Map.of("type", "web_search_20250305", "name", "web_search");

        Map<String, Object> firstRequestBody = new LinkedHashMap<>();
        firstRequestBody.put("model", MODEL);
        firstRequestBody.put("max_tokens", 1024); // 검색 결과 + 모델이 이어 쓰는 요약 텍스트까지 담을 여유
        firstRequestBody.put("tools", List.of(webSearchTool));
        firstRequestBody.put("tool_choice", Map.of("type", "tool", "name", "web_search"));
        Map<String, Object> firstUserMessage = Map.of("role", "user", "content", searchPrompt);
        firstRequestBody.put("messages", List.of(firstUserMessage));

        // [PERF-TEMP] 표준화 제품 경로(웹 검색)의 두 호출 중 어디가 오래 걸리는지 분리 측정
        long webSearchStart = System.currentTimeMillis();
        Optional<Map<String, Object>> firstResponse = postMessages(firstRequestBody);
        log.info("[PERF-TEMP] 4.web_search 호출 소요={}ms, thread={}",
                System.currentTimeMillis() - webSearchStart, Thread.currentThread().getName());
        if (firstResponse.isEmpty()) {
            return Optional.empty();
        }
        Object firstContent = firstResponse.get().get("content");
        if (firstContent == null) {
            return Optional.empty();
        }

        Map<String, Object> secondRequestBody = new LinkedHashMap<>();
        secondRequestBody.put("model", MODEL);
        secondRequestBody.put("max_tokens", 200);
        secondRequestBody.put("tools", List.of(tool));
        secondRequestBody.put("tool_choice", Map.of("type", "tool", "name", toolName));
        secondRequestBody.put("messages", List.of(
                firstUserMessage,
                Map.of("role", "assistant", "content", firstContent),
                Map.of("role", "user", "content", followUpPrompt)
        ));

        long followUpStart = System.currentTimeMillis();
        Optional<Map<String, Object>> result = postMessages(secondRequestBody).flatMap(this::extractToolUseInput);
        log.info("[PERF-TEMP] 4.web_search 후속(확정응답) 호출 소요={}ms, thread={}",
                System.currentTimeMillis() - followUpStart, Thread.currentThread().getName());
        return result;
    }

    private Optional<Map<String, Object>> postMessages(Map<String, Object> requestBody) {
        Map<String, Object> response;
        // [PERF-TEMP] 401 authentication_error 원인 추적용 — 키 값 자체는 절대 안 찍고 길이/앞8자만.
        // 공백/줄바꿈이 섞였는지 확인하려고 trim 전후 길이도 같이 남김
        log.info("[PERF-TEMP] Claude API 키 점검: 원본길이={}, trim후길이={}, 앞8자={}",
                apiKey == null ? -1 : apiKey.length(),
                apiKey == null ? -1 : apiKey.trim().length(),
                apiKey == null ? "null" : apiKey.substring(0, Math.min(8, apiKey.length())));
        try {
            response = restClient.post()
                    .uri(ENDPOINT)
                    .header("x-api-key", apiKey)
                    .header("anthropic-version", ANTHROPIC_VERSION)
                    .contentType(MediaType.APPLICATION_JSON)
                    .body(requestBody)
                    .retrieve()
                    .body(Map.class);
        } catch (RestClientResponseException e) {
            log.warn("Claude API 호출 실패: HTTP {} - {}", e.getStatusCode(), e.getResponseBodyAsString());
            return Optional.empty();
        } catch (RestClientException e) {
            log.warn("Claude API 호출 자체가 실패함 (네트워크/타임아웃 문제로 추정)", e);
            return Optional.empty();
        }
        return Optional.ofNullable(response);
    }

    // HTTP 호출은 성공했지만 응답 "형태"에 대한 가정이 깨질 수 있는 구간(content가 없거나 tool_use
    // 블록이 없는 경우 등) — postMessages()의 catch 블록으론 못 잡으므로 따로 감쌈
    @SuppressWarnings("unchecked")
    private Optional<Map<String, Object>> extractToolUseInput(Map<String, Object> response) {
        try {
            List<Map<String, Object>> content = (List<Map<String, Object>>) response.get("content");
            if (content == null) return Optional.empty();
            return content.stream()
                    .filter(block -> "tool_use".equals(block.get("type")))
                    .findFirst()
                    .map(block -> (Map<String, Object>) block.get("input"));
        } catch (Exception e) {
            log.warn("Claude API 응답 파싱 실패 — 예상한 tool_use 형태가 아님", e);
            return Optional.empty();
        }
    }

    private Optional<Integer> extractInt(Map<String, Object> map, String key) {
        Object value = map.get(key);
        if (value instanceof Number number) {
            return Optional.of((int) Math.round(number.doubleValue()));
        }
        return Optional.empty();
    }
}
