//
//  UserProfileAPIService.swift
//  HealthProject
//
//  "내 정보"(BMR 계산용 키/체중/나이/성별/활동량) 서버 저장/조회 — Food/Run과 달리 사용자당 1건이라
//  id 기반 CRUD 없이 GET/PUT만 있음. 로컬에는 여전히 @AppStorage(UserDefaults)를 빠른 캐시로 쓰고,
//  이 서비스가 로그인 시 서버 값으로 그 캐시를 복원해줌(앱 삭제 후 재설치해도 값이 남게)
//

import Foundation

struct UserProfile: Codable {
    var heightCm: Double?
    var weightKg: Double?
    var age: Int?
    var gender: String?
    var activityLevel: Int?
    var hasCalculatedGoal: Bool
}

enum UserProfileAPIService {
    private static let baseURL = APIConfig.baseURL

    static func fetchProfile() async throws -> UserProfile {
        guard let url = URL(string: "\(baseURL)/api/users/me/profile") else {
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

        return try JSONDecoder().decode(UserProfile.self, from: data)
    }

    static func updateProfile(_ profile: UserProfile) async throws {
        guard let url = URL(string: "\(baseURL)/api/users/me/profile") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(profile)

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

    // 로그인 직후 호출 — 서버에 저장된 프로필 값으로 로컬 UserDefaults(ProfileView/HomeView가 읽는
    // @AppStorage와 동일한 키)를 덮어씀. 앱을 삭제했다 재설치한 경우 로컬 값이 비어있으므로 이 호출이
    // 실질적인 "복원" 역할을 함. 서버에도 아직 값이 없는 최초 사용자는 조용히 아무것도 안 씀(에러 아님)
    static func hydrateLocalCache() async {
        guard let profile = try? await fetchProfile() else { return }

        let defaults = UserDefaults.standard
        if let heightCm = profile.heightCm {
            defaults.set(Self.trimmedNumberString(heightCm), forKey: "bmrHeight")
        }
        if let weightKg = profile.weightKg {
            defaults.set(Self.trimmedNumberString(weightKg), forKey: "bmrWeight")
        }
        if let age = profile.age {
            defaults.set(String(age), forKey: "bmrAge")
        }
        if let gender = profile.gender {
            defaults.set(gender, forKey: "bmrGender")
        }
        if let activityLevel = profile.activityLevel {
            defaults.set(activityLevel, forKey: "bmrActivityLevel")
        }
        defaults.set(profile.hasCalculatedGoal, forKey: "goalCalculated")
    }

    // 170.0처럼 서버 왕복 후 텍스트 필드에 불필요한 소수점이 남지 않도록, 정수면 정수로만 표시
    private static func trimmedNumberString(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(value)
    }
}
