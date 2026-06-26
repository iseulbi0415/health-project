/* ============================================================
   app.js  —  안심 건강 트래커
   ============================================================ */

/* ──────────────────────────────────────────────
   1. 클린식 데이터 (자주 먹는 음식 미리 저장)
────────────────────────────────────────────── */
const CLEAN_FOODS = [
  { name: "🍗 닭가슴살 100g", cal: 165 },
  { name: "🥗 샐러드 ", cal: 80 },
  { name: "🍳 삶은 달걀 2개", cal: 140 },
  { name: "🍚 밥 1공기", cal: 300 },
  { name: "🥛 무지방 우유 200ml", cal: 65 },
  { name: "🍌 바나나 1개", cal: 90 },
];

/* ──────────────────────────────────────────────
   2. DigestiveTimer 클래스 (소화 타이머 핵심 로직)
────────────────────────────────────────────── */
class DigestiveTimer {
  constructor() {
    this.totalMs   = 0;   // 총 소화 시간 (밀리초)
    this.remainMs  = 0;   // 남은 시간 (밀리초)
    this.interval  = null;
    this.isRunning = false;
  }

  /* 식사 유형에 따른 시간(시간 단위)을 받아서 타이머 시작 */
  start(hours) {
    if (this.interval) clearInterval(this.interval);

    this.totalMs   = hours * 60 * 60 * 1000;
    this.remainMs  = this.totalMs;
    this.isRunning = true;

    this._tick();
    this.interval = setInterval(() => this._tick(), 1000);
  }

  /* 1초마다 호출 — 남은 시간을 줄이고 화면을 업데이트 */
  _tick() {
    if (this.remainMs <= 0) {
      this.remainMs  = 0;
      this.isRunning = false;
      clearInterval(this.interval);
    }

    updateTimerUI(this.remainMs, this.totalMs);

    if (this.remainMs > 0) {
      this.remainMs -= 1000;
    }
  }

  /* 타이머 초기화 */
  reset() {
    clearInterval(this.interval);
    this.isRunning = false;
    this.remainMs  = 0;
    this.totalMs   = 0;
  }

  /* 소화 중인지 여부 반환 (운동 가드에 사용) */
  get isDigesting() {
    return this.isRunning && this.remainMs > 0;
  }
}

/* ──────────────────────────────────────────────
   3. 타이머 UI 업데이트 함수
────────────────────────────────────────────── */
function updateTimerUI(remainMs, totalMs) {
  const percent     = totalMs > 0 ? (remainMs / totalMs) * 100 : 0;
  const isDone      = remainMs <= 0;

  // 게이지바
  const gaugeBar    = document.getElementById("gauge-bar");
  const gaugePercent = document.getElementById("gauge-percent");
  gaugeBar.style.width = percent.toFixed(1) + "%";
  gaugePercent.textContent = Math.ceil(percent) + "%";
  gaugeBar.classList.toggle("done", isDone);

  // 게이지 설명 텍스트
  const gaugeDesc = document.getElementById("gauge-desc");
  if (isDone) {
    gaugeDesc.textContent = "✅ 소화가 완료되었습니다! 운동해도 좋아요.";
  } else if (percent > 60) {
    gaugeDesc.textContent = "위장이 활발히 소화 중입니다...";
  } else if (percent > 20) {
    gaugeDesc.textContent = "소화가 거의 끝나가고 있어요.";
  } else {
    gaugeDesc.textContent = "곧 소화가 완료됩니다!";
  }

  // 남은 시간 표시 (HH:MM:SS)
  document.getElementById("timer-remaining").textContent = formatTime(remainMs);

  // 경고 박스
  const warningBox  = document.getElementById("warning-box");
  const warningText = warningBox.querySelector(".warning-text");
  if (isDone) {
    warningBox.classList.add("safe");
    warningText.textContent = "✅ 소화가 완료되었습니다. 이제 운동하셔도 됩니다!";
  } else {
    warningBox.classList.remove("safe");
    warningText.textContent = "아직 눕지 마세요! 격렬한 운동은 역류를 유발할 수 있습니다.";
  }
}

