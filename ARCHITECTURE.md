# 시스템 아키텍처 문서

> 명지대 '2026년도 제5회 창의적 SW프로그램 경진대회' 출품작 — 역류성 식도염 케어 + 러닝 습관 관리 앱

---

## 1. 전체 시스템 구조

3단(3-tier) 구조로, 각 계층은 서로 독립적으로 실행되고 HTTP/JSON으로만 통신한다.

```
┌─────────────────────┐        HTTP (fetch, JSON, 세션 쿠키)   ┌──────────────────────────┐        JDBC        ┌─────────────┐
│   프론트엔드          │  ───────────────────────────►    │   백엔드 (Spring Boot)     │  ─────────────►    │   MySQL     │
│   HTML/CSS/JS         │  ◄───────────────────────────    │   localhost:8080          │  ◄─────────────    │  health_project │
│   (localhost:5500)    │                                   │                            │                     │             │
└─────────────────────┘                                   └──────────────────────────┘                     └─────────────┘
```
로그인 시 백엔드가 카카오 인증 서버(`kauth`/`kapi.kakao.com`)와 별도로 통신해 인가 코드를 사용자 정보로 교환한다 — 흐름은 2-0 참고.

| 계층 | 기술 | 역할 |
|---|---|---|
| 프론트엔드 | HTML / CSS / JS (바닐라, 프레임워크 없음) | 화면 렌더링, 입력 수집, `fetch` API 호출(`credentials: "include"`), BMR/TDEE·MET 칼로리 등 계산, 로그인 게이트 |
| 백엔드 | Spring Boot 4.x (Java 17, Maven) — Web + JPA + MySQL Driver + Lombok + Security + OAuth2 Client | REST API, DB 접근(Spring Data JPA), Entity ↔ JSON 변환(Jackson), 카카오 로그인·세션 관리(`SecurityConfig`) |
| DB | MySQL (`health_project` 스키마) | 데이터 영구 저장, `ddl-auto=update`로 Entity 기준 자동 생성/갱신 |

**계층 분리 이유**: 프론트는 DB를 모르고 REST API만, 백엔드는 화면 구성을 모르고 Entity/JSON만 다룸 — 서로 독립적으로 교체 가능.

### 계층별 실행 방법
- 프론트: 정적 파일 서버 (VS Code Live Server, `localhost:5500`)
- 백엔드: `./mvnw spring-boot:run` → 내장 톰캣이 `localhost:8080`에서 대기
- DB: Homebrew로 설치한 MySQL, `localhost:3306`

---

## 2. API 명세

공통 사항
- Base URL: `http://localhost:8080/api`
- 모든 응답은 `Content-Type: application/json;charset=UTF-8`
- CORS: `SecurityConfig`의 `CorsConfigurationSource` 빈으로 `/**` 전체에 일괄 적용(허용 출처 `http://localhost:5500`, `allowCredentials: true`) — 컨트롤러별 `@CrossOrigin`은 Security가 직접 가로채는 경로(로그아웃 등)엔 안 먹혀서 빈 하나로 통일
- **인증 필요**: `/api/auth/me` 제외 모든 `/api/**`는 카카오 로그인 세션 필요, 비로그인 호출 시 401
- id는 서버 자동 생성(`GenerationType.IDENTITY`) — 요청 바디에 넣어도 무시됨(POST 기준)
- Food/Run/Memo는 모두 `user`(로그인한 사용자) 연관관계를 가짐 — 요청 바디에 안 넣어도 서버가 세션에서 자동으로 채움 (2-0 참고)

### 2-0. Auth (카카오 로그인)

국내 서비스라 카카오 로그인 채택. `Spring Security OAuth2 Client` 기반, 세션(쿠키) 방식.

| 엔드포인트 | 메서드 | 설명 |
|---|---|---|
| `/oauth2/authorization/kakao` | GET (`<a href>` 이동, `fetch` 금지) | 카카오 로그인 페이지로 리다이렉트 |
| `/api/auth/me` | GET | 로그인 상태 확인 — `{"loggedIn": false}` / `{"loggedIn": true, "nickname": "..."}` |
| `/api/auth/logout` | POST | 로그아웃(세션 무효화), 200만 반환 |

