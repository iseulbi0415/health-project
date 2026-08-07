//
//  DayDetailView.swift
//  HealthProject
//
//  특정 날짜의 식단/러닝/메모를 한 화면에서 조회 + 그 날짜로 새 기록 추가 (소화 타이머는 포함 안 함)
//

import SwiftUI

struct DayDetailView: View {
    let date: String   // "yyyy-MM-dd"
    // 이 날짜의 식단/러닝/메모가 추가·수정·삭제될 때마다 호출 — 부모(DietTimerView)가 달력 점
    // 표시(markedDates)를 다시 불러오게 함. loadDayDetail()이 끝날 때마다 한 번씩 불러서
    // 어느 종류(식단/러닝/메모)를 바꾸든 빠짐없이 반영되게 함
    var onDataChanged: () -> Void = {}

    // 타이틀에 요일을 작게 덧붙임 — "2026-07-21 (화)"
    private var dateWithWeekday: String {
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        guard let parsed = parser.date(from: date) else { return date }
        let weekdayFormatter = DateFormatter()
        weekdayFormatter.dateFormat = "E"
        weekdayFormatter.locale = Locale(identifier: "ko_KR")
        return "\(date) (\(weekdayFormatter.string(from: parsed)))"
    }

    @State private var foods: [FoodRecord] = []
    @State private var runs: [RunRecord] = []
    @State private var memos: [MemoRecord] = []

    // 아침→점심→저녁→간식 고정 순서로 표시(DietTimerView.groupedTodayFoods와 동일한 규칙) —
    // 서버는 recordedAt 순으로만 내려주므로 끼니 순서는 여기서 별도로 맞춤
    private var sortedFoods: [FoodRecord] {
        foods.sorted { mealSortIndex(for: $0.meal) < mealSortIndex(for: $1.meal) }
    }

    private func mealSortIndex(for rawValue: String?) -> Int {
        guard let rawValue, let meal = Meal(rawValue: rawValue),
              let index = Meal.allCases.firstIndex(of: meal) else {
            return Meal.allCases.count
        }
        return index
    }
    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var isShowingFoodPicker = false
    @State private var isShowingRunAdd = false
    // 스와이프/컨텍스트 메뉴 "수정"에서 열리는 편집 시트 대상 — DietTimerView/ContentView/ProfileView와 동일 패턴
    @State private var editingFood: FoodRecord?
    @State private var editingRun: RunRecord?
    @State private var editingMemo: MemoRecord?

