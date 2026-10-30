import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kubegrandson/data/datasources/local_storage_client.dart';
import 'package:kubegrandson/presentation/providers/kubernetes_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LocalStorageClient.resetInstance();
  });

  test('keeps every distinct search, with the last term first, across sessions',
      () async {
    final container = ProviderContainer();
    final history = container.read(podLogSearchHistoryProvider.notifier);
    await history.remember(' error ');
    await history.remember('timeout');
    await history.remember('error');
    await history.remember('  ');
    expect(await container.read(podLogSearchHistoryProvider.future),
        ['error', 'timeout']);
    container.dispose();
    LocalStorageClient.resetInstance();

    final restored = ProviderContainer();
    addTearDown(restored.dispose);
    expect(await restored.read(podLogSearchHistoryProvider.future),
        ['error', 'timeout']);
  });
}
