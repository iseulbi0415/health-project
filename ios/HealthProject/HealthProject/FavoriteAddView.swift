//
//  FavoriteAddView.swift
//  HealthProject
//
//  즐겨찾기(자주 먹는 음식) 등록 폼
//

import SwiftUI

struct FavoriteAddView: View {
    let onSave: (FavoriteFood) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var calorieText = ""
    @State private var digestCategory = DigestCategory.normal
    @State private var isTrigger = false
    @State private var showAlert = false
    @State private var alertMessage = ""

    // 자동 매칭이 정확한 영양정보를 못 찾았을 때, 검색했던 이름을 그대로 채워서 이 폼으로 연결하기 위한
    // 프리필 파라미터 — 기존 호출부(DietTimerView)는 그대로 인자 없이 호출 가능(기본값 "")
    init(initialName: String = "", onSave: @escaping (FavoriteFood) -> Void) {
        self._name = State(initialValue: initialName)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("음식 정보") {
                    TextField("음식 이름", text: $name)
                    TextField("칼로리 (kcal)", text: $calorieText)
                        .keyboardType(.numberPad)
                }

                Section("소화 체감") {
                    Picker("소화 체감", selection: $digestCategory) {
                        ForEach(DigestCategory.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Text(digestCategory.exampleFoods)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Toggle("⚠️ 트리거 음식(역류 유발 가능)", isOn: $isTrigger)
                }
            }
            .navigationTitle("즐겨찾기 등록")
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
        guard !name.isEmpty else {
            alertMessage = "음식 이름을 입력해주세요."
            showAlert = true
            return
        }
        guard let calorie = Int(calorieText) else {
            alertMessage = "칼로리를 올바른 숫자로 입력해주세요."
            showAlert = true
            return
        }

        onSave(FavoriteFood(name: name, calorie: calorie, digestCategory: digestCategory, isTrigger: isTrigger))
        dismiss()
    }
}

#Preview {
    FavoriteAddView(onSave: { _ in })
}
