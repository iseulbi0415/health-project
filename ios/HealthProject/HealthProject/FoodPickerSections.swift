//
//  FoodPickerSections.swift
//  HealthProject
//
//  "검색 결과"/"즐겨찾기" 두 섹션 — DietTimerView(오늘)와 FoodPickerView(특정 날짜)가 공유해서 씀.
//  recordedAt이 nil이면 지금(오늘), 값이 있으면 그 날짜/시각으로 기록됨
//

import SwiftUI

struct FoodPickerSections: View {
    @ObservedObject var model: FoodPickerModel
    let selectedMeal: Meal
    let recordedAt: String?
    let onAdded: () async -> Void

    @Environment(\.isSearching) private var isSearchActive

    private var addButtonLabel: String {
        recordedAt == nil ? "오늘 먹었어요" : "이 날짜로 추가"
    }

    var body: some View {
        Group {
            if isSearchActive {
                Section("검색 결과") {
                    if model.isSearchingFoods {
                        ProgressView()
                    } else if let searchErrorMessage = model.searchErrorMessage {
                        Text(searchErrorMessage)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    } else if model.searchResults.isEmpty {
                        Text("검색 결과가 없어요")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(model.searchResults.enumerated()), id: \.offset) { _, result in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(result.name)
                                    Text("\(result.calorie ?? 0) kcal (1인분 기준)")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("추가") {
                                    Task {
                                        await model.addSearchResultToRecord(result, meal: selectedMeal, recordedAt: recordedAt)
                                        await onAdded()
                                    }
                                }
                                .buttonStyle(.bordered)
                                Button("즐겨찾기") {
                                    model.addSearchResultToFavorites(result)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }
            }

            Section("즐겨찾기") {
                if model.favorites.isEmpty {
                    Text("등록된 즐겨찾기가 없습니다.")
                        .foregroundStyle(.secondary)
                }
                ForEach(model.favorites) { favorite in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(favorite.name)
                                if favorite.isTrigger {
                                    Text("⚠️ 트리거")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }
                            }
                            Text("\(favorite.calorie) kcal · \(favorite.digestCategory.label)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(addButtonLabel) {
                            Task {
                                await model.addFavoriteToRecord(favorite, meal: selectedMeal, recordedAt: recordedAt)
                                await onAdded()
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .onDelete(perform: model.deleteFavorites)
            }
        }
        .alert("확인해주세요", isPresented: $model.showAlert) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(model.alertMessage)
        }
    }
}
