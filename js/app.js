// ===== 자주 먹는 음식 데이터 =====
// 빠른 추가 버튼에 쓰일 음식 목록 (이름 / 칼로리 / 소화시간)
const foods = [
    {이름: "바나나", 칼로리: 100, 소화시간: 2},
    {이름: "닭가슴살", 칼로리: 165, 소화시간: 3},
    {이름: "삼겹살", 칼로리: 330, 소화시간: 4}
];

// ===== 오늘 먹은 음식 기록 =====
// 처음엔 비어있고, 빠른 추가 버튼을 누를 때마다 음식이 하나씩 쌓임
const todayFoods = [];

// 오늘 먹은 음식 카드들이 그려질 상자 (HTML의 #food-list)
const foodList = document.getElementById("food-list");

// "식사 완료" 버튼
const mealCompleteBtn = document.getElementById("meal-complete-btn");

// 지금 실행 중인 타이머의 번호를 기억해두는 변수
// (여러 번 클릭해도 타이머가 중복 실행되지 않도록 막는 용도)
let timerId = null;

// ===== 소화 타이머 로직 =====
// "식사 완료" 버튼 클릭 시: 오늘 먹은 음식 중 가장 오래 걸리는 소화시간을 찾아서
// 그 시간만큼 카운트다운 타이머를 시작함
mealCompleteBtn.addEventListener("click", function() {

    // 오늘 먹은 음식들 중 가장 긴 소화시간 찾기
    let maxTime = 0;
    todayFoods.forEach(function(food) {
        if (food.소화시간 > maxTime) {
            maxTime = food.소화시간;
        }
    });

    // 찾은 시간(시간 단위)을 초 단위로 변환
    let remainingSeconds = maxTime * 3600;

    // 이미 돌아가는 타이머가 있으면 먼저 꺼서, 타이머가 여러 개 겹치지 않게 함
    if (timerId !== null) {
        clearInterval(timerId);
    }
    
    // 1초마다 반복 실행되는 카운트다운
    timerId = setInterval(function() {
        remainingSeconds -= 1;

        // 혹시 마이너스로 내려가면 0으로 보정 (안전장치)
        if (remainingSeconds < 0) {
            remainingSeconds = 0;
        }

        // 남은 초를 시/분/초로 변환
        const hours = Math.floor(remainingSeconds / 3600);
        const minutes = Math.floor((remainingSeconds % 3600) / 60);
        const seconds = remainingSeconds % 60;

        // 한 자리 숫자는 앞에 0을 붙여 두 자리로 맞춤 (예: 4 → 04)
        const hh = String(hours).padStart(2, '0');
        const mm = String(minutes).padStart(2, '0');
        const ss = String(seconds).padStart(2, '0');

        // 화면에 시:분:초 표시
        document.getElementById("digest-timer").textContent = `${hh}:${mm}:${ss}`;

        // 시간이 다 됐는지에 따라 타이머 종료 + 안내 문구 전환
        if (remainingSeconds <= 0) {
            clearInterval(timerId); // 0에 도달했으니 자기 자신을 멈춤
            document.getElementById("digest-warning").textContent = "소화 완료! 이제 누우셔도 됩니다!";
        }
        else {
            document.getElementById("digest-warning").textContent = "🙅‍♀️ 아직 눕지 마세요!";
        }
        
    }, 1000);
});

// ===== 오늘 먹은 음식 목록 화면에 그리기 =====
// todayFoods 배열이 바뀔 때마다(음식 추가될 때마다) 호출되는 함수
// 화면을 통째로 비우고, 배열 내용을 처음부터 다시 그려서 항상 최신 상태로 맞춤
function renderFoodList() {
    foodList.innerHTML = ""; // 기존 화면 내용 비우기 (중복 방지)
    let total = 0;

    todayFoods.forEach(function(food){
        foodList.innerHTML += `<div>${food.이름} - ${food.칼로리} kcal</div>`;
        total += food.칼로리; // 칼로리 누적 합산
    });

    // 합산된 총 칼로리를 화면에 표시
    document.getElementById("total-calorie").textContent = `오늘 총 섭취: ${total} kcal`;
}

// ===== 빠른 추가 버튼 만들기 =====
// 빠른 추가 버튼들이 들어갈 상자 (HTML의 #quick-add-list)
const quickAddList = document.getElementById("quick-add-list");

// foods 데이터를 기반으로, 음식마다 버튼을 자동으로 하나씩 생성
foods.forEach(function(food) {
    const btn = document.createElement("button");
    btn.textContent = food.이름;
    quickAddList.appendChild(btn); 

    // 이 버튼 클릭 시: 이 버튼에 해당하는 음식을 todayFoods에 추가하고 화면 갱신
    btn.addEventListener("click", function() {
        todayFoods.push(food);
        renderFoodList();
    });
});

// ===== 하단 탭바 화면 전환 =====
// 탭 버튼 클릭 시: 해당 화면으로 슬라이드 이동 + 클릭된 탭에 active 스타일 적용
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
