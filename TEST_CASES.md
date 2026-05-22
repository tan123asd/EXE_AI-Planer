# Test Cases — EXE AI-Planer Chat Agent

> **Cách dùng:** Mở app, vào tab Chat, chạy từng test case theo thứ tự.  
> Tick ✅ nếu pass, ✗ nếu fail và ghi chú lỗi.  
> Chuẩn bị: có ít nhất 1 task tên **"Ôn thi Toán"** và 1 activity **"Đọc sách"** trong hệ thống trước khi test.

---

## 1. TẠO KẾ HOẠCH MỚI (collect_plan_info → generatePlan)

### 1.1 Happy path — đủ thông tin qua nhiều lượt

| # | User nhập | Kết quả mong đợi | Pass? | Ghi chú |
|---|-----------|-----------------|-------|---------|
| 1.1.1 | `tôi muốn ôn thi Toán` | AI hỏi thêm chi tiết về môn học (chương mấy, chủ đề gì) — không hỏi deadline ngay | ✅ | |
| 1.1.2 | `chương 1-5 giải tích` | AI hỏi deadline | ✅ | |
| 1.1.3 | `deadline 15/6` | AI hỏi bao nhiêu giờ/ngày | ✅ | |
| 1.1.4 | `3 tiếng mỗi ngày` | AI hiện card xem trước kế hoạch (plan preview) | ✅ | |
| 1.1.5 | Nhấn **Lưu kế hoạch** | "✅ Kế hoạch đã được lưu!" + lịch xuất hiện ở tab Lịch | ✅ | |

### 1.2 Reject kế hoạch

| # | User nhập | Kết quả mong đợi | Pass? | Ghi chú |
|---|-----------|-----------------|-------|---------|
| 1.2.1 | Sau khi thấy plan preview: `không, hủy đi` | "Kế hoạch đã bị hủy..." + không lưu gì | ✅ | |

### 1.3 Cung cấp đủ thông tin trong 1 lượt

| # | User nhập | Kết quả mong đợi | Pass? | Ghi chú |
|---|-----------|-----------------|-------|---------|
| 1.3.1 | `tôi muốn học lập trình Python, deadline 30/6, 2h mỗi ngày` | AI tạo plan ngay, hiện card xem trước (không hỏi thêm) | ✅ | |

### 1.4 Mục tiêu mơ hồ — AI phải hỏi cụ thể trước

| # | User nhập | Kết quả mong đợi | Pass? | Ghi chú |
|---|-----------|-----------------|-------|---------|
| 1.4.1 | `tôi muốn ôn thi` | AI hỏi ôn môn gì / chủ đề cụ thể (KHÔNG hỏi deadline ngay) | ✅ | |
| 1.4.2 | `làm slide thuyết trình` | AI hỏi slide về chủ đề gì / nội dung cụ thể | ✅ | |

### 1.5 Lưu profile người dùng sau khi approve

| # | Kiểm tra | Kết quả mong đợi | Pass? | Ghi chú |
|---|----------|-----------------|-------|---------|
| 1.5.1 | Sau khi approve plan 3h/ngày, kiểm tra SharedPreferences key `user_profile` | `planCount: 1`, `avgDailyHours: 3.0` | ☐ | Dùng debug/flutter devtools |
| 1.5.2 | Restart app, mở chat, gửi `tôi muốn học gì đó` | System prompt chứa "Giờ học trung bình/ngày: 3.0h" (debug log) | ☐ | |

---

## 2. THÊM TASK TRỰC TIẾP (add_task_direct)

> Trigger: user cung cấp **tên + ngày cụ thể + giờ + thời lượng** trong 1 tin nhắn

