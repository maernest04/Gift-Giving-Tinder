import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'theme.dart';
import 'onboarding_page.dart';
import 'pages/home_page.dart';

import 'services/theme_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_page.dart';

Future<void> main() async {
  // Load environment variables before running the app
  await dotenv.load(fileName: '.env');
  runApp(const GiftMatchApp());
}

class GiftMatchApp extends StatefulWidget {
  const GiftMatchApp({super.key});

  @override
  State<GiftMatchApp> createState() => _GiftMatchAppState();
}

class _GiftMatchAppState extends State<GiftMatchApp> {
  bool _isInitialized = false;
  bool _showOnboarding = true;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Run initialization and minimum display time in parallel (no font preload to avoid web DDC conflict)
    await Future.wait([
      _performInitialization(),
      Future.delayed(const Duration(milliseconds: 1500)),
    ]);

    // Check if onboarding was already seen
    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;

    // Trigger the transition
    if (mounted) {
      setState(() {
        _showOnboarding = !hasSeenOnboarding;
        _isInitialized = true;
      });
    }
  }

  Future<void> _performInitialization() async {
    // Initialize Theme/Preferences from storage
    await themeService.init();

    // Then initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Initial check of auth state to reduce flicker
    try {
      await FirebaseAuth.instance.authStateChanges().first.timeout(
        const Duration(seconds: 1),
      );
    } catch (_) {
      // Ignore timeout, we'll handle it in build
    }

  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return ListenableBuilder(
        listenable: themeService,
        builder: (context, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: themeService.isGlass
                ? Brightness.light
                : Brightness.dark,
            scaffoldBackgroundColor: themeService.isGlass
                ? AppColors.bgLight
                : AppColors.bgDark,
          ),
          home: _buildSplashScreen(),
        ),
      );
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        return ListenableBuilder(
          listenable: themeService,
          builder: (context, _) {
            return MaterialApp(
              title: 'Gift Match',
              themeAnimationDuration: const Duration(milliseconds: 600),
              themeAnimationCurve: Curves.easeInOut,
              theme: ThemeData(
                brightness: themeService.isGlass
                    ? Brightness.light
                    : Brightness.dark,
                scaffoldBackgroundColor: themeService.isGlass
                    ? AppColors.bgLight
                    : AppColors.bgDark,
                useMaterial3: true,
              ),
              debugShowCheckedModeBanner: false,
              home: AnimatedSwitcher(
                duration: const Duration(milliseconds: 800),
                switchInCurve: Curves.easeIn,
                switchOutCurve: Curves.easeOut,
                transitionBuilder: (child, animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
                child: authSnapshot.connectionState == ConnectionState.waiting
                    ? _buildSplashScreen()
                    : (authSnapshot.data != null
                          ? const HomePage(key: ValueKey('home'))
                          : (_showOnboarding
                                ? const OnboardingPage(
                                    key: ValueKey('onboarding'),
                                  )
                                : const LoginPage(key: ValueKey('login')))),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSplashScreen() {
    return ListenableBuilder(
      listenable: themeService,
      builder: (context, _) {
        return Container(
          key: const ValueKey('splash'),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                themeService.isGlass ? Colors.black : AppColors.bgDark,
                const Color(0xFF667eea).withOpacity(0.1),
                themeService.isGlass ? Colors.black : AppColors.bgDark,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated Logo
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Opacity(
                        opacity: value,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: AppColors.primaryGradient,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryGradient[0].withOpacity(
                                  0.4,
                                ),
                                blurRadius: 30,
                                offset: const Offset(0, 15),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text("💝", style: TextStyle(fontSize: 60)),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                // Pulsing loading indicator
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.5, end: 1.0),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeInOut,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: const SizedBox(
                        width: 60,
                        height: 60,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFFf093fb),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
