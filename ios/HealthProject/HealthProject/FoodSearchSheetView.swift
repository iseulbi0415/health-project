//
//  FoodSearchSheetView.swift
//  HealthProject
//
//  식단·타이머 배너의 돋보기 버튼으로 여는 검색 전용 시트 — 평소 화면엔 검색창을 안 두고,
//  여기 안에서만 iOS 표준 .searchable() UI(취소 버튼 포함)가 뜨게 분리함
//

import SwiftUI

struct FoodSearchSheetView: View {
    @ObservedObject var model: FoodPickerModel
    let selectedMeal: Meal
    let onAdded: () async -> Void

    @Environment(\.dismiss) private var dismiss
    // FoodPickerSections에 Binding으로 넘김 — 이유는 FoodPickerSections.swift 주석 참고
    @State private var editingFavorite: FavoriteFood?

    var body: some View {
        NavigationStack {
            List {
                FoodPickerSections(model: model, selectedMeal: selectedMeal, recordedAt: nil, onAdded: {
                    await onAdded()
                }, editingFavorite: $editingFavorite, favoritesSectionTitle: "빠르게 추가하기")
            }
            .listStyle(.insetGrouped)
            .sheet(item: $editingFavorite) { favorite in
                FavoriteAddView(existingFavorite: favorite, onSave: { updated in
                    Task { await model.updateFavorite(updated) }
                })
            }
            // placement 없으면(.automatic) 검색창이 화면 하단 쪽에 배치돼서, 설정/메시지 앱처럼
            // nav bar 바로 아래 항상 고정되도록 명시
            .searchable(text: $model.searchQuery, placement: .navigationBarDrawer(displayMode: .always), prompt: "음식 이름 검색")
            .onSubmit(of: .search) {
                Task { await model.performAutoMatch() }
            }
            .navigationTitle("음식 검색")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
        // model은 DietTimerView가 들고 있는 공유 인스턴스라 시트를 닫아도 파괴되지 않음 —
        // 열릴 때마다 이전 검색어/결과를 지워서 매번 새로 시작하게 함
        .onAppear {
            model.resetSearch()
        }
    }
}
