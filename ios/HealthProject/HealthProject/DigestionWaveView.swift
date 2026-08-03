//
//  DigestionWaveView.swift
//  HealthProject
//
//  소화 안전 타이머 — 앱의 시그니처 요소라 나머지 화면과 달리 물결(웨이브) 애니메이션으로 표현.
//  DigestionWaveContainerView(DigestionTimerManager 연결) → DigestionWaveView(순수 렌더링) → WaveShape(도형) 3단 구조.
//

import SwiftUI

// 물이 차오르는 방향(도형 자체는 phase 고정, 좌우 흐름은 ScrollingWave의 .offset()이 담당 —
// Shape.animatableData에 phase를 넣으면 매 프레임 path(in:)가 재계산돼 사실상 상시 60fps 리드로우가 되므로
// waterLevel만 animatableData로 두고 스크롤은 트랜스폼으로 분리함(배터리 비용 분리)
struct WaveShape: Shape {
    var waterLevel: CGFloat   // 0 = 빔, 1 = 가득
    let amplitude: CGFloat
    let wavelength: CGFloat

    var animatableData: CGFloat {
        get { waterLevel }
        set { waterLevel = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addPath(Self.crestPath(in: rect, waterLevel: waterLevel, amplitude: amplitude, wavelength: wavelength))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        return path
    }

    static func crestPath(in rect: CGRect, waterLevel: CGFloat, amplitude: CGFloat, wavelength: CGFloat) -> Path {
        let waterLevelY = rect.height * (1 - waterLevel)
        // waterLevel이 0(빔) 또는 1(가득)에 가까워질수록 진폭을 0으로 줄여서 크레스트가 경계선을
        // 넘어가지 않게 함 — 안 그러면 0%에서도 sin의 음(-) 위상이 바닥선 위로 튀어나와 "완전히
        // 안 비워진" 것처럼 얇은 색 띠가 남음(1%에서도 대칭적으로 동일한 문제)
        let edgeDamping = min(1, min(waterLevel, 1 - waterLevel) / 0.08)
        let dampedAmplitude = amplitude * edgeDamping

        var path = Path()
        path.move(to: CGPoint(x: 0, y: waterLevelY))
        let step: CGFloat = 4
        var x: CGFloat = 0
        while x <= rect.width {
            let y = waterLevelY + dampedAmplitude * sin(2 * .pi * x / wavelength)
            path.addLine(to: CGPoint(x: x, y: y))
            x += step
        }
        return path
    }
}

// 물결의 윗면 곡선만 따로 그리는 도형(채우기용 WaveShape와 좌표 계산이 완전히 동일) — 이 위에
// 밝은 하이라이트 선을 스트로크로 얹어서 곡선 윤곽이 카드 위에서 또렷이 보이게 함
struct WaveCrestShape: Shape {
    var waterLevel: CGFloat
    let amplitude: CGFloat
    let wavelength: CGFloat

    var animatableData: CGFloat {
        get { waterLevel }
        set { waterLevel = newValue }
    }

