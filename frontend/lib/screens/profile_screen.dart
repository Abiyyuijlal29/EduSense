import 'package:flutter/material.dart';
import '../models/user_dosen.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/firebase_service.dart';
import '../utils/auth_validators.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/lecturer_avatar.dart';
import '../widgets/password_criteria_widget.dart';
import '../widgets/profile_photo_crop_dialog.dart';
import '../widgets/otp_input_widget.dart';
import 'login_screen.dart';

/// Halaman Profil Dosen, Edit Profil, Ubah Password, & Logout (Prompt 7 & 8)
class ProfileScreen extends StatefulWidget {
  final UserDosen dosen;
  const ProfileScreen({super.key, required this.dosen});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late UserDosen _dosen;

  @override
  void initState() {
    super.initState();
    _dosen = widget.dosen;
  }

  void _openPhotoCropDialog() {
    ProfilePhotoCropDialog.show(
      context,
      currentPhotoUrl: _dosen.fotoUrl ?? '',
      onPhotoSaved: (newUrl) async {
        setState(() {
          _dosen = _dosen.copyWith(fotoUrl: newUrl);
        });
        ApiService().currentUser = _dosen;
        await FirebaseService().updateFotoDosen(_dosen.nip, newUrl);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Foto profil berhasil diperbarui!'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
      },
    );
  }

