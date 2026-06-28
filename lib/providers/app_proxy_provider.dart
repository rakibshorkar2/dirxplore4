import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:yaml/yaml.dart';
import '../models/proxy_config.dart';
import '../utils/socks5_client.dart';

class AppProxyProvider with ChangeNotifier {
  List<ProxyConfig> _proxies = [
    ProxyConfig(
      name: 'Default',
      server: '103.166.253.92',
      port: 1088,
      username: 'test',
      password: 'test',
    )
  ];
  
  int _selectedIndex = 0;
  final List<String> _logs = [];

  List<ProxyConfig> get proxies => _proxies;
  int get selectedIndex => _selectedIndex;
  ProxyConfig get currentConfig => _proxies[_selectedIndex];
  List<String> get logs => _logs;

  void addLog(String message, {bool isDebug = false}) {
    // We will check for the debug flag in the provider or via a global static if needed
    // For now, let's just log everything but mark it
    final timestamp = DateTime.now().toString().split('.').first.split(' ').last;
    _logs.insert(0, '[$timestamp] ${isDebug ? "[DEBUG] " : ""}$message');
    if (_logs.length > 500) _logs.removeLast();
    notifyListeners();
  }

  Future<int?> pingProxy(ProxyConfig config) async {
    final stopwatch = Stopwatch()..start();
    try {
      final socket = await Socket.connect(config.server, config.port, timeout: const Duration(seconds: 5));
      stopwatch.stop();
      socket.destroy();
      return stopwatch.elapsedMilliseconds;
    } catch (e) {
      return null;
    }
  }

  void updateCurrentConfig(ProxyConfig newConfig) {
    _proxies[_selectedIndex] = newConfig;
    addLog('Manual config update: ${newConfig.name}');
    notifyListeners();
  }

  void selectProxy(int index) {
    if (index >= 0 && index < _proxies.length) {
      _selectedIndex = index;
      addLog('Selected proxy: ${_proxies[index].name}');
      notifyListeners();
    }
  }

  void clearLogs() {
    _logs.clear();
    notifyListeners();
  }

  void importFromYaml(String yamlString) {
    try {
      final doc = loadYaml(yamlString);
      if (doc is YamlMap && doc.containsKey('proxies')) {
        final List<ProxyConfig> newProxies = [];
        final yamlProxies = doc['proxies'];
        
        if (yamlProxies is YamlList) {
          for (final item in yamlProxies) {
            if (item is YamlMap) {
              newProxies.add(ProxyConfig.fromYaml(item));
            }
          }
        }
        
        if (newProxies.isNotEmpty) {
          _proxies = newProxies;
          _selectedIndex = 0;
          addLog('Imported ${newProxies.length} proxies.');
          notifyListeners();
        }
      }
    } catch (e) {
      addLog('YAML Error: $e');
      rethrow;
    }
  }

  Future<bool> testConnection() async {
    addLog('TEST: Connectivity check...');
    try {
      final dio = getDio();
      final response = await dio.get('http://www.google.com/generate_204').timeout(const Duration(seconds: 15));
      final success = response.statusCode == 204 || response.statusCode == 200;
      addLog('TEST RESULT: ${success ? 'SUCCESS' : 'FAILED (${response.statusCode})'}');
      return success;
    } catch (e) {
      addLog('TEST FAILED: $e');
      return false;
    }
  }

  Dio getDio() {
    final dio = Dio();
    final config = currentConfig;
    
    dio.options.connectTimeout = const Duration(seconds: 20);
    dio.options.receiveTimeout = const Duration(seconds: 20);
    
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        
        // Use the connectionFactory to intercept all socket creations
        client.connectionFactory = (uri, proxyHost, proxyPort) async {
          addLog('NETWORK: Intercepting request to ${uri.host}:${uri.port}');
          
          final socksClient = Socks5Client(
            proxyHost: config.server,
            proxyPort: config.port,
            username: config.username.isEmpty ? null : config.username,
            password: config.password.isEmpty ? null : config.password,
            onLog: (msg) => addLog(msg),
          );

          return await socksClient.connect(uri.host, uri.port);
        };

        client.badCertificateCallback = (cert, host, port) => true;
        return client;
      },
    );

    return dio;
  }
}
