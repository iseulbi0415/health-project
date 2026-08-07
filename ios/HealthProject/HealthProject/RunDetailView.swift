//
//  RunDetailView.swift
//  HealthProject
//
//  러닝 기록 상세(읽기 전용) — 러닝 탭 목록에서 카드를 탭하면 진입(NavigationLink push).
//  우측 상단 편집 버튼에서 기존 RunAddView(수정 모드)로 연결됨
//

import SwiftUI

struct RunDetailView: View {
    // List에서 넘어온 초기값을 로컬로 들고 있다가, 편집 후 자체적으로 다시 불러와 갱신함
    @State var run: RunRecord
    // 편집이 끝나면 목록도 최신 상태가 되도록 부모(ContentView)에 알림
    let onUpdated: () async -> Void

    @State private var isShowingEdit = false

    var body: some View {
        VStack(spacing: 0) {
            // 다른 탭들과 동일한 GradientHeaderView 배너 — 편집 버튼도 같은 방식(HeaderActionButton)으로 배치
            GradientHeaderView(
                title: "러닝 상세",
                subtitle: "이 기록의 상세 정보",
                colors: HeaderPalette.coral
            ) {
                HeaderActionButton(systemImage: "pencil") {
                    isShowingEdit = true
                }
            }

            List {
                Section {
                    HStack(spacing: 8) {
                        Image(systemName: "figure.run")
                            .foregroundStyle(Color("CalorieCoral"))
                            .font(.title2)
                        // 거리가 이 화면의 대표값이라 가장 크게
                        Text("\(run.distance, specifier: "%.2f") km")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .monospacedDigit()
                    }
                    if !dateDisplay.isEmpty {
                        Text(dateDisplay)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                // 나머지 값들 — 목록에서 폐기했던 그리드 셀 레이아웃을 여기서 재사용(전체 화면이라 잘 맞음).
                // 심박수가 0이면(구 기록 등 데이터 없음) statCells에서 아예 빠져서 자연스럽게 생략됨
                Section {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                        ForEach(statCells, id: \.label) { cell in
                            statCell(value: cell.value, label: cell.label)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.insetGrouped)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .sheet(isPresented: $isShowingEdit) {
            RunAddView(onSaved: {
                isShowingEdit = false
                Task { await refresh() }
            }, existingRun: run)
        }
    }

    // recordedAt 앞 10자리(yyyy-MM-dd) — 목록의 relativeDateDisplay(오늘/어제 등)와 달리
    // 상세 화면에선 정확한 날짜를 그대로 보여줌
    private var dateDisplay: String {
        guard let recordedAt = run.recordedAt, recordedAt.count >= 10 else { return "" }
        return String(recordedAt.prefix(10))
    }

    private var statCells: [(value: String, label: String)] {
        var cells: [(value: String, label: String)] = [
            (run.timeDisplay, "시간"),
            (run.paceDisplay, "페이스"),
            ("\(Int(run.calorieBurned.rounded()))kcal", "칼로리"),
            (String(format: "%.1fkm/h", run.speedKmh), "시속")
        ]
        if run.heartRate > 0 {
            cells.append(("\(run.heartRate)bpm", "심박수"))
        }
        return cells
    }

    @ViewBuilder
    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(Color("CalorieCoral"))
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(.secondarySystemFill), in: RoundedRectangle(cornerRadius: 12))
    }

    // 단건 조회 API가 없어서, 전체 목록을 다시 받아 같은 id를 찾아 로컬 상태를 갱신함
    // (DayDetailView.loadDayDetail()과 같은 "다시 불러와서 반영" 패턴)
    private func refresh() async {
        if let all = try? await RunAPIService.fetchRuns(),
           let updated = all.first(where: { $0.id == run.id }) {
            run = updated
        }
        await onUpdated()
    }
}

#Preview {
    NavigationStack {
        RunDetailView(
            run: RunRecord(id: 1, distance: 5.0, time: 27.87, heartRate: 175, speedKmh: 10.8, calorieBurned: 216, recordedAt: "2026-07-21T08:00:00"),
            onUpdated: {}
        )
    }
}
