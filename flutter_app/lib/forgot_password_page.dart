import 'package:flutter/material.dart';
import 'theme.dart';
import 'services/auth_service.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  String? _emailError;
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleResetPassword() async {
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      setState(() {
        _emailError = 'Please enter your email address';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _emailError = null;
    });

    try {
      await _authService.resetPassword(email);

      if (mounted) {
        setState(() {
          _emailSent = true;
          _isLoading = false;
        });
      }
    } on CustomAuthException catch (e) {
      if (mounted) {
        setState(() {
          _emailError = e.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _emailError = 'Failed to send reset email. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: Stack(
        children: [
          // Background Gradient Orbs
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryGradient[0].withOpacity(0.3),
                    Colors.transparent,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppColors.secondaryGradient[1].withOpacity(0.3),
                    Colors.transparent,
                  ],
                  begin: Alignment.bottomRight,
                  end: Alignment.topLeft,
                ),
              ),
            ),
          ),

          // Main Content
          SafeArea(
            child: Column(
              children: [
                // Back Button
                Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back),
                    color: AppColors.textSecondary,
                    padding: const EdgeInsets.all(16),
                  ),
                ),

                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Icon
                          Container(
                            width: 80,
                            height: 80,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: AppColors.secondaryGradient,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0x4Df5576c),
                                  blurRadius: 20,
                                  offset: Offset(0, 10),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.lock_reset,
                                size: 40,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          Text(
                            _emailSent ? "Check Your Email" : "Reset Password",
                            style: AppTextStyles.h1,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _emailSent
                                ? "We've sent a new password reset link to ${_emailController.text.trim()}. Please check your inbox for the latest email."
                                : "Enter your email address and we'll send you instructions to reset your password",
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 48),

                          if (!_emailSent) ...[
                            // Form Card
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: AppColors.glassBg,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: AppColors.glassBorder,
                                ),
                              ),
                              child: Column(
                                children: [
                                  _buildInput(
                                    controller: _emailController,
                                    label: "Email Address",
                                    icon: Icons.email_outlined,
                                    keyboardType: TextInputType.emailAddress,
                                    errorText: _emailError,
                                  ),
                                  const SizedBox(height: 24),

                                  // Send Button
                                  Container(
                                    width: double.infinity,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: AppColors.secondaryGradient,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x4Df5576c),
                                          blurRadius: 16,
                                          offset: Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(16),
                                        onTap: _isLoading
                                            ? null
                                            : _handleResetPassword,
                                        child: Center(
                                          child: _isLoading
                                              ? const CircularProgressIndicator(
                                                  color: Colors.white,
                                                )
                                              : const Text(
                                                  "Send Reset Link",
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            // Success State
                            Container(
                              padding: const EdgeInsets.all(32),
                              decoration: BoxDecoration(
                                color: AppColors.glassBg,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: AppColors.glassBorder,
                                ),
                              ),
                              child: Column(
                                children: [
                                  const Icon(
                                    Icons.mark_email_read_outlined,
                                    size: 64,
                                    color: Color(0xFFf093fb),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    "Didn't receive the email?",
                                    style: AppTextStyles.body.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _emailSent = false;
                                      });
                                    },
                                    child: Text(
                                      'Try Again',
                                      style: AppTextStyles.body.copyWith(
                                        color: const Color(0xFFf093fb),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 24),

                          // Back to Login
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: RichText(
                              text: TextSpan(
                                text: "Remember your password? ",
                                style: AppTextStyles.body.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                                children: const [
                                  TextSpan(
                                    text: "Sign In",
                                    style: TextStyle(
                                      color: Color(0xFF667eea),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
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

  Widget _buildInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? errorText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            if (errorText != null)
              Text(
                errorText,
                style: const TextStyle(
                  color: Color(0xFFff4d6d),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: errorText != null
                  ? const Color(0xFFff4d6d).withOpacity(0.5)
                  : AppColors.borderColor,
            ),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: AppTextStyles.input,
            decoration: InputDecoration(
              prefixIcon: Icon(
                icon,
                color: errorText != null
                    ? const Color(0xFFff4d6d)
                    : AppColors.textSecondary,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 16,
                horizontal: 16,
              ),
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }
}
