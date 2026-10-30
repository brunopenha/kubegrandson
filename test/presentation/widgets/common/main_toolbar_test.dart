import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kubegrandson/data/datasources/local_storage_client.dart';
import 'package:kubegrandson/presentation/providers/kubernetes_provider.dart';
import 'package:kubegrandson/presentation/widgets/common/main_toolbar.dart';

void main() {
  testWidgets(
      'restores the last search and reuses history without affecting pod names',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'podLogSearchHistory': ['timeout', 'error']
    });
    LocalStorageClient.resetInstance();
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: ThemeData(splashFactory: NoSplash.splashFactory),
        home: const Scaffold(body: MainToolbar()),
      ),
    ));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    expect(tester.widget<TextField>(fields.at(1)).controller!.text, 'timeout');
    await tester.enterText(fields.first, 'api');
    await tester.tap(find.byTooltip('Search history'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('error'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(fields.at(1)).controller!.text, 'error');
    expect(container.read(podLogSearchQueryProvider), 'error');
    await tester.tap(find.byIcon(Icons.clear));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(fields.at(1)).controller!.text, isEmpty);
    expect(container.read(podFilterProvider).searchQuery, 'api');
  });
}
