import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../domain/portfolio_data.dart';
import '../../../shared/ui/components/pressable_scale.dart';

class HeroSection extends ConsumerWidget {
  const HeroSection({super.key, required this.onContactTap});

  final VoidCallback onContactTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Availability badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF22C55E),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Available for work',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          )
              .animate()
              .fadeIn(duration: 400.ms)
              .slideY(begin: -0.3, curve: Curves.easeOut),

          const SizedBox(height: 24),

          // Big headline
          Text(
            PortfolioData.tagline,
            style: AppTextStyles.displayLarge,
          )
              .animate()
              .fadeIn(delay: 100.ms, duration: 500.ms)
              .slideY(begin: 0.2, curve: Curves.easeOut),

          const SizedBox(height: 20),

          Text(
            PortfolioData.bio,
            style: AppTextStyles.bodyLarge,
          )
              .animate()
              .fadeIn(delay: 200.ms, duration: 500.ms)
              .slideY(begin: 0.2, curve: Curves.easeOut),

          const SizedBox(height: 36),

          // CTA row
          Row(
            children: [
              PressableScale(
                onTap: onContactTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.foreground,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    'Get in touch',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: AppColors.onAccent,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              PressableScale(
                onTap: () {},
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: AppColors.border, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'View work',
                        style: AppTextStyles.labelLarge,
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_downward_rounded, size: 16),
                    ],
                  ),
                ),
              ),
            ],
          )
              .animate()
              .fadeIn(delay: 300.ms, duration: 500.ms)
              .slideY(begin: 0.2, curve: Curves.easeOut),

          const SizedBox(height: 48),

          // Stats row
          Row(
            children: [
              _StatChip(value: '3+', label: 'Years exp.'),
              const SizedBox(width: 12),
              _StatChip(value: '1', label: 'Published app'),
              const SizedBox(width: 12),
              _StatChip(value: '5+', label: 'Projects'),
            ],
          )
              .animate()
              .fadeIn(delay: 400.ms, duration: 500.ms),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: AppTextStyles.headlineMedium),
          Text(label, style: AppTextStyles.bodyMedium),
        ],
      ),
    );
  }
}
