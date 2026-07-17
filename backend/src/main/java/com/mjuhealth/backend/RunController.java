package com.mjuhealth.backend;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.List;

@RestController
@RequestMapping("/api/runs")
@CrossOrigin(origins = "*")

public class RunController {

    @Autowired
    private RunRepository runRepository;

    @PostMapping(produces = "application/json;charset=UTF-8")
    public Run createRun(@RequestBody Run run) {
        // 저장 시각은 클라이언트가 보내도 무시하고 서버 기준 현재 시각으로 고정
        run.setRecordedAt(LocalDateTime.now());
        return runRepository.save(run);
    }

    @GetMapping(produces = "application/json;charset=UTF-8")
    public List<Run> getAllRuns() {
        return runRepository.findAll();
    }

    @PutMapping(value = "/{id}", produces = "application/json;charset=UTF-8")
    public Run updateRun(@PathVariable Long id, @RequestBody Run run) {
        Run existing = runRepository.findById(id).orElseThrow();
        run.setId(id);
        // 요청 바디에 recordedAt이 없으면(null) 기존 값 유지 — 프론트가 아직 이 값을 안 보내므로
        // 그대로 두면 수정할 때마다 시각이 null로 덮어써짐
        if (run.getRecordedAt() == null) {
            run.setRecordedAt(existing.getRecordedAt());
        }
        return runRepository.save(run);
    }

    @DeleteMapping("/{id}")
    public void deleteRun(@PathVariable Long id) {
        runRepository.deleteById(id);
    }
}
