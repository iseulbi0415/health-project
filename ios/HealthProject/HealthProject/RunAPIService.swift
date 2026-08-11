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
    let heartRate: Int?
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
    let authorizationCode: String?
}

enum RunAPIService {

    private static let baseURL = APIConfig.baseURL

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
    // fullName은 Apple이 최초 로그인 시에만 내려주므로 재로그인 시엔 nil로 보내도 됨(백엔드가 기존 값 유지).
    // authorizationCode는 로그인마다 매번 보냄 — 백엔드가 refresh_token 교환에 씀(회원탈퇴 시 revoke용)
    static func loginWithApple(identityToken: String, fullName: String?, authorizationCode: String?) async throws {
        guard let url = URL(string: "\(baseURL)/api/auth/apple/native") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(AppleLoginRequest(identityToken: identityToken, fullName: fullName, authorizationCode: authorizationCode))

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
    // 웹(app.js의 calculateRunStats)과 동일한 값을 서버에 보내기 위함. weightKg는 호출부(RunAddView)가
    // @AppStorage("bmrWeight")에서 읽어 넘김 — 이전엔 60kg 고정값을 썼음
    static func createRun(distance: Double, totalMinutes: Double, heartRate: Int?, weightKg: Double, recordedAt: String? = nil) async throws -> RunRecord {
        guard let url = URL(string: "\(baseURL)/api/runs") else {
            throw URLError(.badURL)
        }

        let stats = calculateRunStats(distance: distance, totalMinutes: totalMinutes, weightKg: weightKg)
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
    static func updateRun(id: Int, distance: Double, totalMinutes: Double, heartRate: Int?, weightKg: Double) async throws -> RunRecord {
        guard let url = URL(string: "\(baseURL)/api/runs/\(id)") else {
            throw URLError(.badURL)
        }

        let stats = calculateRunStats(distance: distance, totalMinutes: totalMinutes, weightKg: weightKg)
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

    // 웹 프론트(js/app.js의 calculateRunStats)와 1:1 대응되는 계산식.
    // weightKg는 호출부가 실제 사용자 체중(@AppStorage("bmrWeight"))을 넘겨줌 — 예전엔 60kg 고정값을 썼음
    // 소모 칼로리 = MET × 체중(kg) × 시간(h)
    // MET 값 출처: 2024 Adult Compendium of Physical Activities
    //   https://pacompendium.com/running/
    // 각 구간의 하한 속도에 해당하는 값을 사용
    //   예: 7.0~8.0 mph 구간 → 7 mph = 11.0
    static func calculateRunStats(distance: Double, totalMinutes: Double, weightKg: Double) -> (speedKmh: Double, caloriesBurned: Double) {
        let speedKmh = distance / (totalMinutes / 60)

        let met: Double
        if speedKmh < 8.05 {
            met = 6.5
        } else if speedKmh < 9.66 {
            met = 8.5
        } else if speedKmh < 10.78 {
            met = 9.3
        } else if speedKmh < 11.27 {
            met = 10.5
        } else if speedKmh < 12.87 {
            met = 11.0
        } else if speedKmh < 14.48 {
            met = 12.0
        } else if speedKmh < 16.09 {
            met = 13.0
        } else {
            met = 14.8
        }

        let caloriesBurned = met * weightKg * (totalMinutes / 60)
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
