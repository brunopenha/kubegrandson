import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kubegrandson/data/datasources/local_storage_client.dart';
import 'package:kubegrandson/app.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LocalStorageClient.resetInstance();
  });

  testWidgets('app builds with ProviderScope', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: KubeGrandsonApp(),
      ),
    );
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
