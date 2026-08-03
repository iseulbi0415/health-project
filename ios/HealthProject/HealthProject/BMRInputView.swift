//
//  BMRInputView.swift
//  HealthProject
//
//  "내 정보"의 BMR 계산용 키/체중/나이/성별/활동량 입력 시트 — FavoriteAddView와 같은 골격
//  (로컬 @State로 기존 값 프리필 + 취소/저장 툴바 + onSave 콜백). 계산 자체는 여기서 하지 않고
//  ProfileView의 bmrSummary가 저장된 값으로부터 매번 다시 계산함(단일 소스 유지)
//

import SwiftUI

struct BMRInputView: View {
    let onSave: (String, String, String, Gender, ActivityLevel) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var heightText: String
    @State private var weightText: String
    @State private var ageText: String
    @State private var gender: Gender
    @State private var activityLevel: ActivityLevel
    @State private var showAlert = false
    @State private var alertMessage = ""

    init(heightText: String, weightText: String, ageText: String, gender: Gender, activityLevel: ActivityLevel, onSave: @escaping (String, String, String, Gender, ActivityLevel) -> Void) {
        self._heightText = State(initialValue: heightText)
        self._weightText = State(initialValue: weightText)
        self._ageText = State(initialValue: ageText)
        self._gender = State(initialValue: gender)
        self._activityLevel = State(initialValue: activityLevel)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("키 (cm)", text: $heightText)
                        .keyboardType(.decimalPad)
                    TextField("체중 (kg)", text: $weightText)
                        .keyboardType(.decimalPad)
                    TextField("나이", text: $ageText)
                        .keyboardType(.numberPad)

                    Picker("성별", selection: $gender) {
                        ForEach(Gender.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    Picker("활동량", selection: $activityLevel) {
                        ForEach(ActivityLevel.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("BMR 계산")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장", action: save)
                }
            }
            .alert("확인해주세요", isPresented: $showAlert) {
                Button("확인", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
        }
    }

    private func save() {
        guard Double(heightText) != nil else {
            showError("키를 입력해주세요!")
            return
        }
        guard Double(weightText) != nil else {
            showError("체중을 입력해주세요!")
            return
        }
        guard Double(ageText) != nil else {
            showError("나이를 입력해주세요!")
            return
        }

        onSave(heightText, weightText, ageText, gender, activityLevel)
        dismiss()
    }

    private func showError(_ message: String) {
        alertMessage = message
        showAlert = true
    }
}

#Preview {
    BMRInputView(heightText: "", weightText: "", ageText: "", gender: .male, activityLevel: .moderate, onSave: { _, _, _, _, _ in })
}
