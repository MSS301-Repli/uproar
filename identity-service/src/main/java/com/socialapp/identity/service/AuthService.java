package com.socialapp.identity.service;

import com.socialapp.identity.dto.AuthDtos.AuthResponse;
import com.socialapp.identity.dto.AuthDtos.LoginRequest;
import com.socialapp.identity.dto.AuthDtos.RegisterRequest;
import com.socialapp.identity.dto.AuthDtos.UserResponse;
import com.socialapp.identity.exception.ApiException;
import com.socialapp.identity.model.RefreshToken;
import com.socialapp.identity.model.User;
import com.socialapp.identity.repository.RefreshTokenRepository;
import com.socialapp.identity.repository.UserRepository;
import com.socialapp.identity.security.JwtService;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.UUID;

@Service
public class AuthService {

    private final UserRepository userRepository;
    private final RefreshTokenRepository refreshTokenRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    private final long refreshTokenDays;

    public AuthService(UserRepository userRepository,
                       RefreshTokenRepository refreshTokenRepository,
                       PasswordEncoder passwordEncoder,
                       JwtService jwtService,
                       @Value("${app.jwt.refresh-token-days}") long refreshTokenDays) {
        this.userRepository = userRepository;
        this.refreshTokenRepository = refreshTokenRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtService = jwtService;
        this.refreshTokenDays = refreshTokenDays;
    }

    /** Public sign-up always creates a USER; ADMIN accounts only come from AdminSeeder. */
    @Transactional
    public AuthResponse register(RegisterRequest request) {
        if (userRepository.existsByEmailIgnoreCase(request.email())) {
            throw ApiException.conflict("Email is already registered");
        }
        if (userRepository.existsByUsernameIgnoreCase(request.username())) {
            throw ApiException.conflict("Username is already taken");
        }
        User user = userRepository.save(new User(
                request.email().trim().toLowerCase(),
                request.username().trim(),
                passwordEncoder.encode(request.password()),
                User.Role.USER));
        // TODO(W6, profile-service owner): call profile-service via OpenFeign to create the empty profile
        return issueTokens(user);
    }

    @Transactional
    public AuthResponse login(LoginRequest request) {
        // Same message for "no such email" and "wrong password": do not reveal which emails exist
        User user = userRepository.findByEmailIgnoreCase(request.email())
                .orElseThrow(() -> ApiException.unauthorized("Invalid email or password"));
        if (!passwordEncoder.matches(request.password(), user.getPasswordHash())) {
            throw ApiException.unauthorized("Invalid email or password");
        }
        if (user.isLocked()) {
            throw ApiException.forbidden("Your account is locked. Please contact the administrator.");
        }
        return issueTokens(user);
    }

    /** Rotation: the old refresh token is revoked and a new pair is returned (BR-06: locked users are refused). */
    @Transactional
    public AuthResponse refresh(String refreshToken) {
        RefreshToken stored = refreshTokenRepository.findByToken(refreshToken)
                .filter(token -> token.isUsable(Instant.now()))
                .orElseThrow(() -> ApiException.unauthorized("Refresh token is invalid or expired"));
        stored.revoke();

        User user = userRepository.findById(stored.getUserId())
                .orElseThrow(() -> ApiException.unauthorized("Refresh token is invalid or expired"));
        if (user.isLocked()) {
            throw ApiException.forbidden("Your account is locked. Please contact the administrator.");
        }
        return issueTokens(user);
    }

    @Transactional
    public void logout(String refreshToken) {
        refreshTokenRepository.findByToken(refreshToken).ifPresent(RefreshToken::revoke);
    }

    @Transactional(readOnly = true)
    public UserResponse me(Long userId) {
        return userRepository.findById(userId)
                .map(UserResponse::from)
                .orElseThrow(() -> ApiException.notFound("User not found"));
    }

    private AuthResponse issueTokens(User user) {
        String refresh = UUID.randomUUID().toString();
        refreshTokenRepository.save(new RefreshToken(
                refresh, user.getId(), Instant.now().plus(refreshTokenDays, ChronoUnit.DAYS)));
        return new AuthResponse(
                jwtService.generateAccessToken(user),
                refresh,
                "Bearer",
                jwtService.getAccessTokenSeconds(),
                user.getId(),
                user.getUsername(),
                user.getRole().name());
    }
}
