import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/theme_service.dart';

class PartnerPage extends StatefulWidget {
  const PartnerPage({super.key});

  @override
  State<PartnerPage> createState() => _PartnerPageState();
}

class _PartnerPageState extends State<PartnerPage> {
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeService,
      builder: (context, _) {
        final cardBg = themeService.isGlass
            ? Colors.white.withOpacity(0.7)
            : AppColors.bgCard;
        final inputBg = themeService.isGlass
            ? Colors.black.withOpacity(0.03)
            : AppColors.bgDark;
        final borderColor = themeService.isGlass
            ? Colors.black.withOpacity(0.05)
            : AppColors.borderColor;

        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: borderColor),
                  boxShadow: themeService.isGlass
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  children: [
                    const Text("🔗", style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 16),
                    Text(
                      "Connect with Partner",
                      style: AppTextStyles.h2,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Enter your partner's code to see their interests!",
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.getSecondaryTextColor(),
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // Input
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeInOut,
                      decoration: BoxDecoration(
                        color: inputBg,
                        borderRadius: BorderRadius.circular(16),
                        border: themeService.isGlass
                            ? Border.all(color: borderColor)
                            : null,
                      ),
                      child: TextField(
                        controller: _codeController,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.h3.copyWith(
                          letterSpacing: 2,
                          color: AppColors.getTextColor(),
                        ),
                        decoration: InputDecoration(
                          hintText: "ENTER CODE",
                          hintStyle: TextStyle(
                            color: AppColors.getSecondaryTextColor(),
                            fontSize: 20,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(16),
                        ),
                        textCapitalization: TextCapitalization.characters,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF667eea),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          "Send Request",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
