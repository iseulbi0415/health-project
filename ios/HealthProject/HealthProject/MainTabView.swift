//
//  MainTabView.swift
//  HealthProject
//
//  로그인 후 보여주는 4탭 구조 — 웹 프로젝트와 동일한 순서(홈/식단·타이머/러닝/내 정보)
//

import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("홈", systemImage: "house") }
            DietTimerView()
                .tabItem { Label("식단·타이머", systemImage: "fork.knife") }
            ContentView()
                .tabItem { Label("러닝", systemImage: "figure.run") }
            ProfileView()
                .tabItem { Label("내 정보", systemImage: "person.circle") }
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthManager.shared)
        .environmentObject(DigestionTimerManager.shared)
}
