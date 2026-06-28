import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:socks5_proxy/socks_client.dart';
import 'package:yaml/yaml.dart';
import '../models/proxy_config.dart';

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

  List<ProxyConfig> get proxies => _proxies;
  int get selectedIndex => _selectedIndex;
  ProxyConfig get currentConfig => _proxies[_selectedIndex];

  void updateCurrentConfig(ProxyConfig newConfig) {
    _proxies[_selectedIndex] = newConfig;
    notifyListeners();
  }

  void selectProxy(int index) {
    if (index >= 0 && index < _proxies.length) {
      _selectedIndex = index;
      notifyListeners();
    }
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
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error parsing YAML: $e');
      rethrow;
    }
  }

  Future<bool> testConnection() async {
    try {
      final dio = getDio();
      // Test against a small public resource or a connectivity check
      final response = await dio.get('http://www.google.com/generate_204').timeout(const Duration(seconds: 5));
      return response.statusCode == 204 || response.statusCode == 200;
    } catch (e) {
      debugPrint('Proxy test failed: $e');
      return false;
    }
  }

  Dio getDio() {
    final dio = Dio();
    final config = currentConfig;
    
    dio.options.connectTimeout = const Duration(seconds: 10);
    dio.options.receiveTimeout = const Duration(seconds: 10);
    
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        
        final proxySettings = ProxySettings(
          InternetAddress(config.server),
          config.port,
          username: config.username.isEmpty ? null : config.username,
          password: config.password.isEmpty ? null : config.password,
        );

        SocksTCPClient.assignToHttpClient(client, [proxySettings]);
        client.badCertificateCallback = (cert, host, port) => true;
        
        return client;
      },
    );

    return dio;
  }
}
