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
    // App Store Review Guidelines 1.4.1 대응 — 소화 대기 시간 판정 근거(ACG 가이드라인·위 배출
    // 연구)를 보여주는 공용 시트(CalculationSourcesView, ProfileView·RunDetailView와 동일 화면 재사용).
    // 음식 기록/타이머 동작 여부와 무관하게 상시 노출되어야 해서 "소화 타이머" Section 안에 둠
    @State private var isShowingCalculationSources = false
    // FoodPickerSections에 Binding으로 넘김 — List 안에 끼워지는 자식 뷰가 아니라 List를 직접
    // 소유한 이 뷰가 상태와 .sheet를 들고 있어야 하는 이유는 FoodPickerSections.swift 주석 참고
    @State private var editingFavorite: FavoriteFood?

    @State private var selectedDate = Date()
    @State private var isShowingDayDetail = false
    @State private var markedDates: Set<String> = []
    @State private var isShowingCalendar = false
    // 달력에 현재 보이는 달 — DayDetailView에서 기록이 바뀌었을 때 어느 달의 점 표시를
    // 다시 불러와야 하는지 알기 위해 저장해둠(onVisibleMonthChange에서 갱신됨)
    @State private var visibleYear = Calendar.current.component(.year, from: Date())
    @State private var visibleMonth = Calendar.current.component(.month, from: Date())

    private var totalCalories: Int {
        todayFoods.reduce(0) { $0 + $1.calorie }
    }

    // 아침→점심→저녁→간식(Meal.allCases 순서) 고정 — 끼니 헤더로 묶어서 표시하기 위한 그룹화.
    // 서버가 등록 순서 그대로 내려주는 것과 무관하게 항상 끼니 시간 순서로 보이게 함.
    // 음식이 하나도 없는 끼니는 배열에서 아예 빠져서 헤더 자체가 안 보임
    private var groupedTodayFoods: [(meal: Meal, foods: [FoodRecord])] {
        Meal.allCases.compactMap { meal in
            let foods = todayFoods.filter { $0.meal == meal.rawValue }
            return foods.isEmpty ? nil : (meal, foods)
        }
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
                            isDayDetailPresented: isShowingDayDetail,
                            onSelectDate: { date in
                                selectedDate = date
                                isShowingDayDetail = true
                            },
                            onVisibleMonthChange: { year, month in
                                visibleYear = year
                                visibleMonth = month
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
                        // 끼니를 그룹 헤더로 올리고 그 아래 음식을 묶어서 표시 — 헤더로 이미
                        // 끼니가 드러나므로 각 행에 있던 끼니 표시(footnote)는 제거함
                        ForEach(groupedTodayFoods, id: \.meal) { group in
                            Text(group.meal.label)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .padding(.top, 6)

                            ForEach(group.foods) { food in
                                HStack {
                                    Text(food.quantity > 1 ? "\(food.name) ×\(food.quantity)" : food.name)
                                    if food.isTrigger {
                                        Label("트리거", systemImage: "exclamationmark.triangle.fill")
                                            .font(.caption)
                                            .foregroundStyle(Color("CalorieCoral"))
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

                    Button("계산 근거 보기") {
                        isShowingCalculationSources = true
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
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
                DayDetailView(date: dayDetailDateString(), onDataChanged: {
                    Task { await loadMonthSummary(year: visibleYear, month: visibleMonth) }
                })
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
            .sheet(isPresented: $isShowingCalculationSources) {
                CalculationSourcesView()
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
            // fatGrams가 있으면 이미 "수량 반영된 총량"(서버 병합/FoodRecordEditView 둘 다 그렇게 유지함)이라
            // 그대로 쓰고, 없으면(즐겨찾기 수동 등록 등) 대표값은 1개 기준이라 수량을 곱해야 함
            let fat = food.fatGrams ?? (category.representativeFatGrams * Double(food.quantity))
            return total + fat
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
