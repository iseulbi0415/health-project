//
//  DigestionTimerManager.swift
//  HealthProject
//
//  소화 안전 타이머 상태 — DietTimerView와 HomeView가 같이 보는 상태라서 AuthManager와 같은
//  싱글턴 ObservableObject 패턴으로 분리함 (두 화면은 TabView의 형제 탭이라 공통 부모가 앱 루트뿐)
//

import Combine
import Foundation

final class DigestionTimerManager: ObservableObject {
    static let shared = DigestionTimerManager()

    @Published private(set) var endTime: Date?
    @Published private(set) var totalSeconds: Int = 0

    private init() {
        loadPersisted()
    }

    // endTime(절대 종료 시각)만 진실의 원천으로 두고, 남은 시간/진행률은 호출 시점의 now로 매번 다시
    // 계산함 — 매초 -1 하는 방식이 아니라서 앱이 백그라운드에 있다 돌아와도 항상 정확함
    func remainingSeconds(at now: Date) -> Int {
        guard let endTime else { return 0 }
        return max(0, Int(endTime.timeIntervalSince(now)))
    }

    func progress(at now: Date) -> Double {
        guard totalSeconds > 0 else { return 0 }
        return Double(totalSeconds - remainingSeconds(at: now)) / Double(totalSeconds)
    }

    func countdownText(at now: Date) -> String {
        let remaining = remainingSeconds(at: now)
        let h = remaining / 3600
        let m = (remaining % 3600) / 60
        let s = remaining % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    var endTimeText: String {
        guard let endTime else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "a h:mm"
        formatter.locale = Locale(identifier: "ko_KR")
        return "\(formatter.string(from: endTime))에 완료"
    }

    func warningText(at now: Date) -> String {
        guard endTime != nil else { return "" }
        return remainingSeconds(at: now) > 0 ? "지금 누우면 역류 위험이 있어요" : "소화 완료! 이제 누우셔도 됩니다!"
    }

    // 이미 타이머가 돌고 있으면 남은 시간과 새로 계산된 시간 중 더 긴 쪽을 쓰는 "안전 마진" 규칙
    // (줄어드는 방향으로는 절대 안 바뀜) — 웹과 동일
    func start(hours: Int) {
        let newTotalSeconds = hours * 3600
        let currentRemaining = remainingSeconds(at: Date())

        var finalRemaining = newTotalSeconds
        var finalTotal = newTotalSeconds
        if currentRemaining > newTotalSeconds {
            finalRemaining = currentRemaining
            finalTotal = totalSeconds
        }

        endTime = Date().addingTimeInterval(Double(finalRemaining))
        totalSeconds = finalTotal
        persist()
    }

    func cancel() {
        endTime = nil
        totalSeconds = 0
        UserDefaults.standard.removeObject(forKey: "digestEndTime")
        UserDefaults.standard.removeObject(forKey: "digestTotalSeconds")
    }

    private func persist() {
        guard let endTime else { return }
        UserDefaults.standard.set(endTime.timeIntervalSince1970, forKey: "digestEndTime")
        UserDefaults.standard.set(totalSeconds, forKey: "digestTotalSeconds")
    }

    private func loadPersisted() {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: "digestEndTime") != nil else { return }
        endTime = Date(timeIntervalSince1970: defaults.double(forKey: "digestEndTime"))
        totalSeconds = defaults.integer(forKey: "digestTotalSeconds")
    }
}