| # | User nhập | Kết quả mong đợi | Pass? | Ghi chú |
|---|-----------|-----------------|-------|---------|
| 2.1 | `thêm task họp nhóm 2h vào 14h ngày 26/5` | Task "Họp nhóm" xuất hiện ở lịch ngày 26/5, 14:00–16:00 | ✅ | |
| 2.2 | `thêm 1 task nộp báo cáo 1h lúc 9h ngày mai` | Task lịch ngày mai lúc 9:00–10:00 | ✅ | |
| 2.3 | `thêm công việc review code 90 phút 15h ngày 28/5` | Task 28/5, 15:00–16:30 | ✅ | |
| 2.4 | `thêm task học tiếng Anh mỗi thứ 3` | AI gọi collect_plan_info (KHÔNG gọi add_task_direct vì thiếu ngày cụ thể) | x | |
| 2.5 | `thêm task làm bài tập` (thiếu ngày/giờ) | AI gọi collect_plan_info, hỏi thêm thông tin | ✅ | |

---

## 3. DỜI TASK (shift_task)

> Prerequisite: có task **"Ôn thi Toán"** trong hệ thống


| # | User nhập | Kết quả mong đợi | Pass? | Ghi chú |
|---|-----------|-----------------|-------|---------|
| 3.1 | `dời task ôn thi toán sang ngày mai` | Tất cả sessions dời +1 ngày, AI xác nhận | ☐ | |
| 3.2 | `dời ôn toán đi 3 ngày` | Sessions dời +3 ngày | ✅ | |
| 3.3 | `lùi task ôn toán lại 2 ngày` | Sessions dời −2 ngày | ✅ | |
| 3.4 | `shift task toán to next week` | Sessions dời +7 ngày | ✅ | |
| 3.5 | `dời task` (không rõ tên task, không rõ số ngày) | AI hiện dialog "Xác nhận hành động" (confidence medium/low) hoặc hỏi lại | ✅ | |
| 3.6 | `dời task ôn toán` (không rõ bao nhiêu ngày) | AI set confidence=low, hiện dialog clarification | x | |

note: kết quả sau khi test: khi chat "tôi muốn ôn thi toán" AI phản hồi hỏi thêm muốn làm cho những chủ đề nào, còn khi chat "tạo task ôn thi toán" thì chỉ hỏi deadline không hỏi chi tiết về task
---

## 4. HOÀN THÀNH TASK (complete_task)

| # | User nhập | Kết quả mong đợi | Pass? | Ghi chú |
|---|-----------|-----------------|-------|---------|
| 4.1 | `hoàn thành task ôn thi toán` | Tất cả sessions đánh dấu completed, AI xác nhận | ✅ | |
| 4.2 | `xong task toán rồi` | Nhận diện fuzzy match "toán" → complete | ✅ | |
| 4.3 | `mark done ôn toán` | Tiếng Anh, nhận diện đúng intent → complete | ✅ | |
| 4.4 | `hoàn thành task xyz không tồn tại` | "Could not find a task matching..." | ✅ | |

---

## 5. XÓA TASK (delete_task)

| # | User nhập | Kết quả mong đợi | Pass? | Ghi chú |
|---|-----------|-----------------|-------|---------|
| 5.1 | `xóa task ôn thi toán` | Hiện dialog "Bạn có chắc?" → confirm → task bị xóa | ✅ | |
| 5.2 | `xóa task ôn thi toán` → nhấn **Cancel** | Task vẫn còn, AI: "Được rồi, task vẫn được giữ lại" | ✅ | |
| 5.3 | `delete task toán` | Nhận diện tiếng Anh, hiện dialog confirm | ✅ | |
| 5.4 | `xóa tất cả task` | Hiện dialog "Delete All Tasks — cannot be undone" | ✅ | |
| 5.5 | `xóa tất cả task` → confirm | Tất cả tasks bị xóa | ✅ | |
| 5.6 | `xóa task xyz không tồn tại` | "Could not find a task matching..." | ✅ | |

---

## 6. XÓA SUBTASK (delete_subtask)

> Prerequisite: task có nhiều sessions (ví dụ "Ôn thi Toán" session 1, 2, 3)

