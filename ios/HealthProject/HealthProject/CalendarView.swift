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
    let onSelectDate: (Date) -> Void
    let onVisibleMonthChange: (Int, Int) -> Void

    func makeUIView(context: Context) -> UICalendarView {
        let calendarView = UICalendarView()
        calendarView.calendar = Calendar.current
        calendarView.delegate = context.coordinator

        let selection = UICalendarSelectionSingleDate(delegate: context.coordinator)
        calendarView.selectionBehavior = selection

        return calendarView
    }

    func updateUIView(_ uiView: UICalendarView, context: Context) {
        // 이전 달의 점이 안 지워진 채 남지 않도록, 이전+새 날짜를 합쳐서 다시 그리게 함
        let datesToReload = context.coordinator.markedDateStrings.union(markedDateStrings)
            .compactMap(Self.dateComponents(fromDateString:))
        context.coordinator.markedDateStrings = markedDateStrings
        uiView.reloadDecorations(forDateComponents: datesToReload, animated: false)
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
            guard let dateComponents, let date = Calendar.current.date(from: dateComponents) else { return }
            onSelectDate(date)
        }
    }
}
