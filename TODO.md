# TODO - Deploy Firebase Hosting + Host APK

- [ ] Xác nhận cấu hình `firebase.json` (hosting public folder)
- [ ] Build web mới: `flutter build web --release`
- [ ] Deploy web lên Firebase Hosting: `firebase deploy --only hosting`
- [ ] Copy `build/app/outputs/flutter-apk/app-release.apk` vào folder public dùng để host file (khuyến nghị: `build/web/downloads/`)
- [ ] Deploy lại Hosting để có link tải APK
- [ ] Kiểm tra link download trên Firebase Hosting (trình duyệt)

