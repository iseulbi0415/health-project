//
//  AuthManager.swift
//  HealthProject
//
//  로그인 상태를 앱 전역에서 공유하고 UserDefaults와 동기화하는 매니저
//

import Combine
import Foundation

final class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published private(set) var isLoggedIn: Bool

    private init() {
        isLoggedIn = UserDefaults.standard.bool(forKey: "isLoggedIn")
    }

    func login() {
        UserDefaults.standard.set(true, forKey: "isLoggedIn")
        isLoggedIn = true
    }

    func logout() {
        UserDefaults.standard.set(false, forKey: "isLoggedIn")
        isLoggedIn = false
    }

    // 앱 시작 시 UserDefaults 값만 믿지 않고 서버에 세션이 진짜 살아있는지 확인.
    // 응답을 못 받으면(네트워크 오류 등) 기존 상태를 그대로 둠 — 서버가 잠깐 안 떠 있을 수도 있어서 섣불리 로그아웃하지 않음
    func verifySession() async {
        guard isLoggedIn else { return }
        guard let url = URL(string: "\(APIConfig.baseURL)/api/auth/me") else { return }

        struct MeResponse: Decodable { let loggedIn: Bool }

        if let (data, _) = try? await URLSession.shared.data(from: url),
           let result = try? JSONDecoder().decode(MeResponse.self, from: data),
           !result.loggedIn {
            logout()
        }
    }
}
