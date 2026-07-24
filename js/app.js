// ===== ① 데이터 =====

// 서버 주소 (백엔드가 살아있는 곳)
// 로컬(Live Server, localhost)에서 열었으면 로컬 백엔드를, 배포(Vercel)에서 열었으면
// 배포된 Railway 백엔드를 자동으로 봄
const BACKEND_ORIGIN = window.location.hostname === "localhost"
    ? "http://localhost:8080"
    : "https://health-project-production-5204.up.railway.app";
const API_BASE = `${BACKEND_ORIGIN}/api`;

// --- 식단: 자주 먹는 음식 관련 ---
// 개발 중 테스트용으로 넣어뒀던 기본 즐겨찾기(바나나/닭가슴살/삼겹살)를 제거함 —
// 신규 사용자는 즐겨찾기가 빈 배열로 시작해야 함(localStorage에 저장된 값이 없으면 빈 배열)
const foods = JSON.parse(localStorage.getItem("foods")) || [];

// openQuickAddIndex: 롱프레스로 수정/삭제 버튼이 열려있는 카드 인덱스 (한 번에 하나만 열림)
let openQuickAddIndex = null;
let editingFoodIndex = null;

// --- 식단: 오늘 먹은 음식 관련 ---
let todayFoods = [];
let openFoodIndex = null;
let editingTodayIndex = null;

// --- 식단: 소화 타이머 관련 ---
let timerId = null;
let selectedDigest = null;

// --- 러닝 관련 ---
let runRecords = [];
let openRunIndex = null;
let editingRunIndex = null;

// 끼니(아침/점심/저녁/간식) 선택 — 새로고침하면 초기화됨(별도 저장 안 함),
// 자동 판단 없이 사용자가 매번 직접 고르게 함
let selectedMeal = null;

// --- 내 정보 관련 ---
let selectedGender = null;
let userWeight = Number(localStorage.getItem("userWeight")) || 60;
let selectedActivity = null;

// --- 컨디션 메모 관련 ---
let memoRecords = [];
let openMemoIndex = null;
let editingMemoIndex = null;
let symptomScore = 5;

// 방금 롱프레스로 열렸는지 표시(quick-add 버튼은 클릭=빠른추가 동작도 겸하고 있어서,
// 롱프레스 직후 발생하는 click을 "추가"로 오인하지 않도록 구분하는 용도)
let quickAddLongPressFired = false;

// --- 식단: 달력 뷰 관련 ---
const calendarInitDate = new Date();
let calendarYear = calendarInitDate.getFullYear();
let calendarMonth = calendarInitDate.getMonth() + 1; // getMonth()는 0부터 시작해서 +1
let calendarMarkedDates = new Set(); // 이번 화면에 떠 있는 달의 "기록 있는 날짜" 집합 (yyyy-MM-dd)
let selectedCalendarDate = null; // 달력에서 클릭해서 상세보기 중인 날짜
let calendarLoaded = false; // 달력을 한 번이라도 연 적 있는지(첫 오픈 때만 요약을 새로 불러옴)
// "이 날짜로 추가" 버튼을 눌렀을 때만 세팅됨 — 즐겨찾기 pill/러닝 저장이 이 값을 한 번 소비하고 다시 null로 되돌림
let pendingCalendarDate = null;

// --- 서버 데이터 <-> 한글 변수 이름 번역기 (fetch로 주고받을 때만 사용) ---
// 기록시각(recordedAt): 평소엔 화면에 안 보이고 서버가 현재 시각으로 채우지만, PUT으로 되돌려 보낼 때
// 값이 없으면 서버가 null로 덮어쓰지 않고 기존 값을 유지하므로 왕복 전달만 해둠. 달력의 "이 날짜로 추가"
// 흐름에서만 dateWithCurrentTime()으로 값을 채워 보내 과거 날짜로 저장함
function toServerFood(f) { return { name: f.이름, calorie: f.칼로리, digestTime: f.소화시간, isTrigger: f.트리거 || false, meal: f.끼니 || null, quantity: f.수량, recordedAt: f.기록시각 || null, fatGrams: f.지방 ?? null }; }
function fromServerFood(sf) { return { id: sf.id, 이름: sf.name, 칼로리: sf.calorie, 소화시간: sf.digestTime, 트리거: sf.isTrigger, 끼니: sf.meal, 수량: sf.quantity, 기록시각: sf.recordedAt, 지방: sf.fatGrams }; }

function toServerRun(r) { return { distance: r.거리, time: r.시간, heartRate: r.심박수, speedKmh: r.시속, calorieBurned: r.칼로리, recordedAt: r.기록시각 || null }; }
function fromServerRun(sr) { return { id: sr.id, 거리: sr.distance, 시간: sr.time, 심박수: sr.heartRate, 시속: sr.speedKmh, 칼로리: sr.calorieBurned, 기록시각: sr.recordedAt }; }

// symptomScore는 화면 입력칸이 아직 없어서 0으로 고정 전송 (나중에 인사이트 기능에서 실제 값 연결 예정)
function toServerMemo(m) { return { date: m.날짜, content: m.내용, symptomScore: m.증상점수 || 0 }; }
function fromServerMemo(sm) { return { id: sm.id, 날짜: sm.date, 내용: sm.content, 증상점수: sm.symptomScore }; }

// ===== ② HTML 요소 찾아오기 =====

const loadingScreen = document.getElementById("loading-screen");
const loginGate = document.getElementById("login-gate");
const appShell = document.getElementById("app-shell");
const loginNickname = document.getElementById("login-nickname");
const logoutBtn = document.getElementById("logout-btn");
const kakaoLoginLink = document.getElementById("kakao-login-link");

const quickAddList = document.getElementById("quick-add-list");
const foodList = document.getElementById("food-list");
const mealCompleteBtn = document.getElementById("meal-complete-btn");
const addFoodBtn = document.getElementById("add-food-btn");
const digestButtons = document.querySelectorAll(".digest-btn");
const digestCancelBtn = document.getElementById("digest-cancel-btn");
const foodDateTargetBanner = document.getElementById("food-date-target-banner");
const foodDateTargetCloseBtn = document.getElementById("food-date-target-close-btn");
const mealButtons = document.querySelectorAll(".meal-btn");
const mealButtonsRow = document.getElementById("meal-buttons");

const foodSearchInput = document.getElementById("food-search-input");
const foodSearchBtn = document.getElementById("food-search-btn");
const foodSearchResults = document.getElementById("food-search-results");

const dietCalendarToggleBtn = document.getElementById("diet-calendar-toggle-btn");
const dietCalendarBox = document.getElementById("diet-calendar-box");
const calendarPrevBtn = document.getElementById("calendar-prev-btn");
const calendarNextBtn = document.getElementById("calendar-next-btn");
const calendarMonthLabel = document.getElementById("calendar-month-label");
const calendarGrid = document.getElementById("calendar-grid");
const calendarDetailBox = document.getElementById("calendar-detail-box");
const calendarDetailDate = document.getElementById("calendar-detail-date");
const calendarDetailContent = document.getElementById("calendar-detail-content");
const calendarAddFoodBtn = document.getElementById("calendar-add-food-btn");
const calendarAddRunBtn = document.getElementById("calendar-add-run-btn");
const calendarAddMemoBtn = document.getElementById("calendar-add-memo-btn");

const runList = document.getElementById("run-list");
const runSaveBtn = document.getElementById("run-save-btn");
const runDateTargetBanner = document.getElementById("run-date-target-banner");

const genderButtons = document.querySelectorAll(".gender-btn");
const infoSaveBtn = document.getElementById("info-save-btn");
const activityButtons = document.querySelectorAll(".activity-btn");

const memoInput = document.getElementById("condition-memo-input");
const memoSaveBtn = document.getElementById("memo-save-btn");
const memoDateTargetBanner = document.getElementById("memo-date-target-banner");
const memoList = document.getElementById("memo-list");
const symptomScoreSlider = document.getElementById("symptom-score-slider");
const symptomScoreDisplay = document.getElementById("symptom-score-display");
const symptomScoreInput = document.getElementById("symptom-score-input");
const symptomInsightContent = document.getElementById("symptom-insight-content");
const homeCalorieGaugeTrack = document.getElementById("home-calorie-gauge-track");
const homeCalorieGuide = document.getElementById("home-calorie-guide");
// ===== ③ 함수 정의 =====

// --- 로그인 관련 함수 ---

// 로그인 상태 확인 — 응답 오기 전까진 loading-screen만 보이는 상태(기본값)라 login-gate가
// "잠깐 보였다 사라지는" 깜빡임이 없음. 응답이 오면 결과에 맞는 화면만 보여줌
async function checkLoginState() {
    // /auth/me는 SecurityConfig에서 permitAll이라 401이 나지 않는 별개 성격의 호출이라 apiFetch를 쓰지 않음
    const response = await fetch(`${API_BASE}/auth/me`, { credentials: "include" });
    const data = await response.json();

    loadingScreen.style.display = "none";

    if (data.loggedIn) {
        loginNickname.textContent = `${data.nickname}님`;
        appShell.style.display = "block";
    } else {
        loginGate.style.display = "flex";
    }

    return data.loggedIn;
}

// 세션 만료 시 공통 처리 — 조용히 실패해서 사용자가 "왜 안 되지" 하다 직접 새로고침해야만
// 알게 되던 문제를 없애기 위해, 안내와 함께 그 자리에서 바로 로그인 게이트로 전환함
function handleSessionExpired() {
    alert("로그인이 만료되었습니다. 다시 로그인해주세요.");
    appShell.style.display = "none";
    loginGate.style.display = "flex";
}

// 인증이 필요한 API 호출 전용 fetch 래퍼 — 응답이 401이면 매 호출부마다 따로 체크하지 않고
// 여기서 한 번에 세션 만료 처리를 하고, 호출부가 이어서 response.json() 등을 실행하지 않도록
// 에러를 던져서 그 자리에서 멈춤(별도 try/catch 없이도 각 이벤트 핸들러가 자연스럽게 중단됨)
async function apiFetch(url, options) {
    const response = await fetch(url, { credentials: "include", ...options });
    if (response.status === 401) {
        handleSessionExpired();
        throw new Error("세션 만료로 요청 중단: " + url);
    }
    return response;
}