/* 밀리초 → "HH:MM:SS" 변환 */
function formatTime(ms) {
  if (ms <= 0) return "00:00:00";
  const totalSec = Math.ceil(ms / 1000);
  const h = Math.floor(totalSec / 3600);
  const m = Math.floor((totalSec % 3600) / 60);
  const s = totalSec % 60;
  return [h, m, s].map(n => String(n).padStart(2, "0")).join(":");
}

/* ──────────────────────────────────────────────
   4. 식단 기록 상태
────────────────────────────────────────────── */
let dietLog       = [];   // { name, cal } 배열
let totalCalories = 0;

function addFoodItem(name, cal) {
  if (!name || !cal || isNaN(cal) || cal <= 0) return;
  dietLog.push({ name, cal: Number(cal) });
  renderDietLog();
}

function removeFoodItem(index) {
  dietLog.splice(index, 1);
  renderDietLog();
}

function renderDietLog() {
  const list = document.getElementById("diet-log-list");
  list.innerHTML = "";

  totalCalories = 0;
  dietLog.forEach((item, i) => {
    totalCalories += item.cal;
    const div = document.createElement("div");
    div.className = "diet-log-item";
    div.innerHTML = `
      <span class="diet-item-name">${item.name}</span>
      <div class="diet-item-right">
        <span class="diet-item-cal">${item.cal} kcal</span>
        <button class="btn-delete" data-index="${i}">✕</button>
      </div>
    `;
    list.appendChild(div);
  });

  document.getElementById("total-calories").innerHTML =
    `<strong>${totalCalories}</strong> kcal`;

  list.querySelectorAll(".btn-delete").forEach(btn => {
    btn.addEventListener("click", () => removeFoodItem(Number(btn.dataset.index)));
  });
}

/* ──────────────────────────────────────────────
   5. BMR 계산 (해리스-베네딕트 공식)
────────────────────────────────────────────── */
function calcBMR(weight, height, age, gender) {
  if (gender === "male") {
    return 88.362 + (13.397 * weight) + (4.799 * height) - (5.677 * age);
  } else {
    return 447.593 + (9.247 * weight) + (3.098 * height) - (4.330 * age);
  }
}

/* ──────────────────────────────────────────────
   6. 러닝 기록
────────────────────────────────────────────── */
let runLog = [];

function addRunRecord(distance, time, hr) {
  const pace = time / distance;  // 분/km
  const paceMin = Math.floor(pace);
  const paceSec = Math.round((pace - paceMin) * 60);
  runLog.push({ distance, time, hr, paceMin, paceSec });
  renderRunLog();
}

function renderRunLog() {
  const list = document.getElementById("run-log-list");
  list.innerHTML = "";
  runLog.forEach(r => {
    const card = document.createElement("div");
    card.className = "run-log-card";
    card.innerHTML = `
      <div class="run-stat">
        <span class="run-stat-value">${r.distance} km</span>
        <span class="run-stat-label">거리</span>
      </div>
      <div class="run-stat">
        <span class="run-stat-value">${r.time} 분</span>
        <span class="run-stat-label">총 시간</span>
      </div>
      <div class="run-stat">
        <span class="run-stat-value">${r.paceMin}'${String(r.paceSec).padStart(2,"0")}"</span>
        <span class="run-stat-label">평균 페이스</span>
      </div>
      <div class="run-stat">
        <span class="run-stat-value">${r.hr || "—"} bpm</span>
        <span class="run-stat-label">평균 심박수</span>
      </div>
    `;
    list.appendChild(card);
  });
}

