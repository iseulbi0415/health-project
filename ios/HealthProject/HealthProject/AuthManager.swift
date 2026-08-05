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
        // 소화 타이머는 서버 저장 없이 기기 UserDefaults에만 남는 로컬 상태라, 계정을
        // 전환해도(로그아웃 후 다른 계정으로 로그인) 자동으로 안 지워짐 — 로그아웃 시점에
        // 명시적으로 초기화해서 다음 로그인 계정에 이전 계정의 타이머가 안 보이게 함.
        // (즐겨찾기는 서버 DB 저장으로 전환되어 더 이상 여기서 지울 필요 없음 — 계정마다
        // 로그인 시 서버에서 새로 불러오므로 자동으로 분리됨)
        DigestionTimerManager.shared.cancel()
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