// --- 편집 UX 공용 헬퍼 (식단/러닝/메모 4개 목록에서 재사용) ---

// 요소를 500ms 이상 누르고 있으면 콜백 실행 (수정/삭제 버튼 노출용 롱프레스)
function attachLongPress(el, callback) {
    let timer = null;
    el.addEventListener("mousedown", function () {
        timer = setTimeout(callback, 500);
    });
    el.addEventListener("mouseup", function () { clearTimeout(timer); });
    el.addEventListener("mouseleave", function () { clearTimeout(timer); });
}

// "2026. 7. 17." 같은 기존 한국어 날짜 포맷이나 "2026-07-17"(+시간) 같은 ISO 포맷을 모두
// <input type="date">가 요구하는 "YYYY-MM-DD"로 통일해서 돌려줌. 못 알아보는 값이면 빈 문자열.
// (러닝의 recordedAt처럼 ISO datetime 문자열에서 날짜 부분만 뽑을 때도 재사용)
function toDateInputValue(dateStr) {
    if (!dateStr) return "";
    const isoMatch = dateStr.match(/^(\d{4})-(\d{2})-(\d{2})/);
    if (isoMatch) return isoMatch[0];
    const krMatch = dateStr.match(/(\d{4})\D+(\d{1,2})\D+(\d{1,2})/);
    if (krMatch) {
        return `${krMatch[1]}-${krMatch[2].padStart(2, "0")}-${krMatch[3].padStart(2, "0")}`;
    }
    return "";
}

// 오늘 날짜를 로컬 기준 "YYYY-MM-DD"로 (toISOString은 UTC라 자정 근처에 날짜가 밀릴 수 있어 직접 조합)
function todayDateString() {
    const now = new Date();
    return `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}-${String(now.getDate()).padStart(2, "0")}`;
}

// 화면을 계속 켜놓은 채 자정을 넘기면 loadTodayFoods()를 다시 부르지 않는 한 어제 기준으로 남아있음 —
// 1분마다 날짜가 바뀌었는지 확인해서, 바뀌었으면 "오늘 먹은 음식"을 새 날짜 기준으로 다시 불러옴
let lastKnownDateStr = todayDateString();
function startMidnightWatcher() {
    setInterval(function () {
        const currentDateStr = todayDateString();
        if (currentDateStr !== lastKnownDateStr) {
            lastKnownDateStr = currentDateStr;
            loadTodayFoods();
        }
    }, 60000);
}

// recordedAt(ISO datetime)의 날짜 부분만 새 값으로 바꾸고 기존 시:분:초는 유지
function withUpdatedDate(recordedAt, newDateStr) {
    const timePart = recordedAt ? recordedAt.slice(10) : "T00:00:00";
    return newDateStr + timePart;
}

// 오늘로부터 n일 전 날짜를 로컬 기준 "YYYY-MM-DD"로 (todayDateString과 동일한 방식, 타임존 안전)
function dateStringDaysAgo(n) {
    const d = new Date();
    d.setDate(d.getDate() - n);
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}

// 롱프레스로 열린 카드 바깥을 클릭하면 자동으로 닫기
// container.children[openIndex]가 "지금 열려있는 그 카드"인 이유: render 함수가 매번
// 데이터 배열 순서대로 카드를 하나씩 append하므로 인덱스와 DOM 자식 순번이 항상 1:1로 일치함
function closeIfOutside(container, openIndex, setOpenIndex, renderFn, e) {
    if (openIndex === null) return;
    const openCard = container.children[openIndex];
    if (openCard && !openCard.contains(e.target)) {
        setOpenIndex(null);
        renderFn();
    }
}

// 끼니 선택 pill 바깥을 클릭하면 선택 표시 해제 (위 closeIfOutside와 같은 패턴).
// 단, 즐겨찾기 음식 pill(quickAddList) 클릭은 "바깥"으로 치지 않음 — 그렇게 치면
// 즐겨찾기로 음식을 추가할 때마다 끼니를 매번 다시 선택해야 해서 연속 추가가 안 됨
function clearMealIfOutside(e) {
    if (selectedMeal === null) return;
    if (mealButtonsRow.contains(e.target) || quickAddList.contains(e.target)) return;
    selectedMeal = null;
    mealButtons.forEach(function (b) {
        b.classList.remove("selected");
    });
}

// --- 식단 관련 함수 ---
// 자주 먹는 음식 빠른 추가 버튼 다시 그리기
function renderQuickAddList() {
    quickAddList.innerHTML = "";

    if (foods.length === 0) {
        quickAddList.innerHTML = `<div class="search-empty">아직 즐겨찾기한 음식이 없어요 — 검색이나 직접 추가 후 "즐겨찾기" 버튼을 눌러보세요</div>`;
        return;
    }

    foods.forEach(function (food, index) {
        const card = document.createElement("div");
        card.className = "food-card";

        if (editingFoodIndex === index) {
            // 수정 모드 (이 항목만)
            card.innerHTML = `
                <input type="text" class="inp edit-fname-input" value="${food.이름}">
                <input type="number" class="inp edit-fcalorie-input" value="${food.칼로리}">
                <button type="button" class="btn-save-small">저장</button>
                <button type="button" class="btn-cancel-small">취소</button>
            `;
            quickAddList.appendChild(card);

            card.querySelector(".btn-save-small").addEventListener("click", function () {
                const newName = card.querySelector(".edit-fname-input").value;
                const newCalorie = Number(card.querySelector(".edit-fcalorie-input").value);
                foods[index].이름 = newName;
                foods[index].칼로리 = newCalorie;
                saveFoods();
                editingFoodIndex = null;
                renderQuickAddList();
            });

            card.querySelector(".btn-cancel-small").addEventListener("click", function () {
                editingFoodIndex = null;
                renderQuickAddList();
            });

        } else if (openQuickAddIndex === index) {
            // 롱프레스로 열린 상태: 수정/삭제 버튼 노출
            card.innerHTML = `
                <span class="food-text">${food.이름} - ${food.칼로리} kcal</span>
                <button type="button" class="btn-edit-item">수정</button>
                <button type="button" class="btn-delete-item">삭제</button>
            `;
            quickAddList.appendChild(card);

            card.querySelector(".btn-edit-item").addEventListener("click", function () {
                editingFoodIndex = index;
                openQuickAddIndex = null;
                renderQuickAddList();
            });

            card.querySelector(".btn-delete-item").addEventListener("click", function () {
                foods.splice(index, 1);
                saveFoods();
                openQuickAddIndex = null;
                renderQuickAddList();
            });

        } else {
            // 평소 모드: 클릭하면 오늘 먹은 음식으로 추가, 500ms 이상 누르면 수정/삭제 버튼 노출
            const btn = document.createElement("button");
            btn.textContent = food.이름;
            quickAddList.appendChild(btn);

            attachLongPress(btn, function () {
                quickAddLongPressFired = true;
                openQuickAddIndex = index;
                renderQuickAddList();
            });

            btn.addEventListener("click", async function () {
                // 롱프레스 직후에 이어서 발생하는 click은 "빠른 추가"가 아니라 롱프레스 제스처의 일부이므로 무시
                if (quickAddLongPressFired) {
                    quickAddLongPressFired = false;
                    return;
                }

                await addFoodRecordToToday(food);
            });
        }
    });
}

function saveFoods() {
    localStorage.setItem("foods", JSON.stringify(foods));
}

// 즐겨찾기 pill 클릭과 검색결과 "추가" 버튼이 공유하는 로직 — 끼니 선택 확인 후
// 서버에 POST하고, 서버의 중복 합치기 응답(quantity 누적)을 오늘 목록에 반영함
async function addFoodRecordToToday(food) {
    // 낮밤이 바뀌거나 늦게 일어나는 사람 등 변수가 많아 자동 판단 대신 항상 직접 선택하게 함
    if (selectedMeal === null) {
        alert("끼니를 먼저 선택해주세요!");
        return;
    }

    // 달력에서 "이 날짜로 음식 추가"를 눌러둔 상태면 그 날짜로, 아니면 평소처럼 서버가 현재 시각으로 저장
    const foodToSave = { ...food, 끼니: selectedMeal };
    if (pendingCalendarDate) {
        foodToSave.기록시각 = dateWithCurrentTime(pendingCalendarDate);
    }

    const response = await apiFetch(`${API_BASE}/foods`, {
        method: "POST",
        credentials: "include",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(toServerFood(foodToSave))
    });
    const saved = await response.json();
    const savedFood = fromServerFood(saved);
    // 서버가 같은 날짜·끼니의 기존 항목에 합쳐서 응답한 경우 같은 id가 이미 배열에 있으므로,
    // 그대로 push하면 화면에 중복으로 보임 — 있으면 교체, 없으면 새로 추가
    const existingIndex = todayFoods.findIndex(function (f) { return f.id === savedFood.id; });
    if (existingIndex >= 0) {
        todayFoods[existingIndex] = savedFood;
    } else {
        todayFoods.push(savedFood);
    }
    renderFoodList();

    // pendingCalendarDate는 배너 닫기 버튼이나 달력을 닫을 때까지 유지 —
    // 즐겨찾기를 연달아 눌러도 매번 "이 날짜로 추가"를 다시 누를 필요 없게 함
    if (pendingCalendarDate) {
        loadCalendarSummary(calendarYear, calendarMonth);
        if (selectedCalendarDate === pendingCalendarDate) loadCalendarDetail(pendingCalendarDate);
    }
}

// 식약처 API가 준 실제 지방(g)을 소화시간 카테고리(2/3/4)로 자동 변환 — 검색으로 추가한 음식은
// 사용자가 🟢🟡🔴을 직접 고르지 않고 이 값으로 채워짐. API에 지방 정보가 없는 항목은 "보통(3)"으로 기본 처리
function fatGramsToDigestCategory(fatGrams) {
    if (fatGrams === null || fatGrams === undefined || Number.isNaN(fatGrams)) return 3;
    if (fatGrams < 10) return 2;
    if (fatGrams <= 25) return 3;
    return 4;
}

