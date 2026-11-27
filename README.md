# Neuro Play

Đồ án Lập trình thiết bị di động với Flutter, Node.js, Express, Socket.IO và MySQL.

## Chạy bản demo

Yêu cầu Node.js 24, Flutter 3.50.1, Android SDK với giả lập Android và MySQL 8.4.

Hoàn tất thiết lập MySQL và khóa ký JWT bên dưới trước khi khởi động API.

Mở PowerShell tại thư mục dự án để chạy API.

```powershell
cd server
npm.cmd ci
npm.cmd run dev
```

Trong PowerShell khác, kiểm tra API, mở giả lập và chạy app. Tên giả lập đã tạo trên máy này là `GameTriTue_API_36`.

```powershell
Invoke-RestMethod http://127.0.0.1:3000/health
cd app
flutter emulators --launch GameTriTue_API_36
flutter devices
flutter run -d <device-id>
```

`GET /health` trả HTTP 200 và `{"status":"ok"}` khi Express hoạt động. App Android debug gọi API qua `http://10.0.2.2:3000` trên giả lập. Giá trị này có thể đổi bằng `--dart-define=API_BASE_URL=http://<host>:3000`. Khi thử trên điện thoại thật, đặt `HOST=0.0.0.0` trong `server/.env` và dùng IP LAN của máy chạy API.

Trong app, chọn **Tạo tài khoản**, đăng nhập bằng email hoặc username, rồi đóng và mở lại app để thử khôi phục phiên. Nút **Đăng xuất** thu hồi phiên đang dùng. Các phiên trên thiết bị khác tiếp tục hoạt động.

Sau khi đăng nhập, mở **Sudoku** để chơi một đề Dễ 9×9. Chọn ô trống và dùng bàn phím số, **Xóa** hoặc **Ghi chú**. App báo các số trùng và tự nhận diện khi giải xong. Bàn đang mở giữ tiến độ khi app xuống nền. Khi rời bàn, lần mở tiếp theo sẽ tạo đề mới.

## MySQL

Mở MySQL client bằng tài khoản quản trị tại thư mục dự án. Tạo database `game_tri_tue` rồi nạp schema.

```sql
CREATE DATABASE IF NOT EXISTS game_tri_tue CHARACTER SET utf8mb4;
USE game_tri_tue;
SOURCE server/sql/001_initial.sql;
SOURCE server/sql/002_auth_sessions.sql;
```

Lệnh `SOURCE` dùng đường dẫn tương đối với thư mục mở MySQL client. Tạo tài khoản ứng dụng với quyền `SELECT`, `INSERT`, `UPDATE`, `DELETE` trên database này. Sao chép `server/.env.example` thành `server/.env` nếu chưa có file cấu hình, rồi điền host, cổng và thông tin tài khoản. Kiểm tra kết nối và dữ liệu mẫu bằng `npm.cmd run db:check` trong `server/`.

Nếu đã chạy bản Tuần 1, chỉ cần nạp thêm `002_auth_sessions.sql` bằng tài khoản quản trị. Tạo hai khóa khác nhau bằng cách chạy lệnh sau hai lần rồi điền vào `JWT_ACCESS_SECRET` và `JWT_REFRESH_SECRET` trong `server/.env`.

```powershell
node -p "require('node:crypto').randomBytes(32).toString('base64url')"
```

Trên máy Windows thiết lập cho đồ án, Flutter, Android SDK và MySQL nằm trong `E:\_HUTECH\game-puzzle-sdk`. Mở PowerShell mới để dùng PATH vừa cập nhật. MySQL dùng cổng `3307` và thư mục dữ liệu riêng trong `%LOCALAPPDATA%\GameTriTue\MySQL`.

Khi cần khởi động lại MySQL sau khi tắt máy, chạy lệnh sau trong PowerShell.

```powershell
$dbHome = 'E:/_HUTECH/game-puzzle-sdk/mysql-8.4.13-winx64'
$dbData = Join-Path $env:LOCALAPPDATA 'GameTriTue/MySQL/data'
& "$dbHome/bin/mysqld.exe" --no-defaults "--basedir=$dbHome" "--datadir=$dbData" --bind-address=127.0.0.1 --port=3307 --mysqlx=OFF --console
```

## Kiểm tra mã nguồn

Chạy `npm.cmd test` và `npm.cmd run build` trong `server/`. Để chạy `npm.cmd run test:auth`, cấu hình `AUTH_TEST_DB_NAME`, `AUTH_TEST_DB_USER`, `AUTH_TEST_DB_PASSWORD`, và khi cần `AUTH_TEST_DB_HOST`, `AUTH_TEST_DB_PORT` trong `server/.env.auth-test`. Dùng schema thử nghiệm riêng có tên kết thúc bằng `_test` và cấp thêm quyền `CREATE`, `REFERENCES` cho tài khoản test để bộ kiểm thử tự nạp migration.

Chạy `flutter analyze` và `flutter test` trong `app/`. Xem [thiết kế Tuần 1](docs/week-1.md), [hợp đồng xác thực Tuần 2](docs/week-2-auth-plan.md) và [kế hoạch Sudoku Tuần 3](docs/week-3-sudoku-plan.md).
