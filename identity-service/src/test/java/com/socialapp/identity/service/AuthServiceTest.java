package com.socialapp.identity.service;

import com.socialapp.identity.dto.AuthDtos.AuthResponse;
import com.socialapp.identity.dto.AuthDtos.LoginRequest;
import com.socialapp.identity.dto.AuthDtos.RegisterRequest;
import com.socialapp.identity.exception.ApiException;
import com.socialapp.identity.model.RefreshToken;
import com.socialapp.identity.model.User;
import com.socialapp.identity.repository.RefreshTokenRepository;
import com.socialapp.identity.repository.UserRepository;
import com.socialapp.identity.security.JwtService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class AuthServiceTest {

    @Mock
    private UserRepository userRepository;
    @Mock
    private RefreshTokenRepository refreshTokenRepository;

    private final PasswordEncoder passwordEncoder = new BCryptPasswordEncoder(4); // low cost = fast tests
    private AuthService authService;

    @BeforeEach
    void setUp() {
        JwtService jwtService = new JwtService("test-secret-that-is-at-least-32-characters", 15);
        authService = new AuthService(userRepository, refreshTokenRepository, passwordEncoder, jwtService, 7);
    }

    private User user(long id, String rawPassword, User.Status status) {
        User u = new User("anna@test.com", "anna", passwordEncoder.encode(rawPassword), User.Role.USER);
        u.setId(id);
        u.setStatus(status);
        return u;
    }

    @Test
    void register_duplicateEmail_conflict() {
        when(userRepository.existsByEmailIgnoreCase("anna@test.com")).thenReturn(true);

        assertThatThrownBy(() -> authService.register(new RegisterRequest("anna@test.com", "anna", "password1")))
                .isInstanceOfSatisfying(ApiException.class, e -> assertThat(e.getStatus()).isEqualTo(HttpStatus.CONFLICT));
        verify(userRepository, never()).save(any());
    }

    @Test
    void register_storesBcryptHash_andAlwaysRoleUser() {
        when(userRepository.save(any(User.class))).thenAnswer(inv -> {
            User saved = inv.getArgument(0);
            saved.setId(1L);
            return saved;
        });

        AuthResponse response = authService.register(new RegisterRequest("Anna@Test.com", "anna", "password1"));

        assertThat(response.role()).isEqualTo("USER");
        assertThat(response.accessToken()).isNotBlank();
        assertThat(response.refreshToken()).isNotBlank();
        verify(userRepository).save(argThat(u ->
                u.getEmail().equals("anna@test.com") && passwordEncoder.matches("password1", u.getPasswordHash())));
    }

    @Test
    void login_wrongPassword_unauthorized() {
        when(userRepository.findByEmailIgnoreCase("anna@test.com"))
                .thenReturn(Optional.of(user(1L, "password1", User.Status.ACTIVE)));

        assertThatThrownBy(() -> authService.login(new LoginRequest("anna@test.com", "wrong-password")))
                .isInstanceOfSatisfying(ApiException.class, e -> assertThat(e.getStatus()).isEqualTo(HttpStatus.UNAUTHORIZED));
    }

    @Test
    void login_lockedAccount_forbidden() {
        when(userRepository.findByEmailIgnoreCase("anna@test.com"))
                .thenReturn(Optional.of(user(1L, "password1", User.Status.LOCKED)));

        assertThatThrownBy(() -> authService.login(new LoginRequest("anna@test.com", "password1")))
                .isInstanceOfSatisfying(ApiException.class, e -> assertThat(e.getStatus()).isEqualTo(HttpStatus.FORBIDDEN));
    }

    @Test
    void refresh_rotatesToken_oldOneRevoked() {
        RefreshToken old = new RefreshToken("old-token", 1L, Instant.now().plus(1, ChronoUnit.DAYS));
        when(refreshTokenRepository.findByToken("old-token")).thenReturn(Optional.of(old));
        when(userRepository.findById(1L)).thenReturn(Optional.of(user(1L, "password1", User.Status.ACTIVE)));

        AuthResponse response = authService.refresh("old-token");

        assertThat(old.isRevoked()).isTrue();
        assertThat(response.refreshToken()).isNotEqualTo("old-token");
    }

    @Test
    void refresh_expiredToken_unauthorized() {
        RefreshToken expired = new RefreshToken("old-token", 1L, Instant.now().minus(1, ChronoUnit.MINUTES));
        when(refreshTokenRepository.findByToken("old-token")).thenReturn(Optional.of(expired));

        assertThatThrownBy(() -> authService.refresh("old-token"))
                .isInstanceOfSatisfying(ApiException.class, e -> assertThat(e.getStatus()).isEqualTo(HttpStatus.UNAUTHORIZED));
    }
}