// 위 함수의 반대 방향 근사값 — 지방 실측값(food.지방)이 없을 때만 쓰는 대체 로직.
// 즐겨찾기 수동 등록 등 정확한 그램수를 모르는 음식은 카테고리만 있으므로, 끼니 단위로
// 합산할 때(mealCompleteBtn 참고) 각 카테고리를 대표하는 지방값으로 되돌려 더함
// (5g=가벼움 대표, 15g=보통 대표, 30g=무거움 대표 — 아래 10g/25g 기준 버킷 안에 들어오도록 고름)
function digestCategoryToRepresentativeFat(category) {
    const n = Number(category);
    if (n <= 2) return 5;
    if (n === 3) return 15;
    return 30;
}

// 음식 검색 — 식약처 식품영양성분DB를 프록시하는 백엔드(/api/food-search)를 거쳐서 호출
// (프론트가 식약처 API를 직접 호출하지 않는 이유는 인증키를 프론트에 노출시키지 않기 위함)
async function searchFoodApi(keyword) {
    if (!keyword || !keyword.trim()) return;
    const response = await apiFetch(`${API_BASE}/food-search?keyword=${encodeURIComponent(keyword.trim())}`, {
        credentials: "include"
    });
    const results = await response.json();
    renderFoodSearchResults(results);
}

// 검색 결과 목록 렌더링 — 항목마다 "오늘 기록에 추가"(즐겨찾기 pill과 동일한 addFoodRecordToToday 재사용)
// / "즐겨찾기 등록"(foods 배열에 push, 다음부턴 검색 없이 pill로 원터치 가능) 버튼을 둠
function renderFoodSearchResults(results) {
    foodSearchResults.innerHTML = "";

    if (results.length === 0) {
        foodSearchResults.innerHTML = `<div class="search-empty">검색 결과가 없어요</div>`;
        return;
    }

    results.forEach(function (result) {
        const row = document.createElement("div");
        row.className = "search-result-row";
        row.innerHTML = `
            <div class="search-result-info">
                <span class="search-result-name">${result.name}</span>
                <span class="search-result-kcal">${result.calorie ?? "?"} kcal (1인분 기준)</span>
            </div>
            <div class="search-result-actions">
                <button type="button" class="btn-add-small">➕ 추가</button>
                <button type="button" class="btn-fav-small">⭐ 즐겨찾기</button>
            </div>
        `;

        row.querySelector(".btn-add-small").addEventListener("click", async function () {
            const digestCategory = fatGramsToDigestCategory(result.fat);
            await addFoodRecordToToday({ 이름: result.name, 칼로리: result.calorie || 0, 소화시간: digestCategory, 트리거: false, 지방: result.fat });
        });

        row.querySelector(".btn-fav-small").addEventListener("click", function () {
            const digestCategory = fatGramsToDigestCategory(result.fat);
            // 검색 결과를 즐겨찾기로 등록해도 출처는 API이므로 정확한 지방값을 계속 들고 다니게 함
            // (나중에 이 pill을 눌러 오늘 기록에 추가할 때도 근사치가 아니라 정확치가 이어짐)
            foods.push({ 이름: result.name, 칼로리: result.calorie || 0, 소화시간: digestCategory, 트리거: false, 지방: result.fat });
            saveFoods();
            renderQuickAddList();
        });

        foodSearchResults.appendChild(row);
    });
}

// 서버에서 "오늘"에 해당하는 음식 목록만 가져오기
// (?date= 없이 호출하면 백엔드가 전체 기간을 다 돌려주므로, 반드시 오늘 날짜로 필터링해야 함 —
// 안 그러면 자정이 지나도 어제 이전 기록까지 계속 "오늘"에 섞여 누적됨)
async function loadTodayFoods() {
    const response = await apiFetch(`${API_BASE}/foods?date=${todayDateString()}`, { credentials: "include" });
    const serverFoods = await response.json();
    todayFoods.length = 0;
    serverFoods.forEach(function (sf) {
        todayFoods.push(fromServerFood(sf));
    });
    renderFoodList();
}

// 음식 카드 한 장을 그리는 함수 — index는 todayFoods 배열의 실제 인덱스여야 함
// (수정/삭제/롱프레스가 전부 이 인덱스를 기준으로 todayFoods를 직접 참조하기 때문에,
// 끼니별로 섹션을 나눠 그려도 이 인덱스만큼은 원래 배열 위치 그대로 넘겨야 함)
function renderFoodCard(food, index) {
        const card = document.createElement("div");
        card.className = "food-card";

        if (editingTodayIndex === index) {
            // 수정 모드 화면 (이 항목만)
            card.innerHTML = `
                <input type="text" class="inp edit-name-input" value="${food.이름}">
                <input type="number" class="inp edit-calorie-input" value="${food.칼로리}">
                <button type="button" class="btn-save-small">저장</button>
                <button type="button" class="btn-cancel-small">취소</button>
            `;
            foodList.appendChild(card);

            card.querySelector(".btn-save-small").addEventListener("click", async function () {
                const newName = card.querySelector(".edit-name-input").value;
                const newCalorie = Number(card.querySelector(".edit-calorie-input").value);
                const updated = { ...todayFoods[index], 이름: newName, 칼로리: newCalorie };

                const response = await apiFetch(`${API_BASE}/foods/${updated.id}`, {
                    method: "PUT",
                    credentials: "include",
                    headers: { "Content-Type": "application/json" },
                    body: JSON.stringify(toServerFood(updated))
                });
                const saved = await response.json();
                todayFoods[index] = fromServerFood(saved);

                editingTodayIndex = null;
                renderFoodList();
            });

            card.querySelector(".btn-cancel-small").addEventListener("click", function () {
                editingTodayIndex = null;
                renderFoodList();
            });

        } else if (openFoodIndex === index) {
            // 롱프레스로 열린 상태: 수정/삭제 버튼 노출
            const triggerTag = food.트리거 ? ` <span class="trigger-tag">⚠️ 트리거</span>` : "";
            const qtyTag = food.수량 > 1 ? ` x${food.수량}` : "";
            card.innerHTML = `<span class="food-text">${food.이름}${qtyTag} - ${food.칼로리} kcal${triggerTag}</span>`;

            const editBtn = document.createElement("button");
            editBtn.textContent = "수정";
            editBtn.className = "btn-edit-item";
            card.appendChild(editBtn);

            const deleteBtn = document.createElement("button");
            deleteBtn.textContent = "삭제";
            deleteBtn.className = "btn-delete-item";
            card.appendChild(deleteBtn);

            foodList.appendChild(card);

            editBtn.addEventListener("click", function () {
                editingTodayIndex = index;
                openFoodIndex = null;
                renderFoodList();
            });

            deleteBtn.addEventListener("click", async function () {
                await apiFetch(`${API_BASE}/foods/${todayFoods[index].id}`, { method: "DELETE", credentials: "include" });
                todayFoods.splice(index, 1);
                openFoodIndex = null;
                renderFoodList();
            });

        } else {
            // 평소 모드: 500ms 이상 누르면 수정/삭제 버튼 노출
            const triggerTag = food.트리거 ? ` <span class="trigger-tag">⚠️ 트리거</span>` : "";
            const qtyTag = food.수량 > 1 ? ` x${food.수량}` : "";
            card.innerHTML = `<span class="food-text">${food.이름}${qtyTag} - ${food.칼로리} kcal${triggerTag}</span>`;
            foodList.appendChild(card);

            attachLongPress(card, function () {
                openFoodIndex = index;
                renderFoodList();
            });
        }
}

// 오늘 먹은 음식 목록 + 총 칼로리를 화면에 그리는 함수 — 아침/점심/저녁/간식 섹션으로 나눠서 표시
// (자동 판단 없이 사용자가 고른 끼니 기준. 끼니 정보가 없는 과거 기록은 "기타"로 묶어서 안 보이게 두지 않음)
function renderFoodList() {
    foodList.innerHTML = "";
    let total = 0;

    const mealGroups = [
        { key: "breakfast", label: "🌅 아침" },
        { key: "lunch", label: "🍚 점심" },
        { key: "dinner", label: "🌙 저녁" },
        { key: "snack", label: "🍪 간식" },
        { key: null, label: "🍽️ 기타" }
    ];

    mealGroups.forEach(function (group) {
        // 편집/롱프레스/삭제가 todayFoods의 실제 인덱스를 기준으로 동작하므로,
        // 그룹으로 나눌 때도 인덱스를 그대로 들고 다님(값만 골라내지 않음)
        const indexesInGroup = [];
        todayFoods.forEach(function (food, index) {
            if ((food.끼니 || null) === group.key) {
                indexesInGroup.push(index);
            }
        });
        if (indexesInGroup.length === 0) return;

        const sectionLabel = document.createElement("div");
        sectionLabel.className = "sec-lbl meal-section-label";
        sectionLabel.textContent = group.label;
        foodList.appendChild(sectionLabel);

        indexesInGroup.forEach(function (index) {
            const food = todayFoods[index];
            total += food.칼로리;
            renderFoodCard(food, index);
        });
    });

    document.getElementById("total-calorie").textContent = `오늘 총 섭취: ${total} kcal`;
    const goalCalorie = localStorage.getItem("tdee");
    if (goalCalorie) {
        document.getElementById("home-calorie-value").textContent = `${total} / ${goalCalorie} kcal`;
        const calPercent = Math.min((total / Number(goalCalorie)) * 100, 100);
        document.getElementById("home-calorie-gauge-fill").style.width = `${calPercent}%`;
        homeCalorieGaugeTrack.style.display = "block";
        homeCalorieGuide.style.display = "none";
    }
    else {
        document.getElementById("home-calorie-value").textContent = `${total} kcal`;
        homeCalorieGaugeTrack.style.display = "none";
        homeCalorieGuide.style.display = "block";
    }

    renderSymptomInsight();
}

