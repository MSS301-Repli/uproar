# AGENTS.md

Hướng dẫn cho mọi AI coding agent (Claude Code, Codex, Cursor, Copilot, Gemini...) làm việc trong repo này.
Đọc hết file này trước khi sửa code. Thiết kế nghiệp vụ: `docs/DESIGN.md`. Cách chạy: `README.md`.

## 1. Nguyên tắc — đọc trước

Repo do nhóm 5 người phát triển: backend microservices (Java) và app `mobile/` (Flutter).
Thư mục `docs/local/` (nếu có trên máy) chứa ghi chú riêng của nhóm, không commit — đọc thêm nếu tồn tại.

| Nguyên tắc | Agent phải làm |
|---|---|
| Mỗi thành viên sở hữu trọn 1 service và **phải giải thích được mọi dòng code** của mình | Viết code đơn giản, dễ đọc, đúng mẫu có sẵn. Không dùng kỹ thuật "thông minh" khó giải thích. Sau khi viết, tóm tắt cho người dùng cách code chạy |
| Đóng góp của từng người thể hiện qua **commit history** | Chỉ sửa trong phạm vi sở hữu của người đang dùng agent (mục 3). Không commit thay người khác |
| Việc dùng AI phải **minh bạch** | Sau mỗi phần việc đáng kể, thêm 1 dòng vào `docs/AI_USAGE.md` |
| Không chép code của người khác mà không ghi nguồn | Không chép nguyên khối code từ repo/bài viết khác. Nếu tham khảo, ghi nguồn vào `docs/AI_USAGE.md` (cột Nguồn) |
| **Code phải có comment** | Comment giải thích *tại sao* ở class, method public và chỗ có quy tắc nghiệp vụ (ghi mã `BR-xx`) |

## 2. Cấu trúc repo

```
discovery-server/      Eureka (:8761)
api-gateway/           Spring Cloud Gateway MVC (:8080): verify JWT, phân quyền, route lb://
identity-service/      Tài khoản, JWT, refresh token (:8081)  <- MẪU THAM CHIẾU cho service mới
profile-service/       (chưa có) :8082
post-service/          (chưa có) :8083
notification-service/  (chưa có) :8084
chat-service/          (chưa có) :8085, MongoDB
mobile/                Flutter app, Bloc
mysql/init.sql         Tạo 1 database cho mỗi service MySQL
docs/                  DESIGN.md (nghiệp vụ, API), AI_USAGE.md (nhật ký dùng AI)
docker-compose.yml
```

Mỗi service là 1 Maven project độc lập (không có parent pom chung). Không thêm parent pom.

## 3. Quyền sở hữu — không sửa ngoài phạm vi

| Thành viên | Sở hữu |
|---|---|
| 1 (lead) | `discovery-server/`, `api-gateway/`, `identity-service/`, `docker-compose.yml`, `mysql/`, `.github/`, `scripts/` (trừ phần check của từng service), `mobile/lib/core/`, `mobile/lib/features/auth/`, `mobile/lib/features/home/`, `mobile/lib/main.dart` |
| 2 | `profile-service/`, `mobile/lib/features/profile/`, `mobile/lib/features/admin/` |
| 3 | `post-service/`, `mobile/lib/features/feed/`, `mobile/lib/features/post/`, `mobile/lib/features/map/` |
| 4 | `notification-service/`, `mobile/lib/features/notifications/` |
| 5 | `chat-service/`, `mobile/lib/features/chat/` |

- Hỏi người dùng họ là thành viên nào nếu chưa rõ.
- Cần thay đổi ở phần của người khác (route gateway, block docker-compose, tab trong `home_page.dart`, API của service khác) → **không tự sửa**. Viết đề xuất thay đổi (file, nội dung) để người dùng gửi cho chủ sở hữu qua issue/PR.
- Ngoại lệ: thêm block service của chính mình vào `docker-compose.yml` và thay placeholder tab của chính mình trong `home_page.dart` — được phép, nhưng giữ diff nhỏ.

## 4. Backend — quy tắc bắt buộc

### 4.1 Phiên bản (KHÔNG đoán theo kiến thức cũ)

