//
//  CalendarView.swift
//  HealthProject
//
//  UIKit의 UICalendarView를 감싼 월간 캘린더 — SwiftUI DatePicker와 달리 날짜별 점 표시를
//  정식 API(decorationFor)로 지원해서 이걸 씀. 월 이동 헤더/오늘·선택 하이라이트는 기본 제공됨
//

import SwiftUI
import UIKit

struct CalendarView: UIViewRepresentable {
    // "yyyy-MM-dd" 문자열로 비교함 — DateComponents끼리 직접 == 비교하면 UICalendarView가
    // 내부적으로 채우는 다른 필드(예: era) 때문에 같은 날짜인데도 안 맞는 경우가 있어서(실제로 겪음),
    // year/month/day만 뽑아 문자열로 만들어 비교하는 방식으로 그 문제를 피함
    var markedDateStrings: Set<String>
    // 날짜 상세 시트가 떠 있는지 — 시트가 닫히는 순간(true→false) 캘린더 내부 선택을 비워서,
    // 같은 날짜를 다시 탭해도 "선택 변경 없음"으로 무시되지 않고 새로 선택되게 함(아래 설명 참고)
    var isDayDetailPresented: Bool
    let onSelectDate: (Date) -> Void
    let onVisibleMonthChange: (Int, Int) -> Void

    func makeUIView(context: Context) -> UICalendarView {
        let calendarView = UICalendarView()
        calendarView.calendar = Calendar.current
        calendarView.delegate = context.coordinator

        let selection = UICalendarSelectionSingleDate(delegate: context.coordinator)
        calendarView.selectionBehavior = selection
        context.coordinator.selection = selection

        return calendarView
    }

    func updateUIView(_ uiView: UICalendarView, context: Context) {
        // 이전 달의 점이 안 지워진 채 남지 않도록, 이전+새 날짜를 합쳐서 다시 그리게 함
        let datesToReload = context.coordinator.markedDateStrings.union(markedDateStrings)
            .compactMap(Self.dateComponents(fromDateString:))
        context.coordinator.markedDateStrings = markedDateStrings
        uiView.reloadDecorations(forDateComponents: datesToReload, animated: false)

        // UICalendarSelectionSingleDate는 "이미 선택된 날짜"를 다시 탭하면 선택에 변화가 없다고
        // 판단해 델리게이트(didSelectDate)를 아예 호출하지 않음(실기기 확인) — 그래서 상세 시트가
        // 닫히는 순간 내부 선택을 미리 nil로 비워두면, 다음 탭은 항상 "nil → 날짜"인 진짜 변경으로
        // 처리되어 같은 날짜를 다시 탭해도 정상적으로 열림
        if context.coordinator.wasDayDetailPresented && !isDayDetailPresented {
            // 시트 dismiss 시작과 정확히 같은 런루프 틱에서 실행되면 그 트랜지션과 겹쳐서 뚝뚝
            // 끊겨 보였음(0.4초 지연은 반대로 너무 늦게 시작되는 느낌) — 아주 짧게만 미뤄서
            // 체감상 "닫자마자 바로" 시작되면서도 겹침은 피하게 함
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak selection = context.coordinator.selection] in
                selection?.setSelected(nil, animated: true)
            }
        }
        context.coordinator.wasDayDetailPresented = isDayDetailPresented
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(markedDateStrings: markedDateStrings, onSelectDate: onSelectDate, onVisibleMonthChange: onVisibleMonthChange)
    }

    static func dateComponents(fromDateString dateString: String) -> DateComponents? {
        let parts = dateString.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return DateComponents(year: parts[0], month: parts[1], day: parts[2])
    }

    final class Coordinator: NSObject, UICalendarViewDelegate, UICalendarSelectionSingleDateDelegate {
        var markedDateStrings: Set<String>
        let onSelectDate: (Date) -> Void
        let onVisibleMonthChange: (Int, Int) -> Void
        // updateUIView에서 시트 열림→닫힘 전환을 감지하고, 그 순간 선택을 비우기 위해 필요
        weak var selection: UICalendarSelectionSingleDate?
        var wasDayDetailPresented = false
        // 방어적으로 유지 — 위 nil 선택 초기화 이후로는 사실상 항상 non-nil로 들어오지만,
        // 혹시 nil 콜백이 오는 다른 케이스가 있어도 같은 날짜를 다시 열어주기 위해 기억해둠
        private var lastSelectedDateComponents: DateComponents?

        init(markedDateStrings: Set<String>, onSelectDate: @escaping (Date) -> Void, onVisibleMonthChange: @escaping (Int, Int) -> Void) {
            self.markedDateStrings = markedDateStrings
            self.onSelectDate = onSelectDate
            self.onVisibleMonthChange = onVisibleMonthChange
        }

        func calendarView(_ calendarView: UICalendarView, decorationFor dateComponents: DateComponents) -> UICalendarView.Decoration? {
            guard let year = dateComponents.year, let month = dateComponents.month, let day = dateComponents.day else { return nil }
            let key = String(format: "%04d-%02d-%02d", year, month, day)
            guard markedDateStrings.contains(key) else { return nil }
            return .default(color: .systemBlue, size: .small)
        }

        func calendarView(_ calendarView: UICalendarView, didChangeVisibleDateComponentsFrom previousDateComponents: DateComponents) {
            let visible = calendarView.visibleDateComponents
            guard let year = visible.year, let month = visible.month else { return }
            onVisibleMonthChange(year, month)
        }

        func dateSelection(_ selection: UICalendarSelectionSingleDate, didSelectDate dateComponents: DateComponents?) {
            guard let dateComponents else {
                // 이미 선택돼 있던 날짜를 다시 탭해서 "해제"로 들어온 경우 — 선택 하이라이트는
                // 그대로 유지시키고, 같은 날짜의 상세 화면을 다시 열어줌(재탭해도 반응 없던 버그 수정)
                if let lastSelectedDateComponents {
                    selection.setSelected(lastSelectedDateComponents, animated: false)
                    if let date = Calendar.current.date(from: lastSelectedDateComponents) {
                        onSelectDate(date)
                    }
                }
                return
            }
            lastSelectedDateComponents = dateComponents
            guard let date = Calendar.current.date(from: dateComponents) else { return }
            onSelectDate(date)
        }
    }
}
