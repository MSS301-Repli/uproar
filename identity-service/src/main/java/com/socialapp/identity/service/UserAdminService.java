package com.socialapp.identity.service;

import com.socialapp.identity.dto.AuthDtos.UserResponse;
import com.socialapp.identity.dto.PageResponse;
import com.socialapp.identity.exception.ApiException;
import com.socialapp.identity.model.User;
import com.socialapp.identity.repository.RefreshTokenRepository;
import com.socialapp.identity.repository.UserRepository;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** ADMIN-only account management. Role is enforced by the gateway (/api/admin/**). */
@Service
public class UserAdminService {

    private final UserRepository userRepository;
    private final RefreshTokenRepository refreshTokenRepository;

    public UserAdminService(UserRepository userRepository, RefreshTokenRepository refreshTokenRepository) {
        this.userRepository = userRepository;
        this.refreshTokenRepository = refreshTokenRepository;
    }

    @Transactional(readOnly = true)
    public PageResponse<UserResponse> search(String keyword, int page, int size) {
        String q = keyword == null ? "" : keyword.trim();
        PageRequest pageable = PageRequest.of(page, Math.min(size, 50), Sort.by("createdAt").descending());
        return PageResponse.from(
                userRepository.findByUsernameContainingIgnoreCaseOrEmailContainingIgnoreCase(q, q, pageable),
                UserResponse::from);
    }

    /** Locking ends every session at the next refresh; access tokens die within their short lifetime. */
    @Transactional
    public UserResponse lock(Long userId, Long adminId) {
        if (userId.equals(adminId)) {
            throw ApiException.badRequest("You cannot lock your own account");
        }
        User user = find(userId);
        if (user.getRole() == User.Role.ADMIN) {
            throw ApiException.badRequest("Admin accounts cannot be locked");
        }
        user.setStatus(User.Status.LOCKED);
        refreshTokenRepository.revokeAllForUser(userId);
        return UserResponse.from(user);
    }

    @Transactional
    public UserResponse unlock(Long userId) {
        User user = find(userId);
        user.setStatus(User.Status.ACTIVE);
        return UserResponse.from(user);
    }

    private User find(Long userId) {
        return userRepository.findById(userId).orElseThrow(() -> ApiException.notFound("User not found"));
    }
}
