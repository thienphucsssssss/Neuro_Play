# Neuro Play · Kế hoạch Sudoku Tuần 3

Mốc Tuần 2 là commit `2b2246b` trên `develop` và tag `week-2` ở GitHub. Tuần 3 bổ sung một ván Sudoku 9×9 mức Dễ trên Android.

## Máy chủ

- Thêm `POST /api/games/sudoku/new`, dùng chung xác thực JWT và phiên MySQL với `/api/auth/me`. Yêu cầu JSON `{"difficulty":"easy"}`. Thành công trả `201` với `{sessionId, difficulty, puzzle}`. ID là chuỗi, bàn là 81 số theo hàng và `0` đại diện cho ô trống.
- Sinh bàn đầy bằng backtracking có xáo trộn theo seed. Thử bỏ các ô theo thứ tự xáo trộn và giữ lần bỏ nếu bộ đếm nghiệm trả về đúng một nghiệm. Dừng đếm ở hai nghiệm. Đề Dễ có đúng 42 ô cho sẵn. Giới hạn số lần sinh và số nút tìm kiếm. Nếu hết giới hạn, trả `503`.
- Tái sử dụng bảng `game_sessions` để lưu ván `active` gắn với người dùng, trò Sudoku, mức Dễ và seed có tiền tố `sudoku-v1`. Cùng seed và phiên bản tái tạo được cùng đề. Lời giải và seed nằm ở máy chủ.

## Flutter

- Mở Sudoku từ màn hình chính sau đăng nhập. Dùng Dio và cơ chế gia hạn phiên Tuần 2. Hiện tải đề, lỗi có thể thử lại và thử lại yêu cầu một lần sau khi gia hạn từ `401`.
- Tách logic bàn khỏi widget. Khóa ô cho sẵn, cho chọn ô, nhập 1–9, xóa và bật ghi chú nháp. Nhập số sẽ xóa ghi chú trong ô. Làm nổi bật hàng, cột và khối của ô đang chọn, đồng thời đánh dấu trùng ngay khi nhập.
- Tự báo hoàn thành khi bàn đầy và đúng luật Sudoku. Có thể chơi đề mới hoặc về trang chính. Bàn đang mở giữ tiến độ trong RAM khi app xuống nền. Hỏi xác nhận trước khi rời ván có tiến độ, và tạo đề mới khi mở lại.

## Nghiệm thu

- Kiểm tra đề trên nhiều seed gồm số ô cho sẵn, nghiệm duy nhất và tái tạo. Kiểm tra API yêu cầu xác thực và lưu ván đúng người chơi.
- Kiểm tra bàn Flutter, chạy lại bộ test xác thực và phân tích tĩnh.
- Trên giả lập Android, đăng nhập, chơi hết đề thật, chơi đề mới và thử rời ván dang dở. Kiểm tra mất mạng khi tạo đề và tự gia hạn khi access token hết hạn.
- Nhập `feature/sudoku` vào `develop` và tạo tag local `week-3` sau nghiệm thu. Bộ chọn nhiều mức độ, đồng hồ, đếm lỗi, nộp bài và điểm chuyển sang Tuần 4.
