//
//  ProfileView.swift
//  HealthProject
//
//  내 정보 화면 — BMR/목표 칼로리 계산, 컨디션 메모 저장, 로그아웃
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var authManager: AuthManager

    // @AppStorage: 값이 바뀔 때마다 UserDefaults에 자동 저장 + 다음 실행 시 자동 복원 (AuthManager의
    // UserDefaults 동기화와 같은 목적, 웹의 localStorage 저장과 동등)
    @AppStorage("bmrHeight") private var heightText = ""
    @AppStorage("bmrWeight") private var weightText = ""
    @AppStorage("bmrAge") private var ageText = ""
    @AppStorage("bmrGender") private var gender = Gender.male
    @AppStorage("bmrActivityLevel") private var activityLevel = ActivityLevel.moderate
    // 계산 버튼을 눌러야만 true — HomeView가 "목표 칼로리 설정됨" 여부를 이 값으로 판단함(웹의
    // localStorage "tdee" 존재 여부와 동등: 입력값만 채워져 있고 계산을 안 눌렀으면 목표 없음 상태 유지)
    @AppStorage("goalCalculated") private var hasCalculatedGoal = false
    @State private var isShowingBMRSheet = false

    @State private var recentMemos: [MemoRecord] = []
    @State private var isLoadingMemos = false
    @State private var memosErrorMessage: String?
    @State private var editingMemo: MemoRecord?
    @State private var isShowingAddMemoSheet = false
    // 평소엔 목록 항목 없이 "N개 보기"만, 펼치면 5개 다 — DisclosureGroup 표준 화살표 재사용
    @State private var isMemoListExpanded = false
    // 실수로 로그아웃 버튼을 누르는 걸 방지하기 위한 확인 절차
    @State private var showLogoutConfirmation = false

    // 캐시된 결과 문자열 대신 저장된 값에서 매번 다시 계산 — 시트에서 값이 바뀌어도 별도 동기화 없이
    // 항상 최신 상태를 보여줌(단일 소스: heightText/weightText/ageText/gender/activityLevel)
    // Mifflin-St Jeor Equation(1990) — 미국 영양학회(Academy of Nutrition and Dietetics) 권장 공식.
    // TDEE = BMR × 활동계수, 증량 목표는 TDEE + 400kcal (일반적으로 권장되는 300~500kcal 범위 내 값)
    // 웹 프론트(js/app.js)의 계산 로직과 동일
    private var bmrSummary: (bmr: Int, tdee: Int, bulk: Int)? {
        guard hasCalculatedGoal,
              let height = Double(heightText),
              let weight = Double(weightText),
              let age = Double(ageText) else { return nil }
        let bmr = BMRCalculator.bmr(heightCm: height, weightKg: weight, age: age, gender: gender)
        let tdee = BMRCalculator.tdee(heightCm: height, weightKg: weight, age: age, gender: gender, activity: activityLevel)
        return (Int(bmr.rounded()), Int(tdee.rounded()), Int((tdee + 400).rounded()))
    }

    var body: some View {
        NavigationStack {
            // GradientHeaderView는 Form 밖(VStack의 형제)에 둬서 화면 최상단에 전체 폭 배너로
            // 붙게 함(다른 3개 탭과 동일한 이유)
            VStack(spacing: 0) {
                GradientHeaderView(
                    title: "내 정보",
                    subtitle: "BMR·목표 칼로리와 컨디션 기록",
                    colors: HeaderPalette.purple
                ) {
                    // 연필(BMR 수정)/플러스(메모 추가) — 계산 전후 상관없이 항상 둘 다 표시(DietTimerView의
                    // +/돋보기와 같은 방식). 계산 여부로 버튼 개수를 바꾸면 캡슐 폭이 달라지며 튀어서 고정 세트로 유지
                    HeaderActionCapsule {
                        Button {
                            isShowingBMRSheet = true
                        } label: {
                            Image(systemName: "pencil")
                                .imageScale(.large)
                                .frame(width: 28, height: 28)
                                .contentShape(Rectangle())
                        }
                        Button {
                            isShowingAddMemoSheet = true
                        } label: {
                            Image(systemName: "plus")
                                .imageScale(.large)
                                .frame(width: 28, height: 28)
                                .contentShape(Rectangle())
                        }
                    }
                }

                profileForm
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }

    private var profileForm: some View {
        Form {
                Section {
                    if let bmrSummary {
                        // 최근 컨디션이 접히면서 생긴 여백을 이 카드가 채움 — "요약"이 아니라 화면의
                        // 메인 콘텐츠로 취급. 목표/유지/BMR 세 숫자는 "증량이 무조건 목표"라는 인상을
                        // 주지 않기 위해 동등한 크기로 나란히 배치 — 폰트는 HomeView "오늘 칼로리"
                        // 숫자(.title2.bold())와 통일해서 앱 전체 칼로리 표기 일관성 유지
                        VStack(alignment: .leading, spacing: 18) {
                            HStack(alignment: .top, spacing: 12) {
                                calorieStat(label: "목표 칼로리", value: bmrSummary.bulk)
                                calorieStat(label: "유지 칼로리", value: bmrSummary.tdee)
                                calorieStat(label: "BMR", value: bmrSummary.bmr)
                            }

                            Divider()

                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    inputTag("키 \(heightText)cm")
                                    inputTag("몸무게 \(weightText)kg")
                                    inputTag("나이 \(ageText)세")
                                }
                                HStack(spacing: 8) {
                                    inputTag(gender.rawValue)
                                    inputTag(activityLevel.label)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    } else {
                        Button("BMR 계산하기") {
                            isShowingBMRSheet = true
                        }
                        .buttonStyle(.glassProminent)
                        .tint(.accentColor)
                    }
                } header: {
                    Label("BMR / 목표 칼로리", systemImage: "flame.fill")
                }

                // 방금 저장한 것과는 별개로, 과거에 저장된 기록을 보여주는 섹션 — 최신순 5개
                Section {
                    if isLoadingMemos {
                        ProgressView()
                    } else if let memosErrorMessage {
                        Text(memosErrorMessage)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    } else if recentMemos.isEmpty {
                        Text("저장된 기록이 없습니다.")
                            .foregroundStyle(.secondary)
                    } else {
                        // 평소엔 목록 항목을 하나도 안 보이고 "N개 보기"만 — 펼쳐야 정렬된 최신순 5개가 나타남
                        DisclosureGroup("\(recentMemos.count)개 보기", isExpanded: $isMemoListExpanded) {
                            ForEach(recentMemos) { memo in
                                memoRow(memo)
                            }
                        }
                    }
                } header: {
                    Label("최근 컨디션 (최신 5개)", systemImage: "clock.arrow.circlepath")
                }

                Section {
                    Button("로그아웃", role: .destructive) {
                        showLogoutConfirmation = true
                    }
                }
            }
            // confirmationDialog는 이 환경 시뮬레이터에서 팝오버 형태로 뜨면서 취소 버튼이 안
            // 보이는 렌더링 이슈가 있어서(실기기에서도 재현 확인됨), 항상 화면 중앙 박스로
            // 뜨는 표준 alert로 교체함
            .alert(
                "정말 로그아웃 하시겠어요?",
                isPresented: $showLogoutConfirmation
            ) {
                Button("로그아웃", role: .destructive) {
                    authManager.logout()
                }
                Button("취소", role: .cancel) {}
            }
            .sheet(isPresented: $isShowingBMRSheet) {
                BMRInputView(
                    heightText: heightText,
                    weightText: weightText,
                    ageText: ageText,
                    gender: gender,
                    activityLevel: activityLevel,
                    onSave: saveBMRProfile
                )
            }
            .sheet(item: $editingMemo) { memo in
                MemoEditView(memo: memo, onSaved: {
                    Task { await loadRecentMemos() }
                })
            }
            .sheet(isPresented: $isShowingAddMemoSheet) {
                MemoEditView(onSaved: {
                    Task { await loadRecentMemos() }
                })
            }
            .task {
                await loadRecentMemos()
            }
            .refreshable {
                await loadRecentMemos()
            }
    }

    // 목표/유지/BMR 세 숫자를 동일한 크기로 나란히 배치하기 위한 공용 뷰 — 폰트는 HomeView
    // "오늘 칼로리" 숫자와 동일하게 .title2.bold()로 통일
    @ViewBuilder
    private func calorieStat(label: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(value) kcal")
                .font(.title2)
                .bold()
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // BMR 카드 하단 입력값(키/몸무게/나이/성별/활동량)을 캡슐 태그로 보여줌 — 한 줄에 억지로
    // 다 넣지 않고 여유 있게 나열하기 위한 용도
    @ViewBuilder
    private func inputTag(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color.secondary.opacity(0.12)))
    }

    // 항상 보이는 최신 2개와 접힌 영역 안의 나머지 3개가 똑같은 모양을 쓰도록 공용 행으로 뺌
    @ViewBuilder
    private func memoRow(_ memo: MemoRecord) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(memo.date)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(memo.content)
            Text("증상 점수: \(memo.symptomScore)")
                .font(.footnote)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button("삭제", role: .destructive) {
                Task { await deleteMemo(memo) }
            }
        }
        .swipeActions(edge: .leading) {
            Button("수정") { editingMemo = memo }
                .tint(.blue)
        }
        .contextMenu {
            Button("수정") { editingMemo = memo }
            Button("삭제", role: .destructive) {
                Task { await deleteMemo(memo) }
            }
        }
    }

    // BMRInputView의 onSave 콜백 — 검증은 시트에서 이미 끝났으므로 여기선 저장만 함
    private func saveBMRProfile(height: String, weight: String, age: String, gender: Gender, activityLevel: ActivityLevel) {
        heightText = height
        weightText = weight
        ageText = age
        self.gender = gender
        self.activityLevel = activityLevel
        hasCalculatedGoal = true

        if let heightValue = Double(height), let weightValue = Double(weight), let ageValue = Double(age) {
            Task {
                await syncProfileToServer(height: heightValue, weight: weightValue, age: ageValue)
            }
        }
    }

    // 서버에도 저장해둬야 앱 삭제 후 재설치했을 때 복원됨(UserProfileAPIService.hydrateLocalCache 참고).
    // 로컬 저장은 이미 끝나서 화면엔 결과가 그대로 보이므로, 이 저장은 실패해도 조용히
    // 무시함(달력 점 표시처럼 부가 기능 — 사용자 입력 흐름을 막지 않음)
    private func syncProfileToServer(height: Double, weight: Double, age: Double) async {
        let profile = UserProfile(
            heightCm: height,
            weightKg: weight,
            age: Int(age),
            gender: gender.rawValue,
            activityLevel: activityLevel.rawValue,
            hasCalculatedGoal: true
        )
        try? await UserProfileAPIService.updateProfile(profile)
    }

    private func deleteMemo(_ memo: MemoRecord) async {
        do {
            try await MemoAPIService.deleteMemo(id: memo.id)
            Haptics.success()
            await loadRecentMemos()
        } catch {
            memosErrorMessage = "삭제 실패: \(error.localizedDescription)"
        }
    }

    private func loadRecentMemos() async {
        isLoadingMemos = true
        memosErrorMessage = nil
        do {
            let all = try await MemoAPIService.fetchMemos()
            // id는 "언제 저장했는지" 순서일 뿐 "어떤 날짜의 기록인지"와 다름 — MemoEditView에서 날짜를
            // 자유롭게 골라 저장/수정할 수 있어서, id 순으로 정렬하면 실제 날짜 순서와 어긋남(예: 예전
            // 날짜로 메모를 나중에 추가하면 id는 크지만 date는 더 이름). date(yyyy-MM-dd, 문자열이라도
            // 사전순=날짜순) 기준 내림차순으로 정렬하고, 같은 날짜면 id 내림차순으로 구분
            recentMemos = Array(all.sorted {
                $0.date != $1.date ? $0.date > $1.date : $0.id > $1.id
            }.prefix(5))
        } catch {
            memosErrorMessage = "최근 기록을 불러오지 못했습니다."
        }
        isLoadingMemos = false
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthManager.shared)
}
