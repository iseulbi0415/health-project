//
//  RunAPIService.swift
//  HealthProject
//
//  로컬 Spring Boot 백엔드(/api/auth/kakao/native, /api/runs) 호출을 모아둔 파일.
//  로그인 세션은 URLSession.shared의 공유 쿠키 저장소가 자동으로 유지 — 별도 쿠키 관리 코드 없음.
//

import Foundation

private struct NewRunRequest: Encodable {
    let distance: Double
    let time: Double
    let heartRate: Int
    let speedKmh: Double
    let calorieBurned: Double
    let recordedAt: String?
}

private struct NativeLoginRequest: Encodable {
    let accessToken: String
}

private struct AppleLoginRequest: Encodable {
    let identityToken: String
    let fullName: String?
}

enum RunAPIService {

    private static let baseURL = APIConfig.baseURL

    // 체중 입력 화면이 아직 없어서(오늘 범위 아님), 웹/백엔드에 이미 있던 임시 기본값(60kg)을 그대로 씀
    private static let defaultWeightKg = 60.0

    // 카카오 액세스 토큰을 백엔드로 보내 세션(JSESSIONID)을 생성. 응답의 Set-Cookie가
    // URLSession.shared의 공유 쿠키 저장소에 자동 저장되어, 이후 fetchRuns/createRun 요청에 자동으로 실림
    static func loginWithKakao(accessToken: String) async throws {
        guard let url = URL(string: "\(baseURL)/api/auth/kakao/native") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(NativeLoginRequest(accessToken: accessToken))

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.userAuthenticationRequired)
        }
    }

    // Apple identity token을 백엔드로 보내 세션(JSESSIONID)을 생성 — loginWithKakao와 동일한 패턴.
    // fullName은 Apple이 최초 로그인 시에만 내려주므로 재로그인 시엔 nil로 보내도 됨(백엔드가 기존 값 유지)
    static func loginWithApple(identityToken: String, fullName: String?) async throws {
        guard let url = URL(string: "\(baseURL)/api/auth/apple/native") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(AppleLoginRequest(identityToken: identityToken, fullName: fullName))

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.userAuthenticationRequired)
        }
    }

    static func fetchRuns(date: String? = nil) async throws -> [RunRecord] {
        var urlString = "\(baseURL)/api/runs"
        if let date {
            urlString += "?date=\(date)"
        }
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            if httpResponse.statusCode == 401 {
                AuthManager.shared.logout()
            }
            throw URLError(.userAuthenticationRequired)
        }

        return try JSONDecoder().decode([RunRecord].self, from: data)
    }

    // distance(km)/totalMinutes(분)/heartRate(bpm)만 받으면 시속·칼로리는 여기서 계산해서 같이 보냄 —
    // 웹(app.js의 calculateRunStats)과 동일한 값을 서버에 보내기 위함
    static func createRun(distance: Double, totalMinutes: Double, heartRate: Int, recordedAt: String? = nil) async throws -> RunRecord {
        guard let url = URL(string: "\(baseURL)/api/runs") else {
            throw URLError(.badURL)
        }

        let stats = calculateRunStats(distance: distance, totalMinutes: totalMinutes)
        let body = NewRunRequest(
            distance: distance,
            time: totalMinutes,
            heartRate: heartRate,
            speedKmh: stats.speedKmh,
            calorieBurned: stats.caloriesBurned,
            recordedAt: recordedAt
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        // RunController.validateRun()이 거리/시간/심박수가 잘못되면 400을, 로그인 세션이
        // 없거나 만료됐으면 401을 내려줌 — 호출한 쪽이 구분해서 안내할 수 있게 상태 코드를 그대로 담아 던짐
        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                AuthManager.shared.logout()
            }
            throw RunAPIError.httpError(statusCode: httpResponse.statusCode, body: String(data: data, encoding: .utf8))
        }

        return try JSONDecoder().decode(RunRecord.self, from: data)
    }

    // recordedAt은 항상 nil로 보냄 — RunController.updateRun이 nil이면 기존 저장 시각을 그대로 유지함
    static func updateRun(id: Int, distance: Double, totalMinutes: Double, heartRate: Int) async throws -> RunRecord {
        guard let url = URL(string: "\(baseURL)/api/runs/\(id)") else {
            throw URLError(.badURL)
        }

        let stats = calculateRunStats(distance: distance, totalMinutes: totalMinutes)
        let body = NewRunRequest(
            distance: distance,
            time: totalMinutes,
            heartRate: heartRate,
            speedKmh: stats.speedKmh,
            calorieBurned: stats.caloriesBurned,
            recordedAt: nil
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
            throw RunAPIError.httpError(statusCode: httpResponse.statusCode, body: String(data: data, encoding: .utf8))
        }

        return try JSONDecoder().decode(RunRecord.self, from: data)
    }

    static func deleteRun(id: Int) async throws {
        guard let url = URL(string: "\(baseURL)/api/runs/\(id)") else {
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

    // 시속(km/h)에 따라 MET(운동 강도) 값을 결정해 칼로리를 계산.
    // 웹 프론트(js/app.js의 calculateRunStats)와 1:1 대응되는 계산식. 출처: https://pacompendium.com/running/
    static func calculateRunStats(distance: Double, totalMinutes: Double) -> (speedKmh: Double, caloriesBurned: Double) {
        let speedKmh = distance / (totalMinutes / 60)

        let met: Double
        if speedKmh < 8.05 {
            met = 6.0
        } else if speedKmh < 9.66 {
            met = 8.5
        } else if speedKmh < 10.78 {
            met = 9.3
        } else if speedKmh < 11.27 {
            met = 10.5
        } else if speedKmh < 12.87 {
            met = 11.5
        } else if speedKmh < 14.48 {
            met = 12.3
        } else if speedKmh < 16.09 {
            met = 12.8
        } else {
            met = 14.5
        }

        let caloriesBurned = met * defaultWeightKg * (totalMinutes / 60)
        return (speedKmh, caloriesBurned)
    }
}

enum RunAPIError: LocalizedError {
    case httpError(statusCode: Int, body: String?)

    var errorDescription: String? {
        switch self {
        case .httpError(let statusCode, let body):
            if statusCode == 401 {
                return "세션이 만료됐습니다 — 다시 로그인해주세요."
            }
            return "요청 실패 (HTTP \(statusCode)): \(body ?? "-")"
        }
    }
}
