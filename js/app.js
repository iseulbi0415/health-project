// ===== ① 데이터 =====

// 서버 주소 (백엔드가 살아있는 곳)
// 로컬(Live Server, localhost)에서 열었으면 로컬 백엔드를, 배포(Vercel)에서 열었으면
// 배포된 Railway 백엔드를 자동으로 봄
const BACKEND_ORIGIN = window.location.hostname === "localhost"
    ? "http://localhost:8080"
    : "https://health-project-production-5204.up.railway.app";
const API_BASE = `${BACKEND_ORIGIN}/api`;

// --- 식단: 자주 먹는 음식 관련 ---
const foods = JSON.parse(localStorage.getItem("foods")) || [
    { 이름: "바나나", 칼로리: 100, 소화시간: 2, 트리거: false },
    { 이름: "닭가슴살", 칼로리: 165, 소화시간: 3, 트리거: false },
    { 이름: "삼겹살", 칼로리: 330, 소화시간: 4, 트리거: true }
];

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

// --- 서버 데이터 <-> 한글 변수 이름 번역기 (fetch로 주고받을 때만 사용) ---
// 기록시각(recordedAt)은 화면에 표시/입력하는 곳은 아직 없지만, PUT으로 되돌려 보낼 때
// 값이 없으면 서버가 null로 덮어쓰지 않고 기존 값을 유지하므로 왕복 전달만 해둠(향후 날짜별 기록 관리 기능 대비)
function toServerFood(f) { return { name: f.이름, calorie: f.칼로리, digestTime: f.소화시간, isTrigger: f.트리거 || false, recordedAt: f.기록시각 || null }; }
function fromServerFood(sf) { return { id: sf.id, 이름: sf.name, 칼로리: sf.calorie, 소화시간: sf.digestTime, 트리거: sf.isTrigger, 기록시각: sf.recordedAt }; }

function toServerRun(r) { return { distance: r.거리, time: r.시간, heartRate: r.심박수, speedKmh: r.시속, calorieBurned: r.칼로리, recordedAt: r.기록시각 || null }; }
function fromServerRun(sr) { return { id: sr.id, 거리: sr.distance, 시간: sr.time, 심박수: sr.heartRate, 시속: sr.speedKmh, 칼로리: sr.calorieBurned, 기록시각: sr.recordedAt }; }

// symptomScore는 화면 입력칸이 아직 없어서 0으로 고정 전송 (나중에 인사이트 기능에서 실제 값 연결 예정)
function toServerMemo(m) { return { date: m.날짜, content: m.내용, symptomScore: m.증상점수 || 0 }; }
function fromServerMemo(sm) { return { id: sm.id, 날짜: sm.date, 내용: sm.content, 증상점수: sm.symptomScore }; }

// ===== ② HTML 요소 찾아오기 =====

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

const runList = document.getElementById("run-list");
const runSaveBtn = document.getElementById("run-save-btn");

const genderButtons = document.querySelectorAll(".gender-btn");
const infoSaveBtn = document.getElementById("info-save-btn");
const activityButtons = document.querySelectorAll(".activity-btn");

const memoInput = document.getElementById("condition-memo-input");
const memoSaveBtn = document.getElementById("memo-save-btn");
const memoList = document.getElementById("memo-list");
const symptomScoreSlider = document.getElementById("symptom-score-slider");
const symptomScoreDisplay = document.getElementById("symptom-score-display");
const symptomScoreInput = document.getElementById("symptom-score-input");
const symptomInsightContent = document.getElementById("symptom-insight-content");
const homeCalorieGaugeTrack = document.getElementById("home-calorie-gauge-track");
const homeCalorieGuide = document.getElementById("home-calorie-guide");
// ===== ③ 함수 정의 =====

// --- 로그인 관련 함수 ---

// 로그인 상태 확인 — 로그인 됐으면 게이트를 치우고 앱을 보여주고, 아니면 게이트가 기본 상태(보임) 그대로 유지
async function checkLoginState() {
    const response = await fetch(`${API_BASE}/auth/me`, { credentials: "include" });
    const data = await response.json();

    if (data.loggedIn) {
        loginNickname.textContent = `${data.nickname}님`;
        loginGate.style.display = "none";
        appShell.style.display = "block";
    }

    return data.loggedIn;
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

// --- 식단 관련 함수 ---
// 자주 먹는 음식 빠른 추가 버튼 다시 그리기
function renderQuickAddList() {
    quickAddList.innerHTML = "";

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

                const response = await fetch(`${API_BASE}/foods`, {
                    method: "POST",
                    credentials: "include",
                    headers: { "Content-Type": "application/json" },
                    body: JSON.stringify(toServerFood({ ...food }))
                });
                const saved = await response.json();
                todayFoods.push(fromServerFood(saved));
                renderFoodList();
            });
        }
    });
}