- 로그인 흐름: 카카오 콜백(`/login/oauth2/code/kakao`) → `KakaoOAuth2UserService`가 `User` 조회/생성 → 세션 발급 → 프론트로 리다이렉트
- 컨트롤러는 `@AuthenticationPrincipal KakaoOAuth2User principal`로 로그인 사용자를 받음
- 로그인은 리다이렉트, 로그아웃은 200만 반환 — 로그인(`<a href>` 실이동)은 리다이렉트 가능하지만, 로그아웃(`fetch`)은 리다이렉트를 따라가다 Live Server(CORS 미지원)에서 막혀 실패하기 때문(겪었던 버그). 화면 전환은 프론트가 `reload()`로 직접 처리

### 2-1. Food (식단 기록)

| 엔드포인트 | 메서드 | 설명 |
|---|---|---|
| `/api/foods` | GET | 전체 음식 기록 조회 |
| `/api/foods` | POST | 음식 기록 추가 |
| `/api/foods/{id}` | PUT | 음식 기록 수정 |
| `/api/foods/{id}` | DELETE | 음식 기록 삭제 |

**필드 구조** (Java 필드 ↔ DB 컬럼 ↔ JSON 키 ↔ 프론트 변수명)

| Java (Food.java) | 타입 | DB 컬럼 (실제 `DESCRIBE food`) | JSON 키 | 프론트 매핑 (app.js) |
|---|---|---|---|---|
| id | Long | `id` bigint PK, auto_increment | `id` | `이름 없음(그대로 id)` |
| name | String | `name` varchar(255) | `name` | `이름` |
| calorie | int | `calorie` int | `calorie` | `칼로리` |
| digestTime | String | `digest_time` varchar(255) | `digestTime` | `소화시간` (실제 값은 "2"/"3"/"4" — 소화 난이도 버튼 🟢🟡🔴에서 온 문자열) |
| isTrigger | boolean | `is_trigger` bit(1) | `isTrigger` **(+`trigger` 중복 키, 아래 참고)** | `트리거` |
| recordedAt | LocalDateTime | `recorded_at` datetime | `recordedAt` | `기록시각` (화면 표시 UI는 아직 없음, 아래 참고) |
| user | User (연관관계) | `user_id` bigint FK, NOT NULL | (요청/응답 바디에 없음) | 로그인 세션에서 서버가 자동으로 채움 |

**요청 예시 (POST/PUT)**
```json
{ "name": "닭가슴살", "calorie": 165, "digestTime": "3", "isTrigger": false }
```

**응답 예시**
```json
{ "id": 15, "name": "닭가슴살", "calorie": 165, "digestTime": "3", "isTrigger": false, "trigger": false, "recordedAt": "2026-07-17T12:34:56" }
```

> ⚠️ **`recordedAt` 자동 채움/보존 규칙**: POST는 요청 바디에 `recordedAt`이 있어도 무시하고 서버가 항상 `LocalDateTime.now()`로 덮어써서 저장한다(기록 시각 조작 방지). PUT은 값이 오면 그 값으로 갱신하지만, 지금 프론트는 이 필드를 다루지 않으므로 `recordedAt`을 안 보내면(null) 기존 DB 값을 그대로 유지한다 — 그냥 덮어쓰면 음식을 수정할 때마다 시각이 null이 되어버리기 때문. `FoodController.updateFood`가 수정 전 기존 엔티티를 조회해 이 로직을 처리한다.

> ⚠️ **`isTrigger`/`trigger` 중복 키에 대한 설계 노트**: `Food.java`의 `isTrigger` 필드는 Lombok `@Getter`가 `isTrigger()`라는 getter를 생성하는데, Jackson은 boolean getter `isXxx()`를 프로퍼티명 `xxx`로 해석하는 규칙이 있어 기본값으로는 JSON 키가 `trigger`가 되어버린다. 프론트(`app.js`)는 `isTrigger`라는 키를 기대하므로 필드에 `@JsonProperty("isTrigger")`를 명시적으로 붙여 이름을 고정했다. 다만 Lombok이 만든 `isTrigger()` getter 자체는 여전히 별도 프로퍼티로 잡혀서 응답에 `trigger` 키가 중복으로 따라 나온다 — 프론트는 이 여분 키를 그냥 무시하므로 기능엔 문제없지만, 정석대로 정리하려면 필드명을 `trigger`로 바꾸고 `@Column(name="is_trigger")`로 DB 컬럼명만 유지하는 방법이 있다 (지금은 최소 변경 원칙에 따라 보류). 자세한 원인은 3번 섹션 참고.

