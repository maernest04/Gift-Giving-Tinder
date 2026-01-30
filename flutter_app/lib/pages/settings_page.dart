import 'package:flutter/material.dart';
import '../theme.dart';
import '../onboarding_page.dart';
import '../main.dart'; // For restarting app if needed, or just navigation
import '../login_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int _currentTab = 0;
  final List<String> _tabs = ['Account', 'Interests', 'Experience', 'Security'];

  // Account State
  final _nameController = TextEditingController(text: "User Name");
  final _emailController = TextEditingController(text: "user@example.com");

  // Experience State
  bool _hapticFeedback = true;
  bool _showSwiped = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tab Bar
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          color: AppColors.bgDark,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: List.generate(_tabs.length, (index) {
                final isSelected = _currentTab == index;
                return GestureDetector(
                  onTap: () => setState(() => _currentTab = index),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primaryGradient[0]
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: isSelected
                          ? null
                          : Border.all(color: AppColors.borderColor),
                    ),
                    child: Text(
                      _tabs[index],
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),

        // Content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _buildCurrentTab(),
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentTab() {
    switch (_currentTab) {
      case 0:
        return _buildAccountTab();
      case 1:
        return _buildInterestsTab();
      case 2:
        return _buildExperienceTab();
      case 3:
        return _buildSecurityTab();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildAccountTab() {
    return Column(
      children: [
        _buildSection(
          title: "Profile Information",
          children: [
            _buildTextField("Display Name", _nameController),
            const SizedBox(height: 16),
            _buildTextField("Email Address", _emailController),
          ],
        ),
        const SizedBox(height: 24),
        _buildSection(
          title: "Session",
          children: [
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  // Logout
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                    (route) => false,
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFf5576c),
                  side: const BorderSide(color: Color(0xFFf5576c)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text("Log Out"),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildSection(
          title: "Danger Zone",
          children: [
            const Text(
              "Actions here are permanent and cannot be undone.",
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFf5576c).withOpacity(0.8),
                  side: BorderSide(
                    color: const Color(0xFFf5576c).withOpacity(0.4),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text("Delete Account"),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInterestsTab() {
    // Mock interests
    return _buildSection(
      title: "Your Interests",
      children: [
        const Text(
          "You haven't swiped on anything yet.",
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () {},
            child: const Text("Reset & Swipe Again"),
          ),
        ),
      ],
    );
  }

  Widget _buildExperienceTab() {
    return Column(
      children: [
        _buildSection(
          title: "Interface Settings",
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                "Haptic Feedback",
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                "Vibrate on interactions",
                style: TextStyle(color: AppColors.textSecondary),
              ),
              value: _hapticFeedback,
              onChanged: (val) => setState(() => _hapticFeedback = val),
              activeColor: AppColors.primaryGradient[0],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                "Show Swiped Items",
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                "Keep history visible",
                style: TextStyle(color: AppColors.textSecondary),
              ),
              value: _showSwiped,
              onChanged: (val) => setState(() => _showSwiped = val),
              activeColor: AppColors.primaryGradient[0],
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildSection(
          title: "Theme",
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.bgDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primaryGradient[0],
                        width: 2,
                      ),
                    ),
                    child: const Center(
                      child: Text(
                        "Vibrant Dark",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Opacity(
                    opacity: 0.5,
                    child: Container(
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderColor),
                      ),
                      child: const Center(
                        child: Text(
                          "Glass",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSecurityTab() {
    return _buildSection(
      title: "Update Password",
      children: [
        _buildTextField(
          "Current Password",
          TextEditingController(),
          isPassword: true,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          "New Password",
          TextEditingController(),
          isPassword: true,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          "Confirm New Password",
          TextEditingController(),
          isPassword: true,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGradient[0],
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              "Change Password",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.h3.copyWith(fontSize: 18)),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool isPassword = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.bgDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderColor),
          ),
          child: TextField(
            controller: controller,
            obscureText: isPassword,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }
}