| # | User nhập | Kết quả mong đợi | Pass? | Ghi chú |
|---|-----------|-----------------|-------|---------|
| 6.1 | `xóa subtask buổi học 1 của ôn toán` | Hiện dialog confirm subtask + parent task | ✅ | |
| 6.2 | Confirm xóa subtask | Chỉ session đó bị xóa, các sessions khác còn | x | |
| 6.3 | Cancel xóa subtask | "Đã hủy. Subtask vẫn được giữ lại." | ✅ | |
| 6.4 | `xóa cả task toán` | Gọi delete_task (KHÔNG gọi delete_subtask) | ✅ | |
note: ôn tập lí thuyết là subtask của ôn toán khi xóa dialog confirm hiện lên ấn confirm nhưng subtask không bị xóa và AI trả lời could not find a task matching ôn tập lí thuyết trong khi đó dialog confirm lại hiện lên đúng tên của subtask đó
---

## 7. LẬP KẾ HOẠCH LẠI (re_plan_task)

| # | User nhập | Kết quả mong đợi | Pass? | Ghi chú |
|---|-----------|-----------------|-------|---------|
| 7.1 | `tôi không kịp deadline ôn toán` | AI gọi re_plan_task(userIntent=need_more_time), hiện plan preview mới | ✅ | |
| 7.2 | `task ôn toán dễ hơn tôi nghĩ` | AI gọi re_plan_task(userIntent=task_is_easier), hiện plan preview mới | ✅ | |
| 7.3 | `không kịp deadline` (không rõ task nào) | AI hiện dialog clarification (confidence=low) | x | |
| 7.4 | Approve re-plan preview | Sessions còn lại được cập nhật, sessions đã done không thay đổi | ✅ | |
| 7.5 | `re_plan task xyz không tồn tại` | "Không tìm thấy task khớp với..." | ☐ | |
note: khi replan lại các gợi ý không đúng với yêu cầu của các subtask hiện tại ví dụ: subtask hiện tại là ôn tập chương 1, ôn tập chương 2 những khi replan AI gợi ý lại là ôn tập lí thuyết đại số, ôn tập lí thuyết hình học. yêu cầu bắt buộc ở đây là replan lại dựa trên những subtask hiện tại, ví dụ ôn tập chương 1(duration 1h) thì khi replan lại phải là ôn tập chương 1(dration 1.5h hoặc hơn) hoặc là có thể breakdown subtask đó ra thành 2 subtask nhỏ hơn nữa nhưng tiêu đề của subtask vẫn phải chung chủ đề
---

## 8. ĐIỀU CHỈNH KHỐI LƯỢNG (adjust_workload)

| # | User nhập | Kết quả mong đợi | Pass? | Ghi chú |
|---|-----------|-----------------|-------|---------|
| 8.1 | `task ôn toán quá nặng, nhẹ hơn được không` | AI gọi adjust_workload(direction=lighter), reschedule với 0.7× load | x | |
| 8.2 | `tôi muốn học toán nhiều hơn mỗi ngày` | AI gọi adjust_workload(direction=heavier), reschedule với 1.4× load | x | |
| 8.3 | `nhẹ hơn đi` (không rõ task nào) | AI hiện dialog clarification | x | |
| 8.4 | `adjust workload toán` (tiếng Anh, direction không rõ) | Dialog clarification hỏi lighter hay heavier | x | |

---

## 9. THÊM HOẠT ĐỘNG (add_activity)

### 9A — Mode A: Ngày + Giờ cụ thể (one-off session)

| # | User nhập | Kết quả mong đợi | Pass? | Ghi chú |
|---|-----------|-----------------|-------|---------|
| 9A.1 | `thêm hoạt động đá bóng 1h vào 14h ngày 25/5` | Activity lưu ngay, 1 session ngày 25/5 14:00–15:00 | ✅ | |
| 9A.2 | `thêm hoạt động chạy bộ 30 phút lúc 6h ngày mai` | Activity ngày mai 6:00–6:30 | ✅ | |

