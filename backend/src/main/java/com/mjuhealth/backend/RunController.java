package com.mjuhealth.backend;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;

@RestController
@RequestMapping("/api/runs")
public class RunController {

    @Autowired
    private RunRepository runRepository;
    @Autowired
    private UserRepository userRepository;

    @PostMapping(produces = "application/json;charset=UTF-8")
    public Run createRun(@RequestBody Run run, @AuthenticationPrincipal KakaoOAuth2User principal) {
        // 요청에 recordedAt이 이미 있으면(달력에서 과거 날짜 지정) 그 값을 존중하고,
        // 없으면(평소처럼 러닝 탭에서 "방금 뛰었어요") 서버 현재 시각을 기본값으로 채움
        if (run.getRecordedAt() == null) {
            run.setRecordedAt(LocalDateTime.now());
        }
        run.setUser(userRepository.findById(principal.getInternalUserId()).orElseThrow());
        return runRepository.save(run);
    }

    @GetMapping(produces = "application/json;charset=UTF-8")
    public List<Run> getAllRuns(@RequestParam(required = false) String date, @AuthenticationPrincipal KakaoOAuth2User principal) {
        if (date != null) {
            LocalDate day = LocalDate.parse(date);
            return runRepository.findByUserIdAndRecordedAtGreaterThanEqualAndRecordedAtLessThan(
                    principal.getInternalUserId(), day.atStartOfDay(), day.plusDays(1).atStartOfDay());
        }
        return runRepository.findByUserId(principal.getInternalUserId());
    }

    @PutMapping(value = "/{id}", produces = "application/json;charset=UTF-8")
    public Run updateRun(@PathVariable Long id, @RequestBody Run run, @AuthenticationPrincipal KakaoOAuth2User principal) {
        Run existing = runRepository.findById(id).orElseThrow();
        if (!existing.getUser().getId().equals(principal.getInternalUserId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN);
        }
        run.setId(id);
        run.setUser(existing.getUser());
        // 요청 바디에 recordedAt이 없으면(null) 기존 값 유지 — 프론트가 아직 이 값을 안 보내므로
        // 그대로 두면 수정할 때마다 시각이 null로 덮어써짐
        if (run.getRecordedAt() == null) {
            run.setRecordedAt(existing.getRecordedAt());
        }
        return runRepository.save(run);
    }

    @DeleteMapping("/{id}")
    public void deleteRun(@PathVariable Long id, @AuthenticationPrincipal KakaoOAuth2User principal) {
        Run existing = runRepository.findById(id).orElseThrow();
        if (!existing.getUser().getId().equals(principal.getInternalUserId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN);
        }
        runRepository.deleteById(id);
    }
}
