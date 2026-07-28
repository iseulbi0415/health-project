//
//  FoodRecord.swift
//  HealthProject
//
//  백엔드 /api/foods가 주고받는 "오늘 먹은 음식" 기록 모델
//

import Foundation

struct FoodRecord: Codable, Identifiable {
    let id: Int
    let name: String
    let calorie: Int
    let digestTime: String
    let fatGrams: Double?
    let meal: String?
    let quantity: Int
    let isTrigger: Bool
    let recordedAt: String?
}
