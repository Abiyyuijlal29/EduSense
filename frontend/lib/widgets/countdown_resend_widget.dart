import 'dart:async';
import 'package:flutter/material.dart';

class CountdownResendWidget extends StatefulWidget {
  final int initialSeconds;
  final Future<void> Function() onResend;
  final bool isResending;

  const CountdownResendWidget({
    super.key,
    this.initialSeconds = 60,
    required this.onResend,
    this.isResending = false,
  });

  @override
  State<CountdownResendWidget> createState() => CountdownResendWidgetState();
}

class CountdownResendWidgetState extends State<CountdownResendWidget> {
  late int _remainingSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.initialSeconds;
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() {
      _remainingSeconds = widget.initialSeconds;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  void restartTimer() {
    _startTimer();
  }

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final bool canResend = _remainingSeconds == 0 && !widget.isResending;

    return Column(
      children: [
        if (_remainingSeconds > 0) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.timer_outlined,
                size: 16,
                color: Color(0xFF64748B),
              ),
              const SizedBox(width: 6),
              Text(
                'Kirim ulang kode dalam ${_formatTime(_remainingSeconds)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        TextButton(
          onPressed: canResend
              ? () async {
                  await widget.onResend();
                  if (mounted) {
                    restartTimer();
                  }
                }
              : null,
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF1E3A8A),
            disabledForegroundColor: const Color(0xFF94A3B8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          child: widget.isResending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF1E3A8A),
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.refresh_rounded,
                      size: 16,
                      color: canResend
                          ? const Color(0xFF1E3A8A)
                          : const Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Kirim ulang kode OTP',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            canResend ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

