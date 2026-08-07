//
//  AuthAPIService.swift
//  HealthProject
//
//  로그아웃/회원탈퇴처럼 특정 도메인(Food/Run/Memo)에 속하지 않는 인증 관련 백엔드 호출을 모아둠.
//

import Foundation

enum AuthAPIService {
    private static let baseURL = APIConfig.baseURL

    // fire-and-forget — 네트워크 오류 등으로 실패해도 AuthManager.logout()의 로컬 상태 초기화는
    // 항상 진행돼야 하므로 에러를 던지지 않음(호출부가 실패 여부를 신경 쓸 필요 없게)
    static func logout() async {
        guard let url = URL(string: "\(baseURL)/api/auth/logout") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        _ = try? await URLSession.shared.data(for: request)
    }

    enum DeleteAccountError: Error {
        case failed
    }

    // 회원 탈퇴는 로그아웃과 달리 성공/실패를 명확히 구분해야 함 — 실패 시 로그인 상태를
    // 유지한 채 에러만 보여줘야 하므로(ProfileView.deleteAccount 참고) throws로 던짐
    static func deleteAccount() async throws {
        guard let url = URL(string: "\(baseURL)/api/auth/me") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw DeleteAccountError.failed
        }
    }
}
