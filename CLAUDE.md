@AGENTS.md

# Claude Code

Toàn bộ quy tắc ở `AGENTS.md` (được import ở trên) — áp dụng nguyên văn. Bổ sung riêng cho Claude Code:

- Đầu phiên: hỏi người dùng là thành viên số mấy (AGENTS.md mục 3) nếu chưa biết, rồi chỉ làm trong phạm vi đó.
- Thay đổi lớn (service mới, đổi API, thêm luồng Feign/RabbitMQ): trình bày kế hoạch ngắn và chờ đồng ý trước khi viết code.
- Thư viện Spring Boot 4 / Spring Cloud 2025 / Flutter package: tra tài liệu hiện hành (Context7) thay vì dựa vào trí nhớ — kiến thức Boot 3 dễ sai tên starter/API.
- Dùng `/code-review` hoặc agent reviewer cho diff trước khi người dùng mở PR.
- Không tự commit/push. Khi được yêu cầu commit: theo Conventional Commits ở AGENTS.md mục 6, commit dưới tên người dùng.
