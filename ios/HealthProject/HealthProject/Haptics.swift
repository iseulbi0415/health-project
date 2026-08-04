//
//  Haptics.swift
//  HealthProject
//
//  추가/수정/삭제 성공 시 가벼운 손맛을 주기 위한 공용 헬퍼 — 웹에는 없는 iOS 전용 UX
//

import UIKit

enum Haptics {
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    // 증상 점수 슬라이더처럼 값이 연속으로 바뀌는 컨트롤용 — success()보다 훨씬 가벼운 "틱" 느낌.
    // 호출할 때마다 새 제너레이터를 만들면 Taptic Engine에 매번 새로 연결하는 오버헤드가 생겨서
    // 슬라이더를 빠르게 드래그할 때 살짝 버벅이는 느낌이 남 — 하나만 만들어 재사용함
    private static let selectionGenerator = UISelectionFeedbackGenerator()

    static func selection() {
        selectionGenerator.selectionChanged()
    }
}
