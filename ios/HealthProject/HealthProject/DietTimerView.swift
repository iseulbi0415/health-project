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
    @State private var actionAlertMessage = ""
    @State private var showActionAlert = false

    @State private var selectedDate = Date()
    @State private var isShowingDayDetail = false
    @State private var markedDates: Set<String> = []
    @State private var isShowingCalendar = false

    private var totalCalories: Int {
        todayFoods.reduce(0) { $0 + $1.calorie }
    }

    var body: some View {
        NavigationStack {
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
                })

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
                        ForEach(todayFoods) { food in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(food.quantity > 1 ? "\(food.name) ×\(food.quantity)" : food.name)
                                        if food.isTrigger {
                                            Text("⚠️ 트리거")
                                                .font(.caption)
                                                .foregroundStyle(.orange)
                                        }
                                    }
                                    Text(mealLabel(for: food.meal))
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(food.calorie) kcal")
                            }
                        }
                    }
                    Text("오늘 총 섭취: \(totalCalories) kcal")
                        .font(.headline)
                }

                Section("소화 타이머") {
                    Button("식사 완료 → 타이머 시작", action: completeMeal)

                    if digestionTimerManager.endTime != nil {
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(digestionTimerManager.countdownText(at: context.date))
                                    .font(.title2)
                                    .bold()
                                ProgressView(value: digestionTimerManager.progress(at: context.date))
                                Text(digestionTimerManager.endTimeText)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                Text(digestionTimerManager.warningText(at: context.date))
                                Button("타이머 취소", role: .destructive) {
                                    digestionTimerManager.cancel()
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("식단·타이머")
            .searchable(text: $foodPicker.searchQuery, prompt: "음식 이름 검색")
            .onSubmit(of: .search) {
                Task { await foodPicker.performAutoMatch() }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isShowingAddFavoriteSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $isShowingAddFavoriteSheet) {
                FavoriteAddView(onSave: { favorite in
                    foodPicker.addNewFavorite(favorite)
                })
            }
            .sheet(isPresented: $isShowingDayDetail) {
                DayDetailView(date: dayDetailDateString())
            }
            .alert("확인해주세요", isPresented: $showActionAlert) {
                Button("확인", role: .cancel) {}
            } message: {
                Text(actionAlertMessage)
            }
            .task {
                foodPicker.loadFavorites()
                await loadTodayFoods()
                let currentMonth = Calendar.current.dateComponents([.year, .month], from: Date())
                if let year = currentMonth.year, let month = currentMonth.month {
                    await loadMonthSummary(year: year, month: month)
                }
            }
        }
    }

    private func mealLabel(for rawValue: String?) -> String {
        guard let rawValue, let meal = Meal(rawValue: rawValue) else { return "" }
        return meal.label
    }

    private func loadTodayFoods() async {
        isLoadingToday = true
        todayErrorMessage = nil
        do {
            todayFoods = try await FoodAPIService.fetchTodayFoods(date: todayDateString())
        } catch {
            todayErrorMessage = "오늘 먹은 음식을 불러오지 못했습니다."
        }
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
