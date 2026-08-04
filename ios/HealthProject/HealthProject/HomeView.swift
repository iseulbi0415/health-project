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

    // ── 1번 상태 (탭 세그먼트 컨트롤 방식) ──────────────────────────────────
    // "오늘 칼로리" 카드에서 기준값(유지/목표)을 탭으로 전환하는 인터랙션. 나중에 롱프레스/스와이프 등
    // 다른 방식으로 교체될 수 있어서, 관련 상태·계산·서브뷰를 이 표시 사이에 모아둠 — 교체 시 이 블록과
    // CalorieReferenceModeToggle struct, 카드 안의 사용부만 지우고 바꾸면 나머지 로직은 그대로 유지됨.
    enum CalorieReferenceMode {
        case maintenance // 유지 (TDEE)
        case goal        // 목표 (TDEE + 400)
    }
    @State private var calorieReferenceMode: CalorieReferenceMode = .maintenance
    // ─────────────────────────────────────────────────────────────────

    private var totalCalories: Int {
        todayFoods.reduce(0) { $0 + $1.calorie }
    }

    // ProfileView에서 "계산" 버튼을 눌러야만(hasCalculatedGoal) 목표 칼로리를 보여줌 — 웹의
    // localStorage "tdee" 존재 여부와 동등한 조건(입력값만 채워져 있고 계산을 안 눌렀으면 목표 없음 상태 유지)
    private var maintenanceCalories: Double? {
        guard hasCalculatedGoal,
              let height = Double(heightText),
              let weight = Double(weightText),
              let age = Double(ageText) else { return nil }
        return BMRCalculator.tdee(heightCm: height, weightKg: weight, age: age, gender: gender, activity: activityLevel)
    }

    // 1번 상태 (탭 세그먼트 컨트롤 방식) 전용 — "목표" 세그먼트 선택 시 쓰는 값 (TDEE + 400)
    private var goalBulkCalories: Double? {
        guard hasCalculatedGoal,
              let height = Double(heightText),
              let weight = Double(weightText),
              let age = Double(ageText) else { return nil }
        return BMRCalculator.bulkGoal(heightCm: height, weightKg: weight, age: age, gender: gender, activity: activityLevel)
    }

    // 1번 상태 (탭 세그먼트 컨트롤 방식) 전용 — calorieReferenceMode에 따라 카드에 실제로 표시할 기준값.
    // 이 프로퍼티가 카드 뷰와 세그먼트 상태 사이의 유일한 연결점이라, 인터랙션 방식이 바뀌어도
    // 카드 쪽은 이 이름만 계속 읽으면 되게 하기 위한 어댑터 역할
    private var referenceCalories: Double? {
        switch calorieReferenceMode {
        case .maintenance: return maintenanceCalories
        case .goal: return goalBulkCalories
        }
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
                    } else if let referenceCalories {
                        HStack(spacing: 6) {
                            Image(systemName: "flame.fill")
                                .font(.footnote)
                                .foregroundStyle(Color("CalorieCoral"))
                            Text("\(totalCalories) / \(Int(referenceCalories.rounded())) kcal")
                                .font(.title2)
                                .bold()
                                .monospacedDigit()
                            Spacer()
                            // 1번 상태 (탭 세그먼트 컨트롤 방식) — 애니메이션은 이 바인딩 하나에만 걸어서
                            // 숫자/게이지 값 전환만 기본 애니메이션으로 자연스럽게 바뀌게 함
                            CalorieReferenceModeToggle(mode: $calorieReferenceMode.animation(.default))
                        }
                        ProgressView(value: min(Double(totalCalories) / referenceCalories, 1.0))
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

// 1번 상태 (탭 세그먼트 컨트롤 방식) — "오늘 칼로리" 카드에서 유지/목표 기준값을 탭으로 전환하는
// 작은 세그먼트 컨트롤. 네이티브 Picker(.segmented)가 아니라 직접 그린 이유: 카드 폭에 맞는
// 초소형 사이즈(11pt 폰트)가 필요해서. 롱프레스/스와이프 등 다른 인터랙션으로 나중에 통째로
// 바꿀 수 있도록 별도 struct로 분리 — 교체 시 이 struct만 지우고 HomeView 카드의 사용부
// (CalorieReferenceModeToggle(mode:) 호출 한 줄)만 바꾸면 됨
private struct CalorieReferenceModeToggle: View {
    @Binding var mode: HomeView.CalorieReferenceMode

    var body: some View {
        HStack(spacing: 4) {
            segment("유지", isSelected: mode == .maintenance) { mode = .maintenance }
            segment("목표", isSelected: mode == .goal) { mode = .goal }
        }
        .padding(3)
        .background(Color(.systemGray6), in: Capsule())
    }

    @ViewBuilder
    private func segment(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Text(title)
            .font(.system(size: 11))
            .foregroundStyle(isSelected ? .primary : .secondary)
            .padding(.vertical, 3)
            .padding(.horizontal, 10)
            .background {
                if isSelected {
                    Capsule().fill(.white)
                }
            }
            .onTapGesture(perform: action)
    }
}
