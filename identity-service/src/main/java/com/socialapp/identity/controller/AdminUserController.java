package com.socialapp.identity.controller;

import com.socialapp.identity.dto.AuthDtos.UserResponse;
import com.socialapp.identity.dto.PageResponse;
import com.socialapp.identity.service.UserAdminService;
import org.springframework.web.bind.annotation.*;

/** Reachable only with role ADMIN: the gateway guards /api/admin/**. */
@RestController
@RequestMapping("/api/admin/users")
public class AdminUserController {

    private final UserAdminService userAdminService;

    public AdminUserController(UserAdminService userAdminService) {
        this.userAdminService = userAdminService;
    }

    @GetMapping
    public PageResponse<UserResponse> search(@RequestParam(required = false) String search,
                                             @RequestParam(defaultValue = "0") int page,
                                             @RequestParam(defaultValue = "20") int size) {
        return userAdminService.search(search, page, size);
    }

    @PutMapping("/{id}/lock")
    public UserResponse lock(@PathVariable Long id, @RequestHeader("X-User-Id") Long adminId) {
        return userAdminService.lock(id, adminId);
    }

    @PutMapping("/{id}/unlock")
    public UserResponse unlock(@PathVariable Long id) {
        return userAdminService.unlock(id);
    }
}
