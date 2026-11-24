import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../utils/auth_validators.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/password_criteria_widget.dart';
import '../widgets/otp_input_widget.dart';
import '../widgets/countdown_resend_widget.dart';
import 'login_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  // Step: 1 = Input Email, 2 = Input OTP, 3 = Buat Password Baru
  int _currentStep = 1;

  // Controllers
  final _emailController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final GlobalKey<OtpInputWidgetState> _otpKey = GlobalKey();

  String _enteredOtp = '';
  String? _resetToken;

  // Obscure toggles
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  // State loading & error
  bool _isLoading = false;
  bool _isResending = false;
  String? _errorMessage;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;

  PasswordValidationResult _passwordEvaluation = PasswordValidationResult('');

  @override
  void dispose() {
    _emailController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // STEP 1: KIRIM KODE KE EMAIL
  // ===========================================================================
  void _validateEmail(String val) {
    setState(() {
      _emailError = AuthValidators.validateEmail(val);
      _errorMessage = null;
    });
  }

  Future<void> _handleSendResetCode() async {
    _validateEmail(_emailController.text);
    if (_emailError != null || _emailController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Harap masukkan alamat email yang valid.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await AuthService().requestPasswordResetOtp(
        email: _emailController.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Kode verifikasi telah dikirim.'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );

      setState(() {
        _currentStep = 2; // Pindah ke Step 2 (Verifikasi OTP)
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ===========================================================================
  // STEP 2: VERIFIKASI KODE OTP
  // ===========================================================================
  Future<void> _handleVerifyOtp([String? codeToVerify]) async {
    final code = (codeToVerify ?? _enteredOtp).trim();
    if (code.length != 6) {
      setState(() {
        _errorMessage = 'Harap masukkan 6 digit kode OTP secara lengkap.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await AuthService().verifyPasswordResetOtp(
        email: _emailController.text.trim(),
        otp: code,
      );

      if (!mounted) return;

      setState(() {
        _resetToken = res['reset_token'] ?? 'token_verified';
        _currentStep = 3; // Pindah ke Step 3 (Buat Password Baru)
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kode OTP valid! Silakan buat kata sandi baru.'),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleResendOtp() async {
    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    try {
      final res = await AuthService().requestPasswordResetOtp(
        email: _emailController.text.trim(),
      );

      if (!mounted) return;

      _otpKey.currentState?.clear();
      setState(() {
        _enteredOtp = '';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Kode verifikasi baru telah dikirim.'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  // ===========================================================================
  // STEP 3: BUAT PASSWORD BARU
  // ===========================================================================
  void _validateNewPassword(String val) {
    setState(() {
      _passwordEvaluation = AuthValidators.evaluatePassword(val);
      _passwordError = AuthValidators.validatePassword(val);
      if (_confirmPasswordController.text.isNotEmpty) {
        _confirmPasswordError = AuthValidators.validateConfirmPassword(
          val,
          _confirmPasswordController.text,
        );
      }
    });
  }

  void _validateConfirmNewPassword(String val) {
    setState(() {
      _confirmPasswordError = AuthValidators.validateConfirmPassword(
        _newPasswordController.text,
        val,
      );
    });
  }

  bool get _isNewPasswordValid {
    return _passwordEvaluation.isValid &&
        _passwordError == null &&
        _confirmPasswordController.text.isNotEmpty &&
        _confirmPasswordController.text == _newPasswordController.text &&
        _confirmPasswordError == null;
  }

  Future<void> _handleResetPassword() async {
    _validateNewPassword(_newPasswordController.text);
    _validateConfirmNewPassword(_confirmPasswordController.text);

    if (!_isNewPasswordValid) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await AuthService().resetPassword(
        email: _emailController.text.trim(),
        otp: _enteredOtp.isNotEmpty ? _enteredOtp : (_resetToken ?? ''),
        newPassword: _newPasswordController.text,
      );

      if (!mounted) return;

      // STEP 4: Tampilkan notifikasi sukses dan arahkan ke login
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          icon: Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFD1FAE5),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_reset_rounded,
              color: Color(0xFF10B981),
              size: 48,
            ),
          ),
          title: const Text(
            'Kata Sandi Berhasil Diperbarui!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          content: Text(
            res['message'] ??
                'Kata sandi baru berhasil disimpan. Silakan login menggunakan kata sandi baru Anda.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx); // tutup dialog
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                    (route) => false,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Login dengan Sandi Baru'),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ===========================================================================
  // WIDGET BUILDERS PER STEP
  // ===========================================================================
  Widget _buildStepIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildStepCircle(1, 'Email'),
          _buildStepDivider(1),
          _buildStepCircle(2, 'Kode OTP'),
          _buildStepDivider(2),
          _buildStepCircle(3, 'Sandi Baru'),
        ],
      ),
    );
  }

  Widget _buildStepCircle(int step, String label) {
    final bool isActive = _currentStep == step;
    final bool isDone = _currentStep > step;

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: isDone
                ? const Color(0xFF10B981)
                : (isActive ? const Color(0xFF1E3A8A) : const Color(0xFFE2E8F0)),
            shape: BoxShape.circle,
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: const Color(0xFF1E3A8A).withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    )
                  ]
                : null,
          ),
          child: Center(
            child: isDone
                ? const Icon(Icons.check, color: Colors.white, size: 18)
                : Text(
                    '$step',
                    style: TextStyle(
                      color: isActive ? Colors.white : const Color(0xFF64748B),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isActive
                ? const Color(0xFF1E3A8A)
                : (isDone ? const Color(0xFF10B981) : const Color(0xFF94A3B8)),
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildStepDivider(int step) {
    final bool isDone = _currentStep > step;
    return Container(
      width: 40,
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
      color: isDone ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
    );
  }

  Widget _buildErrorBanner() {
    if (_errorMessage == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded,
              color: Colors.red.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(
                color: Colors.red.shade800,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF1E3A8A)),
          onPressed: () {
            if (_currentStep > 1) {
              setState(() {
                _currentStep--;
                _errorMessage = null;
              });
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: const Text(
          'Pemulihan Kata Sandi',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Step Progress Indicator
              _buildStepIndicator(),
              const SizedBox(height: 16),

              // Form Container
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildErrorBanner(),

                    // STEP 1 CONTENT
                    if (_currentStep == 1) ...[
                      const Text(
                        'Langkah 1: Masukkan Email',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Kami akan mengirimkan 6 digit kode OTP verifikasi untuk memastikan Anda adalah pemilik akun.',
                        style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 20),
                      AuthTextField(
                        controller: _emailController,
                        labelText: 'Email Terdaftar',
                        hintText: 'nama@polije.ac.id',
                        prefixIcon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        errorText: _emailError,
                        onChanged: _validateEmail,
                        textInputAction: TextInputAction.done,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _handleSendResetCode,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3A8A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Kirim Kode Verifikasi',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ],

                    // STEP 2 CONTENT
                    if (_currentStep == 2) ...[
                      const Text(
                        'Langkah 2: Verifikasi Kode OTP',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF64748B),
                          ),
                          children: [
                            const TextSpan(
                                text: 'Masukkan kode 6 digit yang dikirim ke '),
                            TextSpan(
                              text: _emailController.text.trim(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E3A8A),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      OtpInputWidget(
                        key: _otpKey,
                        length: 6,
                        enabled: !_isLoading,
                        onChanged: (val) {
                          setState(() {
                            _enteredOtp = val;
                            _errorMessage = null;
                          });
                        },
                        onCompleted: (code) => _handleVerifyOtp(code),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: (_enteredOtp.length == 6 && !_isLoading)
                            ? () => _handleVerifyOtp()
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3A8A),
                          disabledBackgroundColor: const Color(0xFFCBD5E1),
                          foregroundColor: Colors.white,
                          disabledForegroundColor: const Color(0xFF94A3B8),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Verifikasi Kode OTP',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                      const SizedBox(height: 20),
                      CountdownResendWidget(
                        initialSeconds: 60,
                        onResend: _handleResendOtp,
                        isResending: _isResending,
                      ),
                    ],

                    // STEP 3 CONTENT
                    if (_currentStep == 3) ...[
                      const Text(
                        'Langkah 3: Buat Kata Sandi Baru',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Buat kata sandi baru yang kuat sesuai ketentuan keamanan sistem.',
                        style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 20),

                      // Input Password Baru
                      AuthTextField(
                        controller: _newPasswordController,
                        labelText: 'Kata Sandi Baru',
                        hintText: 'Minimal 8 karakter kombinasi',
                        prefixIcon: Icons.lock_outline_rounded,
                        isPassword: true,
                        obscureText: _obscureNewPassword,
                        onToggleObscure: () {
                          setState(() {
                            _obscureNewPassword = !_obscureNewPassword;
                          });
                        },
                        errorText: _passwordError,
                        onChanged: _validateNewPassword,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 10),

                      // Checklist Password Poin 8
                      PasswordCriteriaWidget(
                        evaluation: _passwordEvaluation,
                      ),
                      const SizedBox(height: 16),

                      // Input Ulangi Password Baru
                      AuthTextField(
                        controller: _confirmPasswordController,
                        labelText: 'Ulangi Kata Sandi Baru',
                        hintText: 'Ketik ulang kata sandi baru',
                        prefixIcon: Icons.lock_reset_rounded,
                        isPassword: true,
                        obscureText: _obscureConfirmPassword,
                        onToggleObscure: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                        errorText: _confirmPasswordError,
                        onChanged: _validateConfirmNewPassword,
                        textInputAction: TextInputAction.done,
                      ),
                      const SizedBox(height: 24),

                      // Tombol Simpan Sandi Baru
                      ElevatedButton(
                        onPressed: (_isNewPasswordValid && !_isLoading)
                            ? _handleResetPassword
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3A8A),
                          disabledBackgroundColor: const Color(0xFFCBD5E1),
                          foregroundColor: Colors.white,
                          disabledForegroundColor: const Color(0xFF94A3B8),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Simpan Kata Sandi Baru',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Kembali ke Login
              Center(
                child: TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_rounded,
                      size: 16, color: Color(0xFF64748B)),
                  label: const Text(
                    'Kembali ke Halaman Login',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

