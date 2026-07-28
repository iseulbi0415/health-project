//
//  DayDetailView.swift
//  HealthProject
//
//  특정 날짜의 식단/러닝/메모를 한 화면에서 조회 + 그 날짜로 새 기록 추가 (소화 타이머는 포함 안 함)
//

import SwiftUI

struct DayDetailView: View {
    let date: String   // "yyyy-MM-dd"

    @State private var foods: [FoodRecord] = []
    @State private var runs: [RunRecord] = []
    @State private var memos: [MemoRecord] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var isShowingFoodPicker = false
    @State private var isShowingRunAdd = false

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
                        ForEach(foods) { food in
                            HStack {
                                Text(food.quantity > 1 ? "\(food.name) ×\(food.quantity)" : food.name)
                                Spacer()
                                Text("\(food.calorie) kcal")
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
                        }
                    }

                    TextEditor(text: $memoText)
                        .frame(minHeight: 80)
                    VStack(alignment: .leading) {
                        Text("증상 점수: \(Int(symptomScore))")
                        Slider(value: $symptomScore, in: 1...10, step: 1)
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
            .navigationTitle(date)
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
