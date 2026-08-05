//
//  DietTimerView.swift
//  HealthProject
//
//  식단·타이머 탭 — 즐겨찾기/검색, 오늘 먹은 음식, 총 칼로리, 소화 안전 타이머, 날짜별 기록 조회 진입점
//

import SwiftUI

struct DietTimerView: View {
    @EnvironmentObject private var digestionTimerManager: DigestionTimerManager
    @StateObject private var foodPicker = FoodPickerModel()

    @State private var todayFoods: [FoodRecord] = []
    @State private var selectedMeal: Meal = .breakfast
    @State private var isShowingAddFavoriteSheet = false
    @State private var isLoadingToday = false
    @State private var todayErrorMessage: String?
    // 탭 재방문마다 .task가 다시 실행돼 재조회가 일어나는데, 최초 로딩이 아니면 스피너로
    // 기존 목록을 가리지 않고 조용히 백그라운드에서 갱신하기 위한 플래그
    @State private var hasLoadedOnce = false
    @State private var actionAlertMessage = ""
    @State private var showActionAlert = false
    @State private var editingFood: FoodRecord?
    @State private var isShowingSearchSheet = false
    // FoodPickerSections에 Binding으로 넘김 — List 안에 끼워지는 자식 뷰가 아니라 List를 직접
    // 소유한 이 뷰가 상태와 .sheet를 들고 있어야 하는 이유는 FoodPickerSections.swift 주석 참고
    @State private var editingFavorite: FavoriteFood?

    @State private var selectedDate = Date()
    @State private var isShowingDayDetail = false
    @State private var markedDates: Set<String> = []
    @State private var isShowingCalendar = false

    private var totalCalories: Int {
        todayFoods.reduce(0) { $0 + $1.calorie }
    }

    // 아침→점심→저녁→간식(Meal.allCases 순서) 기준으로 정렬 — 서버가 등록 순서 그대로 내려주는 것과 무관하게
    // 화면에서는 항상 끼니 시간 순서로 보이게 함
    private var sortedTodayFoods: [FoodRecord] {
        todayFoods.sorted { mealSortIndex(for: $0.meal) < mealSortIndex(for: $1.meal) }
    }

    private func mealSortIndex(for rawValue: String?) -> Int {
        guard let rawValue, let meal = Meal(rawValue: rawValue),
              let index = Meal.allCases.firstIndex(of: meal) else {
            return Meal.allCases.count
        }
        return index
    }

