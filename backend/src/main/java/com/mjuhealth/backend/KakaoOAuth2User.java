package com.mjuhealth.backend;

import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.oauth2.core.user.OAuth2User;

import java.util.Collection;
import java.util.Map;

// principal.getAttribute("internalUserId") 같은 Object 캐스팅 없이 컨트롤러에서
// principal.getInternalUserId()로 바로 꺼내 쓰기 위한 래퍼
public class KakaoOAuth2User implements OAuth2User {

    private final OAuth2User delegate;
    private final Long internalUserId;

    public KakaoOAuth2User(OAuth2User delegate, Long internalUserId) {
        this.delegate = delegate;
        this.internalUserId = internalUserId;
    }

    public Long getInternalUserId() {
        return internalUserId;
    }

    @Override
    public Map<String, Object> getAttributes() {
        return delegate.getAttributes();
    }

    @Override
    public Collection<? extends GrantedAuthority> getAuthorities() {
        return delegate.getAuthorities();
    }

    @Override
    public String getName() {
        return delegate.getName();
    }
}
