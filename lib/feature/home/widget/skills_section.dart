import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../domain/portfolio_data.dart';
import '../../../shared/ui/components/animated_reveal.dart';

class SkillsSection extends ConsumerWidget {
  const SkillsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedReveal(
            child: _SectionLabel(label: 'Skills'),
          ),
          const SizedBox(height: 8),
          AnimatedReveal(
            delay: const Duration(milliseconds: 80),
            child: Text('What I work with', style: AppTextStyles.headlineLarge),
          ),
          const SizedBox(height: 24),
          AnimatedReveal(
            delay: const Duration(milliseconds: 160),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: PortfolioData.skills
                  .asMap()
                  .entries
                  .map((e) => _SkillChip(label: e.value, index: e.key))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkillChip extends StatelessWidget {
  const _SkillChip({required this.label, required this.index});

  final String label;
  final int index;

  @override
  Widget build(BuildContext context) {
    final isHighlighted = index == 0 || index == 5;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isHighlighted ? AppColors.foreground : AppColors.surface,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: isHighlighted ? Colors.transparent : AppColors.border,
        ),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelLarge.copyWith(
          color: isHighlighted ? Colors.white : AppColors.foreground,
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTextStyles.labelMedium.copyWith(
          color: AppColors.accent,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
