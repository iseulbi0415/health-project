package com.mjuhealth.backend;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.YearMonth;
import java.util.List;
import java.util.Set;
import java.util.TreeSet;

// 식단 화면 달력에서 "이 달에 기록이 있는 날짜"를 표시하기 위한 조회 전용 집계 API.
// 자기 소유 Entity가 없어서 Food/Run/Memo Repository를 그대로 재사용함 (새 Entity를 만들지 않음)
@RestController
@RequestMapping("/api/records")
public class RecordSummaryController {

    @Autowired
    private FoodRepository foodRepository;
    @Autowired
    private RunRepository runRepository;
    @Autowired
    private MemoRepository memoRepository;

    @GetMapping(value = "/summary", produces = "application/json;charset=UTF-8")
    public Set<String> getMonthSummary(@RequestParam int year, @RequestParam int month,
                                        @AuthenticationPrincipal KakaoOAuth2User principal) {
        Long userId = principal.getInternalUserId();
        YearMonth ym = YearMonth.of(year, month);
        var monthStart = ym.atDay(1).atStartOfDay();
        var monthEnd = ym.plusMonths(1).atDay(1).atStartOfDay();
        String monthStartStr = ym.atDay(1).toString();
        String monthEndStr = ym.atEndOfMonth().toString();

        List<Food> foods = foodRepository.findByUserIdAndRecordedAtGreaterThanEqualAndRecordedAtLessThan(userId, monthStart, monthEnd);
        List<Run> runs = runRepository.findByUserIdAndRecordedAtGreaterThanEqualAndRecordedAtLessThan(userId, monthStart, monthEnd);
        List<Memo> memos = memoRepository.findByUserIdAndDateBetween(userId, monthStartStr, monthEndStr);

        Set<String> markedDates = new TreeSet<>();
        foods.forEach(f -> markedDates.add(f.getRecordedAt().toLocalDate().toString()));
        runs.forEach(r -> markedDates.add(r.getRecordedAt().toLocalDate().toString()));
        memos.forEach(m -> markedDates.add(m.getDate()));

        return markedDates;
    }
}
