//
//  FoodAPIService.swift
//  HealthProject
//
//  로컬 백엔드(/api/foods) 호출 — 오늘 먹은 음식 조회/등록
//

import Foundation

private struct NewFoodRequest: Encodable {
    let name: String
    let calorie: Int
    let digestTime: String
    let isTrigger: Bool
    let meal: String
    let quantity: Int
    let recordedAt: String?
    let fatGrams: Double?
}

enum FoodAPIService {
    private static let baseURL = "http://localhost:8080"

    static func fetchTodayFoods(date: String) async throws -> [FoodRecord] {
        guard let url = URL(string: "\(baseURL)/api/foods?date=\(date)") else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                AuthManager.shared.logout()
            }
            throw URLError(.userAuthenticationRequired)
        }

        return try JSONDecoder().decode([FoodRecord].self, from: data)
    }

    // 같은 날/같은 이름/같은 끼니 기록이 이미 있으면 서버(FoodController.createFood)가 알아서
    // 수량/칼로리/지방을 합쳐주므로, 여기서는 중복 체크 없이 항상 그냥 등록만 하면 됨
    static func createFood(name: String, calorie: Int, digestTime: String, isTrigger: Bool, meal: Meal, fatGrams: Double? = nil, recordedAt: String? = nil) async throws -> FoodRecord {
        guard let url = URL(string: "\(baseURL)/api/foods") else {
            throw URLError(.badURL)
        }

        let body = NewFoodRequest(
            name: name,
            calorie: calorie,
            digestTime: digestTime,
            isTrigger: isTrigger,
            meal: meal.rawValue,
            quantity: 1,
            recordedAt: recordedAt,
            fatGrams: fatGrams
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                AuthManager.shared.logout()
            }
            throw URLError(.userAuthenticationRequired)
        }

        return try JSONDecoder().decode(FoodRecord.self, from: data)
    }

    // recordedAt은 항상 nil로 보냄 — FoodController.updateFood가 nil이면 기존 저장 시각을 그대로 유지함
    static func updateFood(id: Int, name: String, calorie: Int, digestTime: String, isTrigger: Bool, meal: Meal, quantity: Int, fatGrams: Double? = nil) async throws -> FoodRecord {
        guard let url = URL(string: "\(baseURL)/api/foods/\(id)") else {
            throw URLError(.badURL)
        }

        let body = NewFoodRequest(
            name: name,
            calorie: calorie,
            digestTime: digestTime,
            isTrigger: isTrigger,
            meal: meal.rawValue,
            quantity: quantity,
            recordedAt: nil,
            fatGrams: fatGrams
        )

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                AuthManager.shared.logout()
            }
            throw URLError(.userAuthenticationRequired)
        }

        return try JSONDecoder().decode(FoodRecord.self, from: data)
    }

    static func deleteFood(id: Int) async throws {
        guard let url = URL(string: "\(baseURL)/api/foods/\(id)") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                AuthManager.shared.logout()
            }
            throw URLError(.userAuthenticationRequired)
        }
    }

    static func searchFoods(keyword: String) async throws -> [FoodSearchResult] {
        let encodedKeyword = keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? keyword
        guard let url = URL(string: "\(baseURL)/api/food-search?keyword=\(encodedKeyword)") else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                AuthManager.shared.logout()
            }
            throw URLError(.userAuthenticationRequired)
        }

        return try JSONDecoder().decode([FoodSearchResult].self, from: data)
    }

    // 완전일치면 칼로리 중앙값으로, 아니면 AI가 후보 중 선택 + 1인분 그램수까지 추정해서 결과 하나만
    // 내려주는 자동 매칭. 204는 후보 자체가 없다는 뜻이라 nil로 구분함(200인데 영양정보만 못 찾은
    // 경우는 nil이 아니라 estimatedServingCalorie가 nil인 결과로 내려옴 — 호출부에서 구분해서 처리)
    static func searchFoodsAuto(keyword: String) async throws -> FoodAutoMatchResult? {
        let encodedKeyword = keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? keyword
        guard let url = URL(string: "\(baseURL)/api/food-search/auto?keyword=\(encodedKeyword)") else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        if httpResponse.statusCode == 204 {
            return nil
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                AuthManager.shared.logout()
            }
            throw URLError(.userAuthenticationRequired)
        }

        return try JSONDecoder().decode(FoodAutoMatchResult.self, from: data)
    }
}
