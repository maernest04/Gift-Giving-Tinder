import 'package:flutter/material.dart';
import '../theme.dart';
import '../login_page.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with WidgetsBindingObserver {
  int _currentTab = 0;
  final List<String> _tabs = ['Account', 'Interests', 'Experience'];

  // Account State
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _emailPasswordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = true;
  bool _isSaving = false;

  String? _originalName;
  String? _originalEmail;
  bool _nameChanged = false;
  bool _emailChanged = false;
  String? _passwordError;
  String? _nameSuccess;
  String? _emailSuccess;
  String? _nameError;
  String? _emailError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserData();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadUserData();
    }
  }

  Future<void> _loadUserData() async {
    try {
      final user = await _authService.getCurrentUser();
      if (user != null && mounted) {
        setState(() {
          _nameController.text = user.name;
          _emailController.text = user.email;
          _originalName = user.name;
          _originalEmail = user.email;
          _isLoading = false;
        });
        // Add listeners AFTER data is loaded to prevent false triggers
        _nameController.addListener(_onNameChanged);
        _emailController.addListener(_onEmailChanged);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onNameChanged() {
    final hasChanged = _nameController.text.trim() != _originalName;
    if (hasChanged != _nameChanged) {
      setState(() => _nameChanged = hasChanged);
    }
  }

  void _onEmailChanged() {
    final hasChanged = _emailController.text.trim() != _originalEmail;
    if (hasChanged != _emailChanged) {
      setState(() => _emailChanged = hasChanged);
    }
  }

  void _cancelNameChange() {
    setState(() {
      _nameController.text = _originalName ?? '';
      _nameChanged = false;
    });
  }

  void _cancelEmailChange() {
    setState(() {
      _emailController.text = _originalEmail ?? '';
      _emailChanged = false;
      _emailPasswordController.clear();
      _emailError = null;
    });
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _emailController.removeListener(_onEmailChanged);
    WidgetsBinding.instance.removeObserver(this);
    _nameController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _emailPasswordController.dispose();
    super.dispose();
  }

  void _onTabTap(int index) {
    setState(() => _currentTab = index);
  }

  // Experience State - Now managed by themeService globally

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeService,
      builder: (context, _) {
        final cardBg = themeService.isGlass
            ? Colors.white.withOpacity(0.7)
            : AppColors.bgCard;
        final borderColor = themeService.isGlass
            ? Colors.black.withOpacity(0.05)
            : AppColors.borderColor;
        return Column(
          children: [
            // Modern Single Tab Bar
            AnimatedContainer(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOut,
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
                boxShadow: themeService.isGlass
                    ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: List.generate(_tabs.length, (index) {
                  final isSelected = _currentTab == index;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => _onTabTap(index),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeInOut,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (themeService.isGlass
                                    ? Colors.white
                                    : null) // Use gradient if not glass
                              : Colors.transparent,
                          gradient: isSelected && !themeService.isGlass
                              ? const LinearGradient(
                                  colors: AppColors.primaryGradient,
                                )
                              : null,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: themeService.isGlass
                                        ? Colors.black.withOpacity(0.05)
                                        : AppColors.primaryGradient[0]
                                              .withOpacity(0.3),
                                    blurRadius: themeService.isGlass ? 4 : 8,
                                    offset: themeService.isGlass
                                        ? const Offset(0, 2)
                                        : const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          _tabs[index],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isSelected
                                ? (themeService.isGlass
                                      ? const Color(0xFF1a1a2e)
                                      : Colors.white)
                                : AppColors.getSecondaryTextColor(),
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),

            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                reverseDuration: const Duration(milliseconds: 100),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                layoutBuilder: (currentChild, previousChildren) {
                  return Stack(
                    alignment: Alignment.topCenter,
                    children: <Widget>[
                      ...previousChildren,
                      if (currentChild != null) currentChild,
                    ],
                  );
                },
                transitionBuilder: (child, animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
                child: _buildScrollableContent(
                  _getCurrentTabContent(),
                  key: ValueKey(_currentTab),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildScrollableContent(Widget child, {Key? key}) {
    return SingleChildScrollView(
      key: key,
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: child,
      ),
    );
  }

  Widget _getCurrentTabContent() {
    switch (_currentTab) {
      case 0:
        return _buildAccountTab();
      case 1:
        return _buildInterestsTab();
      case 2:
        return _buildExperienceTab();
      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _saveNameChange() async {
    // Clear previous messages
    setState(() {
      _nameError = null;
      _nameSuccess = null;
    });

    if (_nameController.text.trim() == _originalName) {
      return; // No changes, just return silently
    }

    setState(() => _isSaving = true);
    try {
      await _authService.updateDisplayName(_nameController.text.trim());
      setState(() {
        _originalName = _nameController.text.trim();
        _nameChanged = false;
        _nameSuccess = 'Name updated successfully!';
      });
      // Auto-dismiss success message after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() => _nameSuccess = null);
        }
      });
    } catch (e) {
      setState(() => _nameError = 'Failed to update name. Please try again.');
      // Auto-dismiss error after 5 seconds
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() => _nameError = null);
        }
      });
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveEmailChange() async {
    // Clear previous messages
    setState(() {
      _emailError = null;
      _emailSuccess = null;
    });

    if (_emailController.text.trim() == _originalEmail) {
      return; // No changes, just return silently
    }

    // Validate email format
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(_emailController.text.trim())) {
      setState(() => _emailError = 'Please enter a valid email address');
      // Auto-dismiss error after 5 seconds
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() => _emailError = null);
        }
      });
      return;
    }

    setState(() => _isSaving = true);
    try {
      if (_emailPasswordController.text.isEmpty) {
        throw CustomAuthException(
          'missing-password',
          'Please enter your current password to confirm the change.',
        );
      }

      await _authService.updateEmail(
        _emailController.text.trim(),
        _originalEmail!,
        _emailPasswordController.text,
      );
      setState(() {
        _originalEmail = _emailController.text.trim();
        _emailChanged = false;
        _emailSuccess = 'Verification email sent!';
        _emailPasswordController.clear();
      });
      // Auto-dismiss success message after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() => _emailSuccess = null);
        }
      });
    } catch (e) {
      setState(
        () => _emailError = e.toString().contains('Verification email sent')
            ? null
            : e
                  .toString()
                  .replaceFirst('Exception: ', '')
                  .replaceFirst('CustomAuthException: ', ''),
      );
      // Auto-dismiss error after 5 seconds
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() => _emailError = null);
        }
      });
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _changePassword() async {
    // Clear previous error
    setState(() => _passwordError = null);

    if (_currentPasswordController.text.isEmpty ||
        _newPasswordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      setState(() => _passwordError = 'Please fill in all password fields');
      return;
    }

    if (_newPasswordController.text.length < 6) {
      setState(
        () => _passwordError = 'New password must be at least 6 characters',
      );
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      setState(() => _passwordError = 'New passwords do not match');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _authService.updatePassword(
        _currentPasswordController.text,
        _newPasswordController.text,
      );
      setState(() {
        _passwordError = null;
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      });

      // Logout the user after password change for security
      await _authService.signOut();
    } catch (e) {
      setState(() {
        _passwordError = e.toString().contains('wrong-password')
            ? 'Current password is incorrect'
            : 'Failed to change password. Please try again.';
      });
      // Auto-dismiss error after 5 seconds
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() => _passwordError = null);
        }
      });
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildAccountTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildSection(
          title: "Profile Information",
          children: [
            _buildTextField("Display Name", _nameController),
            if (_nameSuccess != null)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4ade80).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF4ade80).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        color: Color(0xFF4ade80),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _nameSuccess!,
                          style: const TextStyle(
                            color: Color(0xFF4ade80),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_nameError != null)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFff4d6d).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFff4d6d).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Color(0xFFff4d6d),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _nameError!,
                          style: const TextStyle(
                            color: Color(0xFFff4d6d),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_nameChanged) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveNameChange,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGradient[0],
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              "Change Name",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving ? null : _cancelNameChange,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.borderColor),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "Cancel",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            _buildTextField("Email Address", _emailController),
            if (_emailSuccess != null)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4ade80).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF4ade80).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        color: Color(0xFF4ade80),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _emailSuccess!,
                          style: const TextStyle(
                            color: Color(0xFF4ade80),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_emailError != null)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFff4d6d).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFff4d6d).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Color(0xFFff4d6d),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _emailError!,
                          style: const TextStyle(
                            color: Color(0xFFff4d6d),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_emailChanged) ...[
              const SizedBox(height: 16),
              _buildTextField(
                "Current Password to Confirm",
                _emailPasswordController,
                isPassword: true,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveEmailChange,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGradient[0],
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              "Change Email",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSaving ? null : _cancelEmailChange,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.borderColor),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "Cancel",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        const SizedBox(height: 24),
        _buildSection(
          title: "Change Password",
          children: [
            _buildTextField(
              "Current Password",
              _currentPasswordController,
              isPassword: true,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              "New Password",
              _newPasswordController,
              isPassword: true,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              "Confirm New Password",
              _confirmPasswordController,
              isPassword: true,
            ),
            const SizedBox(height: 16),
            if (_passwordError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFff4d6d).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFff4d6d).withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Color(0xFFff4d6d),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _passwordError!,
                          style: const TextStyle(
                            color: Color(0xFFff4d6d),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _changePassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGradient[0],
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        "Change Password",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
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
        const SizedBox(height: 48),
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
    return ListenableBuilder(
      listenable: themeService,
      builder: (context, _) {
        return Column(
          children: [
            _buildSection(
              title: "Interface Settings",
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    "Haptic Feedback",
                    style: TextStyle(color: AppColors.getTextColor()),
                  ),
                  subtitle: Text(
                    "Vibrate on interactions",
                    style: TextStyle(color: AppColors.getSecondaryTextColor()),
                  ),
                  value: themeService.hapticFeedback,
                  onChanged: (val) => themeService.setHapticFeedback(val),
                  activeThumbColor: AppColors.primaryGradient[0],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    "Show Swiped Items",
                    style: TextStyle(color: AppColors.getTextColor()),
                  ),
                  subtitle: Text(
                    "Keep history visible",
                    style: TextStyle(color: AppColors.getSecondaryTextColor()),
                  ),
                  value: themeService.showSwipedItems,
                  onChanged: (val) => themeService.setShowSwipedItems(val),
                  activeThumbColor: AppColors.primaryGradient[0],
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
                      child: InkWell(
                        onTap: () =>
                            themeService.setTheme(AppTheme.vibrantDark),
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 80,
                          decoration: BoxDecoration(
                            color: AppColors.bgDark,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  themeService.currentTheme ==
                                      AppTheme.vibrantDark
                                  ? AppColors.primaryGradient[0]
                                  : AppColors.borderColor,
                              width:
                                  themeService.currentTheme ==
                                      AppTheme.vibrantDark
                                  ? 2
                                  : 1,
                            ),
                          ),
                          child: const Center(
                            child: Text(
                              "Vibrant Dark",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () => themeService.setTheme(AppTheme.glass),
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: themeService.currentTheme == AppTheme.glass
                                  ? AppColors.primaryGradient[0]
                                  : Colors.black.withOpacity(0.1),
                              width: themeService.currentTheme == AppTheme.glass
                                  ? 2
                                  : 1,
                            ),
                          ),
                          child: const Center(
                            child: Text(
                              "Pearly Glass",
                              style: TextStyle(
                                color: Color(0xFF1a1a2e),
                                fontWeight: FontWeight.bold,
                              ),
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
      },
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    final cardColor = themeService.isGlass
        ? Colors.white.withOpacity(0.7)
        : AppColors.bgCard;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: themeService.isGlass
            ? Border.all(color: Colors.black.withOpacity(0.05))
            : null,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.h3.copyWith(
              fontSize: 18,
              color: AppColors.getTextColor(),
            ),
          ),
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
    final fieldBg = themeService.isGlass
        ? Colors.black.withOpacity(0.03)
        : AppColors.bgDark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: AppColors.getSecondaryTextColor(),
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: fieldBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: themeService.isGlass
                  ? Colors.black.withOpacity(0.05)
                  : AppColors.borderColor,
            ),
          ),
          child: TextField(
            controller: controller,
            obscureText: isPassword,
            style: TextStyle(color: AppColors.getTextColor()),
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