    @State private var memoText = ""
    @State private var symptomScore: Double = 5
    @State private var isSavingMemo = false
    @State private var memoAlertMessage = ""
    @State private var showMemoAlert = false

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }

                Section("식단") {
                    if foods.isEmpty {
                        Text("기록 없음").foregroundStyle(.secondary)
                    } else {
                        ForEach(sortedFoods) { food in
                            HStack {
                                Text(food.quantity > 1 ? "\(food.name) ×\(food.quantity)" : food.name)
                                Spacer()
                                Text("\(food.calorie) kcal")
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button("삭제", role: .destructive) {
                                    Task { await deleteFood(food) }
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button("수정") { editingFood = food }
                                    .tint(.blue)
                            }
                            .contextMenu {
                                Button("수정") { editingFood = food }
                                Button("삭제", role: .destructive) {
                                    Task { await deleteFood(food) }
                                }
                            }
                        }
                    }
                    Button("이 날짜로 음식 추가") { isShowingFoodPicker = true }
                }

                Section("러닝") {
                    if runs.isEmpty {
                        Text("기록 없음").foregroundStyle(.secondary)
                    } else {
                        ForEach(runs) { run in
                            HStack {
                                Text("\(run.distance, specifier: "%.2f") km")
                                Spacer()
                                Text(run.timeDisplay)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button("삭제", role: .destructive) {
                                    Task { await deleteRun(run) }
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button("수정") { editingRun = run }
                                    .tint(.blue)
                            }
                            .contextMenu {
                                Button("수정") { editingRun = run }
                                Button("삭제", role: .destructive) {
                                    Task { await deleteRun(run) }
                                }
                            }
                        }
                    }
                    Button("이 날짜로 러닝 추가") { isShowingRunAdd = true }
                }

                Section("컨디션 메모") {
                    if memos.isEmpty {
                        Text("기록 없음").foregroundStyle(.secondary)
                    } else {
                        ForEach(memos) { memo in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(memo.content)
                                Text("증상 점수: \(memo.symptomScore)")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button("삭제", role: .destructive) {
                                    Task { await deleteMemo(memo) }
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button("수정") { editingMemo = memo }
                                    .tint(.blue)
                            }
                            .contextMenu {
                                Button("수정") { editingMemo = memo }
                                Button("삭제", role: .destructive) {
                                    Task { await deleteMemo(memo) }
                                }
                            }
                        }
                    }

                    // TextEditor는 TextField와 달리 placeholder가 없어서, 내용이 비어있을 때만
                    // 안내 문구를 겹쳐 보여줌(MemoEditView와 동일한 패턴)
                    ZStack(alignment: .topLeading) {
                        if memoText.isEmpty {
                            Text("오늘 컨디션이나 증상을 자유롭게 적어보세요")
                                .foregroundStyle(.secondary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: $memoText)
                            .frame(minHeight: 80)
                    }
                    VStack(alignment: .leading) {
                        Text("증상 점수: \(Int(symptomScore))")
                        Slider(value: $symptomScore, in: 1...10, step: 1)
                            .onChange(of: symptomScore) { _, _ in Haptics.selection() }
                    }
                    Button(action: saveMemo) {
                        if isSavingMemo {
                            ProgressView()
                        } else {
                            Text("이 날짜로 메모 추가")
                        }
                    }
                    .disabled(isSavingMemo)
                }
            }
            .navigationTitle(dateWithWeekday)
            .overlay {
                if isLoading {
                    ProgressView()
                }
            }
            .sheet(isPresented: $isShowingFoodPicker) {
                FoodPickerView(date: date, onAdded: {
                    Task { await loadDayDetail() }
                })
            }
            .sheet(isPresented: $isShowingRunAdd) {
                RunAddView(onSaved: {
                    isShowingRunAdd = false
                    Task { await loadDayDetail() }
                }, recordedAt: recordedAtNow())
            }
            .sheet(item: $editingFood) { food in
                FoodRecordEditView(food: food, onSaved: {
                    Task { await loadDayDetail() }
                })
            }
            .sheet(item: $editingRun) { run in
                RunAddView(onSaved: {
                    editingRun = nil
                    Task { await loadDayDetail() }
                }, existingRun: run)
            }
            .sheet(item: $editingMemo) { memo in
                MemoEditView(memo: memo, onSaved: {
                    Task { await loadDayDetail() }
                })
            }
            .alert("메모", isPresented: $showMemoAlert) {
                Button("확인", role: .cancel) {}
            } message: {
                Text(memoAlertMessage)
            }
            .task {
                await loadDayDetail()
            }
        }
    }

    // 웹의 dateWithCurrentTime과 동일 — 선택된 날짜에 지금 시:분:초를 붙임 (Memo는 시각 없이 date만 씀)
    private func recordedAtNow() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return "\(date)T\(formatter.string(from: Date()))"
    }

    private func loadDayDetail() async {
        isLoading = true
        errorMessage = nil
        async let foodsResult = FoodAPIService.fetchTodayFoods(date: date)
        async let runsResult = RunAPIService.fetchRuns(date: date)
        async let memosResult = MemoAPIService.fetchMemos(date: date)
        do {
            foods = try await foodsResult
            runs = try await runsResult
            memos = try await memosResult
        } catch {
            errorMessage = "불러오기 실패: \(error.localizedDescription)"
        }
        isLoading = false
        onDataChanged()
    }

    private func deleteFood(_ food: FoodRecord) async {
        do {
            try await FoodAPIService.deleteFood(id: food.id)
            Haptics.success()
            await loadDayDetail()
        } catch {
            errorMessage = "삭제 실패: \(error.localizedDescription)"
        }
    }

    private func deleteRun(_ run: RunRecord) async {
        do {
            try await RunAPIService.deleteRun(id: run.id)
            Haptics.success()
            await loadDayDetail()
        } catch {
            errorMessage = "삭제 실패: \(error.localizedDescription)"
        }
    }

    private func deleteMemo(_ memo: MemoRecord) async {
        do {
            try await MemoAPIService.deleteMemo(id: memo.id)
            Haptics.success()
            await loadDayDetail()
        } catch {
            errorMessage = "삭제 실패: \(error.localizedDescription)"
        }
    }

    private func saveMemo() {
        guard !memoText.isEmpty else {
            memoAlertMessage = "메모를 작성해주세요!"
            showMemoAlert = true
            return
        }
        isSavingMemo = true
        Task {
            do {
                try await MemoAPIService.createMemo(date: date, content: memoText, symptomScore: Int(symptomScore))
                isSavingMemo = false
                memoText = ""
                symptomScore = 5
                await loadDayDetail()
            } catch {
                isSavingMemo = false
                memoAlertMessage = "저장 실패: \(error.localizedDescription)"
                showMemoAlert = true
            }
        }
    }
}

#Preview {
    DayDetailView(date: "2026-07-28")
}
