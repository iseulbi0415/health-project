//
//  ProfileView.swift
//  HealthProject
//
//  내 정보 화면 — BMR/목표 칼로리 계산, 컨디션 메모 저장, 로그아웃
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var authManager: AuthManager

    // @AppStorage: 값이 바뀔 때마다 UserDefaults에 자동 저장 + 다음 실행 시 자동 복원 (AuthManager의
    // UserDefaults 동기화와 같은 목적, 웹의 localStorage 저장과 동등)
    @AppStorage("bmrHeight") private var heightText = ""
    @AppStorage("bmrWeight") private var weightText = ""
    @AppStorage("bmrAge") private var ageText = ""
    @AppStorage("bmrGender") private var gender = Gender.male
    @AppStorage("bmrActivityLevel") private var activityLevel = ActivityLevel.moderate
    // 계산 버튼을 눌러야만 true — HomeView가 "목표 칼로리 설정됨" 여부를 이 값으로 판단함(웹의
    // localStorage "tdee" 존재 여부와 동등: 입력값만 채워져 있고 계산을 안 눌렀으면 목표 없음 상태 유지)
    @AppStorage("goalCalculated") private var hasCalculatedGoal = false
    @State private var isShowingBMRSheet = false

    @State private var recentMemos: [MemoRecord] = []
    @State private var isLoadingMemos = false
    @State private var memosErrorMessage: String?
    @State private var editingMemo: MemoRecord?
    @State private var isShowingAddMemoSheet = false

    // 캐시된 결과 문자열 대신 저장된 값에서 매번 다시 계산 — 시트에서 값이 바뀌어도 별도 동기화 없이
    // 항상 최신 상태를 보여줌(단일 소스: heightText/weightText/ageText/gender/activityLevel)
    // Mifflin-St Jeor Equation(1990) — 미국 영양학회(Academy of Nutrition and Dietetics) 권장 공식.
    // TDEE = BMR × 활동계수, 증량 목표는 TDEE + 400kcal (일반적으로 권장되는 300~500kcal 범위 내 값)
    // 웹 프론트(js/app.js)의 계산 로직과 동일
    private var bmrSummary: (bmr: Int, tdee: Int, bulk: Int)? {
        guard hasCalculatedGoal,
              let height = Double(heightText),
              let weight = Double(weightText),
              let age = Double(ageText) else { return nil }
        let bmr = BMRCalculator.bmr(heightCm: height, weightKg: weight, age: age, gender: gender)
        let tdee = BMRCalculator.tdee(heightCm: height, weightKg: weight, age: age, gender: gender, activity: activityLevel)
        return (Int(bmr.rounded()), Int(tdee.rounded()), Int((tdee + 400).rounded()))
    }

    var body: some View {
        NavigationStack {
            // GradientHeaderView는 Form 밖(VStack의 형제)에 둬서 화면 최상단에 전체 폭 배너로
            // 붙게 함(다른 3개 탭과 동일한 이유)
            VStack(spacing: 0) {
                GradientHeaderView(
                    title: "내 정보",
                    subtitle: "BMR·목표 칼로리와 컨디션 기록",
                    colors: HeaderPalette.purple
                ) {
                    HeaderActionButton(systemImage: "plus") {
                        isShowingAddMemoSheet = true
                    }
                }

                profileForm
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }

    private var profileForm: some View {
        Form {
                Section {
                    if let bmrSummary {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("BMR \(bmrSummary.bmr) kcal")
                                    .monospacedDigit()
                                Text("유지 \(bmrSummary.tdee) kcal · 목표 \(bmrSummary.bulk) kcal")
                                    .font(.footnote)
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                isShowingBMRSheet = true
                            } label: {
                                Label("수정", systemImage: "pencil")
                            }
                            .buttonStyle(.glass)
                        }
                    } else {
                        Button("BMR 계산하기") {
                            isShowingBMRSheet = true
                        }
                        .buttonStyle(.glassProminent)
                        .tint(.accentColor)
                    }
                } header: {
                    Label("BMR / 목표 칼로리", systemImage: "flame.fill")
                }

                // 방금 저장한 것과는 별개로, 과거에 저장된 기록을 보여주는 섹션 — 최신순 5개
                Section {
                    if isLoadingMemos {
                        ProgressView()
                    } else if let memosErrorMessage {
                        Text(memosErrorMessage)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    } else if recentMemos.isEmpty {
                        Text("저장된 기록이 없습니다.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(recentMemos) { memo in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(memo.date)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text(memo.content)
                                Text("증상 점수: \(memo.symptomScore)")
                                    .font(.footnote)
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
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
                } header: {
                    Label("최근 컨디션 (최신 5개)", systemImage: "clock.arrow.circlepath")
                }

                Section {
                    Button("로그아웃", role: .destructive) {
                        authManager.logout()
                    }
                }
            }
            .sheet(isPresented: $isShowingBMRSheet) {
                BMRInputView(
                    heightText: heightText,
                    weightText: weightText,
                    ageText: ageText,
                    gender: gender,
                    activityLevel: activityLevel,
                    onSave: saveBMRProfile
                )
            }
            .sheet(item: $editingMemo) { memo in
                MemoEditView(memo: memo, onSaved: {
                    Task { await loadRecentMemos() }
                })
            }
            .sheet(isPresented: $isShowingAddMemoSheet) {
                MemoEditView(onSaved: {
                    Task { await loadRecentMemos() }
                })
            }
            .task {
                await loadRecentMemos()
            }
            .refreshable {
                await loadRecentMemos()
            }
    }

    // BMRInputView의 onSave 콜백 — 검증은 시트에서 이미 끝났으므로 여기선 저장만 함
    private func saveBMRProfile(height: String, weight: String, age: String, gender: Gender, activityLevel: ActivityLevel) {
        heightText = height
        weightText = weight
        ageText = age
        self.gender = gender
        self.activityLevel = activityLevel
        hasCalculatedGoal = true

        if let heightValue = Double(height), let weightValue = Double(weight), let ageValue = Double(age) {
            Task {
                await syncProfileToServer(height: heightValue, weight: weightValue, age: ageValue)
            }
        }
    }

    // 서버에도 저장해둬야 앱 삭제 후 재설치했을 때 복원됨(UserProfileAPIService.hydrateLocalCache 참고).
    // 로컬 저장은 이미 끝나서 화면엔 결과가 그대로 보이므로, 이 저장은 실패해도 조용히
    // 무시함(달력 점 표시처럼 부가 기능 — 사용자 입력 흐름을 막지 않음)
    private func syncProfileToServer(height: Double, weight: Double, age: Double) async {
        let profile = UserProfile(
            heightCm: height,
            weightKg: weight,
            age: Int(age),
            gender: gender.rawValue,
            activityLevel: activityLevel.rawValue,
            hasCalculatedGoal: true
        )
        try? await UserProfileAPIService.updateProfile(profile)
    }

    private func deleteMemo(_ memo: MemoRecord) async {
        do {
            try await MemoAPIService.deleteMemo(id: memo.id)
            Haptics.success()
            await loadRecentMemos()
        } catch {
            memosErrorMessage = "삭제 실패: \(error.localizedDescription)"
        }
    }

    private func loadRecentMemos() async {
        isLoadingMemos = true
        memosErrorMessage = nil
        do {
            let all = try await MemoAPIService.fetchMemos()
            // 백엔드가 정렬을 보장하지 않아서, id가 클수록 최근에 저장된 것이라고 보고 직접 정렬
            recentMemos = Array(all.sorted { $0.id > $1.id }.prefix(5))
        } catch {
            memosErrorMessage = "최근 기록을 불러오지 못했습니다."
        }
        isLoadingMemos = false
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthManager.shared)
}