    func path(in rect: CGRect) -> Path {
        WaveShape.crestPath(in: rect, waterLevel: waterLevel, amplitude: amplitude, wavelength: wavelength)
    }
}

// 컨테이너 폭의 2배로 그려서 정확히 폭만큼 옆으로 흘려보내는 방식(CSS의 width:200% + translateX(-50%)
// 이중폭 시임리스 루프 트릭과 동일) — sin 함수 자체가 무한 주기함수라 이 폭 어디서 반씩 잘라 보여줘도
// 이어붙임 자국이 안 생김.
//
// ⚠️ 스크롤 오프셋을 @State + .onAppear + withAnimation(repeatForever)로 구현했더니, 이 뷰가
// TimelineView(.periodic(from:.now, by:1)) 안에서 매초 다시 만들어지는 바람에 .onAppear가 매초
// 재호출되어 애니메이션이 계속 처음부터 재시작되는 버그가 있었음(물결이 매끄럽게 흐르지 않고
// "오른쪽에서 왼쪽으로 차오르는" 게 반복되던 원인). @State에 의존하지 않고 현재 시각으로부터
// 오프셋을 직접 계산하는 방식으로 바꿔서, 뷰가 매초 다시 만들어져도 항상 같은 값이 나오게 함
// (상태를 잃어버릴 게 없으니 재시작 자체가 불가능해짐)
//
// waterLevel도 같은 이유로 정적 값이 아니라 클로저로 받아서 이 뷰의 20fps TimelineView 안에서
// 매 프레임 직접 계산함 — 예전엔 부모(1Hz TimelineView)가 계산한 값을 .animation(value:)로
// 받았는데, 그러면 easeInOut 애니메이션이 정확히 1초마다 재시작되면서 감속/가속 곡선이 1Hz
// 주기로 반복돼 "박동하듯 깜빡이는" 것처럼 보였음(값 자체가 리셋되는 게 아니라 이징이 매초
// 다시 걸리는 게 원인). 20fps로 연속 계산하면 이 문제가 애초에 생기지 않음
private struct ScrollingWave: View {
    let levelFraction: (Date) -> Double
    let amplitude: CGFloat
    let crestsVisible: CGFloat
    let gradient: LinearGradient

    private let period: Double = 6

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let wavelength = width / max(crestsVisible, 0.5)

            TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: false)) { timeline in
                let waterLevel = CGFloat(levelFraction(timeline.date))
                let fillShape = WaveShape(waterLevel: waterLevel, amplitude: amplitude, wavelength: wavelength)
                let crestShape = WaveCrestShape(waterLevel: waterLevel, amplitude: amplitude, wavelength: wavelength)

                let elapsed = timeline.date.timeIntervalSinceReferenceDate
                let progress = elapsed.truncatingRemainder(dividingBy: period) / period
                let offsetX = -width * progress

                ZStack {
                    fillShape
                        .fill(gradient)
                        .frame(width: width * 2, height: geo.size.height)
                        .offset(x: offsetX)
                    crestShape
                        .stroke(Color.white.opacity(0.6), lineWidth: 1.5)
                        .frame(width: width * 2, height: geo.size.height)
                        .offset(x: offsetX)
                }
            }
        }
    }
}

struct DigestionWaveView: View {
    // 1 - progress(at:) — 소화될수록 비워지는 방향. ScrollingWave의 20fps TimelineView 안에서
    // 매 프레임 직접 계산되도록 클로저로 받음(정적 Double을 매초 새로 넘기면 애니메이션이
    // 1Hz로 재시작되는 문제가 있었음 — ScrollingWave 위 주석 참고)
    var levelFraction: (Date) -> Double
    var countdownText: String
    var endTimeText: String
    var warningText: String
    var isFinished: Bool
    var style: Style

    enum Style: Equatable {
        case compact   // HomeView 요약 카드
        case hero      // DietTimerView 메인

        var height: CGFloat { self == .compact ? 76 : 132 }
        var amplitude: CGFloat { self == .compact ? 8 : 14 }
        // ScrollingWave가 offsetX를 -width까지 흘려보냈다가 0으로 되감는 방식(6초 주기)이라,
        // width가 파장(wavelength = width / crestsVisible)의 정수배여야 되감기는 순간이 안 튐 —
        // 즉 crestsVisible 자체가 정수여야 함. 예전에 1.5였을 때 되감길 때마다 반 주기(180도)
        // 어긋난 채로 이어져서 물결이 순간적으로 "재배치"되는 것처럼 보이는 버그가 있었음
        var crestsVisible: CGFloat { self == .compact ? 1 : 2 }
        var cornerRadius: CGFloat { 16 }
        var countdownFont: Font {
            self == .compact ? .title3.bold() : .largeTitle.bold()
        }
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)