/* ──────────────────────────────────────────────
   7. 초기화 & 이벤트 바인딩
────────────────────────────────────────────── */
document.addEventListener("DOMContentLoaded", () => {
  const timer = new DigestiveTimer();

  /* ▶ 식사 유형 버튼 */
  document.querySelectorAll(".meal-btn").forEach(btn => {
    btn.addEventListener("click", () => {
      document.querySelectorAll(".meal-btn").forEach(b => b.classList.remove("active"));
      btn.classList.add("active");

      const hours = parseFloat(btn.dataset.hours);
      timer.start(hours);
      document.getElementById("timer-display").style.display = "block";
    });
  });

  /* ▶ 타이머 초기화 버튼 */
  document.getElementById("btn-reset").addEventListener("click", () => {
    timer.reset();
    document.getElementById("timer-display").style.display = "none";
    document.querySelectorAll(".meal-btn").forEach(b => b.classList.remove("active"));
  });

  /* ▶ 운동 가드: 러닝 섹션 클릭 시 소화 중이면 모달 표시 */
  document.getElementById("running-section").addEventListener("click", (e) => {
    if (timer.isDigesting) {
      e.stopPropagation();
      document.getElementById("guard-modal").style.display = "flex";
    }
  }, true);

  document.getElementById("btn-modal-close").addEventListener("click", () => {
    document.getElementById("guard-modal").style.display = "none";
  });

  /* ▶ BMR 계산 */
  document.getElementById("btn-calc-bmr").addEventListener("click", () => {
    const weight = parseFloat(document.getElementById("weight").value);
    const height = parseFloat(document.getElementById("height").value);
    const age    = parseFloat(document.getElementById("age").value);
    const gender = document.querySelector("input[name='gender']:checked").value;

    if (!weight || !height || !age) {
      alert("키, 체중, 나이를 모두 입력해 주세요.");
      return;
    }

    const bmr      = Math.round(calcBMR(weight, height, age, gender));
    const maintain = Math.round(bmr * 1.375);  // 가벼운 운동 기준
    const gain     = Math.round(maintain + 300);

    document.getElementById("bmr-value").textContent      = bmr + " kcal";
    document.getElementById("maintain-value").textContent = maintain + " kcal";
    document.getElementById("gain-value").textContent     = gain + " kcal";
    document.getElementById("bmr-result").style.display   = "block";
  });

  /* ▶ 클린식 버튼 생성 */
  const quickContainer = document.getElementById("quick-food-buttons");
  CLEAN_FOODS.forEach(food => {
    const btn = document.createElement("button");
    btn.className   = "quick-btn";
    btn.textContent = `${food.name} (${food.cal}kcal)`;
    btn.addEventListener("click", () => addFoodItem(food.name, food.cal));
    quickContainer.appendChild(btn);
  });

  /* ▶ 음식 직접 추가 */
  document.getElementById("btn-add-food").addEventListener("click", () => {
    const name = document.getElementById("food-name-input").value.trim();
    const cal  = document.getElementById("food-cal-input").value;
    if (!name || !cal) { alert("음식 이름과 칼로리를 입력해 주세요."); return; }
    addFoodItem(name, cal);
    document.getElementById("food-name-input").value = "";
    document.getElementById("food-cal-input").value  = "";
  });

  /* ▶ 러닝 기록 저장 */
  document.getElementById("btn-add-run").addEventListener("click", () => {
    const dist = parseFloat(document.getElementById("run-distance").value);
    const time = parseFloat(document.getElementById("run-time").value);
    const hr   = parseFloat(document.getElementById("run-hr").value) || null;
    if (!dist || !time) { alert("거리와 시간을 입력해 주세요."); return; }
    addRunRecord(dist, time, hr);
    document.getElementById("run-distance").value = "";
    document.getElementById("run-time").value     = "";
    document.getElementById("run-hr").value       = "";
  });

  /* ▶ 컨디션 메모 저장 */
  document.getElementById("btn-save-memo").addEventListener("click", () => {
    const memo   = document.getElementById("condition-memo").value.trim();
    const weight = document.getElementById("today-weight").value;
    if (!memo && !weight) { alert("체중 또는 메모를 입력해 주세요."); return; }
    // 현재는 화면에 저장 확인만 표시 (Step 3에서 DB 저장으로 확장 예정)
    const saved = document.getElementById("memo-saved");
    saved.style.display = "block";
    setTimeout(() => { saved.style.display = "none"; }, 3000);
  });
});
