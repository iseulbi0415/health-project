//
//  FoodRecordEditView.swift
//  HealthProject
//
//  "오늘 먹은 음식" 목록 항목 수정 폼 — 스와이프/컨텍스트 메뉴의 "수정"에서 진입
//

import SwiftUI

struct FoodRecordEditView: View {
    let food: FoodRecord
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var calorieText: String
    @State private var quantityText: String
    @State private var meal: Meal
    @State private var digestCategory: DigestCategory
    @State private var isTrigger: Bool
    @State private var isSaving = false
    @State private var showAlert = false
    @State private var alertMessage = ""

    // 1개당 칼로리 — 신규 생성 시 quantity는 항상 1로 고정되므로, 이 화면에
    // 처음 들어온 시점의 food.calorie ÷ food.quantity가 정확한 1개당 기준값.
    // 수량을 바꾸면 이 값 × 새 수량으로 calorieText를 재계산함(단, 재계산 이후
    // 사용자가 칼로리 필드를 직접 고치면 그 값이 그대로 저장됨 — 수량을 다시
    // 바꾸기 전까진 자동 재계산이 덮어쓰지 않음)
    private let caloriePerUnit: Double

    init(food: FoodRecord, onSaved: @escaping () -> Void) {
        self.food = food
        self.onSaved = onSaved
        self._name = State(initialValue: food.name)
        self._calorieText = State(initialValue: String(food.calorie))
        self._quantityText = State(initialValue: String(food.quantity))
        self._meal = State(initialValue: Meal(rawValue: food.meal ?? "") ?? .breakfast)
        self._digestCategory = State(initialValue: DigestCategory(rawValue: Int(food.digestTime) ?? DigestCategory.normal.rawValue) ?? .normal)
        self._isTrigger = State(initialValue: food.isTrigger)
        self.caloriePerUnit = food.quantity > 0 ? Double(food.calorie) / Double(food.quantity) : Double(food.calorie)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("음식 정보") {
                    TextField("음식 이름", text: $name)
                    TextField("칼로리 (kcal)", text: $calorieText)
                        .keyboardType(.numberPad)
                    TextField("수량", text: $quantityText)
                        .keyboardType(.numberPad)
                        .onChange(of: quantityText) { _, newValue in
                            guard let quantity = Int(newValue), quantity > 0 else { return }
                            calorieText = String(Int((caloriePerUnit * Double(quantity)).rounded()))
                        }
                }

                Section("끼니") {
                    Picker("끼니", selection: $meal) {
                        ForEach(Meal.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                Section("소화 체감") {
                    Picker("소화 체감", selection: $digestCategory) {
                        ForEach(DigestCategory.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Toggle("⚠️ 트리거 음식(역류 유발 가능)", isOn: $isTrigger)
                }
            }
            .navigationTitle("기록 수정")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("저장", action: save)
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
        guard let quantity = Int(quantityText), quantity > 0 else {
            alertMessage = "수량을 올바른 숫자로 입력해주세요."
            showAlert = true
            return
        }

        isSaving = true
        Task {
            do {
                _ = try await FoodAPIService.updateFood(
                    id: food.id,
                    name: name,
                    calorie: calorie,
                    digestTime: String(digestCategory.rawValue),
                    isTrigger: isTrigger,
                    meal: meal,
                    quantity: quantity,
                    fatGrams: food.fatGrams
                )
                isSaving = false
                Haptics.success()
                onSaved()
                dismiss()
            } catch {
                isSaving = false
                alertMessage = "수정 실패: \(error.localizedDescription)"
                showAlert = true
            }
        }
    }
}

#Preview {
    FoodRecordEditView(
        food: FoodRecord(id: 1, name: "짜장면", calorie: 500, digestTime: "3", fatGrams: nil, meal: "lunch", quantity: 1, isTrigger: false, recordedAt: nil),
        onSaved: {}
    )
}
