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
    @State private var bmrResultText: String?
    @State private var bmrAlertMessage: String?
    @State private var showBmrAlert = false

    @State private var memoText = ""
    @State private var symptomScore: Double = 5
    @State private var isSavingMemo = false
    @State private var memoAlertMessage: String?
    @State private var showMemoAlert = false

    @State private var recentMemos: [MemoRecord] = []
    @State private var isLoadingMemos = false
    @State private var memosErrorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("BMR / 목표 칼로리") {
                    TextField("키 (cm)", text: $heightText)
                        .keyboardType(.decimalPad)
                    TextField("체중 (kg)", text: $weightText)
                        .keyboardType(.decimalPad)
                    TextField("나이", text: $ageText)
                        .keyboardType(.numberPad)

                    Picker("성별", selection: $gender) {
                        ForEach(Gender.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    Picker("활동량", selection: $activityLevel) {
                        ForEach(ActivityLevel.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    Button("계산", action: calculateBmr)

                    if let bmrResultText {
                        Text(bmrResultText)
                    }
                }

                Section("오늘의 컨디션 메모") {
                    TextEditor(text: $memoText)
                        .frame(minHeight: 100)

                    VStack(alignment: .leading) {
                        Text("증상 점수: \(Int(symptomScore))")
                        Slider(value: $symptomScore, in: 1...10, step: 1)
                    }

                    Button(action: saveMemo) {
                        if isSavingMemo {
                            ProgressView()
                        } else {
                            Text("저장")
                        }
                    }
                    .disabled(isSavingMemo)
                }

                // 방금 저장한 것과는 별개로, 과거에 저장된 기록을 보여주는 섹션 — 최신순 5개
                Section("최근 컨디션 (최신 5개)") {
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
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                Section {
                    Button("로그아웃", role: .destructive) {
                        authManager.logout()
                    }
                }
            }
            .navigationTitle("내 정보")
            .alert("확인해주세요", isPresented: $showBmrAlert) {
                Button("확인", role: .cancel) {}
            } message: {
                Text(bmrAlertMessage ?? "")
            }
            .alert("메모", isPresented: $showMemoAlert) {
                Button("확인", role: .cancel) {}
            } message: {
                Text(memoAlertMessage ?? "")
            }
            .task {
                await loadRecentMemos()
            }
        }
    }

    // Mifflin-St Jeor Equation(1990) — 미국 영양학회(Academy of Nutrition and Dietetics) 권장 공식.
    // TDEE = BMR × 활동계수, 증량 목표는 TDEE + 400kcal (일반적으로 권장되는 300~500kcal 범위 내 값)
    // 웹 프론트(js/app.js)의 계산 로직과 동일
    private func calculateBmr() {
        guard let height = Double(heightText) else {
            showBmrError("키를 입력해주세요!")
            return
        }
        guard let weight = Double(weightText) else {
            showBmrError("체중을 입력해주세요!")
            return
        }
        guard let age = Double(ageText) else {
            showBmrError("나이를 입력해주세요!")
            return
        }

        let bmr = BMRCalculator.bmr(heightCm: height, weightKg: weight, age: age, gender: gender)
        let tdee = BMRCalculator.tdee(heightCm: height, weightKg: weight, age: age, gender: gender, activity: activityLevel)
        let bulkTarget = tdee + 400

        hasCalculatedGoal = true
        bmrResultText = """
        기초대사량(BMR): \(Int(bmr.rounded())) kcal
        유지 칼로리: \(Int(tdee.rounded())) kcal
        증량 목표: \(Int(bulkTarget.rounded())) kcal
        """
    }

    private func showBmrError(_ message: String) {
        bmrAlertMessage = message
        showBmrAlert = true
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
                try await MemoAPIService.createMemo(date: todayDateString(), content: memoText, symptomScore: Int(symptomScore))
                isSavingMemo = false
                memoText = ""
                symptomScore = 5
                memoAlertMessage = "저장했습니다."
                showMemoAlert = true
                await loadRecentMemos()
            } catch {
                isSavingMemo = false
                memoAlertMessage = "저장 실패: \(error.localizedDescription)"
                showMemoAlert = true
            }
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

    private func todayDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthManager.shared)
}