### 9B — Mode B: Giờ cố định, lặp theo thứ

| # | User nhập | Kết quả mong đợi | Pass? | Ghi chú |
|---|-----------|-----------------|-------|---------|
| 9B.1 | `thêm hoạt động đọc sách 1h lúc 9h mỗi thứ 2 và thứ 4` | Sessions lặp thứ 2 + thứ 4 lúc 9:00, preferred_weekdays=[1,3] | ✅ | |
| 9B.2 | `thêm hoạt động gym 1h30 lúc 7h mỗi ngày` | Sessions mỗi ngày 7:00–8:30, weekdays=[1,2,3,4,5,6,7] | ✅ | |
| 9B.3 | `thêm hoạt động yoga 45 phút lúc 21h thứ 3 5 7` | preferred_weekdays=[2,4,6] (thứ 3=2, 5=4, 7=6) | ✅ | |

### 9C — Mode C: AI gợi ý giờ (pending confirmation)

| # | User nhập | Kết quả mong đợi | Pass? | Ghi chú |
|---|-----------|-----------------|-------|---------|
| 9C.1 | `thêm hoạt động đọc sách 1h mỗi thứ 2 và thứ 4` (không có giờ) | AI gợi ý khung giờ, hỏi "ok không?" — chưa lưu | x | |
| 9C.2 | Sau gợi ý → gõ `ok` | Lưu activity với slots AI gợi ý | x | |
| 9C.3 | Sau gợi ý → gõ `không` | "Đã hủy. Bạn có thể chỉ định giờ cụ thể." | x | |
| 9C.4 | `thêm hoạt động thiền AI gợi ý giờ` | AI gọi add_activity với specific_date=null, specific_start_hour=null | ✅ | |

### 9D — Weekday mapping (quan trọng)

| # | User nhập | Kết quả mong đợi | Pass? | Ghi chú |
|---|-----------|-----------------|-------|---------|
| 9D.1 | `thứ 2, 4` | preferred_weekdays = [1, 3] | ✅ | |
| 9D.2 | `thứ 3, 5` | preferred_weekdays = [2, 4] | ✅ | |
| 9D.3 | `thứ 7 và chủ nhật` | preferred_weekdays = [6, 7] | ✅ | |
| 9D.4 | `mỗi ngày` | preferred_weekdays = [1,2,3,4,5,6,7] | ✅ | |

---

## 10. DỜI HOẠT ĐỘNG (shift_activity)

| # | User nhập | Kết quả mong đợi | Pass? | Ghi chú |
|---|-----------|-----------------|-------|---------|
| 10.1 | `dời hoạt động đọc sách 2 ngày` | Tất cả sessions của "Đọc sách" dời +2 ngày | ✅ | |
| 10.2 | `lùi đọc sách lại 1 ngày` | Sessions dời −1 ngày | ✅ | |
| 10.3 | `dời hoạt động không tồn tại` | "Không tìm thấy hoạt động khớp với..." | ✅ | |

---

## 11. XÓA HOẠT ĐỘNG (delete_activity)

| # | User nhập | Kết quả mong đợi | Pass? | Ghi chú |
|---|-----------|-----------------|-------|---------|
| 11.1 | `xóa hoạt động đọc sách` | Hiện dialog confirm → xóa | ✅ | |
| 11.2 | `xóa hoạt động đọc sách` → Cancel | Activity vẫn còn | ✅ | |
| 11.3 | `delete activity đọc sách` | Nhận diện tiếng Anh, hiện dialog | ✅ | |

---

## 12. XEM LỊCH (query — text only, không gọi tool)

> AI phải trả lời trực tiếp từ schedule data trong system prompt, KHÔNG gọi bất kỳ tool nào