- Java **21**, Spring Boot **4.1.1**, Spring Cloud **2025.1.3**, Maven. Copy `pom.xml` của `identity-service` làm gốc.
- Boot 4 đổi tên starter: dùng `spring-boot-starter-webmvc` (không phải `-web`), `spring-boot-starter-flyway` + `flyway-mysql`, test: `spring-boot-starter-test`.
- Swagger: `org.springdoc:springdoc-openapi-starter-webmvc-ui:3.1.1` (bản 2.x không chạy với Boot 4).
- Gateway là **Web MVC** (`spring-cloud-starter-gateway-server-webmvc`), không phải WebFlux. Không thêm WebFlux vào bất kỳ service nào.
- API Spring/Spring Cloud không chắc → tra tài liệu chính thức (Context7 nếu có) trước khi viết. Không bịa method.

### 4.2 Kiến trúc

- **Database-per-service**: mỗi service chỉ đọc/ghi DB của mình. Không khóa ngoại, không join sang DB khác; chỉ lưu ID (`authorId`, `postId`...). Cần dữ liệu service khác → OpenFeign.
- **Mọi request từ client đi qua gateway.** Service không tự verify JWT; đọc user từ header do gateway gắn:
  `@RequestHeader("X-User-Id") Long userId`, `@RequestHeader("X-User-Role") String role`.
- Path: `/api/<resource>/**`. API chỉ ADMIN: `/api/admin/<resource>/**` (gateway tự chặn). Path mới ngoài các prefix đã route trong `api-gateway/.../routes/Routes.java` → báo lead.
- `spring.application.name` phải đúng tên trong `Routes.java`: `identity-service`, `profile-service`, `post-service`, `notification-service`, `chat-service`.
- Gọi service khác: OpenFeign qua tên Eureka (`@FeignClient(name = "profile-service")`), gọi **thẳng service** (không qua gateway), tự chuyển header `X-User-Id` nếu bên kia cần. Bọc bằng Resilience4J + fallback hợp lý (xem `docs/DESIGN.md` mục 5).
- API chỉ để service khác gọi: đặt dưới `/internal/**` (gateway không route prefix này → client không gọi được).
- Sự kiện bất đồng bộ: RabbitMQ (exchange/queue đặt tên theo `docs/DESIGN.md`).

### 4.3 Mẫu code (copy từ identity-service, đổi package)

| Việc | Mẫu |
|---|---|
| Package | `com.socialapp.<service>` với `controller/ service/ repository/ model/ dto/ exception/ config/` |
| Lỗi | Ném `ApiException.notFound(...)`, `.conflict(...)`, `.forbidden(...)`; **không** tự trả `ResponseEntity` lỗi. Copy nguyên `exception/` |
| Body lỗi | `{timestamp, status, error, message, path}` — app Flutter đọc field `message` |
| Phân trang | Tham số `page` (từ 0), `size` (giới hạn ≤ 50); trả `PageResponse<T>` (copy `dto/PageResponse.java`). Không trả `Page<T>` của Spring |
| DTO | Java `record` + Bean Validation; controller dùng `@Valid`. Không trả entity ra ngoài |
| Schema | Flyway `src/main/resources/db/migration/V<n>__<mo_ta>.sql`; `ddl-auto=validate`. **Không sửa file migration đã commit** — thêm file version mới |
| Cấu hình nhạy cảm | Biến môi trường với default dev: `${MYSQL_ROOT_PASSWORD:root}`. Không commit secret thật, không tạo/sửa `.env` |
| Logic | Nằm ở tầng `service`; controller chỉ nhận/trả |

### 4.4 Test & kiểm tra (bắt buộc trước khi báo xong)

- Mỗi method public có logic ở tầng service → unit test JUnit 5 + Mockito (mẫu: `identity-service/src/test/.../AuthServiceTest.java`): 1 case thành công + các case vi phạm quy tắc nghiệp vụ.
- Chạy trong thư mục service: `mvn -q test` → phải pass. Đổi pom → `mvn -q package -DskipTests` phải build được.
- API mới → cập nhật Postman collection của service (nếu đã có) và bảng API trong `docs/DESIGN.md`.
- Thêm vài lệnh kiểm tra API của service mình vào `scripts/smoke-test.sh` (phần "owners add checks below"); CI chạy script này qua gateway sau `docker compose up`.
- CI (`.github/workflows/ci.yml`) phải xanh trước khi merge. Không sửa workflow trong `.github/` (thuộc lead).

