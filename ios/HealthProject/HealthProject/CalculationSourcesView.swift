//
//  CalculationSourcesView.swift
//  HealthProject
//
//  App Store Review Guidelines 1.4.1 대응 — BMR/소모 칼로리/소화 대기 시간 계산식과 근거 논문
//  출처를 한 곳에 모아 보여주는 공용 시트. 계산이 실제로 표시되는 화면(내 정보, 러닝 상세,
//  식단·타이머) 여러 곳에서 같은 화면을 재사용해 열림
//

import SwiftUI

struct CalculationSourcesView: View {
    @Environment(\.dismiss) private var dismiss

    // 원래는 SwiftUI Link를 4개 썼으나, 실기기에서 어떤 링크를 눌러도 전부 같은 논문(Herrmann)
    // 페이지로 열리는 버그가 있었음. 각 버튼이 들고 있는 URL 자체는(alert으로 직접 확인) 서로
    // 정확히 달랐고, Link 대신 openURL 환경변수로 직접 열자 문제가 재현되지 않아 이 방식으로 확정
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            List {
                Section("기초대사량 (BMR)") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("남성: 10 × 체중 + 6.25 × 키 − 5 × 나이 + 5")
                        Text("여성: 10 × 체중 + 6.25 × 키 − 5 × 나이 − 161")
                    }
                    .font(.subheadline)
                    .monospacedDigit()
                    citationText("Mifflin MD, et al. A new predictive equation for resting energy expenditure in healthy individuals. Am J Clin Nutr. 1990;51(2):241-247.")
                    Button("원문 보기") {
                        openURL(URL(string: "https://pubmed.ncbi.nlm.nih.gov/2305711/")!)
                    }
                    .font(.footnote)
                    .tint(Color("AccentPurple"))
                    Text("활동량 계수는 체중 관리 분야에서 통용되는 값을 사용했습니다.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("소모 칼로리") {
                    Text("MET × 체중(kg) × 시간(h)")
                        .font(.subheadline)
                        .monospacedDigit()
                    citationText("Herrmann SD, et al. 2024 Adult Compendium of Physical Activities: A third update of the energy costs of human activities. J Sport Health Sci. 2024.")
                    Button("원문 보기") {
                        openURL(URL(string: "https://pubmed.ncbi.nlm.nih.gov/38242596/")!)
                    }
                    .font(.footnote)
                    .tint(Color("AccentPurple"))
                }

                Section("소화 대기 시간") {
                    Text("끼니의 총 지방량으로 2 / 3 / 4시간을 안내합니다.")
                        .font(.subheadline)

                    citationText("Katz PO, et al. ACG Clinical Guideline for the Diagnosis and Management of Gastroesophageal Reflux Disease. Am J Gastroenterol. 2022;117(1):27-56.")
                    Button("원문 보기") {
                        openURL(URL(string: "https://pubmed.ncbi.nlm.nih.gov/34807007/")!)
                    }
                    .font(.footnote)
                    .tint(Color("AccentPurple"))

                    // Stacher 등(1991) 위 배출 연구 — 최초 조사에서 확보한 PMID(1810890)가 전혀
                    // 무관한 치과 임플란트 논문을 가리키는 오류였음. WebSearch로 원문(저자·제목·저널·
                    // 연도 대조)을 다시 찾아 정확한 PMID(1893810)로 확정
                    citationText("Stacher G, et al. Slow gastric emptying induced by high fat content of meal accelerated by cisapride administered rectally. Dig Dis Sci. 1991;36(9):1259-1265.")
                    Button("원문 보기") {
                        openURL(URL(string: "https://pubmed.ncbi.nlm.nih.gov/1893810/")!)
                    }
                    .font(.footnote)
                    .tint(Color("AccentPurple"))
                }

                Section {
                    Text("이 앱은 의료기기가 아니며, 제공되는 값은 참고용입니다.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("계산 근거")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func citationText(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}

#Preview {
    CalculationSourcesView()
}
