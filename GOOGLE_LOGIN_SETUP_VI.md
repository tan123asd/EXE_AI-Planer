# 📱 Hướng Dẫn Thiết Lập Google Login - Android Studio Emulator

## ✅ Những Gì Đã Được Triển Khai

Ứng dụng Flutter của bạn giờ đây có **xác thực Google Sign-In** đầy đủ với các tính năng sau:

- ✨ **Giao diện Đăng Nhập Đẹp** với trưng bày tính năng ứng dụng
- 🔐 **Xác thực Firebase** với Google OAuth
- 📊 **Định tuyến Tự động**: Màn hình Đăng Nhập → Màn hình Chính dựa trên trạng thái xác thực
- 🚪 **Chức năng Đăng Xuất** trong màn hình Hồ Sơ
- 💾 **Xác thực Lâu Dài** trên các lần khởi động lại ứng dụng

---

## 🚀 Chạy trên Android Studio Emulator

### **Bước 1: Mở Android Studio & Tạo/Khởi Động Emulator**

1. Mở **Android Studio**
2. Đi đến **Tools → Device Manager**
3. Hoặc:
   - Nhấp **"Create device"** để tạo emulator mới, HOẶC
   - Nhấp **"Play"** để khởi động emulator hiện có
4. Chờ emulator khởi động hoàn toàn (xem màn hình chính Android)

### **Bước 2: Xác Minh Emulator Đang Chạy**

Trong PowerShell, chạy:
```powershell
cd "C:\Users\ADMIN\Desktop\GAME CODE\EXE_AI-Planer"
flutter devices
```

Bạn sẽ thấy emulator của mình được liệt kê:
```
chrome (web) • chrome • web • Google Chrome
emulator-5554 (mobile) • emulator-5554 • android • Android 13 (API 33)
```

### **Bước 3: Chạy Ứng Dụng**

```powershell
flutter run -d emulator-5554
```

Thay `emulator-5554` bằng ID emulator thực tế của bạn từ `flutter devices`

**Hoặc chỉ cần chạy với tự động phát hiện:**
```powershell
flutter run
```
(Nó sẽ tự động chọn emulator nếu nó là thiết bị duy nhất)

---

## 🔍 Những Lưu Ý Quan Trọng

### **Google Sign-In trên Android Emulator**

⚠️ **Emulator phải có Google Play Services được cài đặt**

Hầu hết các image emulator Android hiện đại (API 28+) đi kèm với Play Services được cài đặt sẵn, nhưng nếu bạn thấy "user_disabled" hoặc lỗi xác thực:

1. **Kiểm tra image emulator**: Sử dụng **API 33+** với **Google APIs**
2. **Tạo emulator mới** nếu cần:
   - Device Manager → "Create device"
   - Chọn thiết bị (ví dụ: Pixel 6)
   - Chọn Mức API **33 hoặc cao hơn**
   - **Quan Trọng**: Khi cài đặt, chọn image có **"Google APIs"** (có Google Play Services)

### **Cấu Hình Firebase Console**

Ứng dụng của bạn đã được cấu hình để sử dụng dự án `chitan160204`. Thông tin xác thực OAuth được thiết lập cho:
- Gói: `com.exe.aiplanner`
- SHA-1 fingerprint nên được đăng ký trong Firebase Console

Để lấy debug SHA-1 của bạn:
```powershell
cd "C:\Users\ADMIN\Desktop\GAME CODE\EXE_AI-Planer\android"
./gradlew signingReport
```

---

## 📖 Cách Kiểm Tra Đăng Nhập

1. **Ứng dụng bắt đầu trên Màn hình Đăng Nhập** (chưa có người dùng đăng nhập)
2. **Nhấp nút "Sign in with Google"**
3. **Hộp thoại đăng nhập Google xuất hiện** → Chọn tài khoản Gmail của bạn
4. **Chuyển hướng đến Màn hình Chính** sau khi đăng nhập thành công
5. **Thử đăng xuất**: Đi tới tab Hồ Sơ → Nhấp nút Đăng Xuất
6. **Quay lại Màn hình Đăng Nhập**

---

