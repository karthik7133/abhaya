import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:country_code_picker/country_code_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/common_widgets/glass_card.dart';
import '../../../core/providers/settings_provider.dart';
import '../providers/auth_provider.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _ageController = TextEditingController();
  String _selectedGender = 'Male';
  final List<String> _genders = ['Male', 'Female', 'Other'];
  bool _isSignUp = false;
  String _countryCode = '+91';
  bool _otpSent = false;
  String? _verificationId;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.status == AuthStatus.loading;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.bgDeep, AppColors.bgMid],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // ── Ambient Orbs ──────────────────────────────────────────────
              Positioned(
                top: -60, left: -80,
                child: Container(
                  height: 280, width: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      AppColors.accentTeal.withValues(alpha: 0.09),
                      Colors.transparent,
                    ]),
                  ),
                ),
              ),
              Positioned(
                bottom: -100, right: -80,
                child: Container(
                  height: 320, width: 320,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      AppColors.accentCrimson.withValues(alpha: 0.07),
                      Colors.transparent,
                    ]),
                  ),
                ),
              ),
              Positioned(
                top: 200, right: -60,
                child: Container(
                  height: 200, width: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      AppColors.accentAmber.withValues(alpha: 0.06),
                      Colors.transparent,
                    ]),
                  ),
                ),
              ),

              // ── Main Content ──────────────────────────────────────────────
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 64),
                      _buildSignInCard(isLoading, ref, context),

                      if (authState.errorMessage != null) ...[
                        const SizedBox(height: 16),
                        _buildErrorBanner(authState.errorMessage!, ref),
                      ],

                      const SizedBox(height: 48),
                      _buildPrivacyNote(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Column(
      children: [
        // Shield logo
        Container(
          height: 88, width: 88,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: RadialGradient(colors: [
              AppColors.accentTeal.withValues(alpha: 0.25),
              AppColors.accentTeal.withValues(alpha: 0.05),
            ]),
            border: Border.all(
              color: AppColors.accentTeal.withValues(alpha: 0.45),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.accentTeal.withValues(alpha: 0.25),
                blurRadius: 32,
                spreadRadius: -4,
              ),
            ],
          ),
          child: const Icon(
            Icons.shield_outlined,
            size: 44,
            color: AppColors.accentTeal,
          ),
        )
            .animate()
            .scale(duration: 650.ms, curve: Curves.easeOutBack)
            .fadeIn(duration: 400.ms),

        const SizedBox(height: 24),

        const Text(
          'ABHAYA',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 36,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: 5.0,
          ),
        ).animate().fadeIn(duration: 500.ms, delay: 100.ms),

        const SizedBox(height: 8),

        const Text(
          'AI-Powered Predictive Safety Ecosystem',
          style: TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 14,
            color: AppColors.textSecondary,
            letterSpacing: 0.3,
          ),
          textAlign: TextAlign.center,
        ).animate().fadeIn(duration: 500.ms, delay: 200.ms),
      ],
    );
  }

  // ── Sign-In Card ─────────────────────────────────────────────────────────────

  Widget _buildSignInCard(
    bool isLoading,
    WidgetRef ref,
    BuildContext context,
  ) {
    const Color accentColor = AppColors.accentTeal;

    return GlassCard(
      borderRadius: 24,
      borderColor: accentColor.withValues(alpha: 0.30),
      shadows: [
        BoxShadow(
          color: accentColor.withValues(alpha: 0.08),
          blurRadius: 48,
          offset: const Offset(0, 20),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.3),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Title
            Text(
              _otpSent ? 'Enter OTP' : (_isSignUp ? 'Create Account' : 'Sign In to Abhaya'),
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _otpSent ? 'Enter the code sent to your phone' : 'Your personal AI safety guardian.',
              style: const TextStyle(
                fontFamily: 'PlusJakartaSans',
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 32),

            if (!_otpSent) ...[
              if (_isSignUp) ...[
                // Name Field
                TextField(
                  controller: _nameController,
                  style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'PlusJakartaSans', fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Full Name',
                    hintStyle: const TextStyle(color: AppColors.textMuted, fontFamily: 'PlusJakartaSans'),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
                const SizedBox(height: 12),
                // Email Field
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'PlusJakartaSans', fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Email ID (Optional)',
                    hintStyle: const TextStyle(color: AppColors.textMuted, fontFamily: 'PlusJakartaSans'),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: _ageController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'PlusJakartaSans', fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Age',
                          hintStyle: const TextStyle(color: AppColors.textMuted, fontFamily: 'PlusJakartaSans'),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.05),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        value: _selectedGender,
                        dropdownColor: AppColors.bgDeep,
                        items: _genders.map((g) => DropdownMenuItem(value: g, child: Text(g, style: const TextStyle(color: AppColors.textPrimary)))).toList(),
                        onChanged: (val) { if (val != null) setState(() => _selectedGender = val); },
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.05),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              // Phone Number Input
              Row(
                children: [
                  // Country Code Picker
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: CountryCodePicker(
                      padding: EdgeInsets.zero,
                      onChanged: (code) {
                        setState(() => _countryCode = code.dialCode!);
                      },
                      initialSelection: 'IN',
                      favorite: ['+91', 'US'],
                      showOnlyCountryWhenClosed: false,
                      showCountryOnly: false,
                      hideMainText: false,
                      alignLeft: false,
                      textStyle: const TextStyle(
                        color: AppColors.textPrimary,
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 14,
                      ),
                      barrierColor: Colors.black54,
                      backgroundColor: AppColors.bgMid,
                      dialogBackgroundColor: AppColors.bgDeep,
                      dialogTextStyle: const TextStyle(
                        color: AppColors.textPrimary,
                        fontFamily: 'PlusJakartaSans',
                      ),
                      searchStyle: const TextStyle(
                        color: AppColors.textPrimary,
                        fontFamily: 'PlusJakartaSans',
                      ),
                      searchDecoration: InputDecoration(
                        hintText: 'Search Country',
                        hintStyle: TextStyle(
                          color: AppColors.textMuted,
                          fontFamily: 'PlusJakartaSans',
                        ),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Phone Number Field
                  Expanded(
                    child: TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontFamily: 'PlusJakartaSans',
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Phone Number',
                        hintStyle: TextStyle(
                          color: AppColors.textMuted,
                          fontFamily: 'PlusJakartaSans',
                        ),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Send OTP Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: isLoading ? null : () => _sendOTP(ref),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentTeal,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 24, height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Send OTP',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 16),
              TextButton(
                onPressed: () => setState(() => _isSignUp = !_isSignUp),
                child: Text(
                  _isSignUp ? 'Already have an account? Sign In' : 'New here? Create Account',
                  style: const TextStyle(
                    fontFamily: 'PlusJakartaSans',
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ] else ...[
              // OTP Input
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 8,
                ),
                decoration: InputDecoration(
                  hintText: '000000',
                  hintStyle: TextStyle(
                    color: AppColors.textMuted,
                    fontFamily: 'PlusJakartaSans',
                    letterSpacing: 8,
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 20,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Verify OTP Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: isLoading ? null : () => _verifyOTP(ref, context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentTeal,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 24, height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Verify & Sign In',
                          style: TextStyle(
                            fontFamily: 'PlusJakartaSans',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Guest Emergency Mode Button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: isLoading ? null : () async {
                  final notifier = ref.read(authNotifierProvider.notifier);
                  final success = await notifier.guestSignIn();
                  if (success && context.mounted) {
                    context.go('/home');
                  }
                },
                icon: const Icon(Icons.emergency_rounded, color: AppColors.accentCrimson),
                label: const Text('Guest Emergency Mode', style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accentCrimson,
                )),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentCrimson.withValues(alpha: 0.1),
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms, delay: 400.ms)
        .slideY(begin: 0.08, end: 0, duration: 400.ms, delay: 400.ms);
  }

  Future<void> _sendOTP(WidgetRef ref) async {
    final text = _phoneController.text.trim();
    if (text.isEmpty) {
      ref.read(authNotifierProvider.notifier).setError('Please enter your phone number');
      return;
    }

    var cleanDigits = text.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    String phoneNumber;
    if (cleanDigits.startsWith('+')) {
      phoneNumber = cleanDigits;
    } else {
      cleanDigits = cleanDigits.replaceFirst(RegExp(r'^0+'), '');
      final ccDigits = _countryCode.replaceAll('+', '');
      if (cleanDigits.startsWith(ccDigits)) {
        cleanDigits = cleanDigits.substring(ccDigits.length);
      }
      phoneNumber = '$_countryCode$cleanDigits';
    }

    final notifier = ref.read(authNotifierProvider.notifier);

    await notifier.sendOTP(
      phoneNumber: phoneNumber,
      isSignUp: _isSignUp,
      onCodeSent: (verificationId) {
        setState(() {
          _verificationId = verificationId;
          _otpSent = true;
        });
      },
    );
  }

  Future<void> _verifyOTP(WidgetRef ref, BuildContext context) async {
    if (_otpController.text.isEmpty || _verificationId == null) {
      ref.read(authNotifierProvider.notifier).setError('Please enter the OTP code');
      return;
    }

    final notifier = ref.read(authNotifierProvider.notifier);
    final success = await notifier.verifyOTP(
      verificationId: _verificationId!,
      smsCode: _otpController.text.trim(),
      name: _isSignUp ? _nameController.text.trim() : null,
      email: _isSignUp ? _emailController.text.trim() : null,
      age: _isSignUp ? int.tryParse(_ageController.text.trim()) : null,
      gender: _isSignUp ? _selectedGender : null,
    );

    if (success && context.mounted) {
      final isSet = ref.read(settingsProvider).requireBiometric; 
      
      if (!isSet && context.mounted) {
        final enable = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.bgMid,
            title: const Text('Enable Fingerprint Login?', style: TextStyle(color: Colors.white)),
            content: const Text('Would you like to use your fingerprint or face to quickly unlock Abhaya next time?', style: TextStyle(color: AppColors.textSecondary)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Later', style: TextStyle(color: AppColors.textMuted)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Enable', style: TextStyle(color: AppColors.accentTeal, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
        
        if (enable == true) {
          await ref.read(settingsProvider.notifier).toggleBiometric(true);
        }
      }
      if (context.mounted) {
        context.go('/home');
      }
    }
  }

  // ── Error Banner ─────────────────────────────────────────────────────────────

  Widget _buildErrorBanner(String message, WidgetRef ref) {
    return GlassCard(
      borderRadius: 12,
      borderColor: AppColors.accentCrimson.withValues(alpha: 0.5),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        const Icon(Icons.warning_amber_rounded,
            color: AppColors.accentCrimson, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 13,
              color: AppColors.accentCrimson,
            ),
          ),
        ),
        GestureDetector(
          onTap: () => ref.read(authNotifierProvider.notifier).clearError(),
          child: const Icon(Icons.close, color: AppColors.textSecondary, size: 16),
        ),
      ]),
    ).animate().fadeIn(duration: 300.ms).shake(duration: 400.ms);
  }

  // ── Privacy Note ─────────────────────────────────────────────────────────────

  Widget _buildPrivacyNote() {
    return const Text(
      'By continuing, you agree to Abhaya\'s Terms of Service\nand Privacy Policy. We never share your location data.',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: 'PlusJakartaSans',
        fontSize: 12,
        color: AppColors.textMuted,
        height: 1.6,
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 600.ms);
  }
}
