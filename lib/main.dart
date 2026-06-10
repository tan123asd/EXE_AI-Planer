import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:ai_study_planner/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/storage_service.dart';
import 'services/subscription_service.dart';
import 'services/user_profile_service.dart';
import 'services/notification_service.dart';
import 'services/sync_queue_service.dart';
import 'services/connectivity_service.dart';
import 'providers/theme_provider.dart';
import 'providers/language_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await StorageService().init();

  // If user is already logged in (cold start) but user_name was cleared
  // (e.g. after a previous logout), restore it from Firebase Auth.
  final fbUser = FirebaseAuth.instance.currentUser;
  if (fbUser != null && StorageService().getUserName().isEmpty) {
    final name = fbUser.displayName?.trim().isNotEmpty == true
        ? fbUser.displayName!.trim()
        : (fbUser.email?.split('@').first ?? '');
    if (name.isNotEmpty) await StorageService().saveUserName(name);
  }

  await UserProfileService().init();
  await SubscriptionService().init();
  await SyncQueueService().init();
  ConnectivityService().init();
  try {
    await NotificationService().init();
    await NotificationService().scheduleAllNotifications();
  } catch (_) {
    // Notification init failure must not block app startup.
  }

  final languageProvider = LanguageProvider();
  await languageProvider.load();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider.value(value: languageProvider),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final languageProvider = context.watch<LanguageProvider>();

    return MaterialApp(
      title: 'AI Study Planner',
      debugShowCheckedModeBanner: false,
      theme: themeProvider.lightTheme,
      darkTheme: themeProvider.darkTheme,
      themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      locale: languageProvider.locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('vi'),
      ],
      routes: {
        '/home': (context) => const HomeScreen(),
        '/login': (context) => const LoginScreen(),
      },
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // While checking auth state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          // If user is logged in, show HomeScreen, otherwise show LoginScreen
          if (snapshot.hasData && snapshot.data != null) {
            return const HomeScreen();
          } else {
            return const LoginScreen();
          }
        },
      ),
    );
  }
}
