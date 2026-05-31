import 'package:flutter/material.dart';
import 'package:auto_route/auto_route.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../domain/portfolio_data.dart';
import '../../../domain/project.dart';
import '../../../shared/ui/components/animated_reveal.dart';
import '../../../shared/ui/components/pressable_scale.dart';

class ProjectsSection extends ConsumerWidget {
  const ProjectsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedReveal(
            child: _SectionLabel(label: 'Work'),
          ),
          const SizedBox(height: 8),
          AnimatedReveal(
            delay: const Duration(milliseconds: 80),
            child: Text('Selected projects', style: AppTextStyles.headlineLarge),
          ),
          const SizedBox(height: 24),
          ...PortfolioData.projects.asMap().entries.map((entry) {
            final index = entry.key;
            final project = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: AnimatedReveal(
                delay: Duration(milliseconds: index * 80),
                child: _ProjectCard(project: project),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ProjectCard extends ConsumerWidget {
  const _ProjectCard({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = project.accentColor != null &&
        project.accentColor!.computeLuminance() < 0.3;

    return PressableScale(
      onTap: () => context.router.push(ProjectDetailRoute(projectId: project.id)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: project.isPublished
              ? AppColors.accent
              : (isDark ? AppColors.cardDark : AppColors.surface),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: project.isPublished || isDark
                ? Colors.transparent
                : AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    project.title,
                    style: AppTextStyles.headlineMedium.copyWith(
                      color: project.isPublished || isDark
                          ? Colors.white
                          : AppColors.foreground,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_outward_rounded,
                  size: 20,
                  color: project.isPublished || isDark
                      ? Colors.white70
                      : AppColors.foregroundMuted,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              project.subtitle,
              style: AppTextStyles.bodyMedium.copyWith(
                color: project.isPublished || isDark
                    ? Colors.white70
                    : AppColors.foregroundMuted,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              project.description,
              style: AppTextStyles.bodyMedium.copyWith(
                color: project.isPublished || isDark
                    ? Colors.white70
                    : AppColors.foregroundMuted,
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: project.tags
                  .map((tag) => _Tag(
                        label: tag,
                        onDark: project.isPublished || isDark,
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, this.onDark = false});

  final String label;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: onDark ? Colors.white.withValues(alpha: 0.15) : AppColors.surfaceDim,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelMedium.copyWith(
          color: onDark ? Colors.white70 : AppColors.foregroundMuted,
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