//소화 타이머 시작(또는 재개) - 넘겨받은 초부터 카운트다운
function startDigestTimer(startSeconds, endTime, totalSeconds) {
    let remainingSeconds = startSeconds;

    if (timerId !== null) {
        clearInterval(timerId);
    }

    timerId = setInterval(function () {
        remainingSeconds -= 1;

        if (remainingSeconds < 0) {
            remainingSeconds = 0;
        }

        const hours = Math.floor(remainingSeconds / 3600);
        const minutes = Math.floor((remainingSeconds % 3600) / 60);
        const seconds = remainingSeconds % 60;

        const hh = String(hours).padStart(2, '0');
        const mm = String(minutes).padStart(2, '0');
        const ss = String(seconds).padStart(2, '0');

        document.getElementById("digest-timer").textContent = `${hh}:${mm}:${ss}`;
        document.getElementById("home-digest-timer").textContent = `${hh}:${mm}:${ss}`;

        const percent = totalSeconds > 0 ? ((totalSeconds - remainingSeconds) / totalSeconds) * 100 : 100;
        document.getElementById("digest-gauge-fill").style.width = `${percent}%`;
        document.getElementById("home-digest-gauge-fill").style.width = `${percent}%`;

        const endTimeDisplay = new Date(endTime).toLocaleTimeString('ko-KR', { hour: '2-digit', minute: '2-digit' });
        document.getElementById("digest-end-time").textContent = `${endTimeDisplay}에 완료`;
        document.getElementById("home-digest-end-time").textContent = `${endTimeDisplay}에 완료`;

        if (remainingSeconds <= 0) {
            clearInterval(timerId);
            localStorage.removeItem("digestEndTime");
            document.getElementById("digest-warning").textContent = "소화 완료! 이제 누우셔도 됩니다!";
            document.getElementById("home-digest-warning").textContent = "소화 완료! 이제 누우셔도 됩니다!";
        }
        else {
            document.getElementById("digest-warning").textContent = "🙅‍♀️ 아직 눕지 마세요!";
            document.getElementById("home-digest-warning").textContent = "🙅‍♀️ 아직 눕지 마세요!";
        }
    }, 1000);
}

// --- 식단: 달력 뷰 관련 함수 ---

// "YYYY-MM-DD" 날짜만 있는 값에 지금 시:분:초를 붙여 LocalDateTime과 호환되는 문자열로 만듦
// (withUpdatedDate()는 기존 recordedAt의 시간을 유지하며 날짜만 바꾸는 용도였다면,
// 이건 아예 새로 기록을 남길 때 recordedAt 전체를 만드는 용도의 자매 함수)
function dateWithCurrentTime(dateStr) {
    const now = new Date();
    const hh = String(now.getHours()).padStart(2, "0");
    const mm = String(now.getMinutes()).padStart(2, "0");
    const ss = String(now.getSeconds()).padStart(2, "0");
    return `${dateStr}T${hh}:${mm}:${ss}`;
}

// "이 날짜로 추가" 버튼을 누른 순간의 상태 — 즐겨찾기 pill 클릭이나 러닝 저장이
// 이 값을 한 번 읽어서 recordedAt으로 쓰고, 저장 성공 후 clearPendingCalendarDate()로 되돌림
// (단, 음식 배너는 닫기 버튼을 누르기 전까지 유지 — renderQuickAddList의 pill 클릭 핸들러 참고)
function setPendingCalendarDate(dateStr, bannerEl) {
    pendingCalendarDate = dateStr;
    foodDateTargetBanner.style.display = "none";
    runDateTargetBanner.style.display = "none";
    memoDateTargetBanner.style.display = "none";
    // 음식 배너는 텍스트 옆에 닫기 버튼이 같이 있어서, textContent를 통째로 덮어쓰면 버튼이 지워짐 —
    // .banner-text 자식이 있으면 거기에만 쓰고, 없으면(러닝/메모 배너) 기존처럼 그대로 씀
    const textTarget = bannerEl.querySelector(".banner-text") || bannerEl;
    textTarget.textContent = `📅 ${dateStr}로 저장됩니다`;
    // .date-target-banner는 CSS에서 display:flex(텍스트+닫기 버튼 가로 배치)이므로 "block"이 아니라 "flex"로 보여줘야 함
    bannerEl.style.display = "flex";
}

function clearPendingCalendarDate() {
    pendingCalendarDate = null;
    foodDateTargetBanner.style.display = "none";
    runDateTargetBanner.style.display = "none";
    memoDateTargetBanner.style.display = "none";
}

// 서버에서 해당 월의 "기록 있는 날짜" 목록을 받아와 달력을 다시 그림
async function loadCalendarSummary(year, month) {
    const response = await apiFetch(`${API_BASE}/records/summary?year=${year}&month=${month}`, { credentials: "include" });
    const dates = await response.json();
    calendarMarkedDates = new Set(dates);
    renderCalendar();
}

// 달력 그리드 그리기 — 1일의 요일만큼 빈 칸을 먼저 채우고, 그 뒤로 날짜 칸을 이어서 그림
function renderCalendar() {
    calendarMonthLabel.textContent = `${calendarYear}년 ${calendarMonth}월`;
    calendarGrid.innerHTML = "";

    const firstWeekday = new Date(calendarYear, calendarMonth - 1, 1).getDay();
    const daysInMonth = new Date(calendarYear, calendarMonth, 0).getDate();
    const todayStr = todayDateString();

    for (let i = 0; i < firstWeekday; i++) {
        const empty = document.createElement("div");
        empty.className = "calendar-cell empty";
        calendarGrid.appendChild(empty);
    }

    for (let day = 1; day <= daysInMonth; day++) {
        const dateStr = `${calendarYear}-${String(calendarMonth).padStart(2, "0")}-${String(day).padStart(2, "0")}`;
        const cell = document.createElement("div");
        cell.className = "calendar-cell";
        if (dateStr === todayStr) cell.classList.add("today");
        if (dateStr === selectedCalendarDate) cell.classList.add("selected");

        const dot = calendarMarkedDates.has(dateStr) ? `<span class="cal-dot"></span>` : "";
        cell.innerHTML = `<span>${day}</span>${dot}`;

        cell.addEventListener("click", function () {
            clearPendingCalendarDate(); // 다른 날짜를 고르면 이전에 눌러둔 "이 날짜로 추가" 상태는 무효화
            selectedCalendarDate = dateStr;
            renderCalendar();
            loadCalendarDetail(dateStr);
        });

        calendarGrid.appendChild(cell);
    }
}

// 선택한 날짜의 음식/러닝/메모를 병렬로 불러와 상세 카드에 요약해서 보여줌
async function loadCalendarDetail(dateStr) {
    calendarDetailBox.style.display = "block";
    calendarDetailDate.textContent = `${dateStr} 기록`;
    calendarDetailContent.innerHTML = "불러오는 중...";

    const [foodRes, runRes, memoRes] = await Promise.all([
        apiFetch(`${API_BASE}/foods?date=${dateStr}`, { credentials: "include" }),
        apiFetch(`${API_BASE}/runs?date=${dateStr}`, { credentials: "include" }),
        apiFetch(`${API_BASE}/memos?date=${dateStr}`, { credentials: "include" })
    ]);
    const dayFoods = (await foodRes.json()).map(fromServerFood);
    const dayRuns = (await runRes.json()).map(fromServerRun);
    const dayMemos = (await memoRes.json()).map(fromServerMemo);

    if (dayFoods.length === 0 && dayRuns.length === 0 && dayMemos.length === 0) {
        calendarDetailContent.innerHTML = `<div class="insight-sub">이 날짜엔 기록이 없어요.</div>`;
        return;
    }

    let html = "";
    if (dayFoods.length > 0) {
        const totalCal = dayFoods.reduce(function (sum, f) { return sum + f.칼로리; }, 0);
        html += `<div class="insight-sub">🍽 식단 (총 ${totalCal}kcal)</div>`;
        html += dayFoods.map(function (f) {
            const tag = f.트리거 ? ` <span class="trigger-tag">⚠️ 트리거</span>` : "";
            return `<div class="insight-food-row"><span>${f.이름}</span><span>${f.칼로리}kcal${tag}</span></div>`;
        }).join("");
    }
    if (dayRuns.length > 0) {
        html += `<div class="insight-sub">🏃 러닝</div>`;
        html += dayRuns.map(function (r) {
            return `<div class="insight-food-row"><span>${r.거리}km</span><span>${r.칼로리.toFixed(0)}kcal</span></div>`;
        }).join("");
    }
    if (dayMemos.length > 0) {
        html += `<div class="insight-sub">📝 컨디션 메모</div>`;
        html += dayMemos.map(function (m) {
            return `<div class="insight-food-row"><span>증상 ${m.증상점수}/10</span><span>${m.내용}</span></div>`;
        }).join("");
    }
    calendarDetailContent.innerHTML = html;
}

// --- 러닝 관련 함수 ---

// 서버에서 러닝 기록 목록 통째로 가져오기
async function loadRunRecords() {
    const response = await apiFetch(`${API_BASE}/runs`, { credentials: "include" });
    const serverRuns = await response.json();
    runRecords.length = 0;
    serverRuns.forEach(function (sr) {
        runRecords.push(fromServerRun(sr));
    });
    renderRunList();
}

