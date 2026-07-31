//
//  FavoriteFood.swift
//  HealthProject
//
//  즐겨찾기(자주 먹는 음식) — 웹처럼 백엔드에 저장하지 않고 기기에만 저장하는 로컬 전용 모델
//

import Foundation

// 웹의 fatGramsToDigestCategory/digestCategoryToRepresentativeFat과 동일한 3단계.
// rawValue(2/3/4)는 백엔드 Food.digestTime 문자열과 그대로 맞춰 씀
enum DigestCategory: Int, CaseIterable, Identifiable, Codable {
    case light = 2
    case normal = 3
    case heavy = 4

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .light: return "가벼움"
        case .normal: return "보통"
        case .heavy: return "무거움"
        }
    }

    var exampleFoods: String {
        switch self {
        case .light: return "예: 닭가슴살·흰쌀밥·바나나·삶은 달걀"
        case .normal: return "예: 연어·소고기 살코기"
        case .heavy: return "예: 삼겹살·튀김류(치킨·돈까스)"
        }
    }

    // 지방 실측값(fatGrams)이 없을 때 끼니 합산에 쓰는 대표 지방량(g)
    var representativeFatGrams: Double {
        switch self {
        case .light: return 5
        case .normal: return 15
        case .heavy: return 30
        }
    }

    // 웹의 fatGramsToDigestCategory와 동일 — 식약처 검색 결과의 실측 지방값을 카테고리로 변환.
    // 값이 없으면(nil) "보통"으로 기본 처리
    static func from(fatGrams: Double?) -> DigestCategory {
        guard let fatGrams else { return .normal }
        if fatGrams < 10 { return .light }
        if fatGrams <= 25 { return .normal }
        return .heavy
    }
}

// 백엔드 Food.meal에 실제로 저장되는 값과 동일한 영문 rawValue를 씀 (한글이 아님 — 웹 코드에서 확인)
enum Meal: String, CaseIterable, Identifiable, Codable {
    case breakfast, lunch, dinner, snack

    var id: String { rawValue }

    var label: String {
        switch self {
        case .breakfast: return "아침"
        case .lunch: return "점심"
        case .dinner: return "저녁"
        case .snack: return "간식"
        }
    }
}

struct FavoriteFood: Codable, Identifiable {
    let id: UUID
    var name: String
    var calorie: Int
    var digestCategory: DigestCategory
    var isTrigger: Bool
    // 2부(식약처 검색) 대비용 필드 — 1부에서는 항상 nil
    var fatGrams: Double?

    init(id: UUID = UUID(), name: String, calorie: Int, digestCategory: DigestCategory, isTrigger: Bool, fatGrams: Double? = nil) {
        self.id = id
        self.name = name
        self.calorie = calorie
        self.digestCategory = digestCategory
        self.isTrigger = isTrigger
        self.fatGrams = fatGrams
    }
}
