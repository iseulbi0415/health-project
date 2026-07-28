//
//  HomeView.swift
//  HealthProject
//
//  홈 탭 — 소화 타이머/오늘 칼로리/최근 러닝을 한눈에 요약 (웹 index.html의 홈 화면과 동등)
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var digestionTimerManager: DigestionTimerManager

    @AppStorage("bmrHeight") private var heightText = ""
    @AppStorage("bmrWeight") private var weightText = ""
    @AppStorage("bmrAge") private var ageText = ""
    @AppStorage("bmrGender") private var gender = Gender.male
    @AppStorage("bmrActivityLevel") private var activityLevel = ActivityLevel.moderate
    @AppStorage("goalCalculated") private var hasCalculatedGoal = false

    @State private var todayFoods: [FoodRecord] = []
    @State private var recentRun: RunRecord?
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var totalCalories: Int {
        todayFoods.reduce(0) { $0 + $1.calorie }
    }

    // ProfileView에서 "계산" 버튼을 눌러야만(hasCalculatedGoal) 목표 칼로리를 보여줌 — 웹의
    // localStorage "tdee" 존재 여부와 동등한 조건(입력값만 채워져 있고 계산을 안 눌렀으면 목표 없음 상태 유지)
    private var goalCalories: Double? {
        guard hasCalculatedGoal,
              let height = Double(heightText),
              let weight = Double(weightText),
              let age = Double(ageText) else { return nil }
        return BMRCalculator.tdee(heightCm: height, weightKg: weight, age: age, gender: gender, activity: activityLevel)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("소화 타이머") {
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
                            }
                        }
                    } else {
                        Text("소화 중인 기록 없음")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("오늘 칼로리") {
                    if isLoading {
                        ProgressView()
                    } else if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    } else if let goalCalories {
                        Text("\(totalCalories) / \(Int(goalCalories.rounded())) kcal")
                            .font(.title2)
                            .bold()
                        ProgressView(value: min(Double(totalCalories) / goalCalories, 1.0))
                    } else {
                        Text("\(totalCalories) kcal")
                            .font(.title2)
                            .bold()
                        Text("내 정보를 입력하면 목표 대비 칼로리를 확인할 수 있어요")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("최근 러닝") {
                    if isLoading {
                        ProgressView()
                    } else if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    } else if let recentRun {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(recentRun.distance, specifier: "%.2f") km")
                                .font(.headline)
                            HStack {
                                Text("시간 \(recentRun.timeDisplay)")
                                Spacer()
                                Text("페이스 \(recentRun.paceDisplay)")
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("아직 기록 없음")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("홈")
            .refreshable {
                await loadHomeData()
            }
            .task {
                await loadHomeData()
            }
        }
    }

    private func loadHomeData() async {
        isLoading = true
        errorMessage = nil
        async let foodsResult = FoodAPIService.fetchTodayFoods(date: todayDateString())
        async let runsResult = RunAPIService.fetchRuns()
        do {
            todayFoods = try await foodsResult
            let runs = try await runsResult
            // 백엔드가 정렬을 보장하지 않아서, id가 클수록 최근에 저장된 것이라고 보고 직접 정렬
            // (ProfileView.loadRecentMemos()의 메모 정렬 컨벤션을 러닝에도 적용 — 웹은 배열 마지막
            // 요소를 쓰지만 결과는 사실상 동일)
            recentRun = runs.max(by: { $0.id < $1.id })
        } catch {
            errorMessage = "불러오기 실패: \(error.localizedDescription)"
        }
        isLoading = false
    }

    private func todayDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

#Preview {
    HomeView()
        .environmentObject(DigestionTimerManager.shared)
}