| # | User nhập | Kết quả mong đợi | Pass? | Ghi chú |
|---|-----------|-----------------|-------|---------|
| 12.1 | `lịch hôm nay` | Danh sách tasks/activities hôm nay, hoặc "(free)" nếu trống | ✅ | |
| 12.2 | `ngày mai có gì không` | Lịch ngày mai | ✅ | |
| 12.3 | `lịch tuần này` | Tổng quan 7 ngày tới | ✅ | |
| 12.4 | `tôi có task gì vào ngày 28/5` | Tasks ngày 28/5 | ✅ | |
| 12.5 | `deadline nào gần nhất` | Task sắp deadline nhất | ✅ | |
| 12.6 | `hôm nay tôi học mấy giờ` | Tổng thời lượng các sessions hôm nay | ✅ | |
| 12.7 | `what's on my schedule tomorrow` | Tiếng Anh — lịch ngày mai | ✅ | |

---

## 13. LỆNH LOCAL (không gọi API)

| # | User nhập | Kết quả mong đợi | Pass? | Ghi chú |
|---|-----------|-----------------|-------|---------|
| 13.1 | `hướng dẫn` | Hiện _helpText ngay, KHÔNG gọi API | ✅ | |
| 13.2 | `help` | Hiện _helpText | ✅ | |
| 13.3 | `hd` | Hiện _helpText | ✅ | |

---

## 14. HỘI THOẠI THÔNG THƯỜNG (TextOnlyResponse)

| # | User nhập | Kết quả mong đợi | Pass? | Ghi chú |
|---|-----------|-----------------|-------|---------|
| 14.1 | `xin chào` | AI chào lại, KHÔNG gọi tool | ✅ | |
| 14.2 | `cảm ơn bạn` | AI phản hồi lịch sự | ✅ | |
| 14.3 | `bạn là ai` | Giới thiệu bản thân là AI Planning Assistant | ✅ | |
| 14.4 | `bạn có thể làm gì` | Mô tả các chức năng | ✅ | |
| 14.5 | `hello` | Reply tiếng Anh (phát hiện ngôn ngữ) | ✅ | |

---

## 15. GUARDRAILS — Chặn argument sai (Feature 1)

> Phải hiện thông báo ⚠️ và KHÔNG execute, AI tự sửa lại

| # | Scenario | Input user | Kết quả mong đợi | Pass? | Ghi chú |
|---|----------|-----------|-----------------|-------|---------|
| 15.1 | daysOffset quá lớn | `dời task toán đi 400 ngày` | "⚠️ Không thể thực hiện: daysOffset 400 quá lớn (>365 ngày)..." | ✅ | |
| 15.2 | Ngày quá khứ | `thêm task họp lúc 10h ngày 1/1/2020 1h` | "⚠️ Ngày '2020-01-01' đã qua..." | ✅ | |
| 15.3 | Ngày quá xa | `thêm task xyz lúc 10h ngày 1/1/2029 1h` | "⚠️ Ngày '...' quá xa (>2 năm)..." | ✅ | |
| 15.4 | Duration = 0 | `thêm hoạt động chạy bộ 0 phút mỗi ngày` | "⚠️ durationMinutes 0 không hợp lệ..." | ✅ | |
| 15.5 | Duration > 480 | `thêm hoạt động học 600 phút mỗi ngày` | "⚠️ durationMinutes 600 không hợp lệ (phải 1–480)..." | ✅ | |
| 15.6 | Giờ bắt đầu < 6 | `thêm task xyz 1h lúc 3h ngày mai` | "⚠️ specificStartHour 3 ngoài khoảng cho phép (6–22)..." | ✅ | |
| 15.7 | Giờ bắt đầu > 22 | `thêm task xyz 1h lúc 23h ngày mai` | "⚠️ specificStartHour 23 ngoài khoảng cho phép..." | ✅ | |
| 15.8 | dailyHours không hợp lệ | `học 25 tiếng mỗi ngày` (trong khi tạo plan) | "⚠️ dailyHours 25 không hợp lệ (phải 0.5–24)..." | ✅ | |
| 15.9 | shift_activity > 365 ngày | `dời đọc sách 400 ngày` | "⚠️ daysOffset 400 quá lớn..." | ✅ | |
note: giá trị mặc định của specificStartHour là 22h nhưng người dùng cũng nên có quyền thay đổi nó trong profile
---