function saveFoods() {
    localStorage.setItem("foods", JSON.stringify(foods));
}

// 서버에서 오늘 먹은 음식 목록 통째로 가져오기
async function loadTodayFoods() {
    const response = await fetch(`${API_BASE}/foods`, { credentials: "include" });
    const serverFoods = await response.json();
    todayFoods.length = 0;
    serverFoods.forEach(function (sf) {
        todayFoods.push(fromServerFood(sf));
    });
    renderFoodList();
}

// 오늘 먹은 음식 목록 + 총 칼로리를 화면에 그리는 함수
function renderFoodList() {
    foodList.innerHTML = "";
    let total = 0;

    todayFoods.forEach(function (food, index) {
        total += food.칼로리;

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

                const response = await fetch(`${API_BASE}/foods/${updated.id}`, {
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
            card.innerHTML = `<span class="food-text">${food.이름} - ${food.칼로리} kcal${triggerTag}</span>`;

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
                await fetch(`${API_BASE}/foods/${todayFoods[index].id}`, { method: "DELETE", credentials: "include" });
                todayFoods.splice(index, 1);
                openFoodIndex = null;
                renderFoodList();
            });

        } else {
            // 평소 모드: 500ms 이상 누르면 수정/삭제 버튼 노출
            const triggerTag = food.트리거 ? ` <span class="trigger-tag">⚠️ 트리거</span>` : "";
            card.innerHTML = `<span class="food-text">${food.이름} - ${food.칼로리} kcal${triggerTag}</span>`;
            foodList.appendChild(card);

            attachLongPress(card, function () {
                openFoodIndex = index;
                renderFoodList();
            });
        }
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

// --- 러닝 관련 함수 ---

// 서버에서 러닝 기록 목록 통째로 가져오기
async function loadRunRecords() {
    const response = await fetch(`${API_BASE}/runs`, { credentials: "include" });
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

                const response = await fetch(`${API_BASE}/runs/${updated.id}`, {
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
                    await fetch(`${API_BASE}/runs/${runRecords[index].id}`, { method: "DELETE", credentials: "include" });
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
    const response = await fetch(`${API_BASE}/memos`, { credentials: "include" });
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

                const response = await fetch(`${API_BASE}/memos/${updated.id}`, {
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
                await fetch(`${API_BASE}/memos/${memoRecords[index].id}`, { method: "DELETE", credentials: "include" });
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
// "식사 완료" 버튼 클릭 시: 가장 오래 걸리는 소화시간을 찾아서 끝나는 시각을 저장하고 타이머 시작
mealCompleteBtn.addEventListener("click", function () {

    let maxTime = 0;
    todayFoods.forEach(function (food) {
        if (food.소화시간 > maxTime) {
            maxTime = food.소화시간;
        }
    });

    const totalSeconds = maxTime * 3600;
    const endTime = Date.now() + (totalSeconds * 1000);
    localStorage.setItem("digestEndTime", endTime);
    localStorage.setItem("digestTotalSeconds", totalSeconds);

    startDigestTimer(totalSeconds, endTime, totalSeconds);

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

    const distance = Number(document.getElementById("run-distance-input").value);

    const timeValue = (document.getElementById("run-time-input").value);
    const timeParts = timeValue.split(":");
    const minutes = Number(timeParts[0]);
    const seconds = Number(timeParts[40]) || 0;
    const totalMinutes = minutes + (seconds / 60);

    const heartrate = Number(document.getElementById("run-heartrate-input").value);

    const stats = calculateRunStats(distance, totalMinutes);

    const newRecord = {
        거리: distance,
        시간: totalMinutes,
        심박수: heartrate,
        시속: stats.speedKmh,
        칼로리: stats.caloriesBurned
    };

    const response = await fetch(`${API_BASE}/runs`, {
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

    const newMemo = {
        날짜: todayDateString(),
        내용: memoInput.value,
        증상점수: symptomScore
    };

    const response = await fetch(`${API_BASE}/memos`, {
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
});

// --- 로그인 관련 이벤트 ---
// 로그아웃 후 새로고침 — 새로고침해야 login-gate가 기본 표시 상태로 다시 시작함
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
});

// --- 전역(탭바) ---
// 하단 탭 버튼 클릭 시: 해당 화면으로 슬라이드 이동 + 클릭된 탭에 active 스타일 적용
document.addEventListener('DOMContentLoaded', function () {
    document.querySelectorAll(".tab-btn").forEach(function (btn) {
        btn.addEventListener("click", function () {
            const index = Number(btn.dataset.index);
            const screens = document.getElementById("screens");
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
