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

// /api/food-search/auto(음식 자동 매칭) 진행 상태 — 완전일치/AI선택/실패폴백 결과, 후보 자체가 없는
// 경우(notFound), 후보는 있는데 영양정보를 못 찾은 경우(noNutritionData)를 각각 구분해서 화면에서
// 다른 안내를 보여줄 수 있게 함
enum FoodAutoMatchState {
    case idle
    // id를 매번 새로 발급해서 뷰가 .id()로 identity를 강제할 수 있게 함 —
    // 안 그러면 두 번째 검색부터 ProgressView가 SwiftUI에 의해 재사용되면서
    // 회전 애니메이션이 다시 시작되지 않는 문제가 있었음
    case loading(id: UUID)
    case result(FoodAutoMatchResult)
    case noNutritionData(name: String)
    case notFound(keyword: String)
    case error(String)
}

final class FoodPickerModel: ObservableObject {
    @Published var favorites: [FavoriteFood] = []
    @Published var searchQuery = ""
    @Published var searchResults: [FoodSearchResult] = []
    @Published var isSearchingFoods = false
    @Published var searchErrorMessage: String?
    @Published var alertMessage = ""
    @Published var showAlert = false
    @Published var autoMatchState: FoodAutoMatchState = .idle

    // 검색 시트는 상태를 자체 소유하지 않고 이 모델(DietTimerView가 들고 있는 공유 인스턴스)을
    // 그대로 참조하므로, 시트를 닫아도 검색어/결과가 자동으로 사라지지 않음 — 시트가 열릴 때마다
    // 호출해서 매번 빈 상태로 시작하게 함
    func resetSearch() {
        searchQuery = ""
        autoMatchState = .idle
        searchResults = []
        isSearchingFoods = false
        searchErrorMessage = nil
    }

    func loadFavorites() async {
        do {
            favorites = try await FavoriteAPIService.fetchFavorites()
        } catch {
            alertMessage = "즐겨찾기 불러오기 실패: \(error.localizedDescription)"
            showAlert = true
        }
    }

    func deleteFavorites(at offsets: IndexSet) async {
        let toDelete = offsets.map { favorites[$0] }
        favorites.remove(atOffsets: offsets)
        for favorite in toDelete {
            try? await FavoriteAPIService.deleteFavorite(id: favorite.id)
        }
    }

    // .swipeActions/.contextMenu는 인덱스가 아니라 항목 자체를 넘겨주기 때문에 IndexSet 버전과 별도로 필요
    func deleteFavorite(_ favorite: FavoriteFood) async {
        do {
            try await FavoriteAPIService.deleteFavorite(id: favorite.id)
            favorites.removeAll { $0.id == favorite.id }
            Haptics.success()
        } catch {
            alertMessage = "삭제 실패: \(error.localizedDescription)"
            showAlert = true
        }
    }

    func addNewFavorite(_ favorite: FavoriteFood) async {
        do {
            let created = try await FavoriteAPIService.createFavorite(favorite)
            favorites.append(created)
        } catch {
            alertMessage = "즐겨찾기 등록 실패: \(error.localizedDescription)"
            showAlert = true
        }
    }

    // id는 그대로 유지한 채 나머지 필드만 서버에 반영
    func updateFavorite(_ favorite: FavoriteFood) async {
        do {
            let updated = try await FavoriteAPIService.updateFavorite(favorite)
            guard let index = favorites.firstIndex(where: { $0.id == updated.id }) else { return }
            favorites[index] = updated
        } catch {
            alertMessage = "수정 실패: \(error.localizedDescription)"
            showAlert = true
        }
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
    // 반환값은 버튼 쪽 체크마크/햅틱 피드백을 성공했을 때만 재생하기 위한 성공 여부
    @discardableResult
    func addFavoriteToRecord(_ favorite: FavoriteFood, meal: Meal, recordedAt: String?) async -> Bool {
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
            return true
        } catch {
            alertMessage = "추가 실패: \(error.localizedDescription)"
            showAlert = true
            return false
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
    func addSearchResultToFavorites(_ result: FoodSearchResult) async {
        let category = DigestCategory.from(fatGrams: result.fat)
        await addNewFavorite(FavoriteFood(name: result.name, calorie: result.calorie ?? 0, digestCategory: category, isTrigger: false, fatGrams: result.fat))
    }

    func performAutoMatch() async {
        let keyword = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return }

        autoMatchState = .loading(id: UUID())
        do {
            let result = try await FoodAPIService.searchFoodsAuto(keyword: keyword)
            if let result {
                autoMatchState = result.estimatedServingCalorie == nil
                    ? .noNutritionData(name: result.name)
                    : .result(result)
            } else {
                autoMatchState = .notFound(keyword: keyword)
            }
        } catch {
            autoMatchState = .error("검색 실패: \(error.localizedDescription)")
        }
    }

    // 1인분으로 이미 환산된 값(estimatedServingCalorie/estimatedServingFatGrams)을 그대로 씀 —
    // 100g 기준값을 쓰면 예전 "1인분 기준" 오표시 문제가 재발하기 때문
    // 반환값은 버튼 쪽 체크마크/햅틱 피드백을 성공했을 때만 재생하기 위한 성공 여부
    @discardableResult
    func addAutoMatchToRecord(_ result: FoodAutoMatchResult, meal: Meal, recordedAt: String?) async -> Bool {
        guard let calorie = result.estimatedServingCalorie else { return false }
        let category = DigestCategory.from(fatGrams: result.estimatedServingFatGrams)
        do {
            _ = try await FoodAPIService.createFood(
                name: result.name,
                calorie: calorie,
                digestTime: String(category.rawValue),
                isTrigger: false,
                meal: meal,
                fatGrams: result.estimatedServingFatGrams,
                recordedAt: recordedAt
            )
            return true
        } catch {
            alertMessage = "추가 실패: \(error.localizedDescription)"
            showAlert = true
            return false
        }
    }

    func addAutoMatchToFavorites(_ result: FoodAutoMatchResult) async {
        guard let calorie = result.estimatedServingCalorie else { return }
        let category = DigestCategory.from(fatGrams: result.estimatedServingFatGrams)
        await addNewFavorite(FavoriteFood(name: result.name, calorie: calorie, digestCategory: category, isTrigger: false, fatGrams: result.estimatedServingFatGrams))
    }
}