## 16. CLARIFICATION GATE — Dialog xác nhận (Feature 2)

> AI phải set confidence='medium' hoặc 'low' khi không chắc

| # | User nhập | Kết quả mong đợi | Pass? | Ghi chú |
|---|-----------|-----------------|-------|---------|
| 16.1 | `dời task ôn toán` (không nói bao nhiêu ngày) | Dialog "Xác nhận hành động" hiện ra với clarification text | x | |
| 16.2 | Dialog hiện → nhấn **Tiếp tục** | Execute shift_task | x | |
| 16.3 | Dialog hiện → nhấn **Hỏi lại** | "Hành động đã huỷ. Bạn muốn làm gì khác không?" | x | |
| 16.4 | `thêm task họp 1h ngày mai` (không có giờ cụ thể) | Dialog clarification vì thiếu start hour | x | |
| 16.5 | `dời task toán đi 3 ngày` (rõ ràng) | Execute THẲNG, KHÔNG hiện dialog (confidence=high) | ✅ | |
| 16.6 | `nhẹ hơn đi` (không rõ task nào) | Dialog clarification | x | |
note: ở 16.1 không hiện dialog mà trực tiếp shifted task 1 days, 16.4 không hỏi thêm mà trực tiếp thêm task vào 1 giờ ngẫu nhiên, 16.5 pass nhưng trong lịch task tên là ôn thi toán chứ k phải toán hành vi lúc này nên hỏi lại user có đúng là task này không người dùng xác nhận sau đó mới thực hiện hành động, 16.6 không hỏi lại là task nào mà trực tiếp replan đưa ra gợi ý với task ôn tập toán 
---

## 17. FUZZY MATCHING — Nhận diện tên gần đúng

> Agent dùng fuzzy find, không cần gõ chính xác 100%

| # | User nhập | Task tồn tại | Kết quả mong đợi | Pass? | Ghi chú |
|---|-----------|-------------|-----------------|-------|---------|
| 17.1 | `hoàn thành toán` | "Ôn thi Toán" | Nhận diện đúng | ✅ | |
| 17.2 | `xóa task on thi toan` (không dấu) | "Ôn thi Toán" | Normalize + fuzzy match | ✅ | |
| 17.3 | `dời on toán` | "Ôn thi Toán" | Partial match | ✅ | |
| 17.4 | `xóa hoạt động doc sach` | "Đọc sách" | Normalize diacritics | ✅ | |
| 17.5 | `complete task toan` | "Ôn thi Toán" | Tiếng Anh + partial | ✅ | |

---

## 18. XỬ LÝ LỖI & EDGE CASES

| # | Scenario | Kết quả mong đợi | Pass? | Ghi chú |
|---|----------|-----------------|-------|---------|
| 18.1 | Mất kết nối mạng | "Network error. Please check your connection..." | ✅ | Tắt wifi rồi gửi tin |
| 18.2 | API key trống | "OpenAI API key not configured..." | ✅ | Build không có OPENAI_API_KEY |
| 18.3 | Không có task nào | `lịch hôm nay` | "No tasks or activities scheduled." hoặc "(free)" | ✅ | |
| 18.4 | Task tên trùng nhau | 2 tasks cùng tên "Học" | AI match task đầu tiên (fuzzy), không crash | ✅ | |
| 18.5 | Gửi tin trống | (gõ khoảng trắng rồi Enter) | Không làm gì / không gửi | ✅ | |
| 18.6 | Double-tap gửi nhanh | Tap send 2 lần liên tiếp | Không gửi 2 lần (isLoading guard) | ✅ | |
| 18.7 | Schedule rỗng + query | `ngày mai có gì không` | "ngày mai trống" hoặc "(free)" | ✅ | |


