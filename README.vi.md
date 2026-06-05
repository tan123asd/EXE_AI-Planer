# AI Planner

> 🇬🇧 [View English version](README.md)

Ứng dụng lập lịch thông minh cho sinh viên, xây dựng bằng Flutter. Tích hợp AI để tạo kế hoạch học tập, quản lý deadline, và theo dõi hoạt động cá nhân.

## Tính năng

### Free
- Tạo task có deadline với AI lên lịch tự động (15 lượt/ngày)
- Chat với AI Agent để lập kế hoạch
- Lịch tuần, theo dõi tiến độ
- Nhắc nhở Pomodoro (50 phút học / 10 phút nghỉ)
- Đồng bộ dữ liệu đa thiết bị qua Firestore
- Đăng nhập Google

### Pro (79.000đ/tháng hoặc 790.000đ/năm)
- Chat AI Agent không giới hạn
- 100 lượt AI/ngày
- Ưu tiên phản hồi, nhận tính năng mới sớm nhất

## Kiến trúc

```
lib/
├── main.dart
├── models/
│   ├── task.dart                   # Task, ScheduleItem, Activity
│   ├── schedule_item.dart
│   ├── chat_models.dart            # ChatMessage, ConversationContext, AiToolCall
│   └── scheduler_models.dart       # AiTaskPlan, ScheduledSlot, ProductivityWindow
├── screens/
│   ├── home_screen.dart            # Dashboard chính
│   ├── chat_planner_screen.dart    # Chat AI Agent
│   ├── calendar_screen.dart        # Lịch theo ngày/tuần
│   ├── payment_screen.dart         # Nâng cấp Pro (QR VietQR)
│   ├── profile_screen.dart         # Cài đặt, productivity hours
│   ├── new_task_input_screen.dart  # Tạo task mới
│   └── ai_schedule_screen.dart     # Xem lịch AI tạo
├── services/
│   ├── ai_service.dart             # Gemini API → AiTaskPlan
│   ├── scheduler_service.dart      # Thuật toán xếp lịch (deadline + activity)
│   ├── chat_ai_service.dart        # GPT-4o-mini Function Calling
│   ├── chat_planner_service.dart   # Thực thi tool calls
│   ├── payment_service.dart        # Tạo payment_request, VietQR
│   ├── subscription_service.dart   # Quản lý tier Free/Pro + expiry
│   ├── firestore_service.dart      # Sync Firestore ↔ local
│   ├── storage_service.dart        # SharedPreferences CRUD
│   ├── auth_service.dart           # Firebase Auth
│   └── notification_service.dart   # Push notification
├── widgets/
│   ├── chat_message_bubble.dart
│   ├── chat_plan_preview_card.dart # Preview plan + Approve/Reject
│   ├── upgrade_dialog.dart         # Dialog nâng cấp Pro
│   └── ...
└── utils/
    └── constants.dart              # Design system (màu, typography)

vercel-backend/
└── api/
    └── webhook.js                  # Nhận webhook Sepay, cập nhật Firestore
```

## Cài đặt

### Yêu cầu
- Flutter SDK `>=3.0.0`
- Dart SDK `>=3.0.0`
- Firebase project (Auth + Firestore)
- OpenAI API key (GPT-4o-mini)

### Chạy local

```bash
flutter pub get
flutter run --dart-define=OPENAI_API_KEY=sk-...
```

### Build release

```bash
# Android
flutter build apk --release --dart-define=OPENAI_API_KEY=sk-...

# iOS
flutter build ios --release --dart-define=OPENAI_API_KEY=sk-...
```

## Cấu hình Firebase

File `lib/firebase_options.dart` được tạo tự động bằng FlutterFire CLI:

```bash
flutterfire configure
```

File `android/app/google-services.json` lấy từ Firebase Console → Project Settings → Android app.

## Webhook thanh toán (Vercel)

Xử lý thông báo giao dịch từ Sepay → kích hoạt Pro tự động.

### Deploy

```bash
cd vercel-backend
vercel --prod
```

### Biến môi trường trên Vercel

| Biến | Mô tả |
|---|---|
| `FIREBASE_PROJECT_ID` | Firebase project ID |
| `FIREBASE_CLIENT_EMAIL` | Service account email |
| `FIREBASE_PRIVATE_KEY` | Service account private key |
| `SEPAY_API_KEY` | Key xác thực webhook từ Sepay |

### Cấu hình Sepay

Webhook URL (dùng alias, không dùng deployment URL cụ thể):
```
https://vercel-backend-zeta-one.vercel.app/api/webhook
```

## Luồng thanh toán

```
User chọn gói → Flutter tạo payment_request trong Firestore
→ Hiển thị QR VietQR + mã ref (VD: AP84YZYH)
→ User chuyển khoản Sacombank (BẮT BUỘC ghi đúng mã ref vào nội dung)
→ Sepay phát hiện giao dịch → POST tới webhook
→ Webhook xác thực, cập nhật subscription_tier + subscription_expire_at
→ App tự động nhận qua Firestore snapshot → hiển thị "Thanh toán thành công"
```

## Design System

Định nghĩa trong `lib/utils/constants.dart`.

| Token | Giá trị |
|---|---|
| Primary | `#FF6B35` (cam) |
| Background | `#F8F9FA` |
| Success | `#10B981` |
| Warning | `#F59E0B` |
| Danger | `#EF4444` |

## Hỗ trợ

Liên hệ: **0935457152**
