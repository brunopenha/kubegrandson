import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../presentation/screens/home/home_screen.dart';
import '../../presentation/screens/log_viewer/log_viewer_screen.dart';
import '../../presentation/screens/settings/settings_screen.dart';

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
          final container = state.uri.queryParameters['container'];

          return LogViewerScreen(
            namespace: namespace,
            podName: pod,
            containerName: container,
          );
        },
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
}