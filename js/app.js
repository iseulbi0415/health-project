// ===== ① 데이터 =====

// 자주 먹는 음식 목록 (이름 / 칼로리 / 소화시간)
const foods = JSON.parse(localStorage.getItem("foods")) || [
    {이름: "바나나", 칼로리: 100, 소화시간: 2},
    {이름: "닭가슴살", 칼로리: 165, 소화시간: 3},
    {이름: "삼겹살", 칼로리: 330, 소화시간: 4}
];

// 오늘 실제로 먹은 음식 (처음엔 비어있음)
const todayFoods = JSON.parse(localStorage.getItem("todayFoods")) || [];

// 지금 실행 중인 타이머의 번호 (중복 실행 방지용)
let timerId = null;

// 지금 선택된 소화시간 카테고리 값
let selectedDigest = null;

// 지금 수정 중인 "오늘 먹은 음식" 번호 (null이면 수정 중 아님)
let editingTodayIndex = null;

// 지금 전체 편집 모드가 켜져 있는지 (true/false)
let isEditMode = false;

// 러닝 기록 관련 변수 + 저장 배열
const runRecords = JSON.parse(localStorage.getItem("runRecords")) || [];

// 성별 선택 관련 변수
let selectedGender = null;

// 사용자 체중(내 정보 화면에서 입력받은 값)
let userWeight = Number(localStorage.getItem("userWeight")) || 60; 

// 컨디션 메모 기록 (날짜별로 쌓임)
const memoRecords = JSON.parse(localStorage.getItem("memoRecords")) || [];

// 선택된 활동량 계수의 값 
let selectedActivity = null;

// ===== ② HTML 요소 찾아오기 =====

const foodList = document.getElementById("food-list");
const editModeBtn = document.getElementById("edit-mode-btn");
const quickAddList = document.getElementById("quick-add-list");
const mealCompleteBtn = document.getElementById("meal-complete-btn");
const addFoodBtn = document.getElementById("add-food-btn");
const digestButtons = document.querySelectorAll(".digest-btn");
const digestCancelBtn = document.getElementById("digest-cancel-btn");
const runList = document.getElementById("run-list");
const runSaveBtn = document.getElementById("run-save-btn");
const genderButtons = document.querySelectorAll(".gender-btn");
const infoSaveBtn = document.getElementById("info-save-btn");
const memoInput = document.getElementById("condition-memo-input");
const memoSaveBtn = document.getElementById("memo-save-btn");
const memoList = document.getElementById("memo-list");
const activityButtons = document.querySelectorAll(".activity-btn");

// ===== ③ 함수 정의 =====

// 오늘 먹은 음식 목록 + 총 칼로리를 화면에 그리는 함수
function renderFoodList() {
    foodList.innerHTML = "";
    let total = 0;

    todayFoods.forEach(function(food, index) {
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

            card.querySelector(".btn-save-small").addEventListener("click", function() {
                const newName = card.querySelector(".edit-name-input").value;
                const newCalorie = Number(card.querySelector(".edit-calorie-input").value);
                todayFoods[index].이름 = newName;
                todayFoods[index].칼로리 = newCalorie;
                saveTodayFoods();
                editingTodayIndex = null;
                renderFoodList();
            });

            card.querySelector(".btn-cancel-small").addEventListener("click", function() {
                editingTodayIndex = null;
                renderFoodList();
            });

        } else if (isEditMode) {
            // 전체 편집 모드: 수정/삭제 버튼이 바로 보임
            card.innerHTML = `
                <span class="food-text">${food.이름} - ${food.칼로리} kcal</span>
                <button type="button" class="btn-edit-item">수정</button>
                <button type="button" class="btn-delete-item">삭제</button>
            `;
            foodList.appendChild(card);

            card.querySelector(".btn-edit-item").addEventListener("click", function() {
                editingTodayIndex = index;
                renderFoodList();
            });

            card.querySelector(".btn-delete-item").addEventListener("click", function() {
                todayFoods.splice(index, 1);
                saveTodayFoods();
                renderFoodList();
            });

        } else {
            // 평소 모드: 그냥 보기만
            card.innerHTML = `<span class="food-text">${food.이름} - ${food.칼로리} kcal</span>`;
            foodList.appendChild(card);
        }
    });

    document.getElementById("total-calorie").textContent = `오늘 총 섭취: ${total} kcal`;
    const goalCalorie = localStorage.getItem("tdee");
    if (goalCalorie) {
        document.getElementById("home-calorie-value").textContent = `${total} / ${goalCalorie} kcal`;
    }
    else {
        document.getElementById("home-calorie-value").textContent = `${total} kcal`;
    }
}