//러닝 기록 목록 화면에 그리는 함수
function renderRunList() {
    runList.innerHTML = "";

    runRecords.forEach(function (record, index) {

        const totalMin = Math.floor(record.시간);
        const totalSec = Math.round((record.시간 - totalMin) * 60);
        const timeDisplay = totalSec > 0 ? `${totalMin}분 ${totalSec}초` : `${totalMin}분`;

        const paceTotalSec = Math.round((record.시간 / record.거리) * 60);
        const paceMin = Math.floor(paceTotalSec / 60);
        const paceSec = paceTotalSec % 60;
        const paceDisplay = `${paceMin}'${String(paceSec).padStart(2, '0')}"`;

        const card = document.createElement("div");

        if (editingRunIndex === index) {
            // 수정 모드 (이 항목만) — mm:ss 입력칸엔 기존 값을 다시 채워둠
            card.innerHTML = `
                <input type="number" class="inp edit-distance-input" value="${record.거리}" step="0.01">
                <input type="text" class="inp edit-time-input" value="${totalMin}:${String(totalSec).padStart(2, '0')}">
                <input type="number" class="inp edit-heartrate-input" value="${record.심박수}">
                <input type="date" class="inp edit-run-date-input" value="${toDateInputValue(record.기록시각)}">
                <button type="button" class="btn-save-small">저장</button>
                <button type="button" class="btn-cancel-small">취소</button>
            `;
            runList.appendChild(card);

            card.querySelector(".btn-save-small").addEventListener("click", async function () {
                if (!card.querySelector(".edit-distance-input").value) {
                    alert("거리를 입력해주세요!");
                    return;
                }
                if (!card.querySelector(".edit-time-input").value) {
                    alert("시간을 입력해주세요!");
                    return;
                }
                if (!card.querySelector(".edit-heartrate-input").value) {
                    alert("심박수를 입력해주세요!");
                    return;
                }
                if (!card.querySelector(".edit-run-date-input").value) {
                    alert("날짜를 선택해주세요!");
                    return;
                }

                const newDistance = Number(card.querySelector(".edit-distance-input").value);

                const newTimeValue = card.querySelector(".edit-time-input").value;
                const newTimeParts = newTimeValue.split(":");
                const newMinutes = Number(newTimeParts[0]);
                const newSeconds = Number(newTimeParts[1]) || 0;
                const newTotalMinutes = newMinutes + (newSeconds / 60);

                const newHeartrate = Number(card.querySelector(".edit-heartrate-input").value);
                const newDate = card.querySelector(".edit-run-date-input").value;

                const editError = validateRunInput(newDistance, newTotalMinutes, newHeartrate);
                if (editError) {
                    alert(editError);
                    return;
                }

                const newStats = calculateRunStats(newDistance, newTotalMinutes);

                const updated = {
                    ...runRecords[index],
                    거리: newDistance,
                    시간: newTotalMinutes,
                    심박수: newHeartrate,
                    시속: newStats.speedKmh,
                    칼로리: newStats.caloriesBurned,
                    기록시각: withUpdatedDate(record.기록시각, newDate)
                };

                const response = await apiFetch(`${API_BASE}/runs/${updated.id}`, {
                    method: "PUT",
                    credentials: "include",
                    headers: { "Content-Type": "application/json" },
                    body: JSON.stringify(toServerRun(updated))
                });
                const saved = await response.json();
                runRecords[index] = fromServerRun(saved);

                editingRunIndex = null;
                renderRunList();
            });

            card.querySelector(".btn-cancel-small").addEventListener("click", function () {
                editingRunIndex = null;
                renderRunList();
            });

        } else {
            // 평소/편집모드 공통: 정보 그리드는 항상 보여줌
            card.innerHTML = `
            <div class="rc-date">${toDateInputValue(record.기록시각) || "날짜 없음"}</div>
            <div class="rc-grid">
                <div class="rc-stat"><div class="rc-val">${record.거리}km</div><div class="rc-lbl">거리</div></div>
                <div class="rc-stat"><div class="rc-val">${timeDisplay}</div><div class="rc-lbl">시간</div></div>
                <div class="rc-stat"><div class="rc-val">${paceDisplay}</div><div class="rc-lbl">페이스</div></div>
                <div class="rc-stat"><div class="rc-val">${record.시속.toFixed(1)}km/h</div><div class="rc-lbl">시속</div></div>
                <div class="rc-stat"><div class="rc-val">${record.심박수}bpm</div><div class="rc-lbl">심박수</div></div>
                <div class="rc-stat"><div class="rc-val">${record.칼로리.toFixed(0)}kcal</div><div class="rc-lbl">칼로리</div></div>
            </div>
            `;
            runList.appendChild(card);

            if (openRunIndex === index) {
                // 롱프레스로 열린 상태: 수정/삭제 버튼 노출
                const editBtn = document.createElement("button");
                editBtn.textContent = "수정";
                editBtn.className = "btn-edit-item";
                card.appendChild(editBtn);

                const deleteBtn = document.createElement("button");
                deleteBtn.textContent = "삭제";
                deleteBtn.className = "btn-delete-item";
                card.appendChild(deleteBtn);

                editBtn.addEventListener("click", function () {
                    editingRunIndex = index;
                    openRunIndex = null;
                    renderRunList();
                });

                deleteBtn.addEventListener("click", async function () {
                    await apiFetch(`${API_BASE}/runs/${runRecords[index].id}`, { method: "DELETE", credentials: "include" });
                    runRecords.splice(index, 1);
                    openRunIndex = null;
                    renderRunList();
                });
            } else {
                // 평소 모드: 500ms 이상 누르면 수정/삭제 버튼 노출
                attachLongPress(card, function () {
                    openRunIndex = index;
                    renderRunList();
                });
            }
        }
    });

    if (runRecords.length > 0) {
        const latest = runRecords[runRecords.length - 1];
        const latestMin = Math.floor(latest.시간);
        const latestSec = Math.round((latest.시간 - latestMin) * 60);
        const latestTimeDisplay = latestSec > 0 ? `${latestMin}분 ${latestSec}초` : `${latestMin}분`;

        const paceTotalSec = Math.round((latest.시간 / latest.거리) * 60);
        const paceMin = Math.floor(paceTotalSec / 60);
        const paceSec = paceTotalSec % 60;
        const paceDisplay = `${paceMin}'${String(paceSec).padStart(2, '0')}"`;

        document.getElementById("home-run-value").innerHTML = `
            <div class="mini-grid">
                <div class="mini-stat"><div class="mini-val">${latest.거리}km</div><div class="mini-lbl">거리</div></div>
                <div class="mini-stat"><div class="mini-val">${latestTimeDisplay}</div><div class="mini-lbl">시간</div></div>
                <div class="mini-stat"><div class="mini-val">${paceDisplay}</div><div class="mini-lbl">페이스</div></div>
            </div>
        `;
    }
    else {
        document.getElementById("home-run-value").textContent = "아직 기록 없음";
    }
}

// 러닝 기록 저장 전 값 검증 — 프론트에서 1차로 막아서 이상한 값이 서버까지 안 가도록 함
// (서버 쪽 RunController에도 같은 기준으로 2차 검증이 있음: 프론트 우회 요청 대비)
function validateRunInput(distance, totalMinutes, heartRate) {
    if (distance <= 0) return "거리는 0보다 커야 합니다.";
    if (totalMinutes <= 0) return "시간은 0보다 커야 합니다.";
    if (heartRate < 30 || heartRate > 250) return "심박수가 올바르지 않습니다 (30~250 사이로 입력해주세요).";
    return null;
}

// 시속에 따라 MET(운동 강도) 값 결정
// 출처:https://pacompendium.com/running/
function calculateRunStats(distance, totalMinutes) {
    const speedKmh = distance / (totalMinutes / 60);

    let met;
    if (speedKmh < 8.05) {
        met = 6.0;
    } else if (speedKmh < 9.66) {
        met = 8.5;
    } else if (speedKmh < 10.78) {
        met = 9.3;
    } else if (speedKmh < 11.27) {
        met = 10.5;
    } else if (speedKmh < 12.87) {
        met = 11.5;
    } else if (speedKmh < 14.48) {
        met = 12.3;
    } else if (speedKmh < 16.09) {
        met = 12.8;
    } else {
        met = 14.5;
    }

    const caloriesBurned = met * userWeight * (totalMinutes / 60);

    return { speedKmh: speedKmh, caloriesBurned: caloriesBurned };
}

// --- 내 정보 관련 함수 ---
function renderInfo() {
    const savedWeight = localStorage.getItem("userWeight");
    const savedHeight = localStorage.getItem("userHeight")
    const savedAge = localStorage.getItem("userAge");
    const savedGender = localStorage.getItem("userGender");
    const savedBmr = localStorage.getItem("bmr");
    const savedActivity = localStorage.getItem("userActivity");
    const savedTdee = localStorage.getItem("tdee");
    const savedBulk = localStorage.getItem("bulkTarget");

    if (savedWeight) document.getElementById("info-weight-input").value = savedWeight;
    if (savedHeight) document.getElementById("info-height-input").value = savedHeight;
    if (savedAge) document.getElementById("info-age-input").value = savedAge;

    if (savedGender) {
        selectedGender = savedGender;
        genderButtons.forEach(function (b) {
            if (b.dataset.gender === savedGender) {
                b.classList.add("selected");
            }
        });
    }

    if (savedActivity) {
        selectedActivity = Number(savedActivity);
        activityButtons.forEach(function (b) {
            if (b.dataset.activity === savedActivity) {
                b.classList.add("selected");
            }
        });
    }
    if (savedBmr && savedTdee && savedBulk) {
        document.getElementById("bmr-result").innerHTML = `
        기초대사량(BMR): ${savedBmr} kcal<br>
        유지 칼로리: ${savedTdee} kcal<br>
        증량 목표: ${savedBulk} kcal
        `;
    }
}

// --- 컨디션 메모 관련 함수 ---

// 서버에서 컨디션 메모 목록 통째로 가져오기
async function loadMemoRecords() {
    const response = await apiFetch(`${API_BASE}/memos`, { credentials: "include" });
    const serverMemos = await response.json();
    memoRecords.length = 0;
    serverMemos.forEach(function (sm) {
        memoRecords.push(fromServerMemo(sm));
    });
    renderMemoList();
}

