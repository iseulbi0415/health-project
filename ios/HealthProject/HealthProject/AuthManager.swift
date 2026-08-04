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
        // 소화 타이머/즐겨찾기 둘 다 서버 저장 없이 기기 UserDefaults에만 남는 로컬 상태라,
        // 계정을 전환해도(로그아웃 후 다른 계정으로 로그인) 자동으로 안 지워짐 — 로그아웃
        // 시점에 명시적으로 같이 초기화해서 다음 로그인 계정에 이전 계정 데이터가 안 보이게 함
        DigestionTimerManager.shared.cancel()
        // FoodPickerModel은 싱글턴이 아니라 로그인 게이트가 화면을 새로 그릴 때 인스턴스
        // 자체는 새로 만들어지지만, loadFavorites()가 이 UserDefaults 키를 그대로 읽어오므로
        // 키 자체를 지워야 함
        UserDefaults.standard.removeObject(forKey: "favoriteFoods")
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
