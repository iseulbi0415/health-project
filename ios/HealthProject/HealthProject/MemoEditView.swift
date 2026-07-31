//
//  MemoEditView.swift
//  HealthProject
//
//  "최근 컨디션 메모" 항목 수정 폼 — 날짜까지 수정 가능(기존에 없던 기능이었는데,
//  수정 폼을 새로 만드는 김에 같이 지원함)
//

import SwiftUI

struct MemoEditView: View {
    let memo: MemoRecord
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

    init(memo: MemoRecord, onSaved: @escaping () -> Void) {
        self.memo = memo
        self.onSaved = onSaved
        self._date = State(initialValue: Self.dateFormatter.date(from: memo.date) ?? Date())
        self._content = State(initialValue: memo.content)
        self._symptomScore = State(initialValue: Double(memo.symptomScore))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("날짜") {
                    DatePicker("날짜", selection: $date, displayedComponents: .date)
                        .datePickerStyle(.compact)
                }

                Section("컨디션 메모") {
                    TextEditor(text: $content)
                        .frame(minHeight: 100)

                    VStack(alignment: .leading) {
                        Text("증상 점수: \(Int(symptomScore))")
                        Slider(value: $symptomScore, in: 1...10, step: 1)
                    }
                }
            }
            .navigationTitle("메모 수정")
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
                try await MemoAPIService.updateMemo(
                    id: memo.id,
                    date: Self.dateFormatter.string(from: date),
                    content: content,
                    symptomScore: Int(symptomScore)
                )
                isSaving = false
                Haptics.success()
                onSaved()
                dismiss()
            } catch {
                isSaving = false
                alertMessage = "수정 실패: \(error.localizedDescription)"
                showAlert = true
            }
        }
    }
}

#Preview {
    MemoEditView(memo: MemoRecord(id: 1, date: "2026-07-31", content: "속쓰림", symptomScore: 5), onSaved: {})
}
