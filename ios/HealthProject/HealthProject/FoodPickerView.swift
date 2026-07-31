//
//  FoodPickerView.swift
//  HealthProject
//
//  DayDetailView가 "이 날짜로 음식 추가"에서 띄우는 시트 — DietTimerView와 동일한
//  검색+즐겨찾기 UI(FoodPickerSections)를 그대로 재사용하되, 저장 시 그 날짜로 기록됨
//

import SwiftUI

struct FoodPickerView: View {
    let date: String   // "yyyy-MM-dd"
    let onAdded: () -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var foodPicker = FoodPickerModel()
    @State private var selectedMeal: Meal = .breakfast

    // 웹의 dateWithCurrentTime과 동일 — 선택된 날짜에 지금 시:분:초를 붙여 LocalDateTime 문자열을 만듦
    private var recordedAtValue: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return "\(date)T\(formatter.string(from: Date()))"
    }

    var body: some View {
        NavigationStack {
            List {
                Section("끼니") {
                    Picker("끼니", selection: $selectedMeal) {
                        ForEach(Meal.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                FoodPickerSections(model: foodPicker, selectedMeal: selectedMeal, recordedAt: recordedAtValue, onAdded: {
                    onAdded()
                })
            }
            .navigationTitle("\(date) 음식 추가")
            .searchable(text: $foodPicker.searchQuery, prompt: "음식 이름 검색")
            .onSubmit(of: .search) {
                Task { await foodPicker.performAutoMatch() }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
            .task {
                foodPicker.loadFavorites()
            }
        }
    }
}

#Preview {
    FoodPickerView(date: "2026-07-28", onAdded: {})
}
