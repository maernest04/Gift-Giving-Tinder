import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'theme.dart';
import 'onboarding_page.dart';

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

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Run initialization and minimum display time in parallel
    await Future.wait([
      // Actual initialization
      _performInitialization(),
      // Minimum splash screen display time (1.5 seconds)
      Future.delayed(const Duration(milliseconds: 1500)),
    ]);

    // Trigger the transition
    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  Future<void> _performInitialization() async {
    // Preload fonts first
    await GoogleFonts.pendingFonts([GoogleFonts.outfit(), GoogleFonts.inter()]);

    // Then initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Small delay to ensure fonts are fully rendered
    await Future.delayed(const Duration(milliseconds: 300));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gift Match',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.bgDark,
        fontFamily: GoogleFonts.inter().fontFamily,
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
        child: _isInitialized
            ? const OnboardingPage(key: ValueKey('onboarding'))
            : _buildSplashScreen(),
      ),
    );
  }

  Widget _buildSplashScreen() {
    return Container(
      key: const ValueKey('splash'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.bgDark,
            const Color(0xFF667eea).withOpacity(0.1),
            AppColors.bgDark,
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
                        Color(
                          0xFFf093fb,
                        ), // Lighter purple/pink from secondary gradient
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
  }
}
