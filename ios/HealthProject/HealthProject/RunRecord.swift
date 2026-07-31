//
//  RunRecord.swift
//  HealthProject
//
//  서버(Spring Boot, GET/POST /api/runs)가 주고받는 러닝 기록 JSON을
//  Swift 구조체로 옮겨 담기 위한 모델 파일
//

import Foundation

// Codable: JSON <-> Swift 타입 변환(디코딩/인코딩)을 자동으로 처리해주는 프로토콜.
//          목록 조회는 Decodable, 기록 등록 응답도 서버가 같은 모양의 Run을 그대로 돌려주므로
//          하나의 타입으로 양쪽 다 처리 가능
// Identifiable: SwiftUI의 List가 각 항목을 구분(diff)할 때 이 id 값을 기준으로 사용함
struct RunRecord: Codable, Identifiable {
    let id: Int
    let distance: Double        // km 단위 (백엔드 Run.java의 distance 필드)
    let time: Double            // 분(minute) 단위, 소수 가능 (예: 30.5분 = 30분 30초)
    let heartRate: Int
    let speedKmh: Double
    let calorieBurned: Double

    // "N분 M초" 형태로 바꿔서 화면에 보여주기 위한 계산 프로퍼티
    // (계산 프로퍼티: 값을 저장하지 않고, 호출할 때마다 즉석에서 계산해서 돌려주는 프로퍼티)
    var timeDisplay: String {
        let totalSeconds = Int((time * 60).rounded())
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d분 %02d초", minutes, seconds)
    }

    // 페이스(1km를 뛰는 데 걸린 시간) 계산.
    // 기존 웹 프론트(app.js)와 동일한 공식: (time / distance) 분 → "M'SS\"" 형태로 표시
    var paceDisplay: String {
        guard distance > 0 else { return "-" }
        let paceTotalSeconds = Int(((time / distance) * 60).rounded())
        let paceMinutes = paceTotalSeconds / 60
        let paceSeconds = paceTotalSeconds % 60
        return String(format: "%d'%02d\"", paceMinutes, paceSeconds)
    }
}
