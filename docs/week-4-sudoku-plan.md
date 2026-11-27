# Neuro Play · Kế hoạch Sudoku Tuần 4

Hoàn thiện luồng chọn độ khó, chơi có đồng hồ và bộ đếm lỗi, tự nộp bài và nhận điểm lưu trong MySQL. Mốc Tuần 3 trên GitHub là commit `d53cfca` ở `develop` và tag `week-3`. Khi bắt đầu triển khai, tạo `feature/sudoku-scoring` từ mốc này.

## Tham khảo và quyết định về cách chơi

- Sudoku.com có nhiều mức độ, ghi chú, tô số trùng và kiểm tra ngay sau mỗi nước. Neuro Play giữ cách nhập số của Tuần 3. Số sai vẫn hiện trên bàn và được đánh dấu để người chơi tự sửa hoặc xóa. Lỗi làm giảm điểm, người chơi vẫn có thể giải tiếp. [Sudoku.com của Easybrain](https://easybrain.com/sudoku)
- Open Sudoku hiển thị thống kê thời gian và lỗi. Liddle Puzzles đặt bộ chọn mức độ trước bàn và hiện thời gian ở kết quả. Neuro Play hiển thị mức độ, đồng hồ và lỗi ngay trên bàn, sau đó hiện điểm cùng thống kê khi lưu thành công. [Open Sudoku](https://f-droid.org/en/packages/org.moire.opensudoku/) · [Liddle Puzzles](https://github.com/mikeliddle/LiddlePuzzles)
- QQWing phân hạng bằng kỹ thuật giải. Bản đồ án này dùng số ô cho sẵn để phân ba mức theo Master Plan. Dễ có 42 ô, Vừa có 34 ô và Khó có 28 ô. Tiếp tục phát triển bộ sinh hiện có của Neuro Play và giao diện Material của app. [Mã phân hạng QQWing](https://qqwing.com/qqwing.cpp.html)

## API, đồng hồ và dữ liệu

Mọi API dưới đây yêu cầu phiên xác thực còn hiệu lực. ID phiên là chuỗi số nguyên dương, còn bàn chơi là mảng 81 số theo hàng. Giữ lỗi ở dạng `{error}`.

| API | Yêu cầu | Kết quả |
| --- | --- | --- |
| `POST /api/games/sudoku/new` | `{difficulty}` với `easy`, `medium` hoặc `hard` | `201 {sessionId, difficulty, puzzle, elapsedSec}`. Ô trống có giá trị `0`. |
| `POST /api/games/sudoku/move` | `{sessionId, moveNo, cellIndex, value}`. Số thứ tự bắt đầu từ `1`, chỉ số ô từ `0` đến `80`, giá trị `0` để xóa hoặc `1–9` để nhập. | `200 {moveNo, mistakes, correct, elapsedSec, solved}`. `correct` là `null` khi xóa. |
| `POST /api/games/sudoku/submit` | `{sessionId, board}` với 81 số từ `1` đến `9`. | `200 {sessionId, difficulty, score, durationSec, mistakes}`. Nộp lại cùng bàn trả kết quả đã lưu. |

- Sinh đề bằng seed `sudoku-v2` và mức độ lưu trong phiên. Mỗi đề có đúng số ô cho sẵn theo mức và đúng một nghiệm. Giới hạn tám lần thử và tổng 200.000 nút tìm kiếm cho mỗi seed. Nếu hết ngân sách, trả `503` để app tạo lại. Giữ khả năng tái tạo các seed `sudoku-v1`. Khi ván Tuần 3 được gửi sang API nước đi hoặc nộp bài, trả `409` và yêu cầu mở ván Tuần 4 để tính điểm.
- Thêm migration `003_sudoku_progress.sql`. Mỗi hàng `sudoku_progress` gắn với một `game_sessions.id`, lưu bàn hiện tại dạng 81 ký tự số, số lỗi, số thứ tự cùng nội dung nước vừa xác nhận và `solved_at`. Tạo phiên và tiến độ trong cùng giao dịch. Khi sửa bàn hoặc nộp bài, khóa hàng phiên của đúng người chơi trước khi đọc hoặc ghi tiến độ.
- Server kiểm tra ô cho sẵn và so số nhập với đáp án tái tạo từ seed. Một lần đổi giá trị sang số sai làm tăng đúng một lỗi, kể cả khi số đó trùng ở nhiều nơi. Xóa và gửi cùng giá trị đang có không tăng lỗi. Xử lý gửi lại đúng nước vừa xác nhận trước khi kiểm tra trạng thái đã giải, để lần thử lại nước cuối trả `solved: true` mà không làm thay đổi bàn hoặc số lỗi. Nước ngoài thứ tự, dùng lại số thứ tự với nội dung khác hoặc sửa bàn đã giải xong trả `409`. Phiên không tồn tại hoặc thuộc tài khoản khác trả `404`.
- Lấy mốc bắt đầu từ `game_sessions.started_at` và chốt `solved_at` tại nước đi đầu tiên làm bàn đúng hoàn toàn. Đồng hồ tính cả thời gian app xuống nền. `durationSec` là số giây tròn đã trôi qua giữa hai mốc. Thử lại việc nộp bài sau khi đã giải đúng giữ nguyên thời gian và lỗi.
- Khi nộp bài, so sánh bàn gửi lên với bàn server đã xác nhận và đáp án. Bàn chưa đúng trả `422` và không tạo điểm. Server tính `max(0, điểm tối đa − 2 × durationSec − 50 × mistakes)` với điểm tối đa Dễ **1.000**, Vừa **1.500**, Khó **2.000**. Trong cùng giao dịch, ghi một hàng `scores` theo khóa chính `session_id` và cập nhật phiên thành `completed`. Đặt `finished_at` bằng mốc giải xong.

## Luồng Flutter

- Chọn **Dễ**, **Vừa** hoặc **Khó** khi mở Sudoku, rồi tải đề. Hiển thị mức độ, đồng hồ và số lỗi. Đồng hồ hiển thị dựa trên mốc server và thời gian đo cục bộ giữa các phản hồi. Kết quả dùng thời gian của server.
- Giữ lựa chọn ô, bàn phím, xóa, ghi chú nháp và tô hàng, cột, khối từ Tuần 3. Ghi chú ở cục bộ. Với lượt nhập số hoặc xóa, chỉ áp dụng thay đổi sau khi server xác nhận. Trong lúc chờ, app giữ bàn và chỉ cho một nước chưa xác nhận. Khi mất phản hồi, **Thử lại** gửi đúng nước đang chờ. Dùng chung luồng gia hạn token khi gặp `401`.
- Khi server báo `solved`, khóa bàn, dừng đồng hồ và tự nộp. Hiện màn kết quả sau khi MySQL đã lưu điểm. Nếu nộp thất bại, giữ bàn hoàn thành trong RAM và hiện **Nộp lại**. **Chơi đề mới** quay về bộ chọn độ khó. Hỏi xác nhận khi rời ván có tiến độ hoặc kết quả đang chờ nộp. Tiến độ được giữ khi app xuống nền. Sau khi rời bàn hoặc đóng hẳn app, lần chơi sau tạo ván mới.

## Kiểm thử và chốt mốc

- Kiểm tra ba mức sinh đúng số ô và một nghiệm, tái tạo ổn định và giữ được seed Tuần 3. Xác minh lỗi hết ngân sách trả `503`. Thử nghiệm lập kế hoạch đã sinh đủ 250 đề mỗi mức bằng bản mô phỏng trong bộ nhớ dựa trên generator hiện tại. Bài kiểm thử sẽ chạy lại trên mã Tuần 4.
- Dùng schema MySQL thử nghiệm có cả migration cũ và mới. Kiểm tra quyền sở hữu, khóa ô cho sẵn, đếm lỗi khi nhập sai, retry nước đi, nước sai thứ tự, từ chối bàn chưa giải và nộp đồng thời chỉ ra một hàng điểm. Kiểm tra công thức từng mức, điểm sàn 0 và việc trì hoãn nộp không đổi thời gian đã chốt.
- Chạy test Flutter, phân tích tĩnh, build server và APK. Trên Android, xác minh cả ba lựa chọn độ khó, chơi trọn một ván, kiểm tra báo lỗi, đưa app xuống nền, thử lại sau lỗi mạng và đối chiếu điểm, thời gian, số lỗi với hàng MySQL. Sau nghiệm thu, nhập nhánh vào `develop` và tạo tag local `week-4`.