## 5. Flutter (`mobile/`) — quy tắc bắt buộc

- State management: **Bloc** (`flutter_bloc`). Không thêm Provider/Riverpod/GetX.
- Cấu trúc tính năng: `lib/features/<tên>/data/` (repository gọi API) · `bloc/` (event, state, bloc — sealed class) · `ui/` (widget). Theo đúng mẫu `features/auth/`.
- Gọi API **chỉ qua** `ApiClient` (`lib/core/api_client.dart`, inject bằng `context.read<ApiClient>()`) — nó tự gắn token và refresh. Không tạo `Dio()` mới, không tự đọc token.
- Hiển thị lỗi bằng `apiErrorMessage(e)`.
- Không hard-code URL server; dùng `apiBaseUrl` (đổi bằng `--dart-define=API_BASE_URL=...`).
- Widget có thể test → đặt `Key('...')`.
- Thêm package → `flutter pub add <tên>`, nêu lý do cho người dùng; ưu tiên package phổ biến, còn maintain.
- Trước khi báo xong: `dart format lib test` (CI chặn code chưa format; độ rộng dòng 120 đặt trong `analysis_options.yaml`), `flutter analyze` (0 issue) và `flutter test` (pass). Mỗi tính năng có ít nhất 1 unit test cho bloc (mẫu `test/auth_bloc_test.dart`, dùng fake repository `implements`).
- Build APK: nếu lỗi Gradle báo phiên bản Java (vd `25.0.3`), Flutter đang dùng JDK 25 của Android Studio → `flutter config --jdk-dir="<đường dẫn JDK 21>"`.

## 6. Git

Theo Conventional Commits (quy ước của lớp):

- Commit: `<type>(<scope>): <subject>` — type: `feat fix docs style refactor perf test chore build ci revert`; scope = tên service hoặc `mobile`; subject viết thường, mệnh lệnh, ≤ 50 ký tự, không dấu chấm cuối. Body (tùy chọn) giải thích what/why, footer `Closes #<issue>`.
  Ví dụ: `feat(post-service): add like toggle endpoint`, `test(mobile): add feed bloc unit tests`.
- Branch: `<type>/<issue>-<mo-ta-ngan>` (vd `feat/12-post-crud`), tạo từ `dev`. Không làm trực tiếp trên `dev`; mọi thay đổi vào `dev` qua PR và CI phải xanh.
- PR: 1 PR = 1 mục đích, ≤ 400 dòng diff, theo `.github/pull_request_template.md`, link issue.
- Agent **không tự commit/push/merge** khi người dùng chưa yêu cầu. Trước khi commit: xem `git diff`, chắc chắn không có `.env`, `target/`, `build/`, file bí mật.
- Không `git push --force` lên `dev`, không rewrite lịch sử đã push.

## 7. Lệnh hay dùng

```bash
# Hạ tầng cho dev (rồi chạy service của mình trong IDE)
docker compose up -d mysql mongo rabbitmq discovery-server api-gateway identity-service

# Backend (trong thư mục service)
mvn -q test
mvn -q package -DskipTests

# Toàn hệ thống
docker compose up -d --build        # cần .env (copy từ .env.example)

# Flutter
cd mobile && flutter analyze && flutter test
flutter run                          # emulator -> http://10.0.2.2:8080

# Lấy token test
curl -X POST localhost:8080/api/auth/login -H "Content-Type: application/json" \
     -d '{"email":"admin@socialapp.local","password":"Admin@123"}'
```

## 8. Khi kết thúc một phần việc

Báo cho người dùng:
1. Đã thay đổi file nào, vì sao.
2. Kết quả `mvn -q test` / `flutter analyze` / `flutter test` (nguyên văn số test pass/fail).
3. Giải thích ngắn luồng code mới (để họ trình bày được khi bị hỏi).
4. Dòng đã thêm vào `docs/AI_USAGE.md`.
5. Việc còn thiếu hoặc cần chủ sở hữu khác xử lý.
