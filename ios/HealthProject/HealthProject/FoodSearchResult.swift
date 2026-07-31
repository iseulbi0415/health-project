//
//  FoodSearchResult.swift
//  HealthProject
//
//  백엔드 /api/food-search(식약처 식품영양성분DB 프록시) 응답 모델
//

import Foundation

struct FoodSearchResult: Codable {
    let name: String
    let calorie: Int?
    let fat: Double?
    let servingSize: String?
}
