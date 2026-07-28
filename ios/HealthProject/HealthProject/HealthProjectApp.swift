//
//  HealthProjectApp.swift
//  HealthProject
//
//  앱 진입점 — 카카오 SDK 초기화, 로그인 상태에 따른 화면 분기, 카카오 로그인 리다이렉트 처리
//

import SwiftUI
import KakaoSDKCommon
import KakaoSDKAuth

@main
struct HealthProjectApp: App {
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var digestionTimerManager = DigestionTimerManager.shared

    init() {
        KakaoSDK.initSDK(appKey: "864fa2f3dea2a67b3f2e130dd64eb020")
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isLoggedIn {
                    MainTabView()
                } else {
                    LoginView()
                }
            }
            .environmentObject(authManager)
            .environmentObject(digestionTimerManager)
            .task {
                await authManager.verifySession()
            }
            // 카카오톡 앱에서 로그인 후 돌아올 때 호출되는 리다이렉트 URL을 SDK가 처리하게 함
            .onOpenURL { url in
                if AuthApi.isKakaoTalkLoginUrl(url) {
                    _ = AuthController.handleOpenUrl(url: url)
                }
            }
        }
    }
}