> ⚠️ **소유권 검증 (PUT/DELETE)**: 수정·삭제 전 기존 레코드의 `user`가 로그인 사용자와 같은지 확인, 다르면 403(id 추측 접근 방지). 검증 후 `user`는 요청 바디 값을 무시하고 기존 소유자로 고정(바디 위조로 소유권 이전 방지).

### 2-2. Run (러닝 기록)

| 엔드포인트 | 메서드 | 설명 |
|---|---|---|
| `/api/runs` | GET | 전체 러닝 기록 조회 |
| `/api/runs` | POST | 러닝 기록 추가 |
| `/api/runs/{id}` | PUT | 러닝 기록 수정 |
| `/api/runs/{id}` | DELETE | 러닝 기록 삭제 |

| Java (Run.java) | 타입 | DB 컬럼 | JSON 키 | 프론트 매핑 |
|---|---|---|---|---|
| id | Long | `id` bigint PK | `id` | id |
| distance | double | `distance` double | `distance` | `거리` (km) |
| time | double | `time` double | `time` | `시간` (분, 소수점=초 환산에 사용) |
| heartRate | int | `heart_rate` int | `heartRate` | `심박수` |
| speedKmh | double | `speed_kmh` double | `speedKmh` | `시속` |
| calorieBurned | double | `calorie_burned` double | `calorieBurned` | `칼로리` (MET 공식 기반 계산 후 저장) |
| recordedAt | LocalDateTime | `recorded_at` datetime | `recordedAt` | `기록시각` (화면 표시 UI는 아직 없음, Food와 동일한 자동 채움/보존 규칙 — 2-1 참고) |
| user | User (연관관계) | `user_id` bigint FK, NOT NULL | (요청/응답 바디에 없음) | 로그인 세션에서 서버가 자동으로 채움 (2-1 소유권 검증 노트와 동일) |

**요청/응답 예시**
```json
{ "id": 3, "distance": 5.2, "time": 32.5, "heartRate": 145, "speedKmh": 9.6, "calorieBurned": 310.4, "recordedAt": "2026-07-17T12:40:00" }
```

### 2-3. Memo (컨디션 메모)

| 엔드포인트 | 메서드 | 설명 |
|---|---|---|
| `/api/memos` | GET | 전체 메모 조회 |
| `/api/memos` | POST | 메모 추가 |
| `/api/memos/{id}` | PUT | 메모 수정 |
| `/api/memos/{id}` | DELETE | 메모 삭제 |

| Java (Memo.java) | 타입 | DB 컬럼 | JSON 키 | 프론트 매핑 |
|---|---|---|---|---|
| id | Long | `id` bigint PK | `id` | id |
| date | String | `date` varchar(255) | `date` | `날짜` (수정 UI에서 직접 편집 가능 — app.js `renderMemoList()`) |
| content | String | `content` varchar(255) | `content` | `내용` |
| symptomScore | int | `symptom_score` int | `symptomScore` | `증상점수` (1~10 슬라이더 입력값) |
| user | User (연관관계) | `user_id` bigint FK, NOT NULL | (요청/응답 바디에 없음) | 로그인 세션에서 서버가 자동으로 채움 (2-1 소유권 검증 노트와 동일) |

**요청/응답 예시**
```json
{ "id": 7, "date": "2026-07-17", "content": "속이 더부룩함", "symptomScore": 6 }
```

---

## 3. 데이터 흐름 (예: "음식 추가" 시나리오)

트리거 음식 체크박스를 켠 채로 "➕ 음식 추가" 버튼을 눌렀을 때 전체 경로:

