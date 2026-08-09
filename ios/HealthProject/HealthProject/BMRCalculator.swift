//
//  BMRCalculator.swift
//  HealthProject
//
//  ProfileView(BMR 계산)와 HomeView(오늘 칼로리 목표 표시)가 같은 공식을 써야 해서
//  분리한 공유 계산 로직. 공식이 갈라지면 두 화면 숫자가 어긋나는 버그가 생기므로 여기만 예외적으로 공유함
//

import Foundation

enum Gender: String, CaseIterable, Identifiable {
    case male = "남성"
    case female = "여성"
    var id: String { rawValue }
}

// @AppStorage는 RawRepresentable의 RawValue가 Int/String일 때만 직접 지원해서, 실제 활동계수(Double)는
// coefficient 계산 프로퍼티로 따로 두고 rawValue는 저장용 Int 인덱스로 씀
enum ActivityLevel: Int, CaseIterable, Identifiable {
    case sedentary, light, moderate, active

    var id: Int { rawValue }

    // 활동계수 — Harris-Benedict 활동계수 체계에서 통용되는 값(1.2/1.375/1.55/1.725).
    // 단일 원 논문이 아니라 여러 임상 영양 문헌과 계산기에서 관행적으로 쓰이는
    // 근사값이며, 개인차가 커 정밀한 추정에는 한계가 있음.
    // (참고: 위 BMRCalculator가 쓰는 Mifflin-St Jeor 원 논문(1990)에는 활동계수가
    // 포함되어 있지 않음 — 활동계수는 별도로 통용되는 값을 가져와 곱하는 것)
    var coefficient: Double {
        switch self {
        case .sedentary: return 1.2
        case .light: return 1.375
        case .moderate: return 1.55
        case .active: return 1.725
        }
    }
    var label: String {
        switch self {
        case .sedentary: return "거의 안움직임"
        case .light: return "가벼운 활동"
        case .moderate: return "보통 활동"
        case .active: return "활발한 활동"
        }
    }
}

// Mifflin-St Jeor Equation(1990) — 미국 영양학회(Academy of Nutrition and Dietetics) 권장 공식.
// 웹 프론트(js/app.js)의 계산 로직과 동일
enum BMRCalculator {
    static func bmr(heightCm: Double, weightKg: Double, age: Double, gender: Gender) -> Double {
        if gender == .male {
            return (10 * weightKg) + (6.25 * heightCm) - (5 * age) + 5
        } else {
            return (10 * weightKg) + (6.25 * heightCm) - (5 * age) - 161
        }
    }

    static func tdee(heightCm: Double, weightKg: Double, age: Double, gender: Gender, activity: ActivityLevel) -> Double {
        bmr(heightCm: heightCm, weightKg: weightKg, age: age, gender: gender) * activity.coefficient
    }

    // 증량 목표(목표 칼로리) = 유지 칼로리(TDEE) + 400kcal 고정 서지 — 일반적으로 권장되는
    // 300~500kcal 범위 내 값. ProfileView(BMR 계산 화면)와 HomeView("오늘 칼로리" 카드의 "목표"
    // 세그먼트)가 같은 값을 써야 해서 여기 공유 계산에 둠 — 인라인으로 각자 계산하면 두 화면
    // 숫자가 갈라지는 버그가 생길 수 있음(이 파일 상단 주석과 동일한 이유)
    static func bulkGoal(heightCm: Double, weightKg: Double, age: Double, gender: Gender, activity: ActivityLevel) -> Double {
        tdee(heightCm: heightCm, weightKg: weightKg, age: age, gender: gender, activity: activity) + 400
    }
}