// 최근 7일 중 증상 점수가 심했던 상위 2일에 기록된 음식의 등장 빈도 계산
// 규칙기반: 날짜 필터 → 날짜별 최고점 정렬 → 상위 N일 → 그 날 음식 빈도 집계 (AI 미사용)
function calculateSymptomFoodInsight() {
    const RECENT_DAYS = 7;
    const WORST_DAY_COUNT = 2;
    const TOP_FOOD_COUNT = 5;

    const todayStr = todayDateString();
    const startStr = dateStringDaysAgo(RECENT_DAYS - 1);

    const scoreByDate = {};
    memoRecords.forEach(function (m) {
        const d = toDateInputValue(m.날짜);
        if (!d || d < startStr || d > todayStr) return;
        const score = m.증상점수 || 0;
        if (!(d in scoreByDate) || score > scoreByDate[d]) {
            scoreByDate[d] = score;
        }
    });

    const worstDates = Object.keys(scoreByDate)
        .sort(function (a, b) { return scoreByDate[b] - scoreByDate[a]; })
        .slice(0, WORST_DAY_COUNT);

    if (worstDates.length === 0) {
        return { status: "no-memo" };
    }

    const matchedFoods = todayFoods.filter(function (f) {
        return worstDates.indexOf(toDateInputValue(f.기록시각)) !== -1;
    });

    if (matchedFoods.length === 0) {
        return { status: "no-food", worstDates: worstDates };
    }

    const countByName = {};
    const triggerByName = {};
    matchedFoods.forEach(function (f) {
        countByName[f.이름] = (countByName[f.이름] || 0) + 1;
        if (f.트리거) triggerByName[f.이름] = true;
    });

    const items = Object.keys(countByName)
        .sort(function (a, b) { return countByName[b] - countByName[a]; })
        .slice(0, TOP_FOOD_COUNT)
        .map(function (name) {
            return { 이름: name, 횟수: countByName[name], 트리거: !!triggerByName[name] };
        });

    return { status: "ok", worstDates: worstDates, items: items };
}

// 인사이트 카드 다시 그리기 — 음식/메모 데이터가 바뀔 때마다 renderFoodList/renderMemoList 끝에서 호출됨
function renderSymptomInsight() {
    const insight = calculateSymptomFoodInsight();

    if (insight.status === "no-memo") {
        symptomInsightContent.textContent = "최근 7일간 기록된 컨디션 메모가 없어요.";
        return;
    }
    if (insight.status === "no-food") {
        symptomInsightContent.textContent = `증상이 심했던 날(${insight.worstDates.join(", ")})에 기록된 음식이 없어요.`;
        return;
    }

    const itemsHtml = insight.items.map(function (item) {
        const tag = item.트리거 ? ` <span class="trigger-tag">⚠️ 트리거</span>` : "";
        return `<div class="insight-food-row"><span>${item.이름}</span><span>${item.횟수}회${tag}</span></div>`;
    }).join("");

    symptomInsightContent.innerHTML = `
        <div class="insight-sub">증상이 심했던 날: ${insight.worstDates.join(", ")}</div>
        ${itemsHtml}
    `;
}

function renderMemoList() {
    memoList.innerHTML = "";

    memoRecords.forEach(function (memo, index) {
        const card = document.createElement("div");

        if (editingMemoIndex === index) {
            // 수정 모드 — 날짜/내용/증상점수 다 수정 가능
            // type="date" 네이티브 달력 위젯 사용: 자유 텍스트로 두면 아무 글자나 입력되는 문제가 있어
            // 유효한 날짜만 고를 수 있도록 강제함. 기존 한국어 포맷 기록도 toDateInputValue로 변환해 채움
            // 증상점수는 기존 슬라이더 스타일(.symptom-score-row 등)을 그대로 재사용 — 새로 만들 땐 있었는데
            // 수정 폼엔 빠져있어서 수정할 때마다 기존 값이 그대로 재전송되던 게 이번에 고친 버그
            card.innerHTML = `
                <input type="date" class="inp edit-memo-date-input" value="${toDateInputValue(memo.날짜)}">
                <textarea class="inp edit-memo-input">${memo.내용}</textarea>
                <div class="symptom-score-row">
                    <span class="symptom-score-edge">1(가벼움)</span>
                    <input type="range" class="edit-memo-score-input" min="1" max="10" step="1" value="${memo.증상점수}">
                    <span class="symptom-score-edge">10(심함)</span>
                    <span class="symptom-score-num edit-memo-score-display">${memo.증상점수}</span>
                </div>
                <button type="button" class="btn-save-small">저장</button>
                <button type="button" class="btn-cancel-small">취소</button>
            `;
            memoList.appendChild(card);

            card.querySelector(".edit-memo-score-input").addEventListener("input", function () {
                card.querySelector(".edit-memo-score-display").textContent = this.value;
            });

            card.querySelector(".btn-save-small").addEventListener("click", async function () {
                if (!card.querySelector(".edit-memo-date-input").value) {
                    alert("날짜를 입력해주세요!");
                    return;
                }
                if (!card.querySelector(".edit-memo-input").value) {
                    alert("메모를 작성해주세요!");
                    return;
                }
                const updated = {
                    ...memo,
                    날짜: card.querySelector(".edit-memo-date-input").value,
                    내용: card.querySelector(".edit-memo-input").value,
                    증상점수: Number(card.querySelector(".edit-memo-score-input").value)
                };

                const response = await apiFetch(`${API_BASE}/memos/${updated.id}`, {
                    method: "PUT",
                    credentials: "include",
                    headers: { "Content-Type": "application/json" },
                    body: JSON.stringify(toServerMemo(updated))
                });
                const saved = await response.json();
                memoRecords[index] = fromServerMemo(saved);

                editingMemoIndex = null;
                renderMemoList();
            });

            card.querySelector(".btn-cancel-small").addEventListener("click", function () {
                editingMemoIndex = null;
                renderMemoList();
            });

        } else if (openMemoIndex === index) {
            // 롱프레스로 열린 상태: 수정/삭제 버튼 노출
            card.innerHTML = `<strong>${memo.날짜}</strong> <span class="memo-symptom-tag">증상 ${memo.증상점수}/10</span><br>${memo.내용}`;
            memoList.appendChild(card);

            const editBtn = document.createElement("button");
            editBtn.textContent = "수정";
            card.appendChild(editBtn);

            const deleteBtn = document.createElement("button");
            deleteBtn.textContent = "삭제";
            card.appendChild(deleteBtn);

            editBtn.addEventListener("click", function () {
                editingMemoIndex = index;
                openMemoIndex = null;
                renderMemoList();
            });

            deleteBtn.addEventListener("click", async function () {
                await apiFetch(`${API_BASE}/memos/${memoRecords[index].id}`, { method: "DELETE", credentials: "include" });
                memoRecords.splice(index, 1);
                openMemoIndex = null;
                renderMemoList();
            });

        } else {
            // 평소 모드: 500ms 이상 누르면 수정/삭제 버튼 노출
            card.innerHTML = `<strong>${memo.날짜}</strong> <span class="memo-symptom-tag">증상 ${memo.증상점수}/10</span><br>${memo.내용}`;
            memoList.appendChild(card);

            attachLongPress(card, function () {
                openMemoIndex = index;
                renderMemoList();
            });
        }
    });

    renderSymptomInsight();
}

// ===== ④ 이벤트 리스너 연결 =====

// --- 식단 관련 이벤트 ---

// 📅 버튼 클릭 시: 달력 열고/닫기. 처음 열 때만 그 달 요약을 서버에서 불러옴(이후엔 prev/next에서만 재조회)
dietCalendarToggleBtn.addEventListener("click", function () {
    const isHidden = dietCalendarBox.style.display === "none";
    dietCalendarBox.style.display = isHidden ? "block" : "none";

    if (isHidden && !calendarLoaded) {
        calendarLoaded = true;
        loadCalendarSummary(calendarYear, calendarMonth);
    }
    if (!isHidden) {
        // 달력을 닫으면 상세보기/펜딩 상태도 같이 정리 (다음에 열었을 때 묵은 상태가 남지 않도록)
        calendarDetailBox.style.display = "none";
        selectedCalendarDate = null;
        clearPendingCalendarDate();
    }
});

calendarPrevBtn.addEventListener("click", function () {
    calendarMonth -= 1;
    if (calendarMonth < 1) { calendarMonth = 12; calendarYear -= 1; }
    loadCalendarSummary(calendarYear, calendarMonth);
});

calendarNextBtn.addEventListener("click", function () {
    calendarMonth += 1;
    if (calendarMonth > 12) { calendarMonth = 1; calendarYear += 1; }
    loadCalendarSummary(calendarYear, calendarMonth);
});

// "이 날짜로 음식 추가": 즐겨찾기 pill을 그대로 재사용 — 그 카드로 스크롤하고 배너로 안내
calendarAddFoodBtn.addEventListener("click", function () {
    setPendingCalendarDate(selectedCalendarDate, foodDateTargetBanner);
    quickAddList.closest(".hcard").scrollIntoView({ behavior: "smooth" });
});

// "이 날짜로 러닝 추가": 러닝 탭의 기존 입력 폼을 그대로 재사용 — 탭 자동 전환 후 배너로 안내
calendarAddRunBtn.addEventListener("click", function () {
    setPendingCalendarDate(selectedCalendarDate, runDateTargetBanner);
    document.querySelector('.tab-btn[data-index="2"]').click();
});

// "이 날짜로 메모 추가": 내 정보 탭의 기존 컨디션 메모 폼을 그대로 재사용 —
// 탭 자동 전환 후 메모 작성 영역까지 스크롤(내 정보 탭엔 체중/BMR 폼도 같이 있어서 메모 카드가 화면 아래쪽에 있음)
calendarAddMemoBtn.addEventListener("click", function () {
    setPendingCalendarDate(selectedCalendarDate, memoDateTargetBanner);
    document.querySelector('.tab-btn[data-index="3"]').click();

    // scrollIntoView()는 조상 스크롤 컨테이너를 전부 훑는데, 4개 화면이 transform: translateX로
    // 좌우 배치된 이 캐러셀 구조에서는 .screen-wrap(overflow:hidden, 탭 틀)의 스크롤 위치까지
    // 잘못 건드려서 방금 바뀐 탭 전환 transform과 충돌 — 화면이 순간 하얗게 보이는 원인이었음.
    // 그래서 내 정보 화면 자신의 세로 스크롤만 직접 계산해서 이동함. 두 요소의 getBoundingClientRect
    // 차이를 쓰면 .screens에 걸린 transform 값이 얼마든 상쇄돼서 위 문제와 무관하게 항상 정확함
    const infoScreen = document.querySelector(".info-screen");
    const memoSection = document.getElementById("condition-memo-section");
    const targetTop = memoSection.getBoundingClientRect().top - infoScreen.getBoundingClientRect().top + infoScreen.scrollTop;
    infoScreen.scrollTo({ top: targetTop, behavior: "smooth" });
});

