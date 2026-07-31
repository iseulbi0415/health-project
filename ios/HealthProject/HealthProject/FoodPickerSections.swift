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

    // 자동 매칭이 정확한 값을 못 찾았을 때 "직접 등록하러 가기"로 연결하는 폴백 시트 —
    // DietTimerView/FoodPickerView 둘 다 이 컴포넌트를 통해 자동으로 갖게 됨.
    // .sheet(isPresented:)는 SwiftUI가 시트 콘텐츠의 @State storage를 재사용해서
    // initialName이 바뀌어도 프리필이 반영 안 되는 문제가 있어, Identifiable로 감싸
    // .sheet(item:)을 써서 매번 새 identity(= 새 @State)를 강제함
    private struct FallbackPrefillTarget: Identifiable {
        let id = UUID()
        let name: String
    }
    @State private var fallbackTarget: FallbackPrefillTarget?
    // 즐겨찾기 스와이프/컨텍스트 메뉴 "수정"에서 열리는 편집 시트 대상
    @State private var editingFavorite: FavoriteFood?

    private var addButtonLabel: String {
        recordedAt == nil ? "오늘 먹었어요" : "이 날짜로 추가"
    }

    var body: some View {
        Group {
            if isSearchActive {
                Section("검색 결과") {
                    autoMatchContent
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
                    // allowsFullSwipe: true — 끝까지 밀면 확인 없이 바로 삭제(메일 앱과 동일한 iOS 표준 동작)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button("삭제", role: .destructive) {
                            model.deleteFavorite(favorite)
                        }
                    }
                    .swipeActions(edge: .leading) {
                        Button("수정") { editingFavorite = favorite }
                            .tint(.blue)
                    }
                    .contextMenu {
                        Button("수정") { editingFavorite = favorite }
                        Button("삭제", role: .destructive) { model.deleteFavorite(favorite) }
                    }
                }
            }
        }
        .alert("확인해주세요", isPresented: $model.showAlert) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(model.alertMessage)
        }
        .sheet(item: $fallbackTarget) { target in
            FavoriteAddView(initialName: target.name, onSave: { favorite in
                model.addNewFavorite(favorite)
            })
        }
        .sheet(item: $editingFavorite) { favorite in
            FavoriteAddView(existingFavorite: favorite, onSave: { updated in
                model.updateFavorite(updated)
            })
        }
    }

    @ViewBuilder
    private var autoMatchContent: some View {
        switch model.autoMatchState {
        case .idle:
            EmptyView()
        case .loading(let id):
            HStack(spacing: 10) {
                ProgressView()
                    .id(id)
                Text("음식을 자동으로 찾고 있어요... 실제 제품 정보까지 검색하는 중이라 조금만 기다려주세요!")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        case .result(let result):
            autoMatchCard(result)
        case .noNutritionData(let name):
            fallbackView(message: "정확한 영양 정보를 찾지 못했어요", prefillName: name)
        case .notFound(let keyword):
            fallbackView(message: "검색 결과가 없어요", prefillName: keyword)
        case .error(let message):
            Text(message)
                .foregroundStyle(.red)
                .font(.footnote)
        }
    }

    @ViewBuilder
    private func autoMatchCard(_ result: FoodAutoMatchResult) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            matchTypeBadge(result.matchType)
            Text(result.name)
                .font(.headline)
            if let grams = result.estimatedServingGrams {
                Text("실제 섭취량 약 \(grams)g 기준")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if let calorie = result.estimatedServingCalorie, let fat = result.estimatedServingFatGrams {
                Text("\(calorie)kcal · 지방 \(fat, specifier: "%.1f")g")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            HStack {
                Button("오늘 기록에 추가") {
                    Task {
                        await model.addAutoMatchToRecord(result, meal: selectedMeal, recordedAt: recordedAt)
                        await onAdded()
                    }
                }
                .buttonStyle(.borderedProminent)

                // fallback(AI 선택까지 실패해서 관련도순 1위로 대체된 값)이면 부정확한 값을 영구
                // 저장하는 걸 막기 위해 즐겨찾기 등록 버튼을 숨김
                if result.matchType != "fallback" {
                    Button("즐겨찾기 등록") {
                        model.addAutoMatchToFavorites(result)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func matchTypeBadge(_ matchType: String) -> some View {
        switch matchType {
        case "ai-selected":
            Text("AI가 비슷한 음식을 찾아줬어요")
                .font(.caption2)
                .fontWeight(.bold)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.blue.opacity(0.13))
                .foregroundStyle(.blue)
                .clipShape(Capsule())
        case "fallback":
            Text("정확한 값을 찾지 못했어요, 확인해주세요")
                .font(.caption2)
                .fontWeight(.bold)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.red.opacity(0.13))
                .foregroundStyle(.red)
                .clipShape(Capsule())
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func fallbackView(message: String, prefillName: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(message)
                .foregroundStyle(.secondary)
            Button("✏️ 직접 등록하러 가기") {
                fallbackTarget = FallbackPrefillTarget(name: prefillName)
            }
            .buttonStyle(.bordered)
        }
    }

    // 예전 리스트형 검색 결과 렌더링 — 지금은 autoMatchContent로 교체돼서 안 불리지만, 되돌릴 일이
    // 생기면 body의 `autoMatchContent`를 이걸로 바꾸기만 하면 됨(삭제하지 않고 그대로 남겨둠)
    @ViewBuilder
    private var legacySearchResultsSection: some View {
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
