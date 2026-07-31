//
//  RecordSummaryAPIService.swift
//  HealthProject
//
//  로컬 백엔드(/api/records/summary) 호출 — 특정 달에 기록(식단/러닝/메모) 있는 날짜 목록 조회
//

import Foundation

enum RecordSummaryAPIService {
    private static let baseURL = "http://localhost:8080"

    static func fetchMonthSummary(year: Int, month: Int) async throws -> Set<String> {
        guard let url = URL(string: "\(baseURL)/api/records/summary?year=\(year)&month=\(month)") else {
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

        return try JSONDecoder().decode(Set<String>.self, from: data)
    }
}
