//
//  GradientHeaderView.swift
//  HealthProject
//
//  화면 최상단 그라데이션 인사말 헤더 — 목업의 시그니처 요소. 카드/목록 배경은 흰색·시스템 기본을
//  유지하되, 이 헤더만은 화면마다 다른 색으로 앱 정체성을 보여줌(홈=blue/식단·타이머=green/러닝=coral/내정보=purple)
//
//  제목 행에 화면별 액션 버튼(+, 돋보기 등)을 같이 두는 구조 — "제목+버튼 한 줄 / 부제 한 줄" 2줄로
//  4화면 모두 통일해서, 버튼이 있고 없고에 따라 배너 높이가 달라지지 않게 함 (버튼이 예전엔 nav bar
//  툴바에 따로 있어서 그 화면만 배너가 더 길어 보이던 문제가 있었음)
//

import SwiftUI

struct GradientHeaderView<Actions: View>: View {
    let title: String
    let subtitle: String
    let colors: [Color]
    @ViewBuilder var actions: () -> Actions

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 16) {
                Text(title)
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                // minLength로 제목과 버튼 사이 최소 간격을 보장 — 제목이 짧아도 버튼이 바짝 붙지 않음
                Spacer(minLength: 16)
                actions()
            }
            // 버튼 유무·캡슐 유무와 무관하게 4화면 모두 이 줄의 높이를 강제로 통일 —
            // 안 그러면 버튼 없는 화면(홈)과 버튼 있는 화면들의 배너 높이가 달라짐.
            // HeaderActionButton의 52pt 크기에 맞춤
            .frame(minHeight: 52)
            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        .background(
            // 배경만 상태바 뒤까지 꽉 채우고, 텍스트(이 View의 실제 레이아웃)는 안전영역 안에 그대로 둠 —
            // 이렇게 안 하고 View 전체에 ignoresSafeArea를 걸면 텍스트까지 밀려 올라가 상태바 시계와 겹침
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea(edges: .top)
        )
    }
}

// GradientHeaderView가 제네릭 타입(Actions)이라 그 안에 static 프로퍼티로 두면 참조할 때마다
// Actions를 특정해야 하는 문제가 있어서, 제네릭과 무관한 별도 네임스페이스로 뺌.
// 원본 웹 목업 헤더 그라데이션(135deg, 진한 톤→팔레트 기본색)과 동일한 톤 매핑
enum HeaderPalette {
    static var blue: [Color] { [Color(red: 0x27 / 255, green: 0x4d / 255, blue: 0x92 / 255), Color.accentColor] }
    static var green: [Color] { [Color(red: 0x1a / 255, green: 0x7a / 255, blue: 0x45 / 255), Color("SuccessGreen")] }
    static var coral: [Color] { [Color(red: 0xc0 / 255, green: 0x5a / 255, blue: 0x2a / 255), Color("CalorieCoral")] }
    static var purple: [Color] { [Color(red: 0x4a / 255, green: 0x2f / 255, blue: 0x80 / 255), Color("AccentPurple")] }
}

// 배너 안 액션 버튼 — 흰 반투명 원형 배경. 예전엔 44pt였는데 검색창 X 버튼보다 작아 보여서
// 52pt로, 아이콘도 .imageScale(.large)로 같이 키움(배경/재질/모양은 그대로 유지)
struct HeaderActionButton: View {
    let systemImage: String
    let action: () -> Void
    private let dimension: CGFloat = 52

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .imageScale(.large)
                .foregroundStyle(.white)
                .frame(width: dimension, height: dimension)
                .background(Circle().fill(.white.opacity(0.22)))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

// 여러 버튼을 하나의 캡슐 배경 안에 나란히 묶어서 보여줄 때 씀(식단·타이머의 +/돋보기) — 예전엔 nav bar
// 툴바가 인접한 버튼들을 자동으로 하나의 pill로 묶어줬던 모습을 배너 안에서 재현
struct HeaderActionCapsule<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(spacing: 18) {
            content()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        // 세로 패딩 12pt × 2 + 아이콘 28pt = 52pt — HeaderActionButton의 52pt와 높이를 맞춤
        .padding(.vertical, 12)
        .background(Capsule().fill(.white.opacity(0.22)))
    }
}

#Preview {
    VStack(spacing: 12) {
        GradientHeaderView(title: "안녕하세요 🌿 오늘도 안심하게", subtitle: "역류성 식도염 케어 & 러닝 관리", colors: HeaderPalette.blue) {
            EmptyView()
        }
        GradientHeaderView(title: "식단·타이머", subtitle: "오늘 먹은 음식과 소화 타이머", colors: HeaderPalette.green) {
            HeaderActionCapsule {
                Button {} label: { Image(systemName: "plus").imageScale(.large).frame(width: 28, height: 28).contentShape(Rectangle()) }
                Button {} label: { Image(systemName: "magnifyingglass").imageScale(.large).frame(width: 28, height: 28).contentShape(Rectangle()) }
            }
        }
        GradientHeaderView(title: "러닝 기록", subtitle: "오늘도 힘차게 달려볼까요", colors: HeaderPalette.coral) {
            HeaderActionButton(systemImage: "plus") {}
        }
        GradientHeaderView(title: "내 정보", subtitle: "BMR·목표 칼로리와 컨디션 기록", colors: HeaderPalette.purple) {
            HeaderActionButton(systemImage: "plus") {}
        }
    }
}
