package com.socialapp.identity.dto;

import com.socialapp.identity.model.User;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

import java.time.Instant;

/** Request/response bodies of identity-service, grouped in one file because each is a one-line record. */
public final class AuthDtos {

    private AuthDtos() {
    }

    public record RegisterRequest(
            @NotBlank @Email @Size(max = 255) String email,
            @NotBlank @Pattern(regexp = "^[a-zA-Z0-9_.]{3,30}$",
                    message = "3-30 characters: letters, digits, '_' or '.'") String username,
            @NotBlank @Size(min = 8, max = 72, message = "must be 8-72 characters") String password) {
    }

    public record LoginRequest(@NotBlank @Email String email, @NotBlank String password) {
    }

    public record RefreshRequest(@NotBlank String refreshToken) {
    }

    public record AuthResponse(
            String accessToken,
            String refreshToken,
            String tokenType,
            long expiresIn,
            Long userId,
            String username,
            String role) {
    }

    public record UserResponse(Long id, String email, String username, String role, String status, Instant createdAt) {

        public static UserResponse from(User user) {
            return new UserResponse(user.getId(), user.getEmail(), user.getUsername(),
                    user.getRole().name(), user.getStatus().name(), user.getCreatedAt());
        }
    }
}
