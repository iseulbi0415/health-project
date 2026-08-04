//
//  MemoEditView.swift
//  HealthProject
//
//  "컨디션 메모" 작성/수정 시트 — memo가 nil이면 신규 추가, 있으면 수정 모드. 신규 추가도 날짜를
//  고를 수 있게(기존엔 항상 오늘로 고정) 수정 폼과 화면을 합침
//

import SwiftUI

struct MemoEditView: View {
    let memo: MemoRecord?
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var date: Date
    @State private var content: String
    @State private var symptomScore: Double
    @State private var isSaving = false
    @State private var showAlert = false
    @State private var alertMessage = ""

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    init(memo: MemoRecord? = nil, onSaved: @escaping () -> Void) {
        self.memo = memo
        self.onSaved = onSaved
        self._date = State(initialValue: memo.flatMap { Self.dateFormatter.date(from: $0.date) } ?? Date())
        self._content = State(initialValue: memo?.content ?? "")
        self._symptomScore = State(initialValue: Double(memo?.symptomScore ?? 5))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("날짜") {
                    DatePicker("날짜", selection: $date, displayedComponents: .date)
                        .datePickerStyle(.compact)
                }

                Section("컨디션 메모") {
                    // TextEditor는 TextField와 달리 placeholder가 없어서, 내용이 비어있을 때만
                    // 안내 문구를 겹쳐 보여주고 타이핑을 시작하면 사라지게 함(ZStack 트릭)
                    ZStack(alignment: .topLeading) {
                        if content.isEmpty {
                            Text("오늘 컨디션이나 증상을 자유롭게 적어보세요")
                                .foregroundStyle(.secondary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: $content)
                            .frame(minHeight: 100)
                    }

                    VStack(alignment: .leading) {
                        Text("증상 점수: \(Int(symptomScore))")
                        Slider(value: $symptomScore, in: 1...10, step: 1)
                            .onChange(of: symptomScore) { _, _ in Haptics.selection() }
                    }
                }
            }
            .navigationTitle(memo == nil ? "메모 추가" : "메모 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("저장", action: save)
                    }
                }
            }
            .alert("확인해주세요", isPresented: $showAlert) {
                Button("확인", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
        }
    }

    private func save() {
        guard !content.isEmpty else {
            alertMessage = "메모를 작성해주세요!"
            showAlert = true
            return
        }

        isSaving = true
        Task {
            do {
                if let memo {
                    try await MemoAPIService.updateMemo(
                        id: memo.id,
                        date: Self.dateFormatter.string(from: date),
                        content: content,
                        symptomScore: Int(symptomScore)
                    )
                } else {
                    try await MemoAPIService.createMemo(
                        date: Self.dateFormatter.string(from: date),
                        content: content,
                        symptomScore: Int(symptomScore)
                    )
                }
                isSaving = false
                Haptics.success()
                onSaved()
                dismiss()
            } catch {
                isSaving = false
                alertMessage = "저장 실패: \(error.localizedDescription)"
                showAlert = true
            }
        }
    }
}

#Preview("수정") {
    MemoEditView(memo: MemoRecord(id: 1, date: "2026-07-31", content: "속쓰림", symptomScore: 5), onSaved: {})
}

#Preview("추가") {
    MemoEditView(onSaved: {})
}
