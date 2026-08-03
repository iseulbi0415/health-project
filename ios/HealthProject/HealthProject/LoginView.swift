//
//  LoginView.swift
//  HealthProject
//
//  카카오 로그인 버튼 하나만 있는 진입 화면
//

import SwiftUI
import KakaoSDKAuth
import KakaoSDKUser

struct LoginView: View {
    @EnvironmentObject private var authManager: AuthManager

    @State private var isLoggingIn = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "stethoscope")
                .font(.largeTitle)
            Text("건강 케어 & 러닝 트래커")
                .font(.title2)
                .bold()
            Text("로그인하고 나만의 기록을 시작하세요")
                .foregroundStyle(.secondary)

            Button(action: login) {
                if isLoggingIn {
                    ProgressView()
                } else {
                    Text("카카오 로그인")
                }
            }
            .disabled(isLoggingIn)

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.footnote)
            }
        }
        .padding()
    }

    private func login() {
        isLoggingIn = true
        errorMessage = nil
        Task {
            do {
                let accessToken = try await requestKakaoAccessToken()
                try await RunAPIService.loginWithKakao(accessToken: accessToken)
                // 앱을 삭제했다 재설치한 경우 로컬 캐시(@AppStorage)가 비어있으므로, 로그인 성공
                // 직후 서버에 저장된 "내 정보"로 복원함 — 실패해도 로그인 자체는 막지 않음
                await UserProfileAPIService.hydrateLocalCache()
                isLoggingIn = false
                authManager.login()
            } catch {
                isLoggingIn = false
                errorMessage = "로그인 실패: \(error.localizedDescription)"
            }
        }
    }

    // 콜백 기반 SDK API를 async/await으로 감쌈. 시뮬레이터엔 카카오톡 앱이 없어서
    // loginWithKakaoTalk을 못 쓰므로, 그 경우 시스템 브라우저 기반 loginWithKakaoAccount로 자동 대체
    private func requestKakaoAccessToken() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let completion: (OAuthToken?, Error?) -> Void = { oauthToken, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let oauthToken {
                    continuation.resume(returning: oauthToken.accessToken)
                } else {
                    continuation.resume(throwing: URLError(.unknown))
                }
            }
            if UserApi.isKakaoTalkLoginAvailable() {
                UserApi.shared.loginWithKakaoTalk(completion: completion)
            } else {
                UserApi.shared.loginWithKakaoAccount(completion: completion)
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager.shared)
}
