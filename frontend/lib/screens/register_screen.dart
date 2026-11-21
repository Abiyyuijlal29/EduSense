import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../utils/auth_validators.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/password_criteria_widget.dart';
import 'email_verification_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _namaController = TextEditingController();
  final _nipController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  // Real-time validation states
  String? _namaError;
  String? _nipError;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;

  PasswordValidationResult _passwordEvaluation = PasswordValidationResult('');

  @override
  void initState() {
    super.initState();
    _passwordEvaluation = PasswordValidationResult('');
  }

  @override
  void dispose() {
    _namaController.dispose();
    _nipController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _validateNama(String val) {
    setState(() {
      _namaError = AuthValidators.validateNamaLengkap(val);
    });
  }

  void _validateNip(String val) {
    setState(() {
      _nipError = AuthValidators.validateNip(val);
    });
  }

  void _validateEmail(String val) {
    setState(() {
      _emailError = AuthValidators.validateEmail(val);
    });
  }

  void _validatePassword(String val) {
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

  void _validateConfirmPassword(String val) {
    setState(() {
      _confirmPasswordError = AuthValidators.validateConfirmPassword(
        _passwordController.text,
        val,
      );
    });
  }

  bool get _isFormValid {
    final nama = _namaController.text.trim();
    final nip = _nipController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    final bool namaOk = nama.length >= 3 && _namaError == null;
    final bool nipOk =
        nip.length == AuthValidators.nipLength &&
        RegExp(r'^[0-9]+$').hasMatch(nip) &&
        _nipError == null;
    final bool emailOk =
        email.isNotEmpty &&
        AuthValidators.validateEmail(email) == null &&
        _emailError == null;
    final bool passOk = _passwordEvaluation.isValid && _passwordError == null;
    final bool confirmOk =
        confirm.isNotEmpty && confirm == password && _confirmPasswordError == null;

    return namaOk && nipOk && emailOk && passOk && confirmOk;
  }

  Future<void> _handleRegister() async {
    // Validasi akhir sebelum submit
    _validateNama(_namaController.text);
    _validateNip(_nipController.text);
    _validateEmail(_emailController.text);
    _validatePassword(_passwordController.text);
    _validateConfirmPassword(_confirmPasswordController.text);

    if (!_isFormValid) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await AuthService().registerDosen(
        nama: _namaController.text.trim(),
        nip: _nipController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Pendaftaran berhasil!'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Pindah ke Halaman Verifikasi Email OTP
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => EmailVerificationScreen(
            email: _emailController.text.trim(),
            nip: _nipController.text.trim(),
            nama: _namaController.text.trim(),
          ),
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
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Daftar Akun Dosen',
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
              // Header Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1E3A8A).withValues(alpha: 0.25),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.person_add_alt_1_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Registrasi Akun EduSense',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Lengkapi identitas dosen untuk akses sistem monitoring AI',
                            style: TextStyle(
                              color: Color(0xFFE2E8F0),
                              fontSize: 12,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

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
                    // Error Banner
                    if (_errorMessage != null) ...[
                      Container(
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
                      ),
                    ],

                    // 1. Nama Lengkap
                    AuthTextField(
                      controller: _namaController,
                      labelText: 'Nama Lengkap Beserta Gelar',
                      hintText: 'Contoh: Dr. Ir. Budi Santoso, M.Kom.',
                      prefixIcon: Icons.badge_outlined,
                      errorText: _namaError,
                      onChanged: _validateNama,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),

                    // 2. NIP Dosen (18 Digit Angka)
                    AuthTextField(
                      controller: _nipController,
                      labelText: 'NIP (Nomor Induk Pegawai)',
                      hintText: 'Wajib 18 digit angka (tanpa spasi)',
                      prefixIcon: Icons.fingerprint_rounded,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(
                            AuthValidators.nipLength),
                      ],
                      errorText: _nipError,
                      helperText:
                          '${_nipController.text.length}/${AuthValidators.nipLength} digit',
                      onChanged: _validateNip,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),

                    // 3. Email Institusi
                    AuthTextField(
                      controller: _emailController,
                      labelText: 'Alamat Email Resmi',
                      hintText: 'nama@polije.ac.id atau email aktif',
                      prefixIcon: Icons.alternate_email_rounded,
                      keyboardType: TextInputType.emailAddress,
                      errorText: _emailError,
                      onChanged: _validateEmail,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),

                    // 4. Buat Password
                    AuthTextField(
                      controller: _passwordController,
                      labelText: 'Buat Kata Sandi',
                      hintText: 'Minimal 8 karakter kombinasi',
                      prefixIcon: Icons.lock_outline_rounded,
                      isPassword: true,
                      obscureText: _obscurePassword,
                      onToggleObscure: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                      errorText: _passwordError,
                      onChanged: _validatePassword,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 10),

                    // Checklist Password Poin 8
                    PasswordCriteriaWidget(
                      evaluation: _passwordEvaluation,
                    ),
                    const SizedBox(height: 16),

                    // 5. Ulangi Password
                    AuthTextField(
                      controller: _confirmPasswordController,
                      labelText: 'Ulangi Kata Sandi',
                      hintText: 'Ketik ulang kata sandi yang sama',
                      prefixIcon: Icons.lock_reset_rounded,
                      isPassword: true,
                      obscureText: _obscureConfirmPassword,
                      onToggleObscure: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                      errorText: _confirmPasswordError,
                      onChanged: _validateConfirmPassword,
                      textInputAction: TextInputAction.done,
                    ),
                    const SizedBox(height: 24),

                    // Tombol Daftar (Nonaktif hingga semua validasi lolos)
                    ElevatedButton(
                      onPressed: (_isFormValid && !_isLoading)
                          ? _handleRegister
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
                        elevation: _isFormValid ? 3 : 0,
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
                              'Daftar Sekarang',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Link Kembali ke Login
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Sudah punya akun?',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 14,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Login di sini',
                      style: TextStyle(
                        color: Color(0xFF1E3A8A),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

