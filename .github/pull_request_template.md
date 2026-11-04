## Mục tiêu / Why
<!-- Vấn đề cần giải quyết -->

## Thay đổi gì / What
-

## Cách test
```
mvn -q test            # trong thư mục service
cd mobile && flutter analyze && flutter test
```

## Screenshot (nếu có UI)

## Related issues
Closes #

## Checklist
- [ ] Chỉ sửa trong phạm vi sở hữu của mình (AGENTS.md mục 3)
- [ ] Có test mới, `mvn -q test` / `flutter test` pass
- [ ] Code có comment, giải thích được mọi dòng
- [ ] Cập nhật `docs/DESIGN.md` nếu đổi API
- [ ] Ghi `docs/AI_USAGE.md` nếu dùng AI
- [ ] Không commit `.env`, `target/`, `build/`, secret
