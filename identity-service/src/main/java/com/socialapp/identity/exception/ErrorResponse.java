package com.socialapp.identity.exception;

import org.springframework.http.HttpStatus;

import java.time.Instant;

/** Error body shared by every service: { timestamp, status, error, message, path }. */
public record ErrorResponse(Instant timestamp, int status, String error, String message, String path) {

    public static ErrorResponse of(HttpStatus status, String message, String path) {
        return new ErrorResponse(Instant.now(), status.value(), status.getReasonPhrase(), message, path);
    }
}