```
1. 사용자 액션
   식단 화면에서 이름/칼로리 입력 + 소화 난이도 선택 + "⚠️ 트리거 음식" 체크 후 버튼 클릭

2. JS 이벤트 (app.js, add-food-btn 클릭 리스너)
   입력값을 한글 키 객체로 수집: { 이름, 칼로리, 소화시간, 트리거: true }

3. 번역 함수 (app.js, toServerFood)
   한글 키 → 서버가 이해하는 영어 키로 변환
   { name, calorie, digestTime, isTrigger: true }

4. fetch (app.js)
   POST http://localhost:8080/api/foods
   body: JSON.stringify(위 객체)

5. Controller (FoodController.createFood)
   @RequestBody로 JSON을 Food 객체로 역직렬화(Jackson)
   → foodRepository.save(food) 호출

6. Repository / ORM (FoodRepository extends JpaRepository, Hibernate)
   Food 객체를 SQL INSERT로 변환해 실행
   INSERT INTO food (name, calorie, digest_time, is_trigger) VALUES (...)

7. MySQL (health_project.food 테이블)
   행 저장, auto_increment id 채번

8. 응답 역경로
   저장된 Food 객체(생성된 id 포함) → Jackson이 다시 JSON으로 직렬화
   → HTTP 응답으로 프론트에 반환

9. 프론트 반영 (app.js)
   response.json()으로 파싱 → fromServerFood(saved)로 다시 한글 키 객체로 변환
   → todayFoods 배열에 push → renderFoodList() 호출
   → "오늘 먹은 음식" 목록에 카드 추가, food.트리거 값에 따라 "⚠️ 트리거" 태그 표시,
     총 칼로리 재계산 후 화면 텍스트/게이지 갱신
```

GET(조회)/PUT(수정)/DELETE(삭제)도 동일한 계층 순서(JS 이벤트 → fetch → Controller → Repository → DB)를 따르며, 방향만 다르다.

---

## 4. ERD (테이블 구조)

food/run/memo는 서로 외래키로 연결되어 있지 않지만(각 기록이 독립적으로 저장되는 구조 — 날짜 기반 연관관계는 백로그 항목), 셋 다 `user_id`로 `user` 테이블을 참조한다(카카오 로그인 도입으로 추가된 관계).

```
                                 ┌───────────────────────────┐
                                 │ user                      │
                                 ├───────────────────────────┤
                                 │ id            bigint  PK  │
                                 │ kakao_id      varchar(255) UNIQUE│
                                 │ nickname      varchar(255)│
                                 └─────────────┬─────────────┘
                                                │ (1:N, user_id FK)
                     ┌──────────────────────────┼──────────────────────────┐
                     │                          │                          │
┌───────────────────────────┐   ┌───────────────────────────┐   ┌───────────────────────────┐
│ food                      │   │ run                       │   │ memo                      │
├───────────────────────────┤   ├───────────────────────────┤   ├───────────────────────────┤
│ id            bigint  PK  │   │ id             bigint PK  │   │ id             bigint PK  │
│ name          varchar(255)│   │ distance       double     │   │ date           varchar(255)│
│ calorie       int         │   │ time           double     │   │ content        varchar(255)│
│ digest_time   varchar(255)│   │ heart_rate     int        │   │ symptom_score  int         │
│ is_trigger    bit(1)      │   │ speed_kmh      double     │   │ user_id        bigint FK   │
│ recorded_at   datetime    │   │ calorie_burned double     │   └───────────────────────────┘
│ user_id       bigint FK   │   │ recorded_at    datetime   │
└───────────────────────────┘   │ user_id        bigint FK  │
                                 └───────────────────────────┘
```

- PK는 모두 `id` (BIGINT, AUTO_INCREMENT) — JPA `@GeneratedValue(strategy = GenerationType.IDENTITY)`
- 컬럼명은 Java 필드명(camelCase)을 Hibernate가 자동으로 snake_case 변환한 것 (예: `isTrigger` → `is_trigger`, `speedKmh` → `speed_kmh`)
- 테이블은 코드로 직접 만든 게 아니라 `spring.jpa.hibernate.ddl-auto=update` 설정으로 Entity 클래스를 기준으로 Hibernate가 자동 생성/갱신함 — 즉 **Entity 클래스(Food.java 등)가 곧 DB 스키마의 원본(source of truth)**
- `user_id`는 `@ManyToOne(optional = false)`로 NOT NULL — 카카오 로그인 도입 시 기존 테스트 데이터를 삭제하고 시작해서 처음부터 NOT NULL로 추가 가능했음
