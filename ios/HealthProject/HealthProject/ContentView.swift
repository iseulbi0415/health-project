//
//  ContentView.swift
//  HealthProject
//
//  러닝 기록 목록 화면 + 새 기록 추가 진입점
//

import SwiftUI

struct ContentView: View {
    // @State: 이 값이 바뀌면 SwiftUI가 화면을 자동으로 다시 그려주게 만드는 속성 래퍼(property wrapper)
    @State private var runs: [RunRecord] = []       // 서버에서 받아온 러닝 기록 목록
    @State private var isLoading = false            // 네트워크 요청이 진행 중인지 여부
    @State private var errorMessage: String? = nil  // 요청 실패 시 보여줄 에러 메시지
    @State private var isShowingAddSheet = false     // 러닝 기록 추가 화면(시트) 표시 여부
    @State private var editingRun: RunRecord?         // 스와이프/컨텍스트 메뉴 "수정"에서 열리는 편집 시트 대상

    var body: some View {
        // NavigationStack: 화면 위쪽에 타이틀("러닝 기록")이 붙은 내비게이션 바를 만들어줌
        NavigationStack {
            // List: 배열(runs)을 받아서 각 항목마다 아래 클로저(줄 내용)를 반복해서 그려주는 SwiftUI 뷰
            // runs의 각 요소가 Identifiable(RunRecord.id)이라 별도 id 지정 없이 바로 사용 가능
            List(runs) { run in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        // 거리 표시 (소수점 둘째 자리까지)
                        Text("\(run.distance, specifier: "%.2f") km")
                            .font(.headline)
                        Spacer()
                        // 상대 날짜("오늘"/"어제"/"N일 전"), 일주일 이상 지나면 절대 날짜 — RunRecord.relativeDateDisplay
                        Text(run.relativeDateDisplay)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    // 시간 / 페이스를 한 줄에 좌우로 나눠서 표시
                    HStack {
                        Text("시간 \(run.timeDisplay)")
                        Spacer()
                        Text("페이스 \(run.paceDisplay)")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button("삭제", role: .destructive) {
                        Task { await deleteRun(run) }
                    }
                }
                .swipeActions(edge: .leading) {
                    Button("수정") { editingRun = run }
                        .tint(.blue)
                }
                .contextMenu {
                    Button("수정") { editingRun = run }
                    Button("삭제", role: .destructive) {
                        Task { await deleteRun(run) }
                    }
                }
            }
            .navigationTitle("러닝 기록")
            // overlay: List 위에 로딩/에러/빈 상태 메시지를 겹쳐서 보여줌
            .overlay {
                if isLoading {
                    ProgressView("불러오는 중...")
                } else if let errorMessage {
                    Text(errorMessage)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.red)
                        .padding()
                } else if runs.isEmpty {
                    Text("러닝 기록이 없습니다.")
                        .foregroundStyle(.secondary)
                }
            }
            // 내비게이션 바 오른쪽에 기록 추가 버튼 배치
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        isShowingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            // 시트: 화면 아래에서 위로 올라오는 별도 화면. 추가 화면에서 저장에 성공하면
            // onSaved 콜백으로 목록을 다시 불러와서 방금 추가한 기록이 바로 보이게 함
            .sheet(isPresented: $isShowingAddSheet) {
                RunAddView(onSaved: {
                    isShowingAddSheet = false
                    Task { await loadRuns() }
                })
            }
            .sheet(item: $editingRun) { run in
                RunAddView(onSaved: {
                    editingRun = nil
                    Task { await loadRuns() }
                }, existingRun: run)
            }
            // .task: 이 화면이 처음 화면에 나타날 때 딱 한 번 비동기 함수를 실행시켜주는 modifier
            .task {
                await loadRuns()
            }
            // .refreshable: 목록을 아래로 당기면 새로고침 — 웹엔 없는 iOS 네이티브 제스처
            .refreshable {
                await loadRuns()
            }
        }
    }

    private func deleteRun(_ run: RunRecord) async {
        do {
            try await RunAPIService.deleteRun(id: run.id)
            Haptics.success()
            await loadRuns()
        } catch {
            errorMessage = "삭제 실패: \(error.localizedDescription)"
        }
    }

    // 실제로 API를 호출하고, 결과(또는 에러)를 @State 변수에 담아 화면을 갱신하는 함수
    private func loadRuns() async {
        isLoading = true
        errorMessage = nil
        do {
            runs = try await RunAPIService.fetchRuns()
        } catch {
            errorMessage = "불러오기 실패: \(error.localizedDescription)\n(로그인이 만료됐을 수 있습니다 — 앱을 삭제 후 다시 실행해 재로그인해주세요. 로그아웃 기능은 아직 없습니다)"
        }
        isLoading = false
    }
}

#Preview {
    ContentView()
}
