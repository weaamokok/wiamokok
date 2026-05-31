import 'package:auto_route/auto_route.dart';
import 'package:flutter/widgets.dart';
import '../../feature/home/home_screen.dart';
import '../../feature/projects/project_detail_screen.dart';

part 'app_router.gr.dart';

@AutoRouterConfig(replaceInRouteName: 'Screen,Route')
class AppRouter extends RootStackRouter {
  @override
  List<AutoRoute> get routes => [
        AutoRoute(page: HomeRoute.page, initial: true),
        AutoRoute(page: ProjectDetailRoute.page),
      ];
}
