# 📱 Google Login Setup - Android Studio Emulator Guide

## ✅ What's Been Implemented

Your Flutter app now has full **Google Sign-In authentication** with the following features:

- ✨ **Beautiful Login Screen** with app features showcase
- 🔐 **Firebase Authentication** with Google OAuth
- 📊 **Auto-routing**: Login screen → Home screen based on auth state  
- 🚪 **Logout functionality** in the Profile screen
- 💾 **Persistent authentication** across app restarts

---

## 🚀 Running on Android Studio Emulator

### **Step 1: Start Android Studio & Create/Launch Emulator**

1. Open **Android Studio**
2. Go to **Tools → Device Manager**
3. Either:
   - Click **"Create device"** to create a new emulator, OR
   - Click **"Play"** to launch an existing emulator
4. Wait for the emulator to fully boot (see Android home screen)

### **Step 2: Verify Emulator is Running**

In PowerShell, run:
```powershell
cd "C:\Users\ADMIN\Desktop\GAME CODE\EXE_AI-Planer"
flutter devices
```

You should see your emulator listed:
```
chrome (web) • chrome • web • Google Chrome
emulator-5554 (mobile) • emulator-5554 • android • Android 13 (API 33)
```

### **Step 3: Run the App**

```powershell
flutter run -d emulator-5554
```

Replace `emulator-5554` with your actual emulator ID from `flutter devices`

**Or simply run with auto-detection:**
```powershell
flutter run
```
(It will automatically select the emulator if it's the only device)

---

## 🔍 Important Notes

### **Google Sign-In on Android Emulator**

⚠️ **The emulator must have Google Play Services installed**

Most modern Android emulator images (API 28+) come with Play Services pre-installed, but if you see "user_disabled" or authentication errors:

1. **Check emulator image**: Use **API 33+** with **Google APIs**
2. **Create a new emulator** if needed:
   - Device Manager → "Create device"
   - Select device (e.g., Pixel 6)
   - Select API Level **33 or higher**
   - **Important**: When installing, choose the image with **"Google APIs"** (has Google Play Services)

### **Firebase Console Configuration**

Your app is already configured to use project `chitan160204`. The OAuth credentials are set up for:
- Package: `com.exe.aiplanner`
- SHA-1 fingerprint should be registered in Firebase Console

To get your debug SHA-1:
```powershell
cd "C:\Users\ADMIN\Desktop\GAME CODE\EXE_AI-Planer\android"
./gradlew signingReport
```

---

## 📖 How to Test the Login

1. **App starts on Login Screen** (no user logged in yet)
2. **Tap "Sign in with Google"** button
3. **Google sign-in dialog appears** → Select your Gmail account
4. **Redirects to Home Screen** after successful login
5. **Try logout**: Go to Profile tab → Tap Logout button
6. **Returns to Login Screen**

---

## 🐛 Troubleshooting

### Error: "user_disabled" or "operation-not-allowed"
- ✅ **Solution**: Ensure emulator has Google Play Services (API 33+ with Google APIs)

### Error: "invalid-credential"  
- ✅ **Solution**: Check that firebase configuration is correct in Firebase Console

### App shows black screen or crashes on startup
- ✅ **Solution**: 
  ```powershell
  flutter clean
  flutter pub get
  flutter run -d emulator-5554
  ```

### Can't select Google account in emulator
- ✅ **Solution**: Add a Google account to emulator first
  - Settings → Accounts & sync → Add account → Google
  - Sign in with a test Gmail account

---

## 🎯 Next Steps

After testing on Android emulator, you can also test on:

### **Web (Chrome) - Fastest for testing**
```powershell
flutter run -d chrome --dart-define=OPENAI_API_KEY=sk-proj-xxxxx
```

### **Windows Desktop**
```powershell
flutter run -d windows --dart-define=OPENAI_API_KEY=sk-proj-xxxxx
```

### **Build APK for distribution**
```powershell
flutter build apk --release --dart-define=OPENAI_API_KEY=sk-proj-xxxxx
```

---

## 📁 Files Modified/Created

| File | Change |
|------|--------|
| `pubspec.yaml` | Added firebase_core, firebase_auth, google_sign_in |
| `lib/main.dart` | Firebase initialization + Auth state routing |
| `lib/services/auth_service.dart` | ✨ NEW - Handles Google Sign-In |
| `lib/screens/login_screen.dart` | ✨ NEW - Beautiful login UI |
| `lib/firebase_options.dart` | ✨ NEW - Firebase config for all platforms |
| `lib/screens/profile_screen.dart` | Added functional logout button |
| `android/app/build.gradle.kts` | Added Google Services plugin |
| `android/app/google-services.json` | Firebase Android config |
| `android/build.gradle.kts` | Added Google Services classpath |

---

## ✨ UI Features

### **Login Screen**
- Company logo & app title
- 3 feature highlights (Smart Scheduling, Performance Tracking, Chat Planning)
- Google Sign-In button with error handling
- Loading state with progress indicator
- Beautiful gradient background

### **After Login**
- Full access to all app features
- User info displayed in Profile screen
- Logout option available

---

## 🔒 Security Notes

- ✅ API keys are safely stored in Firebase configuration
- ✅ Authentication tokens managed by Firebase Auth
- ✅ No sensitive data stored in SharedPreferences
- ✅ Google Sign-In handles token refresh automatically

---

## 📞 Support

If you encounter any issues:

1. Check **Flutter Doctor** status:
   ```powershell
   flutter doctor
   ```

2. Check emulator logs:
   ```powershell
   adb logcat | grep "flutter"
   ```

3. Ensure you're using **Flutter 3.0+**:
   ```powershell
   flutter --version
   ```

Good luck! 🎉
