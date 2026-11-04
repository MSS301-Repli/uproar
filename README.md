# Uproar

[![CI](https://github.com/MSS301-Repli/uproar/actions/workflows/ci.yml/badge.svg)](https://github.com/MSS301-Repli/uproar/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/MSS301-Repli/uproar?include_prereleases)](https://github.com/MSS301-Repli/uproar/releases)
![Java 21](https://img.shields.io/badge/Java-21-orange)
![Spring Boot 4.1](https://img.shields.io/badge/Spring%20Boot-4.1-6db33f)
![Flutter 3.41](https://img.shields.io/badge/Flutter-3.41-02569b)

> Mạng xã hội nơi mọi người lên tiếng. Nhóm **Repli**.

- **Backend**: microservices Java 21, Spring Boot 4.1, Spring Cloud 2025.1 (Eureka, Gateway, OpenFeign), MySQL, MongoDB, RabbitMQ.
- **Mobile**: Flutter (Bloc), gọi backend qua API Gateway.

Tài liệu:

- Nghiệp vụ, quy tắc, hợp đồng API: [`docs/DESIGN.md`](docs/DESIGN.md)
- Quy tắc cho AI agent (Claude Code, Codex, Cursor, Copilot...): [`AGENTS.md`](AGENTS.md) (`CLAUDE.md` import file này)
- Nhật ký dùng AI: [`docs/AI_USAGE.md`](docs/AI_USAGE.md)

## Mục lục

1. [Kiến trúc](#1-kiến-trúc)
2. [Port](#2-port)
3. [Chạy hệ thống](#3-chạy-hệ-thống)
4. [Tài khoản test](#4-tài-khoản-test)
5. [API hiện có](#5-api-hiện-có)
6. [Quy ước cho mọi service](#6-quy-ước-cho-mọi-service)
7. [Thêm một service mới](#7-thêm-một-service-mới)
8. [App Flutter](#8-app-flutter)
9. [CI/CD](#9-cicd)
10. [Phân công & trạng thái](#10-phân-công--trạng-thái)

## 1. Kiến trúc

```
Flutter app ──HTTP──> api-gateway :8080 ──lb://──> identity / profile / post / notification / chat
                        │ verify JWT (HS256)          │ mỗi service 1 DB riêng
                        │ chặn /api/admin/** nếu      │ (MySQL; chat dùng MongoDB)
                        │ không phải ADMIN            │
                        └─ gắn X-User-Id, X-User-Role  └─ đăng ký vào discovery-server (Eureka) :8761
                                                       RabbitMQ: sự kiện -> notification-service
```

- Token chỉ được kiểm tra **tại gateway**. Service phía sau tin header `X-User-Id` / `X-User-Role` do gateway gắn (header client tự gửi bị xóa).
- Service nghiệp vụ **không publish port** trong Docker → không ai gọi vòng qua gateway được.
- Service tắt / chưa có → gateway trả **503** `{"status":503,...}`.

## 2. Port

| Thành phần | Port | Ghi chú |
|---|---|---|
| api-gateway | 8080 | Điểm vào duy nhất |
| discovery-server | 8761 | Eureka dashboard: http://localhost:8761 |
| identity-service | 8081 | |
| profile-service | 8082 | |
| post-service | 8083 | |
| notification-service | 8084 | |
| chat-service | 8085 | |
| MySQL | 3306 | DB: `identity_db`, `profile_db`, `post_db`, `notification_db` |
| MongoDB | 27017 | DB: `chat_db` |
| RabbitMQ | 5672 / 15672 | UI: http://localhost:15672 (guest/guest) |

## 3. Chạy hệ thống

Yêu cầu: JDK 21, Maven 3.9+, Docker, Flutter 3.41+.

```bash
cp .env.example .env            # rồi đổi JWT_SECRET thành chuỗi ngẫu nhiên >= 32 ký tự

# Build jar từng service (chạy trong mỗi thư mục service)
mvn -q package -DskipTests

docker compose up -d --build
```

Chạy 1 service trong IDE khi dev: chỉ cần `docker compose up -d mysql mongo rabbitmq discovery-server api-gateway`, rồi Run service đó (giá trị mặc định trong `application.properties` trỏ về `localhost`).

Kiểm tra nhanh:

```bash
curl -X POST localhost:8080/api/auth/login -H "Content-Type: application/json" \
     -d '{"email":"admin@socialapp.local","password":"Admin@123"}'
```

## 4. Tài khoản test

| Vai trò | Email | Mật khẩu |
|---|---|---|
| ADMIN | `admin@socialapp.local` | `Admin@123` (đổi qua `ADMIN_PASSWORD` trong `.env`) |
| USER | tự đăng ký qua app hoặc `POST /api/auth/register` | |

## 5. API hiện có

Swagger từng service: `http://localhost:<port>/swagger-ui.html` (khi chạy trong IDE).

**identity-service**

| Method | Path | Quyền | Mô tả |
|---|---|---|---|
| POST | `/api/auth/register` | public | `{email, username, password}` → token pair (role luôn USER) |
| POST | `/api/auth/login` | public | `{email, password}` → `{accessToken, refreshToken, tokenType, expiresIn, userId, username, role}` |
| POST | `/api/auth/refresh` | public | `{refreshToken}` → token pair mới, token cũ bị thu hồi |
| POST | `/api/auth/logout` | đăng nhập | `{refreshToken}` → 204 |
| GET | `/api/auth/me` | đăng nhập | Thông tin tài khoản hiện tại |
| GET | `/api/admin/users?search=&page=&size=` | ADMIN | Tìm tài khoản (phân trang) |
| PUT | `/api/admin/users/{id}/lock` | ADMIN | Khóa tài khoản (BR-06), thu hồi mọi refresh token |
| PUT | `/api/admin/users/{id}/unlock` | ADMIN | Mở khóa |

Access token sống 15 phút, refresh token 7 ngày.

## 6. Quy ước cho mọi service

| Chủ đề | Quy ước |
|---|---|
| Package | `com.socialapp.<service>` (vd `com.socialapp.post`) |
| Tầng | `controller` / `service` / `repository` / `model` / `dto` / `exception` / `config` |
| Path | `/api/<resource>/**`; API admin: `/api/admin/<resource>/**` (gateway tự chặn role) |
| User hiện tại | `@RequestHeader("X-User-Id") Long userId`, role: `@RequestHeader("X-User-Role")` |
| Lỗi | Ném `ApiException.notFound(...)`, `.conflict(...)`...; body lỗi chung: `{timestamp, status, error, message, path}` |
| Phân trang | Trả `PageResponse<T>`: `{content, page, size, totalElements, totalPages}`; tham số `page` (từ 0), `size` |
| Validation | DTO là `record` + Bean Validation, controller dùng `@Valid` |
| DB | Flyway (`src/main/resources/db/migration/V1__init.sql`), `ddl-auto=validate`. **Không** khóa ngoại sang bảng của service khác, chỉ lưu ID |
| Test | JUnit 5 + Mockito cho tầng service (mẫu: `identity-service/src/test/.../AuthServiceTest.java`) |
| Bí mật | Không commit mật khẩu thật; dùng biến môi trường + `.env` |

## 7. Thêm một service mới

1. Tạo project ở https://start.spring.io: Maven, Java 21, Boot 4.1.x, group `com.socialapp`, artifact `<tên>-service`.
   Dependencies: Spring Web MVC, Data JPA (hoặc Data MongoDB), Validation, Flyway (+ `flyway-mysql`), MySQL Driver, Eureka Discovery Client, Actuator, OpenFeign (nếu gọi service khác).
2. `spring.application.name=<tên>-service` — **phải trùng** tên trong `api-gateway/.../routes/Routes.java` (route đã có sẵn).
3. Copy package `exception/` và `dto/PageResponse.java` từ identity-service, đổi package.
4. `application.properties`: copy từ identity-service, đổi port, DB.
5. Copy `Dockerfile`, thêm block service vào `docker-compose.yml` (theo mẫu identity-service).
6. Kiểm tra: service hiện trên Eureka dashboard, gọi được qua `localhost:8080`.

## 8. App Flutter

Thư mục `mobile/`. State management: **Bloc** (`flutter_bloc`). HTTP: `dio`. Token: `flutter_secure_storage`.

```
lib/
  core/api_client.dart        Dio + gắn token + tự refresh khi 401 + apiErrorMessage()
  core/token_storage.dart     Lưu token trong keystore
  features/auth/              data/ (repository) · bloc/ (event, state, bloc) · ui/
  features/home/home_page.dart  Thanh tab; mỗi tab thay placeholder bằng màn thật
```

Mỗi tính năng mới theo cùng cấu trúc `features/<tên>/{data,bloc,ui}`.

```bash
cd mobile
flutter test                                   # unit + widget test
flutter run                                    # emulator: gateway ở http://10.0.2.2:8080
flutter run --dart-define=API_BASE_URL=http://<IP-máy>:8080   # điện thoại thật cùng Wi-Fi
flutter build apk --release --dart-define=API_BASE_URL=http://<IP-máy>:8080
```

## 9. CI/CD

GitHub Actions, file trong `.github/workflows/`:

| Workflow | Chạy khi | Làm gì |
|---|---|---|
| `ci.yml` | Mỗi PR và push lên `dev` | **Backend**: `mvn verify` từng service (tự nhận service mới có `pom.xml`) · **Mobile**: format, `flutter analyze`, `flutter test`, build Release APK (artifact) · **E2E**: `docker compose up` toàn hệ thống rồi chạy `scripts/smoke-test.sh` qua gateway |
| `release.yml` | Push tag `v*.*.*` | Đẩy Docker image từng service lên GitHub Container Registry (`ghcr.io/<owner>/<repo>/<service>`), build APK theo từng CPU, tạo GitHub Release kèm APK |

```bash
bash scripts/smoke-test.sh          # chạy E2E trên máy, sau khi docker compose up
git tag v0.1.0 && git push origin v0.1.0   # phát hành (lead)
```

APK trong Release gọi server ở biến repo `API_BASE_URL` (Settings → Secrets and variables → Actions → Variables); không đặt thì trỏ về emulator.

## 10. Phân công & trạng thái

| Người | Backend | Flutter | Trạng thái |
|---|---|---|---|
| 1 (lead) | discovery-server, api-gateway, identity-service, docker-compose | Khung app, auth, Release APK | Nền tảng xong: đăng ký/đăng nhập/refresh/khóa tài khoản qua gateway |
| 2 | profile-service | Profile, follow, tìm user, màn Admin user | Chưa bắt đầu |
| 3 | post-service | Feed, chi tiết bài, tạo bài, bản đồ | Chưa bắt đầu |
| 4 | notification-service + RabbitMQ | Notifications | Chưa bắt đầu |
| 5 | chat-service (MongoDB) | Chat | Chưa bắt đầu |

Việc còn lại của người 1: `identity → profile` (OpenFeign) khi đăng ký, sau khi profile-service có API tạo profile.
