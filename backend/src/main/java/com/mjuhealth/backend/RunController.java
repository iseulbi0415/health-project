package com.mjuhealth.backend;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/runs")
@CrossOrigin(origins = "*")

public class RunController {

    @Autowired
    private RunRepository runRepository;

    @PostMapping(produces = "application/json;charset=UTF-8")
    public Run createRun(@RequestBody Run run) {
        return runRepository.save(run);
    }

    @GetMapping(produces = "application/json;charset=UTF-8")
    public List<Run> getAllRuns() {
        return runRepository.findAll();
    }

    @PutMapping(value = "/{id}", produces = "application/json;charset=UTF-8")
    public Run updateRun(@PathVariable Long id, @RequestBody Run run) {
        run.setId(id);
        return runRepository.save(run);
    }

    @DeleteMapping("/{id}")
    public void deleteRun(@PathVariable Long id) {
        runRepository.deleteById(id);
    }
}
