# Neuro Play · Kế hoạch Tuần 5

## Mục tiêu

Chơi trọn ván Xếp hình và Caro với máy từ Trang chủ. Mốc bắt đầu là `develop` sau commit giao diện `be8ab22`. Kết quả Tuần 5 là thống kê ván trên thiết bị. Lưu điểm máy chủ và xếp hạng sẽ được xử lý ở đợt sau.

## Xếp hình trượt

- Cho chọn bàn số 3×3 hoặc 4×4. Sinh đề bằng 12 hoặc 24 nước trượt hợp lệ từ đích, bỏ nước đảo ngược ngay và xáo lại nếu kết thúc ở đích.
- Chỉ ô kề ngang/dọc với ô trống được trượt. Đếm bước hợp lệ và thời gian từ lúc mở ván. Dừng đồng hồ khi giải xong, hiển thị kết quả với nhãn “Không gian và lập kế hoạch” và nút chơi đề mới.
- Dùng IDA* với khoảng cách Manhattan trong isolate, giới hạn 120.000 nút. Đánh dấu một nước hợp lệ để người chơi tự thực hiện. Khi hết ngân sách, thông báo chưa tìm được gợi ý cho thế hiện tại. [Nghiên cứu IDA* của Richard Korf](https://ijcai.org/proceedings/1985/208)

## Caro với máy

- Dùng bàn 15×15. Người chơi X đi trước, máy O. Từ năm quân liên tiếp theo hàng, cột hoặc đường chéo là thắng. Bàn đầy mà chưa có bên thắng là hòa. [Tài liệu về các biến thể Gomoku](https://www.renju.se/rif/proof/chap5.pdf)
- Dùng Minimax và alpha-beta trong isolate. Dễ sâu 1, Vừa sâu 2, Khó tìm sâu dần đến 4 với ngân sách 25.000 nút và dùng mức sâu đã hoàn tất khi hết ngân sách. Xét nước thắng hoặc chặn thua ngay trước khi giới hạn các ứng viên gần quân đã đặt.
- Trong ván, hoàn tác cả lượt X–O gần nhất, hoặc chỉ X khi máy còn đang tính. Bỏ phản hồi AI sau khi hoàn tác, chơi lại hoặc rời bàn. Sau ván, cho xem lại lịch sử nước đi của ván vừa chơi bằng nút lùi/tiến. Kết quả ghi nhãn “Chiến thuật và dự đoán”.

## Flutter và nghiệm thu

- Mở hai trò từ Trang chủ, dùng token trong `DESIGN.md` và `STYLE.md`. Tách logic bàn và thuật toán khỏi widget. Trên màn hình hẹp, cung cấp bàn Caro phóng to và điều hướng ô với vùng chạm ít nhất 48dp. Phạm vi Tuần 5 không cần API hoặc migration.
- Kiểm thử tính giải được bằng cách đảo chuỗi xáo trộn, luật trượt, bộ đếm, đồng hồ và gợi ý. Kiểm thử bốn hướng thắng Caro, chuỗi dài hơn năm, hòa, ô đã có quân, nước thắng/chặn của máy, hoàn tác và phản hồi isolate trả muộn.
- Chạy phân tích tĩnh, toàn bộ test và build APK. Trên giả lập, mở hai trò từ Trang chủ, giải trọn một bàn trượt, chơi Caro tới kết quả, thử ba mức AI, hoàn tác và xem lại. Kiểm tra AI và gợi ý không làm đơ giao diện, thao tác trên màn hình hẹp và hồi quy Sudoku.
- Tạo nhánh `feature/week-5-games` từ `develop` có giao diện mới. Sau nghiệm thu, merge vào `develop` và tạo tag local `week-5`.
