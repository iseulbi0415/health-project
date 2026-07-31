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
}
