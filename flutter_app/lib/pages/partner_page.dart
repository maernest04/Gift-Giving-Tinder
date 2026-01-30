import 'package:flutter/material.dart';
import '../theme.dart';

class PartnerPage extends StatefulWidget {
  const PartnerPage({super.key});

  @override
  State<PartnerPage> createState() => _PartnerPageState();
}

class _PartnerPageState extends State<PartnerPage> {
  final _codeController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.borderColor),
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
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Input
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.bgDark,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TextField(
                    controller: _codeController,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.h3.copyWith(letterSpacing: 2),
                    decoration: const InputDecoration(
                      hintText: "ENTER CODE",
                      hintStyle: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 20,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(16),
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
  }
}
