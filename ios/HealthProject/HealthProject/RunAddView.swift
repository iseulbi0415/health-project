//
//  RunAddView.swift
//  HealthProject
//
//  러닝 기록 입력 폼. 웹(app.js)의 "러닝 기록 저장" 버튼과 동일한 항목(거리/시간/심박수)을 받고,
//  저장 시 웹의 validateRunInput()과 같은 기준으로 검증한 뒤 백엔드에 등록함
//

import SwiftUI

struct RunAddView: View {
    // 저장 성공 시 부모(ContentView)에게 알려서 목록을 새로고침하고 시트를 닫게 하는 콜백
    let onSaved: () -> Void
    // nil이면 서버가 현재시각으로 채움(오늘 기록), 특정 날짜+시각 문자열이면 그 날짜로 저장됨
    // (DayDetailView의 "이 날짜로 러닝 추가"에서만 값을 넘김 — 기존 호출부는 그대로 nil)
    var recordedAt: String? = nil
    // nil이면 신규 등록, 값이 있으면 수정 모드(스와이프/컨텍스트 메뉴 "수정"에서 진입) — id를 대상으로 updateRun 호출
    var existingRun: RunRecord? = nil

    @Environment(\.dismiss) private var dismiss

    // ProfileView/HomeView와 같은 키 — UserProfileAPIService.hydrateLocalCache()가 로그인 시
    // 서버의 실제 체중으로 이미 채워둠. 칼로리 계산에 씀(RunAPIService.calculateRunStats 참고)
    @AppStorage("bmrWeight") private var weightText = ""

    @State private var distanceText: String     // km
    @State private var timeText: String         // "mm:ss" 형식 (웹과 동일한 입력 관례)
    @State private var heartRateText: String    // bpm
    @State private var isSaving = false
    @State private var showAlert = false
    @State private var alertMessage = ""

    init(onSaved: @escaping () -> Void, recordedAt: String? = nil, existingRun: RunRecord? = nil) {
        self.onSaved = onSaved
        self.recordedAt = recordedAt
        self.existingRun = existingRun
        self._distanceText = State(initialValue: existingRun.map { String($0.distance) } ?? "")
        self._timeText = State(initialValue: existingRun.map { RunAddView.mmss(from: $0.time) } ?? "")
        self._heartRateText = State(initialValue: existingRun.map { String($0.heartRate) } ?? "")
    }

    // RunRecord.time(분, 소수)을 입력창의 "mm:ss" 표기로 되돌리는 역변환 — parseTotalMinutes()의 반대
    private static func mmss(from totalMinutes: Double) -> String {
        let totalSeconds = Int((totalMinutes * 60).rounded())
        return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("러닝 기록 입력") {
                    TextField("거리 (km)", text: $distanceText)
                        .keyboardType(.decimalPad)
                    TextField("시간 (예: 30:15)", text: $timeText)
                        .keyboardType(.numbersAndPunctuation)
                    TextField("심박수 (bpm)", text: $heartRateText)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle(existingRun == nil ? "기록 추가" : "기록 수정")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("저장") { save() }
                    }
                }
            }
            .alert("확인해주세요", isPresented: $showAlert) {
                Button("확인", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
        }
    }

    // "mm:ss" 텍스트를 "총 분(minute)" 소수값으로 변환.
    // 웹(app.js)은 초 부분이 없거나 이상해도 0으로 봐주지만(Number(...) || 0), 분 부분이 숫자가
    // 아니면 NaN이 그대로 서버까지 넘어가는 허점이 있음 — Swift는 분 파싱 실패 시 nil을 돌려줘서
    // 아예 저장 자체를 막으므로 웹보다 한 단계 더 안전하게 처리됨
    private func parseTotalMinutes(from text: String) -> Double? {
        let parts = text.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        guard let minutesPart = parts.first, let minutes = Double(minutesPart) else { return nil }
        let seconds = parts.count > 1 ? (Double(parts[1]) ?? 0) : 0
        return minutes + seconds / 60
    }

    private func showError(_ message: String) {
        alertMessage = message
        showAlert = true
    }

    private func save() {
        guard let distance = Double(distanceText) else {
            showError("거리를 올바른 숫자로 입력해주세요.")
            return
        }
        guard let totalMinutes = parseTotalMinutes(from: timeText) else {
            showError("시간을 올바르게 입력해주세요 (예: 30:15).")
            return
        }
        guard let heartRate = Int(heartRateText) else {
            showError("심박수를 올바른 숫자로 입력해주세요.")
            return
        }

        // 웹의 validateRunInput()과 동일한 기준: 거리/시간은 0 초과, 심박수는 30~250만 허용
        // (백엔드 RunController.validateRun()에도 같은 기준으로 2차 검증이 있어서, 여길 통과해도
        // 서버가 한 번 더 확인함)
        if distance <= 0 {
            showError("거리는 0보다 커야 합니다.")
            return
        }
        if totalMinutes <= 0 {
            showError("시간은 0보다 커야 합니다.")
            return
        }
        if heartRate < 30 || heartRate > 250 {
            showError("심박수가 올바르지 않습니다 (30~250 사이로 입력해주세요).")
            return
        }

        // 웹(app.js)과 동일한 정책 — 체중 미입력 시 60kg로 조용히 계산하는 대신 저장을 막고
        // 내 정보 입력을 유도. 웹은 탭까지 자동으로 전환하지만, iOS는 TabView 구조를 안 건드리기
        // 위해 알럿 안내까지만 함
        guard let weightKg = Double(weightText) else {
            showError("정확한 칼로리 계산을 위해 내 정보 탭에서 체중을 먼저 입력해주세요.")
            return
        }

        isSaving = true
        Task {
            do {
                if let existingRun {
                    _ = try await RunAPIService.updateRun(id: existingRun.id, distance: distance, totalMinutes: totalMinutes, heartRate: heartRate, weightKg: weightKg)
                } else {
                    _ = try await RunAPIService.createRun(distance: distance, totalMinutes: totalMinutes, heartRate: heartRate, weightKg: weightKg, recordedAt: recordedAt)
                }
                isSaving = false
                Haptics.success()
                onSaved()
            } catch {
                isSaving = false
                showError(error.localizedDescription)
            }
        }
    }
}

#Preview {
    RunAddView(onSaved: {})
}
