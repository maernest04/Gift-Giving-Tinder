import 'package:flutter/material.dart';
import 'theme.dart';
import 'login_page.dart';

class OnboardingSlide {
  final String emoji;
  final String title;
  final String description;
  final List<Color> gradientColors;

  const OnboardingSlide({
    required this.emoji,
    required this.title,
    required this.description,
    required this.gradientColors,
  });
}

const slides = [
  OnboardingSlide(
    emoji: '💝',
    title: 'Welcome to Gift Match',
    description: 'The smart way to find the perfect gift for your partner',
    gradientColors: [Color(0xFF667eea), Color(0xFF764ba2)],
  ),
  OnboardingSlide(
    emoji: '👆',
    title: 'Swipe on Preferences',
    description:
        'Not actual gifts - just styles, categories, and themes you like',
    // #f093fb -> #f5576c
    gradientColors: [Color(0xFFf093fb), Color(0xFFf5576c)],
  ),
  OnboardingSlide(
    emoji: '🤝',
    title: 'Connect with your Partner',
    description: 'See what your partner likes and what gifts they would love',
    // #4facfe -> #00f2fe
    gradientColors: [Color(0xFF4facfe), Color(0xFF00f2fe)],
  ),
  OnboardingSlide(
    emoji: '🎁',
    title: 'Get Matched',
    description:
        "Swipe on your own interests to build a profile. Your partner gets your wishlist to surprise you with the perfect gift.",
    // #fa709a -> #fee140
    gradientColors: [Color(0xFFfa709a), Color(0xFFfee140)],
  ),
];

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onNext() {
    if (_currentIndex < slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _onBack() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  void _finishOnboarding() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const LoginPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Stack(
        children: [
          // Animated Background Gradient
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  slides[_currentIndex].gradientColors[0].withOpacity(0.15),
                  AppColors.bgDark,
                  slides[_currentIndex].gradientColors[1].withOpacity(0.15),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Skip Button
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextButton(
                      onPressed: _finishOnboarding,
                      child: Text(
                        "Skip",
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),

                // Page View
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentIndex = index;
                      });
                    },
                    children: slides.map((slide) {
                      return Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Emoji Circle
                            Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: slide.gradientColors,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: slide.gradientColors[0].withOpacity(
                                      0.4,
                                    ),
                                    blurRadius: 30,
                                    offset: const Offset(0, 15),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  slide.emoji,
                                  style: const TextStyle(fontSize: 64),
                                ),
                              ),
                            ),
                            const SizedBox(height: 48),

                            // Text Content
                            Text(
                              slide.title,
                              style: AppTextStyles.h1.copyWith(fontSize: 32),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              slide.description,
                              style: AppTextStyles.body.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 18,
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),

                // Controls
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 48),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Left Side: Back Button + Dots
                      Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            width: _currentIndex > 0 ? 48.0 : 0.0,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const NeverScrollableScrollPhysics(),
                              child: SizedBox(
                                width: 48,
                                child: AnimatedOpacity(
                                  duration: const Duration(milliseconds: 300),
                                  opacity: _currentIndex > 0 ? 1.0 : 0.0,
                                  child: IconButton(
                                    onPressed: _currentIndex > 0
                                        ? _onBack
                                        : null,
                                    icon: const Icon(Icons.arrow_back),
                                    color: AppColors.textSecondary,
                                    tooltip: 'Back',
                                    padding: EdgeInsets.zero,
                                    alignment: Alignment.centerLeft,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Dots
                          Row(
                            children: List.generate(
                              slides.length,
                              (index) => AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin: const EdgeInsets.only(right: 8),
                                height: 8,
                                width: _currentIndex == index ? 24 : 8,
                                decoration: BoxDecoration(
                                  color: _currentIndex == index
                                      ? slides[_currentIndex].gradientColors[0]
                                      : AppColors.textSecondary.withOpacity(
                                          0.3,
                                        ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Next/Done Button
                      GestureDetector(
                        onTap: _onNext,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: slides[_currentIndex].gradientColors,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: slides[_currentIndex].gradientColors[0]
                                    .withOpacity(0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _currentIndex == slides.length - 1
                                    ? "Get Started"
                                    : "Next",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                _currentIndex == slides.length - 1
                                    ? Icons.rocket_launch
                                    : Icons.arrow_forward,
                                color: Colors.white,
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
