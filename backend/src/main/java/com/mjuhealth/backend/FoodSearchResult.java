package com.mjuhealth.backend;

// 프론트로 내려주는 검색 결과 한 건 — 식약처 API 원본 필드를 그대로 노출하지 않고
// 화면(app.js)에 필요한 값만 추려서 내려줌. GERD 소화시간 판단(지방g 임계값 계산)은
// 여기서 하지 않고 프론트에 맡김 — 도메인 로직을 한 곳에 몰아 기준 변경 시 한 곳만 고치면 되게 함
public record FoodSearchResult(String name, Integer calorie, Double fat, String servingSize) {}
