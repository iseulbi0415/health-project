package com.mjuhealth.backend;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;

@RestController
@RequestMapping("/api/memos")
public class MemoController {

    @Autowired
    private MemoRepository memoRepository;
    @Autowired
    private UserRepository userRepository;

    @PostMapping(produces = "application/json;charset=UTF-8")
    public Memo createMemo(@RequestBody Memo memo, @AuthenticationPrincipal KakaoOAuth2User principal) {
        memo.setUser(userRepository.findById(principal.getInternalUserId()).orElseThrow());
        return memoRepository.save(memo);
    }

    @GetMapping(produces = "application/json;charset=UTF-8")
    public List<Memo> getAllMemos(@AuthenticationPrincipal KakaoOAuth2User principal) {
        return memoRepository.findByUserId(principal.getInternalUserId());
    }

    @PutMapping(value = "/{id}", produces = "application/json;charset=UTF-8")
    public Memo updateMemo(@PathVariable Long id, @RequestBody Memo memo, @AuthenticationPrincipal KakaoOAuth2User principal) {
        Memo existing = memoRepository.findById(id).orElseThrow();
        if (!existing.getUser().getId().equals(principal.getInternalUserId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN);
        }
        memo.setId(id);
        memo.setUser(existing.getUser());
        return memoRepository.save(memo);
    }

    @DeleteMapping("/{id}")
    public void deleteMemo(@PathVariable Long id, @AuthenticationPrincipal KakaoOAuth2User principal) {
        Memo existing = memoRepository.findById(id).orElseThrow();
        if (!existing.getUser().getId().equals(principal.getInternalUserId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN);
        }
        memoRepository.deleteById(id);
    }
}