---

## 21. NGÔN NGỮ TỰ ĐỘNG (language detection)

| # | User nhập | Kết quả mong đợi | Pass? | Ghi chú |
|---|-----------|-----------------|-------|---------|
| 21.1 | `xin chào` | AI reply tiếng Việt | ✅ | |
| 21.2 | `hello` | AI reply tiếng Anh | ✅ | |
| 21.3 | `lịch hôm nay` | AI reply tiếng Việt | ✅ | |
| 21.4 | `what's my schedule` | AI reply tiếng Anh | ✅ | |
| 21.5 | Trong session đã chat tiếng Việt → gõ `ok` | AI vẫn reply tiếng Việt (nhớ ngôn ngữ của session) | ✅ | |

---

## 22. QUICK CHIPS (phím tắt UI)

| # | Chip nhấn | Kết quả mong đợi | Pass? | Ghi chú |
|---|-----------|-----------------|-------|---------|
| 22.1 | **Create a Plan** | Gửi "Create a Plan" → AI bắt đầu hỏi thông tin kế hoạch | ✅ | |
| 22.2 | **Modify Task** | Gửi "Modify Task" → AI hỏi muốn sửa task nào | ✅ | |
| 22.3 | **Mark Done** | Gửi "Mark Done" → AI hỏi task nào đã xong | ✅ | |
| 22.4 | **Reduce Load** | Gửi "Reduce Load" → AI hỏi task nào muốn giảm tải | ✅ | |

---

## 23. CLEAR CHAT

| # | Scenario | Kết quả mong đợi | Pass? | Ghi chú |
|---|----------|-----------------|-------|---------|
| 23.1 | Nhấn icon xóa → confirm | Chat xóa sạch, hiện message chào ban đầu | ✅ | |
| 23.2 | Nhấn icon xóa → cancel | Chat giữ nguyên | ✅ | |
| 23.3 | Sau clear, gửi tin mới | Agent hoạt động bình thường (context reset) | ✅ | |

---

## Tổng kết

| Nhóm | Tổng tests | Pass | Fail |
|------|-----------|------|------|
| 1. Tạo kế hoạch | 10 | | |
| 2. Thêm task trực tiếp | 5 | | |
| 3. Dời task | 6 | | |
| 4. Hoàn thành task | 4 | | |
| 5. Xóa task | 6 | | |
| 6. Xóa subtask | 4 | | |
| 7. Re-plan task | 5 | | |
| 8. Điều chỉnh khối lượng | 4 | | |
| 9. Thêm hoạt động | 12 | | |
| 10. Dời hoạt động | 3 | | |
| 11. Xóa hoạt động | 3 | | |
| 12. Xem lịch | 7 | | |
| 13. Lệnh local | 3 | | |
| 14. Hội thoại thông thường | 5 | | |
| 15. Guardrails | 9 | | |
| 16. Clarification gate | 6 | | |
| 17. Fuzzy matching | 5 | | |
| 18. Xử lý lỗi & edge cases | 7 | | |
| 19. Context compression | 4 | | |
| 20. Phase-aware prompt | 5 | | |
| 21. Ngôn ngữ tự động | 5 | | |
| 22. Quick chips | 4 | | |
| 23. Clear chat | 3 | | |
| **Tổng** | **124** | | |

---
 **những gì muốn thay đổi**
1. agent đang thiếu việc check block trùng, ví dụ block 14-15h ngày 23 đã có task ôn bài nhưng khi yêu cầu add activity vào 14h duration 1h ngày 23 thì agent vẫn add vào block đó. hãy debug và tìm ra nguyên nhân -> fix
2. Tôi không muốn 2 task hoặc activity có tên trùng nhau hãy thêm điều kiện check và thông báo cho user tên task hoặc activity đã tồn tại
3. hãy đọc kĩ note dưới mỗi test case mà tôi đã soạn -> tìm ra nguyên nhân -> fix