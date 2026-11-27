# Neuro Play · Kế hoạch Tuần 2

Tuần 2 bổ sung đăng ký, đăng nhập và khôi phục phiên trên Flutter, Express và MySQL. Mốc Tuần 1 là commit `add8e0e` trên `main`, `develop` và tag `week-1` ở GitHub.

## Hợp đồng API

| API | Đầu vào | Kết quả |
| --- | --- | --- |
| POST `/api/auth/register` | `username`, `email`, `password`, `displayName` tùy chọn | `201 {user}` |
| POST `/api/auth/login` | `identifier` (email hoặc username), `password` | `200 {accessToken, refreshToken}` |
| GET `/api/auth/me` | `Authorization: Bearer <accessToken>` | `200 {user}` |
| POST `/api/auth/refresh` | `{refreshToken}` | `200 {accessToken, refreshToken}` |
| POST `/api/auth/logout` | `{refreshToken}` | `204` |

Hồ sơ `user` có `id` dạng chuỗi, `username`, `email`, `displayName` và `avatarUrl` có thể null. Lỗi trả `{error}` với mã 400 cho đầu vào sai, 409 cho tài khoản trùng, 401 cho thông tin xác thực không hợp lệ và 429 cho giới hạn tần suất. Kết quả đăng nhập sai dùng chung thông báo.

## Backend

- Dùng bảng `users` và truy vấn MySQL tham số hóa. Email và username được trim và chuyển chữ thường. Username dài 3–32 ký tự ASCII gồm chữ, số và dấu gạch dưới. Email tối đa 254 ký tự, tên hiển thị tối đa 80 ký tự và mặc định bằng username. Mật khẩu giữ nguyên nội dung, tối thiểu 15 ký tự Unicode, tối đa 72 byte UTF-8. Dùng bcrypt cost 12.
- Thêm `002_auth_sessions.sql` với khóa ngoại tới người dùng, ID phiên, hash SHA-256 của refresh token, hạn phiên và thời điểm thu hồi. Mỗi lần đăng nhập tạo một phiên. Access JWT sống tối đa 15 phút và phiên hết hạn sau 30 ngày kể từ lúc đăng nhập. Dùng hai khóa khác nhau từ biến môi trường. Refresh xoay token trong giao dịch khóa hàng, giữ hạn phiên và thu hồi phiên khi phát hiện token cũ hợp lệ được dùng lại. Logout thu hồi đúng phiên, middleware kiểm tra phiên cho mọi request được bảo vệ.
- Giới hạn yêu cầu xác thực theo IP, giữ `GET /health` công khai và ghi hướng dẫn migration, cấu hình JWT và demo trong README.

## Flutter

- Tái sử dụng Dio. Quản lý phiên bằng Provider, giữ access token trong RAM và lưu refresh token trong `flutter_secure_storage`. Tắt Android Auto Backup.
- Hai form tiếng Việt kiểm tra dữ liệu và chặn gửi lặp. Sau đăng ký, trở về đăng nhập với email điền sẵn và thông báo thành công. Sau đăng nhập, gọi `/me` rồi hiện tên người chơi, trạng thái API và nút đăng xuất.
- Khi mở app, dùng refresh token đã lưu để khôi phục phiên. Khi request được bảo vệ trả 401, dùng một yêu cầu refresh dùng chung rồi thử lại một lần. Lỗi mạng và 5xx cho phép thử lại. Nếu máy chủ đã xoay token nhưng mất phản hồi, token cũ có thể buộc đăng nhập lại. Logout xóa token sau khi máy chủ xác nhận thu hồi hoặc xác nhận phiên không còn hợp lệ.

## Nghiệm thu

- Backend chạy build TypeScript, test health và test với schema MySQL thử nghiệm riêng. Kiểm tra đăng ký trùng, cả hai định danh đăng nhập, giới hạn UTF-8, hết hạn, xoay đồng thời, phát lại và thu hồi riêng từng phiên.
- Flutter chạy phân tích tĩnh, widget test và build APK debug. Kiểm tra trên Android luồng đăng ký, đăng nhập, mở lại app, gia hạn, lỗi mạng và đăng xuất.
- Sau khi xác minh, nhập `feature/auth` vào `develop` và tạo tag local `week-2`. Phạm vi là xác thực bằng mật khẩu và quản lý phiên.
