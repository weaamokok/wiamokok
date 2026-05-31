// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// AutoRouterGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'app_router.dart';

/// generated route for
/// [HomeScreen]
class HomeRoute extends PageRouteInfo<void> {
  const HomeRoute({List<PageRouteInfo>? children})
    : super(HomeRoute.name, initialChildren: children);

  static const String name = 'HomeRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      return const HomeScreen();
    },
  );
}

/// generated route for
/// [ProjectDetailScreen]
class ProjectDetailRoute extends PageRouteInfo<ProjectDetailRouteArgs> {
  ProjectDetailRoute({
    Key? key,
    required String projectId,
    List<PageRouteInfo>? children,
  }) : super(
         ProjectDetailRoute.name,
         args: ProjectDetailRouteArgs(key: key, projectId: projectId),
         rawPathParams: {'projectId': projectId},
         initialChildren: children,
       );

  static const String name = 'ProjectDetailRoute';

  static PageInfo page = PageInfo(
    name,
    builder: (data) {
      final pathParams = data.inheritedPathParams;
      final args = data.argsAs<ProjectDetailRouteArgs>(
        orElse: () => ProjectDetailRouteArgs(
          projectId: pathParams.getString('projectId'),
        ),
      );
      return ProjectDetailScreen(key: args.key, projectId: args.projectId);
    },
  );
}

class ProjectDetailRouteArgs {
  const ProjectDetailRouteArgs({this.key, required this.projectId});

  final Key? key;

  final String projectId;

  @override
  String toString() {
    return 'ProjectDetailRouteArgs{key: $key, projectId: $projectId}';
  }
}
