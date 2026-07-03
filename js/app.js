// ===== ① 데이터 =====

// 자주 먹는 음식 목록 (이름 / 칼로리 / 소화시간)
const foods = JSON.parse(localStorage.getItem("foods")) || [
    {이름: "바나나", 칼로리: 100, 소화시간: 2},
    {이름: "닭가슴살", 칼로리: 165, 소화시간: 3},
    {이름: "삼겹살", 칼로리: 330, 소화시간: 4}
];

// 오늘 실제로 먹은 음식 (처음엔 비어있음)
const todayFoods = [];

// 지금 실행 중인 타이머의 번호 (중복 실행 방지용)
let timerId = null;

// 지금 선택된 소화시간 카테고리 값
let selectedDigest = null;

// 러닝 기록 관련 변수 + 저장 배열
const runRecords = JSON.parse(localStorage.getItem("runRecords")) || [];


// ===== ② HTML 요소 찾아오기 =====

const foodList = document.getElementById("food-list");
const quickAddList = document.getElementById("quick-add-list");
const mealCompleteBtn = document.getElementById("meal-complete-btn");
const addFoodBtn = document.getElementById("add-food-btn");
const digestButtons = document.querySelectorAll(".digest-btn");
const runList = document.getElementById("run-list");
const runSaveBtn = document.getElementById("run-save-btn");


// ===== ③ 함수 정의 =====

// 오늘 먹은 음식 목록 + 총 칼로리를 화면에 그리는 함수
function renderFoodList() {
    foodList.innerHTML = ""; // 기존 화면 내용 비우기 (중복 방지)
    let total = 0;

    todayFoods.forEach(function(food){
        foodList.innerHTML += `<div>${food.이름} - ${food.칼로리} kcal</div>`;
        total += food.칼로리; // 칼로리 누적 합산
    });

    document.getElementById("total-calorie").textContent = `오늘 총 섭취: ${total} kcal`;
}

// 자주 먹는 음식 빠른 추가 버튼 다시 그리기 (삭제 버튼 포함)
function renderQuickAddList() {
    quickAddList.innerHTML = "";

    foods.forEach(function(food, index) {
        const btn = document.createElement("button");
        btn.textContent = food.이름;
        quickAddList.appendChild(btn);

        btn.addEventListener("click", function() {
            todayFoods.push(food);
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

//러닝 기록 목록 화면에 그리는 함수
function renderRunList() {
    runList.innerHTML = "";

    runRecords.forEach(function(record,index) {
        const card = document.createElement("div");
        card.innerHTML = `
        <div>
            거리: ${record.거리}km 
            시간: ${record.시간.toFixed(1)}분 
            시속: ${record.시속.toFixed(1)}km/h 
            심박수: ${record.심박수}bpm 
            칼로리: ${record.칼로리.toFixed(0)}kcal
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
}

function saveRunRecords() {
    localStorage.setItem("runRecords", JSON.stringify(runRecords));
}


// ===== ④ 이벤트 리스너 연결 =====

// "식사 완료" 버튼 클릭 시: 가장 오래 걸리는 소화시간을 찾아서 카운트다운 시작
mealCompleteBtn.addEventListener("click", function() {

    let maxTime = 0;
    todayFoods.forEach(function(food) {
        if (food.소화시간 > maxTime) {
            maxTime = food.소화시간;
        }
    });

    let remainingSeconds = maxTime * 3600;

    if (timerId !== null) {
        clearInterval(timerId);
    }

    timerId = setInterval(function() {
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

        if (remainingSeconds <= 0) {
            clearInterval(timerId);
            document.getElementById("digest-warning").textContent = "소화 완료! 이제 누우셔도 됩니다!";
        }
        else {
            document.getElementById("digest-warning").textContent = "🙅‍♀️ 아직 눕지 마세요!";
        }

    }, 1000);
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
    const seconds = Number(timeParts[1]);
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

    const tempWeight = 60;
    // 칼로리 계산: MET * 체중(kg) * 시간
    const caloriesBurned = met * tempWeight * (totalMinutes / 60);

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
renderRunList();
