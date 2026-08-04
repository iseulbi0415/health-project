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
    // 검색 시트에서는 "빠르게 추가하기"로 다르게 부르고 싶어서 파라미터화 — 기존 호출부(DietTimerView/
    // FoodPickerView)는 인자 없이 그대로 컴파일되도록 기본값을 "즐겨찾기"로 둠
    var favoritesSectionTitle: String = "즐겨찾기"

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
    // 추가 버튼 탭 시 잠깐 체크마크로 바뀌는 마이크로 인터랙션용 — 토스트/화면전환 없이도
    // "확실히 추가됐다"는 느낌을 주기 위함. 즐겨찾기는 여러 행 중 방금 누른 행만 표시해야 해서 id로,
    // 검색결과 카드는 한 번에 하나뿐이라 Bool로 충분
    @State private var justAddedFavoriteID: FavoriteFood.ID?
    @State private var justAddedAutoMatch = false

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

            Section(favoritesSectionTitle) {
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
                                    Label("트리거", systemImage: "exclamationmark.triangle.fill")
                                        .font(.caption)
                                        .foregroundStyle(Color("CalorieCoral"))
                                }
                            }
                            Text("\(favorite.calorie) kcal · \(favorite.digestCategory.label)")
                                .font(.footnote)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            Task {
                                let success = await model.addFavoriteToRecord(favorite, meal: selectedMeal, recordedAt: recordedAt)
                                await onAdded()
                                guard success else { return }
                                Haptics.success()
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.55)) {
                                    justAddedFavoriteID = favorite.id
                                }
                                try? await Task.sleep(nanoseconds: 580_000_000)
                                guard justAddedFavoriteID == favorite.id else { return }
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    justAddedFavoriteID = nil
                                }
                            }
                        } label: {
                            Group {
                                if justAddedFavoriteID == favorite.id {
                                    Image(systemName: "checkmark")
                                        .scaleEffect(1.15)
                                        .transition(.opacity.combined(with: .scale))
                                } else {
                                    Text(addButtonLabel)
                                        .transition(.opacity.combined(with: .scale))
                                }
                            }
                            .frame(minWidth: 70)
                        }
                        .buttonStyle(.glass)
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
            VStack(alignment: .leading, spacing: 4) {
                matchTypeBadge(result.matchType)
                if result.isServingEstimateFallback {
                    servingEstimateFallbackBadge()
                }
            }
            Text(result.name)
                .font(.headline)
            if let grams = result.estimatedServingGrams {
                Text("실제 섭취량 약 \(grams)g 기준")
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            if let calorie = result.estimatedServingCalorie, let fat = result.estimatedServingFatGrams {
                Text("\(calorie)kcal · 지방 \(fat, specifier: "%.1f")g")
                    .font(.subheadline)
                    .monospacedDigit()
                    .fontWeight(.semibold)
            }
            HStack {
                Button {
                    Task {
                        let success = await model.addAutoMatchToRecord(result, meal: selectedMeal, recordedAt: recordedAt)
                        await onAdded()
                        guard success else { return }
                        Haptics.success()
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.55)) {
                            justAddedAutoMatch = true
                        }
                        try? await Task.sleep(nanoseconds: 580_000_000)
                        withAnimation(.easeInOut(duration: 0.3)) {
                            justAddedAutoMatch = false
                        }
                    }
                } label: {
                    Group {
                        if justAddedAutoMatch {
                            Image(systemName: "checkmark")
                                .scaleEffect(1.15)
                                .transition(.opacity.combined(with: .scale))
                        } else {
                            Text("오늘 기록에 추가")
                                .transition(.opacity.combined(with: .scale))
                        }
                    }
                    .frame(minWidth: 90)
                }
                .buttonStyle(.glassProminent)
                .tint(.accentColor)

                // fallback(AI 선택까지 실패해서 관련도순 1위로 대체된 값)이거나 그램수 추정
                // 자체가 실패한 값이면, 부정확한 값을 영구 저장하는 걸 막기 위해 즐겨찾기 등록 버튼을 숨김
                if result.matchType != "fallback" && !result.isServingEstimateFallback {
                    Button("즐겨찾기 등록") {
                        model.addAutoMatchToFavorites(result)
                    }
                    .buttonStyle(.glass)
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
                .foregroundStyle(Color.accentColor)
                .glassEffect(.regular.tint(Color.accentColor.opacity(0.18)), in: Capsule())
        case "fallback":
            Text("정확한 값을 찾지 못했어요, 확인해주세요")
                .font(.caption2)
                .fontWeight(.bold)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .foregroundStyle(Color("CalorieCoral"))
                .glassEffect(.regular.tint(Color("CalorieCoral").opacity(0.18)), in: Capsule())
        default:
            EmptyView()
        }
    }

    // matchTypeBadge와 별개 축 — 음식 후보 선택은 성공했지만 1인분 그램수 AI 추정이 실패해서
    // 100g 기본값으로 조용히 대체된 경우를 알려줌(FoodAutoMatchService.java의 그램수 추정 실패 폴백).
    // matchType과 무관하게(예: "exact" 경로에서도) 뜰 수 있어 matchTypeBadge와 독립적으로 렌더링함
    @ViewBuilder
    private func servingEstimateFallbackBadge() -> some View {
        Text("1인분 양 추정에 실패해 100g 기준으로 표시돼요")
            .font(.caption2)
            .fontWeight(.bold)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(Color("CalorieCoral"))
            .glassEffect(.regular.tint(Color("CalorieCoral").opacity(0.18)), in: Capsule())
    }

    @ViewBuilder
    private func fallbackView(message: String, prefillName: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(message)
                .foregroundStyle(.secondary)
            Button {
                fallbackTarget = FallbackPrefillTarget(name: prefillName)
            } label: {
                Label("직접 등록하러 가기", systemImage: "pencil")
            }
            .buttonStyle(.glass)
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
