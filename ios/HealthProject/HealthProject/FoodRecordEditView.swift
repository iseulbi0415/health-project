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
    // 화면엔 안 보이지만(폼에 입력 필드 없음) 수량이 바뀔 때 caloriePerUnit과 동일한 방식으로
    // 비례 재계산해서 저장 시 같이 실어 보냄 — fatGramsPerUnit 주석 참고
    @State private var fatGrams: Double?
    @State private var isSaving = false
    @State private var showAlert = false
    @State private var alertMessage = ""

    // 1개당 칼로리 — 신규 생성 시 quantity는 항상 1로 고정되므로, 이 화면에
    // 처음 들어온 시점의 food.calorie ÷ food.quantity가 정확한 1개당 기준값.
    // 수량을 바꾸면 이 값 × 새 수량으로 calorieText를 재계산함(단, 재계산 이후
    // 사용자가 칼로리 필드를 직접 고치면 그 값이 그대로 저장됨 — 수량을 다시
    // 바꾸기 전까진 자동 재계산이 덮어쓰지 않음)
    private let caloriePerUnit: Double
    // 1개당 지방(g) — caloriePerUnit과 동일한 이유로 필요함. fatGrams는 두 경로로
    // 만들어지는데 (1) 즐겨찾기/자동매칭/검색에서 최초 등록 시엔 "1개 기준" 값이고,
    // (2) 같은 음식을 여러 번 추가해 서버가 병합한 경우엔 FoodController.createFood가
    // calorie와 함께 누적 합산해서 이미 "수량 반영된 총량"임. 이 화면에 들어온 시점의
    // food.fatGrams ÷ food.quantity로 역산하면 두 경로 모두에서 정확한 1개당 값이 나오고,
    // 수량을 바꾸면 그 값 × 새 수량으로 재계산해서 항상 "수량 반영된 총량" 의미를 유지함.
    // (예전엔 이 재계산이 없어서 수량만 늘리면 지방은 1개분에 머물러 소화 타이머 fatSum이
    // 과소 계산되는 버그가 있었음 — DietTimerView.swift의 fatSum은 그대로 두고 여기서 고침)
    private let fatGramsPerUnit: Double?
    // 저장 시점에 이 값과 digestCategory를 비교해서 사용자가 소화 체감을 직접 바꿨는지 판단함.
    // 실측 fatGrams가 있어도 소화 타이머 계산은 항상 fatGrams를 카테고리보다 우선하는데
    // (DietTimerView.swift의 fatSum 참고), 그러면 사용자가 카테고리를 명시적으로 바꿔도
    // 반영되지 않는 문제가 있었음 — 카테고리를 바꾼 경우엔 "사용자 판단이 실측값보다
    // 우선"이라고 보고 fatGrams를 지워서, 바뀐 카테고리의 대표값이 쓰이게 함
    private let originalDigestCategory: DigestCategory

    init(food: FoodRecord, onSaved: @escaping () -> Void) {
        self.food = food
        self.onSaved = onSaved
        self._name = State(initialValue: food.name)
        self._calorieText = State(initialValue: String(food.calorie))
        self._quantityText = State(initialValue: String(food.quantity))
        self._meal = State(initialValue: Meal(rawValue: food.meal ?? "") ?? .breakfast)
        self._digestCategory = State(initialValue: DigestCategory(rawValue: Int(food.digestTime) ?? DigestCategory.normal.rawValue) ?? .normal)
        self._isTrigger = State(initialValue: food.isTrigger)
        self._fatGrams = State(initialValue: food.fatGrams)
        self.originalDigestCategory = DigestCategory(rawValue: Int(food.digestTime) ?? DigestCategory.normal.rawValue) ?? .normal
        self.caloriePerUnit = food.quantity > 0 ? Double(food.calorie) / Double(food.quantity) : Double(food.calorie)
        if let fat = food.fatGrams {
            self.fatGramsPerUnit = food.quantity > 0 ? fat / Double(food.quantity) : fat
        } else {
            self.fatGramsPerUnit = nil
        }
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
                            if let fatGramsPerUnit {
                                fatGrams = fatGramsPerUnit * Double(quantity)
                            }
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
                    // 트리거/경고 계열 색은 CalorieCoral로 통일 — FavoriteAddView와 동일
                    Toggle(isOn: $isTrigger) {
                        Label("트리거 음식(역류 유발 가능)", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color("CalorieCoral"))
                    }
                    .tint(Color("CalorieCoral"))
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

        // 소화 체감을 원래 값에서 직접 바꿨다면 사용자 판단을 실측값보다 우선 — fatGrams를
        // 지워서 DietTimerView의 fatSum이 (더 이상 실측값에 가로막히지 않고) 바뀐 카테고리의
        // 대표값을 쓰게 함
        let fatGramsToSave = digestCategory == originalDigestCategory ? fatGrams : nil

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
                    fatGrams: fatGramsToSave
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
