//
//  FoodAutoMatchResult.swift
//  HealthProject
//
//  백엔드 /api/food-search/auto(음식 자동 매칭) 응답 모델
//

import Foundation

struct FoodAutoMatchResult: Codable {
    let name: String
    let calorie: Int?
    let fatGrams: Double?
    let estimatedServingGrams: Int?
    let estimatedServingCalorie: Int?
    let estimatedServingFatGrams: Double?
    let matchType: String
    let isServingEstimateFallback: Bool
}
