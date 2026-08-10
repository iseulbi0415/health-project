//
//  LoginView.swift
//  HealthProject
//
//  카카오 로그인 버튼 하나만 있는 진입 화면
//

import SwiftUI
import AuthenticationServices
import KakaoSDKAuth
import KakaoSDKUser

struct LoginView: View {
    @EnvironmentObject private var authManager: AuthManager

    // 어느 버튼을 눌렀는지 구분해서 그 버튼에만 로딩 UI를 표시하기 위한 상태 — 예전엔 Bool
    // 하나(isLoggingIn)를 두 버튼이 공유해서, 애플 로그인 중에도 카카오 버튼에 스피너가 뜨는
    // 버그가 있었음
    private enum LoginProvider { case idle, kakao, apple }
    @State private var loginState: LoginProvider = .idle
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "stethoscope")
                .font(.largeTitle)
            Text("소담 - 소화 타이머")
                .font(.title2)
                .bold()
            Text("끼니의 지방량을 기록해 소화 시간을 안내합니다")
                .foregroundStyle(.secondary)

            // 카카오 공식 로그인 버튼 가이드라인(옐로우 #FEE500 배경 + 검정 텍스트) 적용.
            // SDK에 공식 배포용 심볼 에셋이 번들되어 있지 않아(내부 브릿지 전용 리소스만 있음)
            // 아이콘 없이 텍스트만 — 애플 버튼과 높이/폭을 맞춰 두 버튼이 나란히 통일감 있게 보이게 함
            Button(action: login) {
                Group {
                    if loginState == .kakao {
                        ProgressView()
                    } else {
                        Text("카카오 로그인")
                            .font(.system(size: 15, weight: .medium))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
            }
            .foregroundStyle(.black)
            .background(Color(red: 254 / 255, green: 229 / 255, blue: 0 / 255))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .disabled(loginState != .idle)
            .opacity(loginState == .idle || loginState == .kakao ? 1 : 0.4)

            // SignInWithAppleButton의 문구는 기기 시스템 언어를 따라가는데, 이 앱은 로컬라이징이
            // 안 되어 있어(developmentRegion=en, 지원 언어 선언 없음) 기기가 한국어여도 시스템이
            // 영어로 표시하는 경우가 있음 — locale을 명시적으로 ko_KR로 고정해서 항상 "Apple로 로그인"으로 뜨게 함
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName]
            } onCompletion: { result in
                handleAppleSignIn(result)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .environment(\.locale, Locale(identifier: "ko_KR"))
            .disabled(loginState != .idle)
            .opacity(loginState == .idle || loginState == .apple ? 1 : 0.4)
            .overlay {
                // SignInWithAppleButton은 시스템 컴포넌트라 내부 콘텐츠(텍스트)를 직접 못
                // 바꾸므로(가이드라인상으로도 권장 안 됨), 카카오 버튼처럼 텍스트를 스왑하는
                // 대신 위에 스피너를 얹는 방식으로 로딩 상태를 표시함
                if loginState == .apple {
                    ProgressView()
                        .tint(.white)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.footnote)
            }
        }
        .padding()
    }

    private func login() {
        loginState = .kakao
        errorMessage = nil
        Task {
            do {
                let accessToken = try await requestKakaoAccessToken()
                try await RunAPIService.loginWithKakao(accessToken: accessToken)
                // 앱을 삭제했다 재설치한 경우 로컬 캐시(@AppStorage)가 비어있으므로, 로그인 성공
                // 직후 서버에 저장된 "내 정보"로 복원함 — 실패해도 로그인 자체는 막지 않음
                await UserProfileAPIService.hydrateLocalCache()
                loginState = .idle
                authManager.login()
            } catch {
                loginState = .idle
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

    // 카카오 login()과 동일한 흐름(로딩/에러 상태, hydrateLocalCache, authManager.login())을
    // 그대로 재사용 — nonce 검증은 이번 범위에서 의도적으로 스킵(서명/issuer/audience 검증으로 충분,
    // 재전송 공격 방어까지 강화하려면 추후 nonce 추가 가능)
    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let identityToken = String(data: tokenData, encoding: .utf8) else {
                errorMessage = "로그인 실패: Apple 인증 정보를 읽을 수 없어요"
                return
            }
            // fullName은 Apple이 최초 로그인 시에만 내려줌(재로그인 시 nil)
            let fullName = [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")
            // authorizationCode는 로그인마다 매번 새로 발급됨(5분 내 만료) — 백엔드가 refresh_token으로
            // 교환해서 저장해두면 나중에 회원탈퇴 시 Apple 쪽 토큰 폐기(revoke)에 씀. 못 읽어도(거의
            // 없는 케이스) 로그인 자체는 막지 않고 nil로 보냄
            let authorizationCode = credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
            loginState = .apple
            errorMessage = nil
            Task {
                do {
                    try await RunAPIService.loginWithApple(identityToken: identityToken, fullName: fullName.isEmpty ? nil : fullName, authorizationCode: authorizationCode)
                    await UserProfileAPIService.hydrateLocalCache()
                    loginState = .idle
                    authManager.login()
                } catch {
                    loginState = .idle
                    errorMessage = "로그인 실패: \(error.localizedDescription)"
                }
            }
        case .failure(let error):
            // 코드 1001(canceled)은 사용자가 로그인 시트를 직접 닫은 경우라 에러가 아님 — .unknown도
            // 시트를 닫을 때 종종 같이 발생해서(실기기 확인) 함께 무시. 둘 다 메시지를 띄우지 않음
            if let authError = error as? ASAuthorizationError,
               authError.code == .canceled || authError.code == .unknown {
                return
            }
            errorMessage = "로그인에 실패했습니다. 다시 시도해 주세요."
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager.shared)
}
