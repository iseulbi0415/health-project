//
//  MemoAPIService.swift
//  HealthProject
//
//  로컬 백엔드(/api/memos) 호출 — 컨디션 메모 등록
//

import Foundation

private struct NewMemoRequest: Encodable {
    let date: String
    let content: String
    let symptomScore: Int
}

struct MemoRecord: Decodable, Identifiable {
    let id: Int
    let date: String
    let content: String
    let symptomScore: Int
}

enum MemoAPIService {
    private static let baseURL = "http://localhost:8080"

    static func fetchMemos(date: String? = nil) async throws -> [MemoRecord] {
        var urlString = "\(baseURL)/api/memos"
        if let date {
            urlString += "?date=\(date)"
        }
        guard let url = URL(string: urlString) else {
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

        return try JSONDecoder().decode([MemoRecord].self, from: data)
    }

    static func createMemo(date: String, content: String, symptomScore: Int) async throws {
        guard let url = URL(string: "\(baseURL)/api/memos") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(NewMemoRequest(date: date, content: content, symptomScore: symptomScore))

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

    static func updateMemo(id: Int, date: String, content: String, symptomScore: Int) async throws {
        guard let url = URL(string: "\(baseURL)/api/memos/\(id)") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(NewMemoRequest(date: date, content: content, symptomScore: symptomScore))

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

    static func deleteMemo(id: Int) async throws {
        guard let url = URL(string: "\(baseURL)/api/memos/\(id)") else {
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
