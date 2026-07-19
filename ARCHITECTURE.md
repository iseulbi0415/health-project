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
└─────────────────────┘                                   └───────────┬──────────────┘                     └─────────────┘
                                                                        │ OAuth2 인가 코드 교환
                                                                        ▼
                                                              ┌──────────────────────────┐
                                                              │   카카오 인증 서버          │
                                                              │   (kauth/kapi.kakao.com)  │
                                                              └──────────────────────────┘
```

| 계층 | 기술 | 역할 |
|---|---|---|
| 프론트엔드 | HTML / CSS / JS (바닐라, 프레임워크 없음) | 화면 렌더링, 사용자 입력 수집, `fetch`로 백엔드 API 호출(세션 쿠키 포함, `credentials: "include"`), 계산 로직(BMR/TDEE, MET 칼로리 등) 실행, 로그인 게이트(비로그인 시 앱 전체를 가림) |
| 백엔드 | Spring Boot 4.x (Java 17, Maven) — Web + JPA + MySQL Driver + Lombok + Security + OAuth2 Client | REST API 제공(`@RestController`), 요청 검증/위임(`Controller`), DB 접근(`Repository`, Spring Data JPA), Entity ↔ JSON 자동 변환(Jackson), 카카오 OAuth2 로그인 처리 및 세션 관리(`SecurityConfig`) |
| DB | MySQL (`health_project` 스키마) | 데이터 영구 저장. 테이블은 Hibernate가 Entity 클래스로부터 자동 생성/갱신 (`spring.jpa.hibernate.ddl-auto=update`) |

**계층 간 경계가 명확한 이유**: 프론트는 DB 존재 자체를 모르고 오직 REST API만 알고, 백엔드는 화면 구성을 모르고 오직 Entity/JSON만 다룬다. 덕분에 프론트를 나중에 다른 프레임워크로 바꾸거나, DB를 교체해도 서로에게 영향이 적다.

**로그인 흐름 요약**: 사용자가 "카카오로 로그인" 클릭 → 백엔드(`/oauth2/authorization/kakao`)가 카카오 로그인 페이지로 리다이렉트 → 로그인 성공 시 카카오가 백엔드(`/login/oauth2/code/kakao`)로 콜백 → 백엔드가 카카오 인증 서버에서 사용자 정보(고유 ID, 닉네임)를 받아와 `User` 테이블에 저장/조회 → 세션(쿠키)을 발급하고 프론트(`localhost:5500`)로 다시 리다이렉트. 이후 모든 `/api/**` 요청은 이 세션 쿠키로 로그인 여부를 판단한다.

### 계층별 실행 방법
- 프론트: 정적 파일 서버 (VS Code Live Server, `localhost:5500`)
- 백엔드: `./mvnw spring-boot:run` → 내장 톰캣이 `localhost:8080`에서 대기
- DB: Homebrew로 설치한 MySQL, `localhost:3306`

---

## 2. API 명세

공통 사항
- Base URL: `http://localhost:8080/api`
- 모든 응답은 `Content-Type: application/json;charset=UTF-8`
- CORS: `SecurityConfig`의 `CorsConfigurationSource` 빈으로 전체 경로(`/**`)에 일괄 적용 — 프론트 주소(`http://localhost:5500`)만 허용 + 세션 쿠키 전달 허용(`allowCredentials`). 로그인 세션이 쿠키 기반이라, CORS 스펙상 `allowCredentials`와 와일드카드(`*`) 출처는 함께 쓸 수 없어서 출처를 프론트 주소로 명시함. 원래는 컨트롤러마다 `@CrossOrigin`을 붙였는데, `@CrossOrigin`은 실제 `@RequestMapping` 핸들러가 있는 경로에만 적용돼서 Spring Security가 직접 처리하는 `/api/auth/logout` 같은 경로엔 CORS 헤더가 아예 안 붙는 문제가 있었음 — 빈 하나로 통일해 이 문제를 해결함
- **인증 필요**: `/api/auth/me`를 제외한 모든 `/api/**` 요청은 카카오 로그인 세션이 있어야 함(`SecurityConfig`). 로그인 안 된 상태로 호출하면 401 응답
- id는 서버가 자동 생성(`GenerationType.IDENTITY`) — 요청 바디에 넣어도 무시됨(POST 기준)
- Food/Run/Memo는 모두 `user`(로그인한 사용자) 연관관계를 가지며, 요청 바디에 넣을 필요 없이 서버가 로그인 세션에서 자동으로 채움 — 자세한 내용은 2-0 참고

### 2-0. Auth (카카오 로그인)

| 엔드포인트 | 메서드 | 설명 |
|---|---|---|
| `/oauth2/authorization/kakao` | GET (브라우저 이동) | 카카오 로그인 페이지로 리다이렉트 — 프론트에서 `<a href>`로 이동시켜야 함(`fetch` 금지, 리다이렉트를 JSON으로 파싱하려다 깨짐) |
| `/api/auth/me` | GET | 현재 로그인 상태 확인. `{"loggedIn": false}` 또는 `{"loggedIn": true, "nickname": "..."}` |
| `/api/auth/logout` | POST | 로그아웃(세션 무효화), 200만 반환 — 리다이렉트는 안 함(아래 참고) |

카카오 로그인 성공 시 서버가 `User`(고유 카카오 ID, 닉네임)를 찾거나 새로 만들고, 그 사용자의 로그인 세션을 쿠키로 발급한다. 컨트롤러는 `@AuthenticationPrincipal KakaoOAuth2User principal`로 현재 로그인한 사용자를 받는다.

> ⚠️ **로그인은 리다이렉트, 로그아웃은 리다이렉트 안 함 — 이유**: 로그인은 `<a href>`로 시작하는 실제 브라우저 이동이라 성공 후 서버가 프론트 주소로 리다이렉트해도 문제없다. 반면 로그아웃은 프론트가 `fetch`로 호출하는데, 여기서 서버가 리다이렉트를 보내면 `fetch`가 그 리다이렉트를 자동으로 따라가다 Live Server(정적 파일 서버, CORS 미지원)의 응답을 읽지 못해 `fetch` 자체가 실패해버린다(실제로 겪은 버그). 그래서 로그아웃은 200만 반환하고, 화면 전환(로그인 게이트로 복귀)은 프론트 JS가 `window.location.reload()`로 직접 처리한다.

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

> ⚠️ **소유권 검증 (PUT/DELETE)**: `id`는 순차 증가하는 값이라 다른 사용자가 URL의 id만 바꿔서 남의 기록에 접근을 시도할 수 있다. `FoodController.updateFood`/`deleteFood`는 수정·삭제 전에 기존 레코드의 `user`가 현재 로그인한 사용자와 같은지 확인하고, 다르면 403을 반환한다. 또한 PUT 요청 바디에 다른 `user` 값을 넣어 소유권 자체를 넘기는 것을 막기 위해, 검증 후 `user` 필드는 요청 바디 값을 무시하고 기존 소유자로 강제 고정한다.

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
- `user_id`는 `@ManyToOne(optional = false) @JoinColumn(name = "user_id", nullable = false)`로 선언되어 NOT NULL — 카카오 로그인 도입 시점에 기존 테스트 데이터를 모두 삭제하고 시작했기 때문에 처음부터 NOT NULL로 추가 가능했음(기존 행이 있었다면 Hibernate가 컬럼 추가 시 실패했을 것)
