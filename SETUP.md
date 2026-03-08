# Quick Setup Guide

## Complete Folder Structure

```
EXE/
├── lib/
│   ├── main.dart
│   ├── models/
│   │   ├── task.dart
│   │   └── schedule_item.dart
│   ├── screens/
│   │   ├── splash_screen.dart
│   │   ├── daily_check_screen.dart
│   │   ├── home_screen.dart
│   │   ├── task_input_screen.dart
│   │   ├── ai_schedule_screen.dart
│   │   ├── tasks_screen.dart
│   │   ├── calendar_screen.dart
│   │   └── profile_screen.dart
│   ├── widgets/
│   │   ├── task_card.dart
│   │   ├── growth_activity_card.dart
│   │   └── schedule_card.dart
│   └── utils/
│       └── constants.dart
├── pubspec.yaml
└── README.md
```

## Step-by-Step Setup

### 1. Verify Flutter Installation
```bash
flutter --version
```

You should see Flutter SDK version 2.19.0 or higher.

### 2. Navigate to Project Directory
```bash
cd "C:\Users\ADMIN\Desktop\EXE"
```

### 3. Get Dependencies
```bash
flutter pub get
```

This will download all required packages specified in `pubspec.yaml`.

### 4. Check Connected Devices
```bash
flutter devices
```

Make sure you have either:
- An Android/iOS emulator running
- A physical device connected via USB with USB debugging enabled

### 5. Run the App
```bash
flutter run
```

Or for specific platforms:
```bash
# Run on specific device
flutter run -d <device-id>

# Run on Chrome (web)
flutter run -d chrome

# Run on Windows (if Windows support is enabled)
flutter run -d windows
```

### 6. Hot Reload During Development

While the app is running:
- Press `r` to hot reload
- Press `R` to hot restart
- Press `q` to quit

## Troubleshooting

### Issue: "No devices found"
**Solution**: Make sure you have an emulator running or a device connected.

```bash
# List available emulators
flutter emulators

# Launch an emulator
flutter emulators --launch <emulator-id>
```

### Issue: "Gradle build failed" (Android)
**Solution**: Make sure you have Java JDK installed and Android SDK properly configured.

### Issue: "Waiting for another flutter command to release the startup lock"
**Solution**: Delete the lock file:

```bash
rm "C:\Users\ADMIN\AppData\Local\Pub\Cache\.flutter_tool_state"
```

Or on Windows PowerShell:
```powershell
Remove-Item "$env:LOCALAPPDATA\Pub\Cache\.flutter_tool_state" -Force
```

### Issue: "CocoaPods not installed" (iOS)
**Solution**: Install CocoaPods:

```bash
sudo gem install cocoapods
```

## Building Release Versions

### Android APK
```bash
flutter build apk --release
```

Output location: `build/app/outputs/flutter-apk/app-release.apk`

### Android App Bundle (for Play Store)
```bash
flutter build appbundle --release
```

Output location: `build/app/outputs/bundle/release/app-release.aab`

### iOS
```bash
flutter build ios --release
```

Then open `ios/Runner.xcworkspace` in Xcode to archive and distribute.

## Testing on Different Screen Sizes

To test responsive design, you can use Flutter DevTools:

```bash
flutter run
# Then press 'v' to open DevTools in browser
```

## Code Quality Checks

### Run Linter
```bash
flutter analyze
```

### Format Code
```bash
flutter format lib/
```

## Performance Profiling

```bash
flutter run --profile
```

## Additional Commands

### Clean Build Files
```bash
flutter clean
```

### Update Dependencies
```bash
flutter pub upgrade
```

### Check for Flutter Updates
```bash
flutter upgrade
```

## IDE Setup

### VS Code Extensions
1. Flutter
2. Dart
3. Flutter Widget Snippets
4. Awesome Flutter Snippets

### Android Studio Plugins
1. Flutter
2. Dart

## Demo Data

The app currently uses hardcoded demo data:
- User name: "Tan"
- 4 sample tasks
- 7 sample schedule items
- 4 personal growth activities

To modify demo data, edit the respective screen files in `lib/screens/`.

## Next Steps

1. Run the app and test all screens
2. Verify navigation works properly
3. Test task card interactions
4. Review UI on different screen sizes
5. Customize colors/styles if needed
6. Add your own demo data

## Support

If you encounter any issues:
1. Check Flutter doctor: `flutter doctor -v`
2. Read the error messages carefully
3. Search for the error on Stack Overflow
4. Check Flutter documentation: https://flutter.dev/docs

---

**Happy Coding! 🚀**