        ZStack {
            shape
                .fill(Color.clear)
                .glassEffect(.regular.tint(Color.accentColor.opacity(0.08)), in: shape)

            ScrollingWave(
                levelFraction: levelFraction,
                amplitude: style.amplitude,
                crestsVisible: style.crestsVisible,
                gradient: LinearGradient(
                    colors: isFinished
                        ? [Color("SuccessGreen").opacity(0.45), Color("SuccessGreen").opacity(0.95)]
                        : [Color.accentColor.opacity(0.45), Color.accentColor.opacity(0.95)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(shape)
            .animation(.easeInOut(duration: 0.6), value: isFinished)

            VStack(spacing: 4) {
                Text(countdownText)
                    .font(style.countdownFont)
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                Text(endTimeText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if style == .hero {
                    Text(warningText)
                        .font(.footnote)
                        .foregroundStyle(isFinished ? Color("SuccessGreen") : Color("CalorieCoral"))
                }
            }
            .padding(.horizontal, 8)

            // 완료 시점을 카드 자체에서도 알 수 있게 하는 이펙트 — 물결 색이 초록으로 바뀌는 것과
            // 별개로, 눈에 잘 띄는 체크마크 배지를 모서리에 확대/페이드로 등장시킴
            if isFinished {
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .font(style == .hero ? .title2 : .title3)
                            .foregroundStyle(Color("SuccessGreen"))
                            .padding(style == .hero ? 10 : 6)
                            .transition(.scale(scale: 0.4).combined(with: .opacity))
                    }
                    Spacer()
                }
            }
        }
        .frame(height: style.height)
        .clipShape(shape)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: isFinished)
    }
}

// DigestionTimerManager와 실제로 연결되는 쪽 — HomeView/DietTimerView는 이 뷰만 놓으면 됨
struct DigestionWaveContainerView: View {
    @EnvironmentObject private var digestionTimerManager: DigestionTimerManager
    var style: DigestionWaveView.Style

    var body: some View {
        Group {
            if digestionTimerManager.endTime != nil {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    DigestionWaveView(
                        levelFraction: { date in 1 - digestionTimerManager.progress(at: date) },
                        countdownText: digestionTimerManager.countdownText(at: context.date),
                        endTimeText: digestionTimerManager.endTimeText,
                        warningText: digestionTimerManager.warningText(at: context.date),
                        isFinished: digestionTimerManager.remainingSeconds(at: context.date) == 0,
                        style: style
                    )
                }
            } else {
                DigestionEmptyStateView(style: style)
            }
        }
    }
}

private struct DigestionEmptyStateView: View {
    var style: DigestionWaveView.Style

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "drop")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("소화 중인 기록 없음")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: style == .compact ? 60 : 90)
    }
}

#Preview("Hero — 68% 남음") {
    DigestionWaveView(
        levelFraction: { _ in 0.68 },
        countdownText: "01:42:30",
        endTimeText: "오후 11:47에 완료",
        warningText: "🙅‍♀️ 아직 눕지 마세요!",
        isFinished: false,
        style: .hero
    )
    .padding()
}

#Preview("Compact — 30% 남음") {
    DigestionWaveView(
        levelFraction: { _ in 0.3 },
        countdownText: "00:18:04",
        endTimeText: "오후 9:10에 완료",
        warningText: "🙅‍♀️ 아직 눕지 마세요!",
        isFinished: false,
        style: .compact
    )
    .padding()
}

#Preview("완료") {
    DigestionWaveView(
        levelFraction: { _ in 0 },
        countdownText: "00:00:00",
        endTimeText: "오후 9:10에 완료",
        warningText: "소화 완료! 이제 누우셔도 됩니다!",
        isFinished: true,
        style: .hero
    )
    .padding()
}

#Preview("빈 상태") {
    DigestionWaveContainerView(style: .hero)
        .environmentObject(DigestionTimerManager.shared)
        .padding()
}
