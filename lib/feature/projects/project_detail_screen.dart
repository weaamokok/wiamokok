import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../domain/portfolio_data.dart';
import '../../domain/project.dart';
import '../../shared/ui/components/pressable_scale.dart';

@RoutePage()
class ProjectDetailScreen extends ConsumerWidget {
  const ProjectDetailScreen({
    super.key,
    @PathParam('projectId') required this.projectId,
  });

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = PortfolioData.projects.firstWhere(
      (p) => p.id == projectId,
      orElse: () => PortfolioData.projects.first,
    );

    final isDark = project.accentColor != null &&
        project.accentColor!.computeLuminance() < 0.3;
    final isAccent = project.isPublished;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            backgroundColor: isAccent
                ? AppColors.accent
                : isDark
                    ? AppColors.cardDark
                    : AppColors.surface,
            expandedHeight: 240,
            pinned: true,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_rounded,
                color: isAccent || isDark ? Colors.white : AppColors.foreground,
              ),
              onPressed: () => context.router.maybePop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Padding(
                padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _StatusBadge(project: project, onDark: isAccent || isDark),
                    const SizedBox(height: 12),
                    Text(
                      project.title,
                      style: AppTextStyles.displayMedium.copyWith(
                        color: isAccent || isDark ? Colors.white : AppColors.foreground,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project.subtitle,
                    style: AppTextStyles.titleLarge.copyWith(
                      color: AppColors.foregroundMuted,
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 100.ms, duration: 400.ms)
                      .slideY(begin: 0.2),

                  const SizedBox(height: 24),

                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      project.description,
                      style: AppTextStyles.bodyLarge,
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 200.ms, duration: 400.ms)
                      .slideY(begin: 0.2),

                  const SizedBox(height: 24),

                  Text('Tech stack', style: AppTextStyles.titleLarge)
                      .animate()
                      .fadeIn(delay: 260.ms, duration: 400.ms),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: project.tags.map((t) => _Tag(label: t)).toList(),
                  )
                      .animate()
                      .fadeIn(delay: 300.ms, duration: 400.ms),

                  if (project.storeUrl != null) ...[
                    const SizedBox(height: 32),
                    PressableScale(
                      onTap: () => launchUrl(Uri.parse(project.storeUrl!)),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: AppColors.foreground,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'View on Store',
                          style: AppTextStyles.labelLarge.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.project, required this.onDark});

  final Project project;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final label = switch (project.status) {
      ProjectStatus.published => 'Published',
      ProjectStatus.unreleased => 'Unreleased',
      ProjectStatus.inProgress => 'In Progress',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: onDark ? Colors.white.withValues(alpha: 0.15) : AppColors.surfaceDim,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelMedium.copyWith(
          color: onDark ? Colors.white70 : AppColors.foregroundMuted,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceDim,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(label, style: AppTextStyles.labelMedium),
    );
  }
}
