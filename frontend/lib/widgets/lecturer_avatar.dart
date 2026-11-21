import 'package:flutter/material.dart';

// Cache gambar in-memory sederhana agar foto tidak perlu diunduh berulang kali
final Map<String, ImageProvider> _avatarImageCache = {};

class LecturerAvatar extends StatefulWidget {
  final String? fotoUrl;
  final String nama;
  final double radius;
  final bool showCameraIcon;
  final VoidCallback? onCameraTap;
  final bool enableZoomOnTap;
  final String? heroTag;

  const LecturerAvatar({
    super.key,
    this.fotoUrl,
    required this.nama,
    this.radius = 24,
    this.showCameraIcon = false,
    this.onCameraTap,
    this.enableZoomOnTap = true,
    this.heroTag,
  });

  @override
  State<LecturerAvatar> createState() => _LecturerAvatarState();
}

class _LecturerAvatarState extends State<LecturerAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  bool _isLoading = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController.unbounded(vsync: this)
      ..repeat(min: -0.5, max: 1.5, period: const Duration(milliseconds: 1200));

    if (widget.fotoUrl != null && widget.fotoUrl!.isNotEmpty) {
      _isLoading = true;
    }
  }

  @override
  void didUpdateWidget(covariant LecturerAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fotoUrl != widget.fotoUrl) {
      if (widget.fotoUrl != null && widget.fotoUrl!.isNotEmpty) {
        setState(() {
          _isLoading = true;
          _hasError = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  String get _initials {
    if (widget.nama.trim().isEmpty) return 'D';
    final parts = widget.nama.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      // Ambil 2 huruf inisial dari kata pertama & kedua jika bukan gelar singkatan
      final f = parts[0][0].toUpperCase();
      final s = parts[1][0].toUpperCase();
      return '$f$s';
    }
    return parts[0][0].toUpperCase();
  }

  void _openFullPhotoViewer(BuildContext context) {
    if (!widget.enableZoomOnTap) return;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (ctx) => _FullPhotoViewerDialog(
        fotoUrl: widget.fotoUrl,
        nama: widget.nama,
        initials: _initials,
        heroTag: widget.heroTag,
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return Container(
          width: widget.radius * 2,
          height: widget.radius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: const [
                Color(0xFFE2E8F0),
                Color(0xFFF1F5F9),
                Color(0xFFE2E8F0),
              ],
              stops: [
                (_shimmerController.value - 0.3).clamp(0.0, 1.0),
                _shimmerController.value.clamp(0.0, 1.0),
                (_shimmerController.value + 0.3).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDefaultInitialsAvatar() {
    return Container(
      width: widget.radius * 2,
      height: widget.radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Text(
          _initials,
          style: TextStyle(
            fontSize: widget.radius * 0.72,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasUrl = widget.fotoUrl != null &&
        widget.fotoUrl!.isNotEmpty &&
        widget.fotoUrl!.startsWith('http');

    Widget avatarCore;

    if (hasUrl && !_hasError) {
      // Menggunakan cache gambar agar tidak perlu download berulang
      ImageProvider imageProvider = _avatarImageCache.putIfAbsent(
        widget.fotoUrl!,
        () => NetworkImage(widget.fotoUrl!),
      );

      avatarCore = ClipOval(
        child: SizedBox(
          width: widget.radius * 2,
          height: widget.radius * 2,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_isLoading) _buildSkeletonLoader(),
              Image(
                image: imageProvider,
                fit: BoxFit.cover,
                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                  if (wasSynchronouslyLoaded || frame != null) {
                    if (_isLoading) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) setState(() => _isLoading = false);
                      });
                    }
                    return child;
                  }
                  return _buildSkeletonLoader();
                },
                errorBuilder: (context, error, stackTrace) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() {
                        _isLoading = false;
                        _hasError = true;
                      });
                    }
                  });
                  return _buildDefaultInitialsAvatar();
                },
              ),
            ],
          ),
        ),
      );
    } else {
      avatarCore = _buildDefaultInitialsAvatar();
    }

    if (widget.heroTag != null) {
      avatarCore = Hero(tag: widget.heroTag!, child: avatarCore);
    }

    final tappableAvatar = GestureDetector(
      onTap: () => _openFullPhotoViewer(context),
      child: avatarCore,
    );

    if (!widget.showCameraIcon) {
      return tappableAvatar;
    }

    // Tampilan dengan Ikon Kamera Kecil di Pojok Foto (Halaman Profil)
    final cameraIconSize = (widget.radius * 0.65).clamp(24.0, 36.0);

    return SizedBox(
      width: widget.radius * 2 + 8,
      height: widget.radius * 2 + 8,
      child: Stack(
        alignment: Alignment.center,
        children: [
          tappableAvatar,
          Positioned(
            right: 0,
            bottom: 0,
            child: GestureDetector(
              onTap: widget.onCameraTap,
              child: Container(
                width: cameraIconSize,
                height: cameraIconSize,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A8A),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.white,
                  size: cameraIconSize * 0.55,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// MODAL TAMPILAN FOTO PENUH DENGAN ZOOM (InteractiveViewer)
// =============================================================================
class _FullPhotoViewerDialog extends StatelessWidget {
  final String? fotoUrl;
  final String nama;
  final String initials;
  final String? heroTag;

  const _FullPhotoViewerDialog({
    this.fotoUrl,
    required this.nama,
    required this.initials,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = fotoUrl != null && fotoUrl!.isNotEmpty && fotoUrl!.startsWith('http');

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(Icons.account_circle_outlined,
                    color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Foto Profil Dosen',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        nama,
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Tutup',
                ),
              ],
            ),
          ),

          // Zoomable Viewport
          Container(
            color: Colors.black,
            constraints: const BoxConstraints(maxHeight: 420, minHeight: 280),
            child: Center(
              child: InteractiveViewer(
                panEnabled: true,
                minScale: 1.0,
                maxScale: 4.0,
                child: hasPhoto
                    ? Image.network(
                        fotoUrl!,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return const Center(
                            child: CircularProgressIndicator(color: Colors.white),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return _buildInitialBigAvatar();
                        },
                      )
                    : _buildInitialBigAvatar(),
              ),
            ),
          ),

          // Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.pinch_rounded, size: 16, color: Color(0xFF94A3B8)),
                const SizedBox(width: 6),
                const Text(
                  'Cubit / Pinch untuk memperbesar foto (Zoom)',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialBigAvatar() {
    return Container(
      width: 180,
      height: 180,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            fontSize: 64,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

