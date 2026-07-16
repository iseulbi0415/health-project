package com.mjuhealth.backend;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/memos")
@CrossOrigin(origins = "*")
public class MemoController {

    @Autowired
    private MemoRepository memoRepository;

    @PostMapping(produces = "application/json;charset=UTF-8")
    public Memo createMemo(@RequestBody Memo memo) {
        return memoRepository.save(memo);
    }

    @GetMapping(produces = "application/json;charset=UTF-8")
    public List<Memo> getAllMemos() {
        return memoRepository.findAll();
    }

    @PutMapping(value = "/{id}", produces = "application/json;charset=UTF-8")
    public Memo updateMemo(@PathVariable Long id, @RequestBody Memo memo) {
        memo.setId(id);
        return memoRepository.save(memo);
    }

    @DeleteMapping("/{id}")
    public void deleteMemo(@PathVariable Long id) {
        memoRepository.deleteById(id);
    }
}