## 🐛 Khắc Phục Sự Cố

### Lỗi: "user_disabled" hoặc "operation-not-allowed"
- ✅ **Giải Pháp**: Đảm bảo emulator có Google Play Services (API 33+ với Google APIs)

### Lỗi: "invalid-credential"
- ✅ **Giải Pháp**: Kiểm tra xem cấu hình firebase có chính xác không trong Firebase Console

### Ứng dụng hiển thị màn hình đen hoặc gặp lỗi khi khởi động
- ✅ **Giải Pháp**:
  ```powershell
  flutter clean
  flutter pub get
  flutter run -d emulator-5554
  ```

### Không thể chọn tài khoản Google trong emulator
- ✅ **Giải Pháp**: Thêm tài khoản Google vào emulator trước tiên
  - Cài Đặt → Tài Khoản & đồng bộ → Thêm tài khoản → Google
  - Đăng nhập bằng tài khoản Gmail thử nghiệm

---

## 🎯 Các Bước Tiếp Theo

Sau khi kiểm tra trên emulator Android, bạn cũng có thể kiểm tra trên:

### **Web (Chrome) - Nhanh nhất để kiểm tra**
```powershell
flutter run -d chrome --dart-define=OPENAI_API_KEY=sk-proj-xxxxx
```

### **Windows Desktop**
```powershell
flutter run -d windows --dart-define=OPENAI_API_KEY=sk-proj-xxxxx
```

### **Xây dựng APK để phân phối**
```powershell
flutter build apk --release --dart-define=OPENAI_API_KEY=sk-proj-xxxxx
```

---

## 📁 Các Tệp Được Sửa Đổi/Tạo

| Tệp | Thay Đổi |
|-----|----------|
| `pubspec.yaml` | Thêm firebase_core, firebase_auth, google_sign_in |
| `lib/main.dart` | Khởi tạo Firebase + Định tuyến trạng thái xác thực |
| `lib/services/auth_service.dart` | ✨ MỚI - Xử lý Google Sign-In |
| `lib/screens/login_screen.dart` | ✨ MỚI - Giao diện đăng nhập đẹp |
| `lib/firebase_options.dart` | ✨ MỚI - Cấu hình Firebase cho tất cả các nền tảng |
| `lib/screens/profile_screen.dart` | Thêm nút đăng xuất chức năng |
| `android/app/build.gradle.kts` | Thêm plugin Google Services |
| `android/app/google-services.json` | Cấu hình Firebase cho Android |
| `android/build.gradle.kts` | Thêm classpath Google Services |

---

## ✨ Tính Năng Giao Diện

### **Màn Hình Đăng Nhập**
- Logo công ty & tiêu đề ứng dụng
- 3 điểm nổi bật tính năng (Lập Lịch Thông Minh, Theo Dõi Hiệu Suất, Lập Kế Hoạch Trò Chuyện)
- Nút Google Sign-In với xử lý lỗi
- Trạng thái đang tải với chỉ báo tiến trình
- Nền tảng gradient đẹp

### **Sau Khi Đăng Nhập**
- Truy cập đầy đủ vào tất cả các tính năng ứng dụng
- Thông tin người dùng được hiển thị trong màn hình Hồ Sơ
- Tùy chọn đăng xuất có sẵn

---

## 🔒 Ghi Chú Bảo Mật

- ✅ Các khóa API được lưu trữ an toàn trong cấu hình Firebase
- ✅ Mã thông báo xác thực được quản lý bởi Firebase Auth
- ✅ Không có dữ liệu nhạy cảm được lưu trữ trong SharedPreferences
- ✅ Google Sign-In xử lý làm mới mã thông báo tự động

---

## 📞 Hỗ Trợ

Nếu bạn gặp bất kỳ vấn đề nào:

1. Kiểm tra trạng thái **Flutter Doctor**:
   ```powershell
   flutter doctor
   ```

2. Kiểm tra nhật ký emulator:
   ```powershell
   adb logcat | grep "flutter"
   ```

3. Đảm bảo bạn đang sử dụng **Flutter 3.0+**:
   ```powershell
   flutter --version
   ```

Chúc may mắn! 🎉