// "식사 완료" 버튼 클릭 시: 개별 음식이 아니라 "지금 선택된 끼니"에 추가된 음식들의 지방을
// 합산해서 소화시간을 판단 — 실제 식사는 여러 음식을 같이 먹으므로, 음식 하나만 보고 판단하면
// 그 끼니 전체의 위 부담을 과소평가할 수 있음
//
// 출처: 지방 함량이 높을수록 위 배출 시간이 길어져 역류 위험이 높아진다는 원리는 GERD 관련 의학 자료
// (대한소화기학회 등 국내 임상 자료, 서울아산병원 등 의료기관 자료)에서 확인됨. 다만 정확한 그램
// 구간(10g/25g)은 논문 수치를 그대로 인용한 것이 아니라, 이 원리를 바탕으로 대표 음식(삼겹살,
// 비빔밥, 아이스크림 등)의 실제 지방 함량을 참고해 이 프로젝트에서 실용적으로 설계한 기준임
mealCompleteBtn.addEventListener("click", function () {
    if (selectedMeal === null) {
        alert("끼니를 먼저 선택해주세요!");
        return;
    }

    const mealFoods = todayFoods.filter(function (food) { return food.끼니 === selectedMeal; });
    if (mealFoods.length === 0) {
        alert("먼저 음식을 추가해주세요!");
        return;
    }

    // 지방 실측값(검색으로 추가한 음식)이 있으면 그대로, 없으면(즐겨찾기 수동 등록 등) 근사값으로
    // 대체하는 혼합 계산 — 정확한 데이터가 있는 만큼 합산 정확도를 끌어올림
    let fatSum = 0;
    mealFoods.forEach(function (food) {
        fatSum += (food.지방 != null) ? food.지방 : digestCategoryToRepresentativeFat(food.소화시간);
    });

    let mealHours;
    if (fatSum < 10) mealHours = 2;
    else if (fatSum <= 25) mealHours = 3;
    else mealHours = 4;

    const newTotalSeconds = mealHours * 3600;

    // 이미 타이머가 돌고 있으면 "지금 남은 시간"과 "이번에 새로 계산된 시간" 중 더 긴 쪽으로 갱신
    // — 안전 마진이 줄어드는 방향(예: 무거운 끼니로 4시간 남은 상태에서 가벼운 간식으로 2시간으로 단축)
    // 으로는 절대 안 바뀌게 함
    const savedEndTime = localStorage.getItem("digestEndTime");
    let finalRemaining = newTotalSeconds;
    let finalTotal = newTotalSeconds;
    if (savedEndTime) {
        const existingRemaining = Math.max(0, Math.round((Number(savedEndTime) - Date.now()) / 1000));
        if (existingRemaining > newTotalSeconds) {
            finalRemaining = existingRemaining;
            finalTotal = Number(localStorage.getItem("digestTotalSeconds")) || existingRemaining;
        }
    }

    const endTime = Date.now() + (finalRemaining * 1000);
    localStorage.setItem("digestEndTime", endTime);
    localStorage.setItem("digestTotalSeconds", finalTotal);

    startDigestTimer(finalRemaining, endTime, finalTotal);
});

// "타이머 취소" 버튼 클릭 시: 타이머 정지 + 저장된 끝나는 시각 삭제 + 화면 초기화
digestCancelBtn.addEventListener("click", function () {
    if (timerId !== null) {
        clearInterval(timerId);
        timerId = null;
    }
    localStorage.removeItem("digestEndTime");
    localStorage.removeItem("digestTotalSeconds");
    document.getElementById("digest-timer").textContent = "--:--:--";
    document.getElementById("home-digest-timer").textContent = "--:--:--";
    document.getElementById("digest-end-time").textContent = "";
    document.getElementById("home-digest-end-time").textContent = "";
    document.getElementById("digest-gauge-fill").style.width = "0%";
    document.getElementById("home-digest-gauge-fill").style.width = "0%";
    document.getElementById("digest-warning").textContent = "";
    document.getElementById("home-digest-warning").textContent = "";
});

// 끼니(아침/점심/저녁/간식) 버튼 클릭 시: 선택 표시 토글 + selectedMeal 값 저장
// "음식 검색" 버튼 클릭 또는 검색창에서 Enter 입력 시 식약처 API 검색 실행
foodSearchBtn.addEventListener("click", function () {
    searchFoodApi(foodSearchInput.value);
});
foodSearchInput.addEventListener("keydown", function (e) {
    if (e.key === "Enter") searchFoodApi(foodSearchInput.value);
});

// (성별/활동량 버튼과 같은 패턴 — 한 번 선택하면 다른 걸 누르기 전까지 유지)
mealButtons.forEach(function (btn) {
    btn.addEventListener("click", function () {
        mealButtons.forEach(function (b) {
            b.classList.remove("selected");
        });
        btn.classList.add("selected");

        selectedMeal = btn.dataset.meal;
    });
});

// 음식 배너의 닫기(✕) 버튼: 사용자가 명시적으로 눌러야 "이 날짜로 추가" 상태가 풀림
// (즐겨찾기 pill을 여러 번 눌러도 배너를 닫기 전까진 계속 같은 날짜로 저장됨)
foodDateTargetCloseBtn.addEventListener("click", clearPendingCalendarDate);

// 소화시간 카테고리 버튼 클릭 시: 선택 표시 토글 + selectedDigest 값 저장
digestButtons.forEach(function (btn) {
    btn.addEventListener("click", function () {
        digestButtons.forEach(function (b) {
            b.classList.remove("selected");
        });
        btn.classList.add("selected");

        selectedDigest = Number(btn.dataset.digest);
    });
});

// "음식 추가" 버튼 클릭 시: 입력값+선택된 소화시간으로 새 음식을 foods에 추가
addFoodBtn.addEventListener("click", function () {
    if (selectedDigest === null) {
        alert("소화 시간 카테고리를 선택해주세요!");
        return;
    }

    const nameValue = document.getElementById("food-name-input").value;
    const calorieValue = document.getElementById("food-calorie-input").value;
    const triggerValue = document.getElementById("food-trigger-input").checked;

    const newFood = {
        이름: nameValue,
        칼로리: Number(calorieValue),
        소화시간: selectedDigest,
        트리거: triggerValue
    };

    foods.push(newFood);
    saveFoods();
    renderQuickAddList();
});

// --- 러닝 관련 이벤트 ---
runSaveBtn.addEventListener("click", async function () {
    if (!document.getElementById("run-distance-input").value) {
        alert("거리를 입력해주세요!");
        return;
    }
    if (!document.getElementById("run-time-input").value) {
        alert("시간을 입력해주세요!");
        return;
    }
    if (!document.getElementById("run-heartrate-input").value) {
        alert("심박수를 입력해주세요!");
        return;
    }
    // 체중을 한 번도 입력한 적 없으면(내 정보 미작성) 기본값(60kg)으로 조용히 계산하는 대신
    // 저장을 막고 내 정보 입력을 유도 — 잘못된 칼로리 값이 기록에 남는 것을 방지
    if (!localStorage.getItem("userWeight")) {
        alert("정확한 칼로리 계산을 위해 내 정보에서 체중을 먼저 입력해주세요!");
        document.querySelector('.tab-btn[data-index="3"]').click();
        return;
    }

    const distance = Number(document.getElementById("run-distance-input").value);

    const timeValue = (document.getElementById("run-time-input").value);
    const timeParts = timeValue.split(":");
    const minutes = Number(timeParts[0]);
    const seconds = Number(timeParts[1]) || 0;
    const totalMinutes = minutes + (seconds / 60);

    const heartrate = Number(document.getElementById("run-heartrate-input").value);

    const runError = validateRunInput(distance, totalMinutes, heartrate);
    if (runError) {
        alert(runError);
        return;
    }

    const stats = calculateRunStats(distance, totalMinutes);

    // 달력에서 "이 날짜로 러닝 추가"를 눌러둔 상태면 그 날짜로, 아니면 평소처럼 서버가 현재 시각으로 저장
    const newRecord = {
        거리: distance,
        시간: totalMinutes,
        심박수: heartrate,
        시속: stats.speedKmh,
        칼로리: stats.caloriesBurned,
        기록시각: pendingCalendarDate ? dateWithCurrentTime(pendingCalendarDate) : null
    };

    const response = await apiFetch(`${API_BASE}/runs`, {
        method: "POST",
        credentials: "include",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(toServerRun(newRecord))
    });
    const saved = await response.json();
    runRecords.push(fromServerRun(saved));

    document.getElementById("run-distance-input").value = "";
    document.getElementById("run-time-input").value = "";
    document.getElementById("run-heartrate-input").value = "";

    renderRunList();

    if (pendingCalendarDate) {
        const savedDate = pendingCalendarDate;
        clearPendingCalendarDate();
        loadCalendarSummary(calendarYear, calendarMonth);
        if (selectedCalendarDate === savedDate) loadCalendarDetail(savedDate);
        document.querySelector('.tab-btn[data-index="1"]').click(); // 식단 탭(달력)으로 복귀
    }
});

// --- 내 정보 관련 이벤트 ---
// 성별 버튼 클릭 시: 선택 표시 토글 + selectedGender 값 저장
genderButtons.forEach(function (btn) {
    btn.addEventListener("click", function () {
        genderButtons.forEach(function (b) {
            b.classList.remove("selected");
        });
        btn.classList.add("selected");

        selectedGender = btn.dataset.gender;
    });
});

