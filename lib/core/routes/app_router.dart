import 'package:go_router/go_router.dart';

import '../../presentation/screens/home/home_screen.dart';
import '../../presentation/screens/config_maps/config_map_screen.dart';
import '../../presentation/screens/log_viewer/log_viewer_screen.dart';
import '../../presentation/screens/settings/settings_screen.dart';
import '../../presentation/screens/mock_server/mock_server_screen.dart';
import '../../presentation/screens/xml_analyzer/xml_analyzer_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/logs/:namespace/:pod',
        builder: (context, state) {
          final namespace = state.pathParameters['namespace']!;
          final pod = state.pathParameters['pod']!;
          final pods = state.uri.queryParameters['pods']
              ?.split(',')
              .where((value) => value.isNotEmpty)
              .map(Uri.decodeComponent)
              .toList();
          final container = state.uri.queryParameters['container'];
          final groups = state.uri.queryParameters['groups']
              ?.split(',')
              .where((value) => value.isNotEmpty)
              .map(Uri.decodeComponent)
              .toList();
          final importPath = state.uri.queryParameters['importPath'];
          final initialSearchQuery = state.uri.queryParameters['search'];

          return LogViewerScreen(
            namespace: namespace,
            podName: pod,
            podNames: pods ?? [pod],
            podGroupNames: groups ?? const [],
            containerName: container,
            initialImportPath: importPath,
            initialSearchQuery: initialSearchQuery,
          );
        },
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/mock-services',
        builder: (context, state) => const MockServerScreen(),
      ),
      GoRoute(
        path: '/xml-analyzer',
        builder: (context, state) => const XmlAnalyzerScreen(),
      ),
      GoRoute(
        path: '/configmaps/:namespace/:group',
        builder: (context, state) {
          final namespace = state.pathParameters['namespace']!;
          final group = state.pathParameters['group']!;
          final pods = state.uri.queryParameters['pods']
                  ?.split(',')
                  .where((value) => value.isNotEmpty)
                  .map(Uri.decodeComponent)
                  .toList() ??
              const <String>[];

          return ConfigMapScreen(
            namespace: namespace,
            groupName: group,
            podNames: pods,
          );
        },
      ),
    ],
  );
}
