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
    // 탭을 벗어났다 돌아올 때마다 .task가 다시 실행돼 재조회가 일어나는데, 최초 로딩이 아니면
    // 스피너로 기존 데이터를 가리지 않고 조용히 백그라운드에서 갱신하기 위한 플래그
    @State private var hasLoadedOnce = false

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
            // GradientHeaderView는 List 밖(VStack의 형제)에 둬서 리스트 행/섹션 카드 스타일과
            // 무관하게 화면 최상단에 전체 폭 배너로 붙게 함 — List 안에 넣으면 .insetGrouped가
            // 둥근 카드 배경을 강제로 씌워서 "배너"가 아니라 "카드 하나"처럼 보이는 문제가 있었음
            VStack(spacing: 0) {
                GradientHeaderView(
                    title: "안녕하세요 🌿 오늘도 안심하게",
                    subtitle: todayDateDisplay() + " · 역류성 식도염 케어 & 러닝 관리",
                    colors: HeaderPalette.blue
                ) {
                    EmptyView()
                }

                homeList
            }
            // 시스템 nav bar 제목 텍스트를 완전히 숨김 — 화면 이름은 GradientHeaderView 안에만 존재.
            // 빈 문자열 + inline이라 nav bar 자체(칸)는 남지만 텍스트가 없고, 배경도 숨겨서
            // 배너 그라데이션이 상태바 뒤까지 자연스럽게 이어지게 함
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }

    private var homeList: some View {
        List {
                Section("소화 타이머") {
                    DigestionWaveContainerView(style: .compact)
                        .listRowInsets(EdgeInsets())
                }

                Section("오늘 칼로리") {
                    if isLoading {
                        ProgressView()
                    } else if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    } else if let goalCalories {
                        HStack(spacing: 6) {
                            Image(systemName: "flame.fill")
                                .font(.footnote)
                                .foregroundStyle(Color("CalorieCoral"))
                            Text("\(totalCalories) / \(Int(goalCalories.rounded())) kcal")
                                .font(.title2)
                                .bold()
                                .monospacedDigit()
                        }
                        ProgressView(value: min(Double(totalCalories) / goalCalories, 1.0))
                            .tint(Color("CalorieCoral"))
                            .frame(height: 12)
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "flame.fill")
                                .font(.footnote)
                                .foregroundStyle(Color("CalorieCoral"))
                            Text("\(totalCalories) kcal")
                                .font(.title2)
                                .bold()
                                .monospacedDigit()
                        }
                        Text("내 정보를 입력하면 목표 대비 칼로리를 확인할 수 있어요")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
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
                                .monospacedDigit()
                            HStack {
                                Text("시간 \(recentRun.timeDisplay)")
                                Spacer()
                                Text("페이스 \(recentRun.paceDisplay)")
                            }
                            .font(.subheadline)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("아직 기록 없음")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Label("최근 러닝", systemImage: "figure.run")
                }
            }
            .listStyle(.insetGrouped)
            .refreshable {
                await loadHomeData()
            }
            .task {
                await loadHomeData()
            }
    }

    private func loadHomeData() async {
        if !hasLoadedOnce { isLoading = true }
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
        hasLoadedOnce = true
        isLoading = false
    }

    private func todayDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    // 헤더 인사말 아래 보조 텍스트용 — "2026.08.01 토요일" 형식
    private func todayDateDisplay() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd EEEE"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: Date())
    }
}

#Preview {
    HomeView()
        .environmentObject(DigestionTimerManager.shared)
}
