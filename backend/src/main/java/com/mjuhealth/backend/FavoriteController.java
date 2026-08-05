package com.mjuhealth.backend;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;

@RestController
@RequestMapping("/api/favorites")
public class FavoriteController {

    @Autowired
    private FavoriteRepository favoriteRepository;
    @Autowired
    private UserRepository userRepository;

    @PostMapping(produces = "application/json;charset=UTF-8")
    public Favorite createFavorite(@RequestBody Favorite favorite, @AuthenticationPrincipal KakaoOAuth2User principal) {
        favorite.setUser(userRepository.findById(principal.getInternalUserId()).orElseThrow());
        return favoriteRepository.save(favorite);
    }

    @GetMapping(produces = "application/json;charset=UTF-8")
    public List<Favorite> getFavorites(@AuthenticationPrincipal KakaoOAuth2User principal) {
        return favoriteRepository.findByUserId(principal.getInternalUserId());
    }

    @PutMapping(value = "/{id}", produces = "application/json;charset=UTF-8")
    public Favorite updateFavorite(@PathVariable Long id, @RequestBody Favorite favorite,
                                    @AuthenticationPrincipal KakaoOAuth2User principal) {
        Favorite existing = favoriteRepository.findById(id).orElseThrow();
        // id만 바꿔서 남의 기록에 접근하는 걸 막는 소유권 확인
        if (!existing.getUser().getId().equals(principal.getInternalUserId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN);
        }
        favorite.setId(id);
        favorite.setUser(existing.getUser());
        return favoriteRepository.save(favorite);
    }

    @DeleteMapping("/{id}")
    public void deleteFavorite(@PathVariable Long id, @AuthenticationPrincipal KakaoOAuth2User principal) {
        Favorite existing = favoriteRepository.findById(id).orElseThrow();
        if (!existing.getUser().getId().equals(principal.getInternalUserId())) {
            throw new ResponseStatusException(HttpStatus.FORBIDDEN);
        }
        favoriteRepository.deleteById(id);
    }
}
