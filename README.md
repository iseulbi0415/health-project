# 🏋️‍♀️ 지언의 첫 프로젝트 시작!
방학 동안 멋지게 완성해 보겠습니다.

## 진행 상황 2026-06-30

### 오늘 한 일
- [x] VS Code Live Server 확장 설치 및 사용법 숙지 (저장 시 자동 새로고침)
- [x] index.html 기존 코드 전체 삭제, D안(리퀴드 글래스 탭형) 기반으로 새로 작성 시작
- [x] 화면 슬라이드 전환 구조(틀) 작성
  - `screen-wrap` (창문 틀, overflow:hidden)
  - `screens` (화면 4개를 가로로 담는 컨테이너, flex)
  - `screen` × 4 (홈 / 식단·타이머 / 러닝 / 내 정보, 각각 home-screen / diet-screen / run-screen / info-screen class 추가)
- [x] style.css와 index.html 외부 스타일시트 연결 확인 (`<link rel="stylesheet" href="css/style.css">`)
- [x] 하단 탭바(`nav.tabbar`) HTML 작성 — 버튼 4개, `data-index`로 각 버튼이 연결될 화면 번호 지정
- [x] 탭바 CSS 작성 — `position: fixed`로 하단 고정, `tab-btn.active`로 선택된 탭 강조 표시
- [x] 학습: class vs id 차이, `:active`(가상 클래스) vs `active`(커스텀 class) 차이, `data-*` 속성 개념, flex/overflow/position:fixed 개념

### 다음에 할 일
- JS로 탭 버튼 클릭 시 `screens`를 translateX로 슬라이드 이동시키는 기능 구현
- 클릭한 버튼에만 `active` class 옮겨 붙이는 로직 작성
- 각 screen(홈/식단/러닝/정보) 안에 실제 콘텐츠 채우기 (기존 app.js 로직과 연결)

## 진행 상황 2026-07-01

### 오늘 한 일
- [x] 탭 버튼(`tab-btn`) 클릭 시 `screens`를 translateX로 슬라이드시키는 JS 기능 구현
- [x] 클릭한 버튼에만 `active` 클래스가 옮겨가도록 강조 표시 토글 기능 구현
- [x] `data-index` 값을 문자열 → 숫자로 변환(`Number()`)하여 이동 거리 계산 로직 작성
- [x] 이벤트 리스너, querySelectorAll+forEach, 콜백 함수, classList, 클로저 개념 학습

### 다음에 할 일
각 화면(`home-screen`, `diet-screen`, `run-screen`, `info-screen`) 안에 실제 콘텐츠 채우기 — 기존 app.js에 있던 BMR 계산기, 소화 타이머, 식단 기록, 러닝 기록, 컨디션 메모 로직을 새 탭 구조에 맞게 옮겨서 재구성할 예정. 특히 소화 타이머(`DigestiveTimer` 클래스)는 홈 화면과 식단 화면 두 군데에 동시에 반영되어야 해서, 상태 공유 방법을 같이 고민하며 진행하기로 함.