import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class AppConfig {
  static AppConfig? _instance;

  late String kubeConfigPath;
  late String appDataPath;

  AppConfig._();

  static Future<AppConfig> getInstance() async {
    if (_instance == null) {
      _instance = AppConfig._();
      await _instance!._initialize();
    }
    return _instance!;
  }

  Future<void> _initialize() async {
    // Set default kubeconfig path
    final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    kubeConfigPath = path.join(home ?? '', '.kube', 'config');

    // Set app data path
    final appDir = await getApplicationDocumentsDirectory();
    appDataPath = path.join(appDir.path, 'kubegrandson');

    // Create app data directory if it doesn't exist
    final dir = Directory(appDataPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  String getLogFilePath() {
    return path.join(appDataPath, 'app.log');
  }


  static const String version = '1.0.0';
  static const String appName = 'Kubegrandson';
  static const String vendor = 'Bruno Penha';
  static const String description = 'Kubegrandson Kubernetes log viewer - Grandson of Kubeson';
  static const String parentApp = 'Kubeson';
  static const String parentVersion = '2.3.2';

  // Kubernetes configuration
  static const String defaultKubeConfigPath = '.kube/config';
  static const int logBufferSize = 1000;
  static const int maxConcurrentStreams = 10;
  static const int maxLogLines = 10000;

  // UI configuration
  static const int searchDebounceMs = 300;
  static const int autoScrollThreshold = 50;
  static const int jsonArrayCollapseThreshold = 4;
  static const int bigFieldSizeThreshold = 10000; // characters

  // Log export
  static const String exportDateFormat = 'yyyy-MM-dd_HH-mm-ss';
  static const String exportFilePrefix = 'kubegrandson_logs_';
}