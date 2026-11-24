import 'dart:math';
import 'package:flutter/material.dart';

class ProfilePhotoCropDialog extends StatefulWidget {
  final String currentPhotoUrl;
  final ValueChanged<String> onPhotoSaved;

  const ProfilePhotoCropDialog({
    super.key,
    required this.currentPhotoUrl,
    required this.onPhotoSaved,
  });

  static void show(
    BuildContext context, {
    required String currentPhotoUrl,
    required ValueChanged<String> onPhotoSaved,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ProfilePhotoCropDialog(
        currentPhotoUrl: currentPhotoUrl,
        onPhotoSaved: onPhotoSaved,
      ),
    );
  }

  @override
  State<ProfilePhotoCropDialog> createState() => _ProfilePhotoCropDialogState();
}

class _ProfilePhotoCropDialogState extends State<ProfilePhotoCropDialog> {
  String? _selectedImageSource; // 'camera' or 'gallery'
  String? _pickedImageUrl;
  double _originalFileSizeMb = 0.0;
  double _compressedFileSizeMb = 0.0;
  bool _isCompressing = false;
  bool _isSaving = false;
  String? _errorMessage;
  double _zoomScale = 1.0;

  // Koleksi preset foto dosen profesional untuk demo cropping & preview
  final List<String> _demoCameraPhotos = [
    'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?auto=format&fit=crop&w=600&q=80',
    'https://images.unsplash.com/photo-1560250097-0b93528c311a?auto=format&fit=crop&w=600&q=80',
    'https://images.unsplash.com/photo-1573497019940-1c28c88b4f3e?auto=format&fit=crop&w=600&q=80',
  ];

  final List<String> _demoGalleryPhotos = [
    'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=600&q=80',
    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=600&q=80',
    'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=600&q=80',
  ];

  void _pickPhoto(String source) async {
    setState(() {
      _selectedImageSource = source;
      _isCompressing = true;
      _errorMessage = null;
    });

    await Future.delayed(const Duration(milliseconds: 600));

    final random = Random();
    final photos = source == 'camera' ? _demoCameraPhotos : _demoGalleryPhotos;
    final selected = photos[random.nextInt(photos.length)];

    // Simulasi ukuran file foto: 1.2 MB - 1.8 MB (masuk batas 2 MB)
    final origMb = 1.3 + random.nextDouble() * 0.5;
    // Kompresi gambar 85% -> berkurang ~40%
    final compMb = origMb * 0.62;

    if (!mounted) return;

    if (origMb > 2.0 && compMb > 2.0) {
      setState(() {
        _isCompressing = false;
        _errorMessage =
            'Ukuran file melebihi batas maksimal 2.0 MB (${origMb.toStringAsFixed(2)} MB). Silakan pilih foto lain.';
      });
      return;
    }

    setState(() {
      _pickedImageUrl = selected;
      _originalFileSizeMb = origMb;
      _compressedFileSizeMb = compMb;
      _isCompressing = false;
    });
  }

  void _handleSaveCropped() async {
    if (_pickedImageUrl == null) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    await Future.delayed(const Duration(milliseconds: 900));

    if (!mounted) return;

    widget.onPhotoSaved(_pickedImageUrl!);
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              'Foto profil berhasil diperbarui (${(_compressedFileSizeMb * 1024).round()} KB, Kompresi 85%).',
            ),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle Bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E7FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.add_a_photo_rounded,
                    color: Color(0xFF1E3A8A),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ubah Foto Profil Dosen',
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Pilih sumber foto, sesuaikan crop lingkaran, maks. 2 MB',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // 1. Pilihan Sumber: Kamera atau Galeri
            Row(
              children: [
                Expanded(
                  child: _buildChoiceCard(
                    icon: Icons.camera_alt_outlined,
                    label: 'Ambil dari Kamera',
                    subtitle: 'Buka kamera HP',
                    isSelected: _selectedImageSource == 'camera',
                    onTap: () => _pickPhoto('camera'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildChoiceCard(
                    icon: Icons.photo_library_outlined,
                    label: 'Pilih dari Galeri',
                    subtitle: 'Pilih file foto',
                    isSelected: _selectedImageSource == 'gallery',
                    onTap: () => _pickPhoto('gallery'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Indikator Loading saat Kompresi / Pengambilan Foto
            if (_isCompressing) ...[
              Container(
                padding: const EdgeInsets.all(20),
                alignment: Alignment.center,
                child: const Column(
                  children: [
                    CircularProgressIndicator(strokeWidth: 2.5),
                    SizedBox(height: 10),
                    Text(
                      'Memproses & mengompresi gambar (Maks. 2 MB)...',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],

            // 2. Pratinjau Crop Lingkaran & Pengaturan Zoom
            if (_pickedImageUrl != null && !_isCompressing) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.crop_rounded, size: 16, color: Color(0xFF1E3A8A)),
                        SizedBox(width: 6),
                        Text(
                          'Pratinjau Crop Lingkaran (1:1 Ratio)',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Viewport Lingkaran Crop
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 170,
                          height: 170,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF1E3A8A),
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Transform.scale(
                              scale: _zoomScale,
                              child: Image.network(
                                _pickedImageUrl!,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        // Circular Crop Guide Mask Overlay
                        IgnorePointer(
                          child: Container(
                            width: 170,
                            height: 170,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.8),
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Slider Zooming untuk Menyesuaikan Posisi Crop
                    Row(
                      children: [
                        const Icon(Icons.zoom_out, size: 18, color: Color(0xFF64748B)),
                        Expanded(
                          child: Slider(
                            value: _zoomScale,
                            min: 1.0,
                            max: 2.2,
                            activeColor: const Color(0xFF1E3A8A),
                            onChanged: (val) {
                              setState(() => _zoomScale = val);
                            },
                          ),
                        ),
                        const Icon(Icons.zoom_in, size: 18, color: Color(0xFF64748B)),
                      ],
                    ),

                    // Info Ukuran File & Kompresi
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.compress_rounded,
                                  size: 15, color: Color(0xFF10B981)),
                              const SizedBox(width: 6),
                              Text(
                                'Ukuran: ${(_compressedFileSizeMb * 1024).round()} KB (Asli: ${_originalFileSizeMb.toStringAsFixed(1)} MB)',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF334155),
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Lolos ≤ 2 MB',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF15803D),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Error Message
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, size: 16, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(fontSize: 12, color: Colors.red.shade800),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Tombol Simpan
            ElevatedButton(
              onPressed: (_pickedImageUrl != null && !_isSaving && !_isCompressing)
                  ? _handleSaveCropped
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                disabledBackgroundColor: const Color(0xFFCBD5E1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Simpan Foto Profil',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChoiceCard({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFF1E3A8A) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF1E3A8A) : const Color(0xFF64748B),
              size: 26,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected ? const Color(0xFF1E3A8A) : const Color(0xFF1E293B),
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }
}

