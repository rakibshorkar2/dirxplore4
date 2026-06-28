import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:socks5_proxy/socks_client.dart';
import '../models/proxy_config.dart';

class ProxyProvider with ChangeNotifier {
  ProxyConfig _config = ProxyConfig(
    server: '103.166.253.92',
    port: 1088,
    username: 'test',
    password: 'test',
  );

  ProxyConfig get config => _config;

  void updateConfig(ProxyConfig newConfig) {
    _config = newConfig;
    notifyListeners();
  }

  Dio getDio() {
    final dio = Dio();
    
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        
        final proxySettings = ProxySettings(
          InternetAddress(_config.server),
          _config.port,
          username: _config.username,
          password: _config.password,
        );

        SocksTCPClient.assignToHttpClient(client, [proxySettings]);
        
        // Disable certificate verification for internal/test servers if needed
        client.badCertificateCallback = (cert, host, port) => true;
        
        return client;
      },
    );

    return dio;
  }
}
