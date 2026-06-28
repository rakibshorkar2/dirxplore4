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
  final List<String> _logs = [];

  List<ProxyConfig> get proxies => _proxies;
  int get selectedIndex => _selectedIndex;
  ProxyConfig get currentConfig => _proxies[_selectedIndex];
  List<String> get logs => _logs;

  void addLog(String message) {
    final timestamp = DateTime.now().toString().split('.').first.split(' ').last;
    _logs.insert(0, '[$timestamp] $message');
    if (_logs.length > 50) _logs.removeLast();
    notifyListeners();
  }

  void updateCurrentConfig(ProxyConfig newConfig) {
    _proxies[_selectedIndex] = newConfig;
    addLog('Manual config update for ${newConfig.name}');
    notifyListeners();
  }

  void selectProxy(int index) {
    if (index >= 0 && index < _proxies.length) {
      _selectedIndex = index;
      addLog('Selected proxy: ${_proxies[index].name}');
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
          addLog('Imported ${newProxies.length} proxies from YAML');
          notifyListeners();
        }
      }
    } catch (e) {
      addLog('YAML Error: $e');
      rethrow;
    }
  }

  Future<bool> testConnection() async {
    addLog('Testing connection to ${_proxies[_selectedIndex].server}...');
    try {
      final dio = getDio();
      // Use HTTP for testing as some proxies/targets might have issues with HTTPS 204
      final response = await dio.get('http://www.google.com/generate_204').timeout(const Duration(seconds: 10));
      final success = response.statusCode == 204 || response.statusCode == 200;
      addLog('Test Result: ${success ? 'SUCCESS' : 'FAILED (${response.statusCode})'}');
      return success;
    } catch (e) {
      addLog('Test Failed: $e');
      return false;
    }
  }

  Dio getDio() {
    final dio = Dio();
    final config = currentConfig;
    
    dio.options.connectTimeout = const Duration(seconds: 15);
    dio.options.receiveTimeout = const Duration(seconds: 15);
    
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        
        // Force IPv4 if possible to avoid IPv6 connection issues seen in Proxifier
        client.connectionTimeout = const Duration(seconds: 10);
        
        try {
          // Attempt to parse server as IP. If it fails, it's a hostname.
          final address = InternetAddress.tryParse(config.server) ?? config.server;
          
          final proxySettings = ProxySettings(
            address is InternetAddress ? address : InternetAddress.anyIPv4, // Placeholder if hostname
            config.port,
            username: config.username.isEmpty ? null : config.username,
            password: config.password.isEmpty ? null : config.password,
          );

          // If it was a hostname, we might need a different approach or let the library handle it
          // socks5_proxy's ProxySettings actually takes InternetAddress.
          // If it's a hostname, we should resolve it first.
          
          SocksTCPClient.assignToHttpClient(client, [proxySettings]);
          
          if (address is String) {
            // This is a limitation of socks5_proxy package. It needs an InternetAddress.
            // We'll try to resolve it.
            addLog('Resolving hostname: $address...');
            InternetAddress.lookup(address).then((list) {
              if (list.isNotEmpty) {
                proxySettings.host = list.first;
              }
            });
          }
        } catch (e) {
          addLog('Adapter Error: $e');
        }

        client.badCertificateCallback = (cert, host, port) => true;
        return client;
      },
    );

    return dio;
  }
}