// 자주 먹는 음식 빠른 추가 버튼 다시 그리기 (삭제 버튼 포함)
function renderQuickAddList() {
    quickAddList.innerHTML = "";

    foods.forEach(function(food, index) {
        const btn = document.createElement("button");
        btn.textContent = food.이름;
        quickAddList.appendChild(btn);

        btn.addEventListener("click", function() {
            todayFoods.push({...food});
            saveTodayFoods();
            renderFoodList();
        });

        const deleteBtn = document.createElement("button");
        deleteBtn.textContent = "❌";
        quickAddList.appendChild(deleteBtn);

        deleteBtn.addEventListener("click", function() {
            foods.splice(index, 1);
            saveFoods();
            renderQuickAddList();
        });
    });
}

function saveFoods() {
    localStorage.setItem("foods", JSON.stringify(foods));
}

function saveTodayFoods() {
    localStorage.setItem("todayFoods", JSON.stringify(todayFoods));
}

//소화 타이머 시작(또는 재개) - 넘겨받은 초부터 카운트다운
function startDigestTimer(startSeconds, endTime) {
    let remainingSeconds = startSeconds;

    if (timerId !== null) {
        clearInterval(timerId);
    }

    timerId = setInterval(function() {
        remainingSeconds -= 1;

        if(remainingSeconds < 0) {
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

//러닝 기록 목록 화면에 그리는 함수
function renderRunList() {
    runList.innerHTML = "";

    runRecords.forEach(function(record,index) {

        const totalMin = Math.floor(record.시간);
        const totalSec = Math.round((record.시간 - totalMin)*60);
        const timeDisplay = totalSec > 0 ? `${totalMin}분 ${totalSec}초` : `${totalMin}분`;

        const paceTotalSec = Math.round((record.시간 / record.거리) * 60);
        const paceMin = Math.floor(paceTotalSec / 60);
        const paceSec = paceTotalSec % 60;
        const paceDisplay = `${paceMin}'${String(paceSec).padStart(2, '0')}"`;

        const card = document.createElement("div");
        card.innerHTML = `
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

        const deleteBtn = document.createElement("button");
        deleteBtn.textContent = "❌";
        card.appendChild(deleteBtn);

        deleteBtn.addEventListener("click", function() {
            runRecords.splice(index, 1);
            saveRunRecords();
            renderRunList();
        });
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

        document.getElementById("home-run-value").textContent = `${latest.거리}km / ${latestTimeDisplay} / 페이스 ${paceDisplay}/km`;
    }
    else {
        document.getElementById("home-run-value").textContent = "아직 기록 없음";
    }
}

function saveRunRecords() {
    localStorage.setItem("runRecords", JSON.stringify(runRecords));
}

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
        genderButtons.forEach(function(b){
            if (b.dataset.gender === savedGender){
                b.classList.add("selected");
            }
        });
    }
    
    if (savedActivity) {
        selectedActivity = Number(savedActivity);
        activityButtons.forEach(function(b){
            if (b.dataset.activity === savedActivity){
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

function renderMemoList() {
    memoList.innerHTML = "";

    memoRecords.forEach(function(memo, index) {
        const card = document.createElement("div");
        card.innerHTML = `<strong>${memo.날짜}</strong><br>${memo.내용}`;
        memoList.appendChild(card);

        const deleteBtn = document.createElement("button");
        deleteBtn.textContent = "❌";
        card.appendChild(deleteBtn);

        deleteBtn.addEventListener("click", function() {
            memoRecords.splice(index, 1);
            localStorage.setItem("memoRecords", JSON.stringify(memoRecords));
            renderMemoList();
        });
    });
}

// ===== ④ 이벤트 리스너 연결 =====

// "식사 완료" 버튼 클릭 시: 가장 오래 걸리는 소화시간을 찾아서 끝나는 시각을 저장하고 타이머 시작
mealCompleteBtn.addEventListener("click", function() {

    let maxTime = 0;
    todayFoods.forEach(function(food) {
        if (food.소화시간 > maxTime) {
            maxTime = food.소화시간;
        }
    });
    
    const totalSeconds = maxTime * 3600;
    const endTime = Date.now() + (totalSeconds * 1000); 
    localStorage.setItem("digestEndTime", endTime);

    startDigestTimer(totalSeconds, endTime);

});

// "타이머 취소" 버튼 클릭 시: 타이머 정지 + 저장된 끝나는 시각 삭제 + 화면 초기화
digestCancelBtn.addEventListener("click", function() {
    if (timerId !== null) {
        clearInterval(timerId);
        timerId = null;
    }
    localStorage.removeItem("digestEndTime");
    document.getElementById("digest-timer").textContent = "--:--:--";
    document.getElementById("home-digest-timer").textContent = "--:--:--";
    document.getElementById("digest-end-time").textContent = "";
    document.getElementById("home-digest-end-time").textContent = "";
    document.getElementById("digest-warning").textContent = "";
    document.getElementById("home-digest-warning").textContent = "";
});

// "편집" 버튼 클릭 시: 전체 편집 모드 켜고 끄기
editModeBtn.addEventListener("click", function() {
    isEditMode = !isEditMode;
    editModeBtn.textContent = isEditMode ? "완료" : "편집";
    editingTodayIndex = null;
    renderFoodList();
});

// 소화시간 카테고리 버튼 클릭 시: 선택 표시 토글 + selectedDigest 값 저장
digestButtons.forEach(function(btn) {
    btn.addEventListener("click", function() {
        digestButtons.forEach(function(b) {
            b.classList.remove("selected");
        });
        btn.classList.add("selected");

        selectedDigest = Number(btn.dataset.digest);
    });
});

// "음식 추가" 버튼 클릭 시: 입력값+선택된 소화시간으로 새 음식을 foods에 추가
addFoodBtn.addEventListener("click", function() {
    if (selectedDigest === null) {
        alert("소화 시간 카테고리를 선택해주세요!");
        return;
    }

    const nameValue = document.getElementById("food-name-input").value;
    const calorieValue = document.getElementById("food-calorie-input").value;

    const newFood = {
        이름: nameValue,
        칼로리: Number(calorieValue),
        소화시간: selectedDigest
    };

    foods.push(newFood);
    saveFoods();
    renderQuickAddList();
});

runSaveBtn.addEventListener("click", function() {
    const distance = Number(document.getElementById("run-distance-input").value);

    const timeValue = (document.getElementById("run-time-input").value);
    const timeParts = timeValue.split(":");
    const minutes = Number(timeParts[0]);
    const seconds = Number(timeParts[1]) || 0;
    const totalMinutes = minutes + (seconds / 60);

    const heartrate = Number(document.getElementById("run-heartrate-input").value);

    const speedKmh = distance / (totalMinutes / 60);

    // 시속에 따라 MET(운동 강도) 값 결정
    // 출처:https://pacompendium.com/running/
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

    // 칼로리 계산: MET * 체중(kg) * 시간
    const caloriesBurned = met * userWeight * (totalMinutes / 60);

    const newRecord = {
        거리: distance,
        시간: totalMinutes,
        심박수: heartrate,
        시속: speedKmh,
        칼로리: caloriesBurned
    };

    runRecords.push(newRecord);
    saveRunRecords();
    renderRunList();
});

// 성별 버튼 클릭 시: 선택 표시 토글 + selectedGender 값 저장
genderButtons.forEach(function(btn) {
    btn.addEventListener("click", function() {
        genderButtons.forEach(function(b) {
            b.classList.remove("selected");
        });
        btn.classList.add("selected");

        selectedGender = btn.dataset.gender;
    });
});

// 활동량 버튼 클릭 시: 선택 표시 토글 + selectedActivity 값 저장
activityButtons.forEach(function(btn) {
    btn.addEventListener("click", function() {
        activityButtons.forEach(function(b) {
            b.classList.remove("selected");
        });
        btn.classList.add("selected");
        selectedActivity = Number(btn.dataset.activity);
    });
});    


// "정보 저장" 버튼 클릭 시: 입력값으로 BMR 계산
// 공식 출처: Mifflin-St Jeor Equation (1990) — 미국 영양학회(Academy of Nutrition and Dietetics) 권장 공식
// 출처: TDEE = BMR × 활동계수(1.2~1.9), 증량은 TDEE+300~500kcal (일반적으로 권장되는 범위)
infoSaveBtn.addEventListener("click", function() {
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

memoSaveBtn.addEventListener("click", function() {
    if (!memoInput.value){
        alert("메모를 작성해주세요!");
        return;
    }
    
    const today = new Date();
    const dateString = today.toLocaleDateString("ko-KR");

    const newMemo = {
        날짜: dateString,
        내용: memoInput.value
    };

    memoRecords.push(newMemo);
    localStorage.setItem("memoRecords", JSON.stringify(memoRecords));
    memoInput.value = "";
    renderMemoList();
});
// 하단 탭 버튼 클릭 시: 해당 화면으로 슬라이드 이동 + 클릭된 탭에 active 스타일 적용
document.addEventListener('DOMContentLoaded', function() {
    document.querySelectorAll(".tab-btn").forEach(function(btn) {
        btn.addEventListener("click", function() {
            const index = Number(btn.dataset.index);
            const screens = document.getElementById("screens");
            screens.style.transform = `translateX(-${index * 100}vw)`;

            document.querySelectorAll(".tab-btn").forEach(function(b) {
                b.classList.remove("active");
            });
            btn.classList.add("active");
        });
    });
});


// ===== ⑤ 초기 실행 =====
renderQuickAddList();
renderFoodList();
renderRunList();
renderInfo();
renderMemoList();

// 페이지 열릴때: 저장된 소화 타이머가 있으면 남은 시간을 계산해서 이어서 시작
const savedEndTime = localStorage.getItem("digestEndTime");
if (savedEndTime) {
    const remaining = Math.round((Number(savedEndTime) - Date.now()) / 1000);
    if (remaining > 0) {
        startDigestTimer(remaining, Number(savedEndTime));
    }
    else {
        localStorage.removeItem("digestEndTime");
        document.getElementById("digest-warning").textContent = "소화 완료! 이제 누우셔도 됩니다!";
        document.getElementById("home-digest-warning").textContent = "소화 완료! 이제 누우셔도 됩니다!";
    }
}
