//
//  FoodPickerModel.swift
//  HealthProject
//
//  즐겨찾기 목록 + 식품 검색 상태/로직 — DietTimerView와 DayDetailView의 FoodPickerView가
//  각자 인스턴스를 만들어 공유하는 모델 (AuthManager와 같은 ObservableObject 패턴, 싱글턴은 아님)
//

import Combine
import Foundation
import SwiftUI // IndexSet 기반 remove(atOffsets:)가 SwiftUI 확장이라 필요

final class FoodPickerModel: ObservableObject {
    @Published var favorites: [FavoriteFood] = []
    @Published var searchQuery = ""
    @Published var searchResults: [FoodSearchResult] = []
    @Published var isSearchingFoods = false
    @Published var searchErrorMessage: String?
    @Published var alertMessage = ""
    @Published var showAlert = false

    func loadFavorites() {
        guard let data = UserDefaults.standard.data(forKey: "favoriteFoods"),
              let decoded = try? JSONDecoder().decode([FavoriteFood].self, from: data) else { return }
        favorites = decoded
    }

    func saveFavorites() {
        guard let data = try? JSONEncoder().encode(favorites) else { return }
        UserDefaults.standard.set(data, forKey: "favoriteFoods")
    }

    func deleteFavorites(at offsets: IndexSet) {
        favorites.remove(atOffsets: offsets)
        saveFavorites()
    }

    func addNewFavorite(_ favorite: FavoriteFood) {
        favorites.append(favorite)
        saveFavorites()
    }

    func performSearch() async {
        let keyword = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return }

        isSearchingFoods = true
        searchErrorMessage = nil
        do {
            searchResults = try await FoodAPIService.searchFoods(keyword: keyword)
        } catch {
            searchErrorMessage = "검색 실패: \(error.localizedDescription)"
        }
        isSearchingFoods = false
    }

    // recordedAt이 nil이면 서버가 현재시각으로 채움(오늘 기록), 특정 날짜+시각 문자열이면 그 날짜로 저장됨
    func addFavoriteToRecord(_ favorite: FavoriteFood, meal: Meal, recordedAt: String?) async {
        do {
            _ = try await FoodAPIService.createFood(
                name: favorite.name,
                calorie: favorite.calorie,
                digestTime: String(favorite.digestCategory.rawValue),
                isTrigger: favorite.isTrigger,
                meal: meal,
                fatGrams: favorite.fatGrams,
                recordedAt: recordedAt
            )
        } catch {
            alertMessage = "추가 실패: \(error.localizedDescription)"
            showAlert = true
        }
    }

    // 검색 결과는 즐겨찾기를 거치지 않고 바로 기록에 추가 가능 — 실측 지방값(result.fat)을 그대로 보냄
    func addSearchResultToRecord(_ result: FoodSearchResult, meal: Meal, recordedAt: String?) async {
        let category = DigestCategory.from(fatGrams: result.fat)
        do {
            _ = try await FoodAPIService.createFood(
                name: result.name,
                calorie: result.calorie ?? 0,
                digestTime: String(category.rawValue),
                isTrigger: false,
                meal: meal,
                fatGrams: result.fat,
                recordedAt: recordedAt
            )
        } catch {
            alertMessage = "추가 실패: \(error.localizedDescription)"
            showAlert = true
        }
    }

    // 검색 결과를 즐겨찾기로 등록해도 출처는 API이므로, 정확한 지방값을 그대로 들고 감 —
    // 나중에 이 즐겨찾기로 기록에 추가할 때도 근사치가 아니라 정확치가 이어짐
    func addSearchResultToFavorites(_ result: FoodSearchResult) {
        let category = DigestCategory.from(fatGrams: result.fat)
        addNewFavorite(FavoriteFood(name: result.name, calorie: result.calorie ?? 0, digestCategory: category, isTrigger: false, fatGrams: result.fat))
    }
}
