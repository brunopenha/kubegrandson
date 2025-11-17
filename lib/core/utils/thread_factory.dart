import 'dart:async';
import 'dart:isolate';
import 'package:flutter/foundation.dart';

import 'app_logger.dart';

class ThreadFactory {
  static final Map<String, Isolate> _isolates = {};
  static final Map<String, StreamSubscription> _subscriptions = {};

  static Future<void> createWorker(
      String name,
      Function(SendPort) entryPoint,
      ) async {
    try {
      final receivePort = ReceivePort();
      final isolate = await Isolate.spawn(
        _isolateEntryPoint,
        receivePort.sendPort,
      );

      _isolates[name] = isolate;
      AppLogger.debug('Created isolate: $name');
    } catch (e, stackTrace) {
      AppLogger.error('Failed to create isolate: $name', e, stackTrace);
      rethrow;
    }
  }

  static void _isolateEntryPoint(SendPort sendPort) {
    // Isolate entry point
    final receivePort = ReceivePort();
    sendPort.send(receivePort.sendPort);

    receivePort.listen((message) {
      // Handle messages
    });
  }

  static void killWorker(String name) {
    final isolate = _isolates[name];
    if (isolate != null) {
      isolate.kill(priority: Isolate.immediate);
      _isolates.remove(name);
      AppLogger.debug('Killed isolate: $name');
    }
  }

  static void cancelSubscription(String name) {
    final subscription = _subscriptions[name];
    if (subscription != null) {
      subscription.cancel();
      _subscriptions.remove(name);
      AppLogger.debug('Cancelled subscription: $name');
    }
  }

  static void shutdownAll() {
    AppLogger.info('Shutting down all workers...');

    // Cancel all subscriptions
    for (var subscription in _subscriptions.values) {
      subscription.cancel();
    }
    _subscriptions.clear();

    // Kill all isolates
    for (var isolate in _isolates.values) {
      isolate.kill(priority: Isolate.immediate);
    }
    _isolates.clear();

    AppLogger.info('All workers shut down');
  }

  // FIXME static Future<T> runInBackground<T>(
  //     ComputeCallback<Q, T> callback,
  //     Q message,
  //     ) async {
  //   return await compute(callback, message);
  // }

  static Future<void> runIsolate<T>(
      void Function(T message) entryPoint,
      T message,
      ) async {
    await Isolate.spawn(entryPoint, message);
  }

  static Stream<T> createStream<T>(
      Stream<T> Function() streamGenerator,
      ) {
    return streamGenerator();
  }

}