    var body: some View {
        NavigationStack {
            // GradientHeaderView는 List 밖(VStack의 형제)에 둬서 리스트 행/섹션 카드 스타일과
            // 무관하게 화면 최상단에 전체 폭 배너로 붙게 함(HomeView와 동일한 이유)
            VStack(spacing: 0) {
                GradientHeaderView(
                    title: "식단·타이머",
                    subtitle: "오늘 먹은 것을 기록하고 타이머를 시작하세요",
                    colors: HeaderPalette.green
                ) {
                    HeaderActionCapsule {
                        Button {
                            isShowingAddFavoriteSheet = true
                        } label: {
                            Image(systemName: "plus")
                                .imageScale(.large)
                                .frame(width: 28, height: 28)
                                .contentShape(Rectangle())
                        }
                        Button {
                            isShowingSearchSheet = true
                        } label: {
                            Image(systemName: "magnifyingglass")
                                .imageScale(.large)
                                .frame(width: 28, height: 28)
                                .contentShape(Rectangle())
                        }
                    }
                }

                dietTimerList
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }

    private var dietTimerList: some View {
        List {
                Section("날짜별 기록 조회") {
                    Button(isShowingCalendar ? "달력 닫기" : "달력 열기") {
                        withAnimation { isShowingCalendar.toggle() }
                    }

                    if isShowingCalendar {
                        // 기록(식단/러닝/메모) 있는 날짜에 점 표시 — 웹 달력과 동등. 월이 바뀌면
                        // onVisibleMonthChange가 그 달 요약만 새로 불러옴(날짜별 개별 호출 아님)
                        CalendarView(
                            markedDateStrings: markedDates,
                            onSelectDate: { date in
                                selectedDate = date
                                isShowingDayDetail = true
                            },
                            onVisibleMonthChange: { year, month in
                                Task { await loadMonthSummary(year: year, month: month) }
                            }
                        )
                    }
                }

                FoodPickerSections(model: foodPicker, selectedMeal: selectedMeal, recordedAt: nil, onAdded: {
                    await loadTodayFoods()
                }, editingFavorite: $editingFavorite)

                Section("끼니") {
                    Picker("끼니", selection: $selectedMeal) {
                        ForEach(Meal.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                Section("오늘 먹은 음식") {
                    if isLoadingToday {
                        ProgressView()
                    } else if let todayErrorMessage {
                        Text(todayErrorMessage)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    } else if todayFoods.isEmpty {
                        Text("오늘 먹은 음식이 없습니다.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(sortedTodayFoods) { food in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(food.quantity > 1 ? "\(food.name) ×\(food.quantity)" : food.name)
                                        if food.isTrigger {
                                            Label("트리거", systemImage: "exclamationmark.triangle.fill")
                                                .font(.caption)
                                                .foregroundStyle(Color("CalorieCoral"))
                                        }
                                    }
                                    Text(mealLabel(for: food.meal))
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(food.calorie) kcal")
                                    .monospacedDigit()
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
                    Text("오늘 총 섭취: \(totalCalories) kcal")
                        .font(.headline)
                        .monospacedDigit()
                }

                Section("소화 타이머") {
                    Button("식사 완료 → 타이머 시작", action: completeMeal)
                        .buttonStyle(.borderedProminent)
                        .tint(.accentColor)

                    DigestionWaveContainerView(style: .hero)
                        .listRowInsets(EdgeInsets())

                    if digestionTimerManager.endTime != nil {
                        Button("타이머 취소", role: .destructive) {
                            digestionTimerManager.cancel()
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .sheet(isPresented: $isShowingAddFavoriteSheet) {
                FavoriteAddView(onSave: { favorite in
                    Task { await foodPicker.addNewFavorite(favorite) }
                })
            }
            // 검색 전용 시트 — 평소 화면엔 검색창을 안 두고, 돋보기 버튼을 눌렀을 때만
            // iOS 표준 검색 UI(취소 버튼 포함)가 여기 안에서 뜨게 함
            .sheet(isPresented: $isShowingSearchSheet) {
                FoodSearchSheetView(model: foodPicker, selectedMeal: selectedMeal, onAdded: {
                    await loadTodayFoods()
                })
            }
            .sheet(isPresented: $isShowingDayDetail) {
                DayDetailView(date: dayDetailDateString())
            }
            .sheet(item: $editingFood) { food in
                FoodRecordEditView(food: food, onSaved: {
                    Task { await loadTodayFoods() }
                })
            }
            .sheet(item: $editingFavorite) { favorite in
                FavoriteAddView(existingFavorite: favorite, onSave: { updated in
                    Task { await foodPicker.updateFavorite(updated) }
                })
            }
            .alert("확인해주세요", isPresented: $showActionAlert) {
                Button("확인", role: .cancel) {}
            } message: {
                Text(actionAlertMessage)
            }
            .refreshable {
                await loadTodayFoods()
            }
            .task {
                await foodPicker.loadFavorites()
                await loadTodayFoods()
                let currentMonth = Calendar.current.dateComponents([.year, .month], from: Date())
                if let year = currentMonth.year, let month = currentMonth.month {
                    await loadMonthSummary(year: year, month: month)
                }
            }
    }

    private func mealLabel(for rawValue: String?) -> String {
        guard let rawValue, let meal = Meal(rawValue: rawValue) else { return "" }
        return meal.label
    }

    private func deleteFood(_ food: FoodRecord) async {
        do {
            try await FoodAPIService.deleteFood(id: food.id)
            Haptics.success()
            await loadTodayFoods()
        } catch {
            actionAlertMessage = "삭제 실패: \(error.localizedDescription)"
            showActionAlert = true
        }
    }

    private func loadTodayFoods() async {
        if !hasLoadedOnce { isLoadingToday = true }
        todayErrorMessage = nil
        do {
            todayFoods = try await FoodAPIService.fetchTodayFoods(date: todayDateString())
        } catch {
            todayErrorMessage = "오늘 먹은 음식을 불러오지 못했습니다."
        }
        hasLoadedOnce = true
        isLoadingToday = false
    }

    // 선택된 끼니의 오늘 기록만 지방을 합산(지방 실측값이 없으면 소화 체감 카테고리의 대표값으로 대체) →
    // 10g 미만 2시간 / 10~25g 3시간 / 25g 초과 4시간. 이미 타이머가 돌고 있으면 남은 시간과 새로
    // 계산된 시간 중 더 긴 쪽을 쓰는 "안전 마진" 규칙 (줄어드는 방향으로는 절대 안 바뀜) — 웹과 동일
    private func completeMeal() {
        let mealFoods = todayFoods.filter { $0.meal == selectedMeal.rawValue }
        guard !mealFoods.isEmpty else {
            actionAlertMessage = "먼저 음식을 추가해주세요!"
            showActionAlert = true
            return
        }

        let fatSum = mealFoods.reduce(0.0) { total, food in
            let category = DigestCategory(rawValue: Int(food.digestTime) ?? DigestCategory.normal.rawValue) ?? .normal
            return total + (food.fatGrams ?? category.representativeFatGrams)
        }

        let hours: Int
        if fatSum < 10 {
            hours = 2
        } else if fatSum <= 25 {
            hours = 3
        } else {
            hours = 4
        }

        digestionTimerManager.start(hours: hours)
    }

    private func loadMonthSummary(year: Int, month: Int) async {
        do {
            markedDates = try await RecordSummaryAPIService.fetchMonthSummary(year: year, month: month)
        } catch {
            // 달력 점 표시는 부가 기능이라, 실패해도 화면 전체를 막지 않고 조용히 무시함
        }
    }

    private func todayDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private func dayDetailDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: selectedDate)
    }
}

#Preview {
    DietTimerView()
        .environmentObject(DigestionTimerManager.shared)
}
