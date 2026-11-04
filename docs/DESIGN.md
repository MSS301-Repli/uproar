# Thiết kế hệ thống — Uproar

Nguồn sự thật về nghiệp vụ và hợp đồng API giữa các service. Đổi API → cập nhật file này trong cùng PR.

## Mục lục

1. [Vai trò](#1-vai-trò)
2. [Service & sở hữu dữ liệu](#2-service--sở-hữu-dữ-liệu)
3. [Quy tắc nghiệp vụ](#3-quy-tắc-nghiệp-vụ)
4. [API công khai (qua gateway)](#4-api-công-khai-qua-gateway)
5. [API nội bộ (service gọi service)](#5-api-nội-bộ-service-gọi-service)
6. [Sự kiện RabbitMQ](#6-sự-kiện-rabbitmq)
7. [Màn hình Flutter](#7-màn-hình-flutter)
8. [Ngoài scope](#8-ngoài-scope)
9. [Vấn đề chưa chốt](#9-vấn-đề-chưa-chốt)

## 1. Vai trò

| Vai trò | Chức năng |
|---|---|
| USER | Đăng ký/đăng nhập, feed, đăng bài (ảnh + vị trí), like, comment, báo cáo bài, follow, profile, bản đồ bài viết, chat 1-1, thông báo |
| ADMIN | Tìm & khóa/mở khóa tài khoản, xem bài bị báo cáo, ẩn/hiện bài, thống kê đơn giản |

## 2. Service & sở hữu dữ liệu

| Service | Port | DB | Dữ liệu sở hữu | Chủ |
|---|---|---|---|---|
| identity-service | 8081 | MySQL `identity_db` | users (email, username, password hash, role, status), refresh_tokens | 1 |
| profile-service | 8082 | MySQL `profile_db` | profiles (userId, displayName, avatarUrl, bio), follows (followerId, followingId) | 2 |
| post-service | 8083 | MySQL `post_db` | posts (authorId, content, imageUrls, lat/lng, hidden), comments, likes, reports | 3 |
| notification-service | 8084 | MySQL `notification_db` | notifications (recipientId, actorId, type, targetId, read) | 4 |
| chat-service | 8085 | MongoDB `chat_db` | conversations (participantIds), messages | 5 |

Không khóa ngoại giữa các DB. Tham chiếu chéo chỉ bằng ID (`userId` = `users.id` của identity-service).

## 3. Quy tắc nghiệp vụ

| Mã | Quy tắc | Service kiểm tra |
|---|---|---|
| BR-01 | Không tự follow chính mình; follow trùng bị từ chối (409) | profile |
| BR-02 | Mỗi user like 1 bài tối đa 1 lần; bấm lại = unlike | post |
| BR-03 | Chỉ chủ bài hoặc ADMIN được xóa bài; chỉ ADMIN ẩn/hiện bài | post |
| BR-04 | Nội dung bài 1–2000 ký tự, tối đa 4 ảnh, mỗi ảnh ≤ 5MB | post |
| BR-05 | Chỉ chat được với người follow lẫn nhau | chat (hỏi profile) |
| BR-06 | Tài khoản bị khóa không đăng nhập/refresh được; access token cũ hết hạn sau ≤ 15 phút | identity ✅ |
| BR-07 | Bài bị ≥ 5 báo cáo (từ 5 user khác nhau) tự ẩn, chờ ADMIN xét | post |
| BR-08 | Không tạo thông báo cho hành động lên chính mình | notification |
| BR-09 | Feed phân trang 10 bài/trang, mới nhất trước; bài ẩn không xuất hiện | post |

## 4. API công khai (qua gateway)

Gateway: `http://<host>:8080`. Tất cả cần `Authorization: Bearer <accessToken>` trừ khi ghi "public".
Phân trang: `?page=0&size=10` → `PageResponse {content, page, size, totalElements, totalPages}`.
Lỗi: `{timestamp, status, error, message, path}`.

**identity-service** — ✅ đã làm

| Method | Path | Ghi chú |
|---|---|---|
| POST | `/api/auth/register` | public. `{email, username, password}` → AuthResponse |
| POST | `/api/auth/login` | public. `{email, password}` → `{accessToken, refreshToken, tokenType, expiresIn, userId, username, role}` |
| POST | `/api/auth/refresh` | public. `{refreshToken}` → AuthResponse mới (token cũ bị thu hồi) |
| POST | `/api/auth/logout` | `{refreshToken}` → 204 |
| GET | `/api/auth/me` | `{id, email, username, role, status, createdAt}` |
| GET | `/api/admin/users?search=` | ADMIN, phân trang |
| PUT | `/api/admin/users/{id}/lock` · `/unlock` | ADMIN |

**profile-service** — đề xuất (chủ 2 chốt)

| Method | Path | Ghi chú |
|---|---|---|
| GET | `/api/profiles/me` · `/api/profiles/{userId}` | profile + số follower/following + `followedByMe` |
| PUT | `/api/profiles/me` | `{displayName, bio, avatarUrl}` |
| GET | `/api/profiles?search=` | tìm user, phân trang |
| POST / DELETE | `/api/profiles/{userId}/follow` | BR-01 |
| GET | `/api/profiles/{userId}/followers` · `/following` | phân trang |

**post-service** — đề xuất (chủ 3 chốt)

| Method | Path | Ghi chú |
|---|---|---|
| GET | `/api/posts?scope=following\|all&page=` | feed, BR-09 |
| GET | `/api/posts/nearby?minLat=&maxLat=&minLng=&maxLng=` | bài có vị trí trong khung bản đồ |
| GET | `/api/posts/{id}` · `/api/posts/{id}/comments` | |
| GET | `/api/posts?authorId=` | bài của 1 user |
| POST | `/api/posts` | BR-04 |
| DELETE | `/api/posts/{id}` | BR-03 |
| POST | `/api/posts/{id}/like` | toggle, BR-02 |
| POST | `/api/posts/{id}/comments` | |
| POST | `/api/posts/{id}/report` | `{reason}`, BR-07 |
| GET | `/api/admin/posts?reported=true` | ADMIN |
| PUT | `/api/admin/posts/{id}/hide` · `/unhide` | ADMIN, BR-03 |

**notification-service** — đề xuất (chủ 4 chốt)

| Method | Path | Ghi chú |
|---|---|---|
| GET | `/api/notifications?page=` | của user hiện tại, mới nhất trước |
| GET | `/api/notifications/unread-count` | |
| PUT | `/api/notifications/{id}/read` · `/api/notifications/read-all` | |

**chat-service** — đề xuất (chủ 5 chốt)

| Method | Path | Ghi chú |
|---|---|---|
| GET | `/api/conversations` | danh sách hội thoại + tin cuối |
| POST | `/api/conversations` | `{otherUserId}` → tạo hoặc trả hội thoại có sẵn, BR-05 |
| GET | `/api/conversations/{id}/messages?page=` | |
| POST | `/api/conversations/{id}/messages` | `{content}` |

## 5. API nội bộ (service gọi service)

- Đặt dưới `/internal/**`. Gateway **không** route `/internal/**` → client không gọi được.
- Gọi bằng OpenFeign theo tên Eureka, trực tiếp tới service (không qua gateway).

| # | Kịch bản | Gọi | Khi service bị gọi lỗi |
|---|---|---|---|
| F1 | Đăng ký → tạo profile rỗng | identity → `POST profile-service /internal/profiles {userId, username}` | Đăng ký vẫn thành công; profile tạo lười khi `GET /api/profiles/me` lần đầu |
| F2 | Dựng feed "following" + tên/avatar tác giả | post → `GET profile-service /internal/profiles/{userId}/following-ids`, `POST /internal/profiles/batch {userIds}` | Resilience4J fallback: feed `all`, tác giả hiển thị username "unknown" |
| F3 | Mở hội thoại | chat → `GET profile-service /internal/profiles/{a}/mutual/{b}` → `true/false` | Từ chối tạo hội thoại, 503 "Thử lại sau" |

## 6. Sự kiện RabbitMQ

- Exchange: `social.events` (topic). Mỗi service phát sự kiện của mình; notification-service tiêu thụ.
- Queue của notification-service: `notification.events`, bind `#`.
- Payload JSON chung: `{ "type": "...", "actorId": 1, "recipientId": 2, "targetId": 10, "occurredAt": "ISO-8601" }`.

| Routing key | Phát bởi | Khi | recipientId | targetId |
|---|---|---|---|---|
| `post.liked` | post | like (không phát khi unlike) | tác giả bài | postId |
| `post.commented` | post | comment mới | tác giả bài | postId |
| `user.followed` | profile | follow mới | người được follow | followerId |
| `message.sent` | chat | tin nhắn mới | người nhận | conversationId |

notification-service áp dụng BR-08 (bỏ qua khi `actorId == recipientId`).

## 7. Màn hình Flutter

| Màn | Service | Chủ |
|---|---|---|
| Login / Register | identity | 1 ✅ |
| Feed (following / tất cả), pull-to-refresh, cuộn vô hạn | post + profile | 3 |
| Chi tiết bài + comment | post | 3 |
| Tạo bài (ảnh, chọn vị trí) | post | 3 |
| Bản đồ bài viết gần đây (`flutter_map`, OpenStreetMap) | post | 3 |
| Profile, sửa profile, follow, tìm user | profile | 2 |
| Admin: user, bài bị báo cáo | identity + post | 2 |
| Thông báo | notification | 4 |
| Danh sách hội thoại + chat | chat | 5 |

## 8. Ngoài scope

Story, video/reels, share/repost, hashtag/trending, reply comment lồng nhau, chat nhóm, trạng thái đã xem/đang gõ, thuật toán xếp hạng feed, email/SMS. Google OAuth chỉ làm nếu dư thời gian.

## 9. Vấn đề chưa chốt

| Vấn đề | Ghi chú | Người quyết |
|---|---|---|
| Realtime (thông báo, chat) | Gateway hiện là Web MVC; cần kiểm tra khả năng proxy WebSocket. Phương án dự phòng: app poll 5–10 giây | 1 + 4 + 5 |
| Lưu ảnh bài viết | Lưu file trong volume của post-service, trả URL qua gateway; hoặc MinIO (thưởng "lưu file") | 3 |
| Swagger tổng ở gateway | Mẫu có sẵn ở lab slot 9 | 1 |
