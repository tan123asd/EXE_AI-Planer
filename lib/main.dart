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
import 'services/auth_service.dart';
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
      home: const _AuthGate(),
    );
  }
}

/// Listens to Firebase auth state. When the state becomes null (e.g. due to
/// Android Doze killing the background token refresh), tries a silent Google
/// sign-in before falling back to the login screen. This prevents spurious
/// logouts caused by temporary token refresh failures.
class _AuthGate extends StatefulWidget {
  const _AuthGate({Key? key}) : super(key: key);

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  bool _isSigningInSilently = false;
  bool _didTriggerSilentSignIn = false;

  @override
  void initState() {
    super.initState();

    // Trigger silent sign-in once on app start; prevents rebuild-triggered loops.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _trySilentSignInOnce();
    });
  }

  void _trySilentSignInOnce() async {
    if (_isSigningInSilently || _didTriggerSilentSignIn) return;
    _didTriggerSilentSignIn = true;
    if (!mounted) return;

    setState(() => _isSigningInSilently = true);
    await AuthService().signInSilently();
    if (!mounted) return;
    setState(() => _isSigningInSilently = false);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting ||
            _isSigningInSilently) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          return const HomeScreen();
        }

        // If still signed out after silent sign-in attempt, show login.
        return const LoginScreen();
      },
    );
  }
}

