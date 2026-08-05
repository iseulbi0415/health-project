//
//  FavoriteAPIService.swift
//  HealthProject
//
//  로컬 백엔드(/api/favorites) 호출 — 즐겨찾기 조회/등록/수정/삭제.
//  FoodAPIService.swift와 완전히 동일한 패턴(에러 처리/401 시 자동 로그아웃 포함)
//

import Foundation

// id는 서버가 발급하므로 요청 바디엔 안 실음 — NewFoodRequest와 동일한 이유
private struct FavoriteRequestBody: Encodable {
    let name: String
    let calorie: Int
    let digestCategory: Int
    let isTrigger: Bool
    let fatGrams: Double?
}

enum FavoriteAPIService {
    private static let baseURL = APIConfig.baseURL

    static func fetchFavorites() async throws -> [FavoriteFood] {
        guard let url = URL(string: "\(baseURL)/api/favorites") else {
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

        return try JSONDecoder().decode([FavoriteFood].self, from: data)
    }

    static func createFavorite(_ favorite: FavoriteFood) async throws -> FavoriteFood {
        guard let url = URL(string: "\(baseURL)/api/favorites") else {
            throw URLError(.badURL)
        }

        let body = FavoriteRequestBody(
            name: favorite.name,
            calorie: favorite.calorie,
            digestCategory: favorite.digestCategory.rawValue,
            isTrigger: favorite.isTrigger,
            fatGrams: favorite.fatGrams
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

        return try JSONDecoder().decode(FavoriteFood.self, from: data)
    }

    static func updateFavorite(_ favorite: FavoriteFood) async throws -> FavoriteFood {
        guard let url = URL(string: "\(baseURL)/api/favorites/\(favorite.id)") else {
            throw URLError(.badURL)
        }

        let body = FavoriteRequestBody(
            name: favorite.name,
            calorie: favorite.calorie,
            digestCategory: favorite.digestCategory.rawValue,
            isTrigger: favorite.isTrigger,
            fatGrams: favorite.fatGrams
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

        return try JSONDecoder().decode(FavoriteFood.self, from: data)
    }

    static func deleteFavorite(id: Int) async throws {
        guard let url = URL(string: "\(baseURL)/api/favorites/\(id)") else {
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
}
