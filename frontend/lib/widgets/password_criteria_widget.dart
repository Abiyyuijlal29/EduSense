import 'package:flutter/material.dart';
import '../utils/auth_validators.dart';

/// Widget Checklist Real-Time & Indikator Kekuatan Password (Prompt 8)
class PasswordCriteriaWidget extends StatelessWidget {
  final PasswordValidationResult evaluation;

  const PasswordCriteriaWidget({
    super.key,
    required this.evaluation,
  });

  Widget _buildCheckItem(String label, bool isSatisfied) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: isSatisfied
                  ? const Color(0xFF10B981)
                  : const Color(0xFFE2E8F0),
              shape: BoxShape.circle,
              border: Border.all(
                color: isSatisfied
                    ? const Color(0xFF059669)
                    : const Color(0xFFCBD5E1),
                width: 1,
              ),
            ),
            child: Icon(
              isSatisfied ? Icons.check : Icons.circle,
              size: isSatisfied ? 12 : 5,
              color: isSatisfied ? Colors.white : const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSatisfied
                    ? const Color(0xFF0F766E)
                    : const Color(0xFF64748B),
                fontWeight:
                    isSatisfied ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStrengthMeter() {
    final fraction = evaluation.strengthFraction;
    final strengthColor = evaluation.strengthColor;
    final strengthLabel = evaluation.strengthLabel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Kekuatan Sandi:',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: strengthColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                strengthLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: strengthColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // 3 Segmented Strength Bars
        Row(
          children: [
            Expanded(
              child: Container(
                height: 4.5,
                decoration: BoxDecoration(
                  color: fraction >= 0.33
                      ? strengthColor
                      : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Container(
                height: 4.5,
                decoration: BoxDecoration(
                  color: fraction >= 0.66
                      ? strengthColor
                      : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Container(
                height: 4.5,
                decoration: BoxDecoration(
                  color: fraction >= 1.0
                      ? strengthColor
                      : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: evaluation.isValid
              ? const Color(0xFF86EFAC)
              : const Color(0xFFE2E8F0),
          width: evaluation.isValid ? 1.4 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.shield_outlined,
                size: 16,
                color: Color(0xFF1E3A8A),
              ),
              const SizedBox(width: 6),
              const Text(
                'Ketentuan Kata Sandi (Prompt 8):',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const Spacer(),
              Text(
                '${evaluation.metCriteriaCount}/5 Terpenuhi',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: evaluation.isValid
                      ? const Color(0xFF10B981)
                      : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildStrengthMeter(),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 8),
          _buildCheckItem('Minimal 8 karakter', evaluation.hasMinLength),
          _buildCheckItem(
              'Minimal 1 huruf kapital (A-Z)', evaluation.hasUppercase),
          _buildCheckItem(
              'Minimal 1 huruf kecil (a-z)', evaluation.hasLowercase),
          _buildCheckItem('Minimal 1 angka (0-9)', evaluation.hasNumber),
          _buildCheckItem('Tanpa spasi', evaluation.hasNoSpaces),
        ],
      ),
    );
  }
}