  // ===========================================================================
  // 1. DIALOG / BOTTOMSHEET EDIT PROFIL (NAMA, EMAIL, FOTO, NIP READ-ONLY)
  // ===========================================================================
  void _openEditProfileDialog() {
    final namaController = TextEditingController(text: _dosen.nama);
    final emailController = TextEditingController(text: _dosen.email);
    String? localPhotoUrl = _dosen.fotoUrl;
    bool isSaving = false;
    String? namaError;
    String? emailError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;

            void validateInputs() {
              setSheetState(() {
                namaError =
                    AuthValidators.validateNamaLengkap(namaController.text);
                emailError = AuthValidators.validateEmail(emailController.text);
              });
            }

            Future<void> saveProfile() async {
              validateInputs();
              if (namaError != null || emailError != null) return;

              final oldEmail = _dosen.email.trim().toLowerCase();
              final newEmail = emailController.text.trim().toLowerCase();
              final newNama = namaController.text.trim();

              setSheetState(() => isSaving = true);

              // Jika email diubah -> minta verifikasi ulang OTP
              if (newEmail != oldEmail) {
                setSheetState(() => isSaving = false);
                Navigator.pop(sheetContext); // Tutup edit profile sheet
                _showEmailReverificationDialog(
                  targetNewEmail: newEmail,
                  targetNewNama: newNama,
                  targetFotoUrl: localPhotoUrl,
                );
                return;
              }

              // Update data ke API dan Firebase
              try {
                await AuthService().updateProfile(
                  nama: newNama,
                  email: newEmail,
                  fotoUrl: localPhotoUrl,
                );

                await FirebaseService().updateProfileDosen(
                  nip: _dosen.nip,
                  nama: newNama,
                  email: newEmail,
                  fotoUrl: localPhotoUrl,
                );

                setState(() {
                  _dosen = _dosen.copyWith(
                    nama: newNama,
                    email: newEmail,
                    fotoUrl: localPhotoUrl,
                  );
                });
                ApiService().currentUser = _dosen;

                if (mounted) {
                  Navigator.pop(sheetContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Profil dosen berhasil diperbarui!'),
                      backgroundColor: Color(0xFF10B981),
                    ),
                  );
                }
              } catch (e) {
                setSheetState(() => isSaving = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Gagal menyimpan profil: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }

            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: bottomInset + 20,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.edit_note_rounded,
                            color: Color(0xFF1E3A8A), size: 26),
                        const SizedBox(width: 10),
                        const Text(
                          'Edit Data Dosen',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(sheetContext),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Avatar & tombol ganti foto
                    Center(
                      child: Stack(
                        children: [
                          LecturerAvatar(
                            fotoUrl: localPhotoUrl,
                            nama: namaController.text.isNotEmpty
                                ? namaController.text
                                : _dosen.nama,
                            radius: 42,
                            showCameraIcon: false,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: InkWell(
                              onTap: () {
                                ProfilePhotoCropDialog.show(
                                  context,
                                  currentPhotoUrl: localPhotoUrl ?? '',
                                  onPhotoSaved: (savedUrl) {
                                    setSheetState(() {
                                      localPhotoUrl = savedUrl;
                                    });
                                  },
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(7),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF1E3A8A),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Center(
                      child: Text(
                        'Ketuk ikon kamera untuk ganti foto',
                        style:
                            TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Field NIP (READ ONLY)
                    const Text(
                      'Nomor Induk Pegawai (NIP)',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.lock_outline_rounded,
                              size: 18, color: Color(0xFF64748B)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _dosen.nip,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF334155),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Read-Only',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Field Nama Lengkap
                    AuthTextField(
                      controller: namaController,
                      labelText: 'Nama Lengkap Beserta Gelar',
                      hintText: 'Contoh: Dr. Ir. Dosen Pengampu, M.Kom.',
                      prefixIcon: Icons.badge_outlined,
                      errorText: namaError,
                      onChanged: (v) {
                        setSheetState(() {
                          namaError = AuthValidators.validateNamaLengkap(v);
                        });
                      },
                    ),
                    const SizedBox(height: 14),

                    // Field Email
                    AuthTextField(
                      controller: emailController,
                      labelText: 'Alamat Email Resmi',
                      hintText: 'dosen@polije.ac.id',
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      errorText: emailError,
                      onChanged: (v) {
                        setSheetState(() {
                          emailError = AuthValidators.validateEmail(v);
                        });
                      },
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'ℹ️ Mengubah email akan mewajibkan verifikasi kode OTP 6 digit.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 20),

                    // Tombol Simpan
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: isSaving ? null : saveProfile,
                      child: isSaving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Simpan Perubahan',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // 2. DIALOG VERIFIKASI ULANG KETIKA EMAIL DIUBAH
  // ===========================================================================
  void _showEmailReverificationDialog({
    required String targetNewEmail,
    required String targetNewNama,
    String? targetFotoUrl,
  }) {
    String enteredOtp = '';
    bool isVerifying = false;
    String? otpError;

    // Trigger kirim kode OTP ke email baru
    AuthService().requestPasswordResetOtp(email: targetNewEmail);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: const Row(
                children: [
                  Icon(Icons.mark_email_read_outlined,
                      color: Color(0xFF1E3A8A)),
                  SizedBox(width: 8),
                  Text('Verifikasi Email Baru', style: TextStyle(fontSize: 16)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kode verifikasi OTP 6 digit telah dikirimkan ke:\n$targetNewEmail',
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF475569)),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: OtpInputWidget(
                      onChanged: (code) {
                        setDialogState(() {
                          enteredOtp = code;
                          otpError = null;
                        });
                      },
                      onCompleted: (code) {
                        setDialogState(() {
                          enteredOtp = code;
                        });
                      },
                    ),
                  ),
                  if (otpError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      otpError!,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFFEF4444)),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isVerifying
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isVerifying || enteredOtp.length != 6
                      ? null
                      : () async {
                          setDialogState(() => isVerifying = true);
                          try {
                            final res = await AuthService().verifyEmailOtp(
                              email: targetNewEmail,
                              otp: enteredOtp,
                            );

                            if (res['success'] == true) {
                              await AuthService().updateProfile(
                                nama: targetNewNama,
                                email: targetNewEmail,
                                fotoUrl: targetFotoUrl,
                              );

                              await FirebaseService().updateProfileDosen(
                                nip: _dosen.nip,
                                nama: targetNewNama,
                                email: targetNewEmail,
                                fotoUrl: targetFotoUrl,
                              );

                              setState(() {
                                _dosen = _dosen.copyWith(
                                  nama: targetNewNama,
                                  email: targetNewEmail,
                                  fotoUrl: targetFotoUrl,
                                );
                              });
                              ApiService().currentUser = _dosen;

                              if (mounted) {
                                Navigator.pop(dialogContext);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Email berhasil diverifikasi & profil disimpan!'),
                                    backgroundColor: Color(0xFF10B981),
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            setDialogState(() {
                              isVerifying = false;
                              otpError = e.toString().replaceAll('Exception: ', '');
                            });
                          }
                        },
                  child: isVerifying
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Verifikasi & Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // 3. DIALOG / BOTTOMSHEET UBAH PASSWORD (PROMPT 7 & PROMPT 8)
  // ===========================================================================
  void _openChangePasswordDialog() {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    bool obscureOld = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool isSubmitting = false;

    String? oldPasswordError;
    String? newPasswordError;
    String? confirmPasswordError;
    PasswordValidationResult passwordEvaluation = PasswordValidationResult('');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;

            void validateForm() {
              setSheetState(() {
                if (oldPasswordController.text.isEmpty) {
                  oldPasswordError = 'Password lama wajib diisi';
                } else {
                  oldPasswordError = null;
                }
                passwordEvaluation = AuthValidators.evaluatePassword(
                    newPasswordController.text);
                newPasswordError = AuthValidators.validatePassword(
                    newPasswordController.text);
                confirmPasswordError = AuthValidators.validateConfirmPassword(
                  newPasswordController.text,
                  confirmPasswordController.text,
                );
              });
            }

            final bool canSubmit = oldPasswordController.text.isNotEmpty &&
                passwordEvaluation.isValid &&
                newPasswordError == null &&
                confirmPasswordController.text.isNotEmpty &&
                confirmPasswordController.text == newPasswordController.text &&
                confirmPasswordError == null;

            Future<void> submitChangePassword() async {
              validateForm();
              if (!canSubmit) return;

              setSheetState(() => isSubmitting = true);

              try {
                final res = await AuthService().changePassword(
                  oldPassword: oldPasswordController.text,
                  newPassword: newPasswordController.text,
                );

                await FirebaseService()
                    .changePasswordDosen(newPasswordController.text);

                if (mounted) {
                  Navigator.pop(sheetContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        res['message'] ?? 'Kata sandi berhasil diperbarui!',
                      ),
                      backgroundColor: const Color(0xFF10B981),
                    ),
                  );
                }
              } catch (e) {
                setSheetState(() => isSubmitting = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      e.toString().replaceAll('Exception: ', ''),
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }

            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: bottomInset + 20,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.shield_rounded,
                            color: Color(0xFF1E3A8A), size: 24),
                        const SizedBox(width: 10),
                        const Text(
                          'Ubah Kata Sandi Dosen',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(sheetContext),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Password Lama
                    AuthTextField(
                      controller: oldPasswordController,
                      labelText: 'Kata Sandi Saat Ini',
                      hintText: 'Masukkan kata sandi lama',
                      prefixIcon: Icons.lock_outline,
                      isPassword: true,
                      obscureText: obscureOld,
                      errorText: oldPasswordError,
                      onToggleObscure: () {
                        setSheetState(() => obscureOld = !obscureOld);
                      },
                      onChanged: (v) => validateForm(),
                    ),
                    const SizedBox(height: 14),

                    // Password Baru
                    AuthTextField(
                      controller: newPasswordController,
                      labelText: 'Kata Sandi Baru (Prompt 8)',
                      hintText: 'Minimal 8 karakter, huruf, angka, tanpa spasi',
                      prefixIcon: Icons.lock_reset_rounded,
                      isPassword: true,
                      obscureText: obscureNew,
                      errorText: newPasswordError,
                      onToggleObscure: () {
                        setSheetState(() => obscureNew = !obscureNew);
                      },
                      onChanged: (v) => validateForm(),
                    ),
                    const SizedBox(height: 10),

                    // Visual Criteria Widget & Strength Meter (Prompt 8)
                    PasswordCriteriaWidget(evaluation: passwordEvaluation),
                    const SizedBox(height: 14),

                    // Konfirmasi Password Baru
                    AuthTextField(
                      controller: confirmPasswordController,
                      labelText: 'Ulangi Kata Sandi Baru',
                      hintText: 'Ketik ulang kata sandi baru Anda',
                      prefixIcon: Icons.check_circle_outline,
                      isPassword: true,
                      obscureText: obscureConfirm,
                      errorText: confirmPasswordError,
                      onToggleObscure: () {
                        setSheetState(() => obscureConfirm = !obscureConfirm);
                      },
                      onChanged: (v) => validateForm(),
                    ),
                    const SizedBox(height: 20),

                    // Tombol Submit (Disabled sampai semua kriteria valid)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3A8A),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFFCBD5E1),
                        disabledForegroundColor: const Color(0xFF94A3B8),
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: (!canSubmit || isSubmitting)
                          ? null
                          : submitChangePassword,
                      child: isSubmitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Perbarui Kata Sandi',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // 4. DIALOG KONFIRMASI LOGOUT
  // ===========================================================================
  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Color(0xFFDC2626)),
            SizedBox(width: 8),
            Text(
              'Konfirmasi Keluar',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'Yakin ingin keluar dari akun dosen?\nSesi aktif Anda akan ditutup.',
          style: TextStyle(color: Color(0xFF475569), fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ApiService().currentUser = null;
              ApiService().authToken = null;
              FirebaseService().signOut();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text('Ya, Keluar'),
          ),
        ],
      ),
    );
  }

  void _showServerSettings(BuildContext context) {
    final urlController = TextEditingController(text: ApiService().baseUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ubah Alamat Server API'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'IP Backend FastAPI aktif:',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'http://192.168.1.x:8000',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              ApiService().updateBaseUrl(urlController.text);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Server diperbarui: ${ApiService().baseUrl}'),
                  backgroundColor: Colors.teal,
                ),
              );
            },
            child: const Text('Simpan'),
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
        title: const Text(
          'Profil Dosen & Pengaturan',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Avatar & Info Ringkas Card (Hanya Foto, Nama, NIP, Email)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Foto Profil Lingkaran dengan Ikon Kamera & Tap Zoom (Prompt 4)
                  LecturerAvatar(
                    fotoUrl: _dosen.fotoUrl,
                    nama: _dosen.nama,
                    radius: 48,
                    showCameraIcon: true,
                    onCameraTap: _openPhotoCropDialog,
                    enableZoomOnTap: true,
                    heroTag: 'profile_lecturer_photo',
                  ),
                  const SizedBox(height: 14),

                  // Nama Lengkap Dosen
                  Text(
                    _dosen.nama,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // NIP
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'NIP: ${_dosen.nip}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Email
                  Text(
                    _dosen.email,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Hint interaktif tap foto
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.touch_app_outlined,
                            size: 13, color: Color(0xFF64748B)),
                        SizedBox(width: 4),
                        Text(
                          'Ketuk foto untuk zoom • Ikon kamera untuk ganti',
                          style: TextStyle(
                              fontSize: 10.5, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Kartu Menu Tindakan Profil
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Tombol Edit Profil
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.edit_outlined,
                          color: Color(0xFF1D4ED8), size: 20),
                    ),
                    title: const Text(
                      'Edit Profil Dosen',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      'Ubah nama, email, dan foto profil',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded,
                        color: Color(0xFF94A3B8)),
                    onTap: _openEditProfileDialog,
                  ),
                  const Divider(height: 1, indent: 64),

                  // Opsi Ubah Password
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.lock_reset_rounded,
                          color: Color(0xFF15803D), size: 20),
                    ),
                    title: const Text(
                      'Ubah Kata Sandi',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      'Sesuai ketentuan keamanan sandi (Prompt 8)',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded,
                        color: Color(0xFF94A3B8)),
                    onTap: _openChangePasswordDialog,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Server Settings Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF5FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.dns_outlined,
                      color: Color(0xFF7E22CE), size: 20),
                ),
                title: const Text(
                  'Alamat Server Backend API',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  ApiService().baseUrl,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                trailing: TextButton(
                  onPressed: () => _showServerSettings(context),
                  child: const Text('Ubah'),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Logout Button (Merah dengan Konfirmasi Dialog)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFDC2626),
                side: const BorderSide(color: Color(0xFFFCA5A5), width: 1.5),
                backgroundColor: const Color(0xFFFEF2F2),
                padding: const EdgeInsets.symmetric(vertical: 14),
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.logout_rounded),
              label: const Text(
                'Keluar dari Akun Dosen',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: _confirmLogout,
            ),

            const SizedBox(height: 30),
            const Text(
              'EduSense Smart Classroom v2.0.0\nJurusan Teknologi Informasi - POLIJE',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