// 활동량 버튼 클릭 시: 선택 표시 토글 + selectedActivity 값 저장
activityButtons.forEach(function (btn) {
    btn.addEventListener("click", function () {
        activityButtons.forEach(function (b) {
            b.classList.remove("selected");
        });
        btn.classList.add("selected");
        selectedActivity = Number(btn.dataset.activity);
    });
});

// "정보 저장" 버튼 클릭 시: 입력값으로 BMR 계산
// 공식 출처: Mifflin-St Jeor Equation (1990) — 미국 영양학회(Academy of Nutrition and Dietetics) 권장 공식
// 출처: TDEE = BMR × 활동계수(1.2~1.9), 증량은 TDEE+300~500kcal (일반적으로 권장되는 범위)
infoSaveBtn.addEventListener("click", function () {
    if (!document.getElementById("info-weight-input").value) {
        alert("체중을 입력해주세요!");
        return;
    }
    if (!document.getElementById("info-height-input").value) {
        alert("키를 입력해주세요!");
        return;
    }
    if (!document.getElementById("info-age-input").value) {
        alert("나이를 입력해주세요!");
        return;
    }
    if (selectedGender === null) {
        alert("성별을 선택해주세요!");
        return;
    }
    if (selectedActivity === null) {
        alert("활동량을 선택해주세요!");
        return;
    }


    const age = Number(document.getElementById("info-age-input").value);
    const height = Number(document.getElementById("info-height-input").value);
    const weight = Number(document.getElementById("info-weight-input").value);

    let bmr;
    if (selectedGender === "male") {
        bmr = (10 * weight) + (6.25 * height) - (5 * age) + 5;
    }
    else {
        bmr = (10 * weight) + (6.25 * height) - (5 * age) - 161;
    }

    const tdee = bmr * selectedActivity;
    const bulkTarget = tdee + 400;

    userWeight = weight;
    localStorage.setItem("userWeight", userWeight);
    localStorage.setItem("userHeight", height);
    localStorage.setItem("userAge", age);
    localStorage.setItem("userGender", selectedGender);
    localStorage.setItem("userActivity", selectedActivity)
    localStorage.setItem("bmr", bmr.toFixed(0));
    localStorage.setItem("tdee", tdee.toFixed(0));
    localStorage.setItem("bulkTarget", bulkTarget.toFixed(0));

    document.getElementById("bmr-result").innerHTML = `
    기초대사량(BMR): ${bmr.toFixed(0)} kcal<br>
    유지 칼로리: ${tdee.toFixed(0)} kcal<br>
    증량 목표: ${bulkTarget.toFixed(0)} kcal
    `;

    renderFoodList();
});

// --- 컨디션 메모 관련 이벤트 ---

// 슬라이더 움직이면 숫자 표시도 같이 갱신
symptomScoreSlider.addEventListener("input", function () {
    symptomScore = Number(symptomScoreSlider.value);
    symptomScoreDisplay.textContent = symptomScore;
});

// 숫자를 클릭하면 직접 입력 가능한 칸으로 전환
symptomScoreDisplay.addEventListener("click", function () {
    symptomScoreInput.value = symptomScore;
    symptomScoreDisplay.style.display = "none";
    symptomScoreInput.style.display = "inline-block";
    symptomScoreInput.focus();
    symptomScoreInput.select();
});

// 입력 끝나면(포커스 아웃) 1~10 범위로 정리하고 슬라이더/숫자 표시에 반영, 다시 텍스트로 전환
function commitSymptomScoreInput() {
    let value = Math.round(Number(symptomScoreInput.value));
    if (!value || value < 1) value = 1;
    if (value > 10) value = 10;
    symptomScore = value;
    symptomScoreSlider.value = value;
    symptomScoreDisplay.textContent = value;
    symptomScoreInput.style.display = "none";
    symptomScoreDisplay.style.display = "inline-block";
}
symptomScoreInput.addEventListener("blur", commitSymptomScoreInput);
symptomScoreInput.addEventListener("keydown", function (e) {
    if (e.key === "Enter") symptomScoreInput.blur(); // blur 핸들러가 정리 로직을 처리
});

memoSaveBtn.addEventListener("click", async function () {
    if (!memoInput.value) {
        alert("메모를 작성해주세요!");
        return;
    }

    // 달력에서 "이 날짜로 메모 추가"를 눌러둔 상태면 그 날짜로, 아니면 평소처럼 오늘 날짜로 저장
    const newMemo = {
        날짜: pendingCalendarDate || todayDateString(),
        내용: memoInput.value,
        증상점수: symptomScore
    };

    const response = await apiFetch(`${API_BASE}/memos`, {
        method: "POST",
        credentials: "include",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(toServerMemo(newMemo))
    });
    const saved = await response.json();
    memoRecords.push(fromServerMemo(saved));

    memoInput.value = "";
    symptomScore = 5;
    symptomScoreSlider.value = 5;
    symptomScoreDisplay.textContent = 5;
    renderMemoList();

    if (pendingCalendarDate) {
        const savedDate = pendingCalendarDate;
        clearPendingCalendarDate();
        loadCalendarSummary(calendarYear, calendarMonth);
        if (selectedCalendarDate === savedDate) loadCalendarDetail(savedDate);
        document.querySelector('.tab-btn[data-index="1"]').click(); // 식단 탭(달력)으로 복귀
    }
});

// --- 로그인 관련 이벤트 ---
// 로그아웃 후 새로고침 — 새로고침해야 login-gate가 기본 표시 상태로 다시 시작함
// (이미 만료된 세션에서 로그아웃을 눌러도 새로고침으로 어차피 로그인 게이트로 가므로 apiFetch의
// 만료 alert는 필요 없음 — 그래서 여기만 apiFetch가 아닌 일반 fetch를 그대로 씀)
logoutBtn.addEventListener("click", async function () {
    await fetch(`${API_BASE}/auth/logout`, { method: "POST", credentials: "include" });
    window.location.reload();
});

// --- 편집 UX 공용: 롱프레스로 열린 카드 바깥 클릭 시 닫기 ---
document.addEventListener("click", function (e) {
    closeIfOutside(quickAddList, openQuickAddIndex, function (v) { openQuickAddIndex = v; }, renderQuickAddList, e);
    closeIfOutside(foodList, openFoodIndex, function (v) { openFoodIndex = v; }, renderFoodList, e);
    closeIfOutside(runList, openRunIndex, function (v) { openRunIndex = v; }, renderRunList, e);
    closeIfOutside(memoList, openMemoIndex, function (v) { openMemoIndex = v; }, renderMemoList, e);
    clearMealIfOutside(e);
});

// --- 전역(탭바) ---
// 하단 탭 버튼 클릭 시: 해당 화면으로 슬라이드 이동 + 클릭된 탭에 active 스타일 적용
document.addEventListener('DOMContentLoaded', function () {
    document.querySelectorAll(".tab-btn").forEach(function (btn) {
        btn.addEventListener("click", function () {
            const index = Number(btn.dataset.index);
            const screens = document.getElementById("screens");

            // 이동 칸 수만큼 이동 거리도 늘어나는데 애니메이션 시간은 고정이면, 여러 칸을 건너뛰는
            // 전환(예: 달력에서 "이 날짜로 메모 추가" 클릭 시 식단→내정보처럼 2칸)이 유난히 빨라 보임 —
            // 칸당 이동 거리는 일정하니, 칸 수에 비례해서 애니메이션 시간도 늘려 체감 속도를 맞춤
            const currentBtn = document.querySelector(".tab-btn.active");
            const currentIndex = currentBtn ? Number(currentBtn.dataset.index) : 0;
            const distance = Math.max(1, Math.abs(index - currentIndex));
            screens.style.transitionDuration = `${0.45 + (distance - 1) * 0.15}s`;

            screens.style.transform = `translateX(-${index * 100}vw)`;

            document.querySelectorAll(".tab-btn").forEach(function (b) {
                b.classList.remove("active");
            });
            btn.classList.add("active");
        });
    });
});

// ===== ⑤ 초기 실행 =====

// index.html의 카카오 로그인 링크는 기본값이 배포 주소로 박혀있음(배포 환경에서 안전한 기본값) —
// 로컬(localhost)에서 열었을 때만 로컬 백엔드 주소로 되돌림
if (window.location.hostname === "localhost") {
    kakaoLoginLink.href = `${BACKEND_ORIGIN}/oauth2/authorization/kakao`;
}

// 로그인 안 했으면 login-gate가 이미 보이는 상태로 대기 — 데이터 로드 자체를 생략함
// (안 그러면 401 응답을 파싱하려다 콘솔 에러만 남고, 게이트에 가려 안 보이는 화면 데이터를 미리 불러오는 낭비이기도 함)
checkLoginState().then(function (loggedIn) {
    if (!loggedIn) return;

    renderQuickAddList();
    loadTodayFoods();   // renderFoodList()는 이 함수 안에서 자동으로 호출됨
    startMidnightWatcher();   // 화면을 켜놓은 채 자정을 넘기는 경우 대비
    loadRunRecords();   // renderRunList()는 이 함수 안에서 자동으로 호출됨
    renderInfo();
    loadMemoRecords();  // renderMemoList()는 이 함수 안에서 자동으로 호출됨

    // 페이지 열릴때: 저장된 소화 타이머가 있으면 남은 시간을 계산해서 이어서 시작
    const savedEndTime = localStorage.getItem("digestEndTime");
    if (savedEndTime) {
        const remaining = Math.round((Number(savedEndTime) - Date.now()) / 1000);
        const savedTotal = Number(localStorage.getItem("digestTotalSeconds"));
        if (remaining > 0) {
            startDigestTimer(remaining, Number(savedEndTime), savedTotal);
        }
        else {
            localStorage.removeItem("digestEndTime");
            localStorage.removeItem("digestTotalSeconds");
            document.getElementById("digest-warning").textContent = "소화 완료! 이제 누우셔도 됩니다!";
            document.getElementById("home-digest-warning").textContent = "소화 완료! 이제 누우셔도 됩니다!";
        }
    }
});
