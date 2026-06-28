import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

class Socks5Client {
  final String proxyHost;
  final int proxyPort;
  final String? username;
  final String? password;
  final Function(String) onLog;

  Socks5Client({
    required this.proxyHost,
    required this.proxyPort,
    this.username,
    this.password,
    required this.onLog,
  });

  Future<Socket> connect(String targetHost, int targetPort) async {
    onLog('--- SOCKS5 HANDSHAKE START ---');
    onLog('Target: $targetHost:$targetPort');
    onLog('Proxy: $proxyHost:$proxyPort');

    Socket socket;
    try {
      socket = await Socket.connect(proxyHost, proxyPort, timeout: const Duration(seconds: 10));
      onLog('Connected to Proxy Server.');
    } catch (e) {
      onLog('Failed to connect to Proxy Server: $e');
      rethrow;
    }

    try {
      // 1. Greeting
      onLog('Step 1: Sending Greeting [0x05, 0x01, 0x02] (Methods: Username/Password)');
      socket.add([0x05, 0x01, 0x02]);
      
      final greetingResponse = await _readExactly(socket, 2);
      onLog('Step 1: Received Greeting Response: ${greetingResponse.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').toList()}');
      
      if (greetingResponse[0] != 0x05) {
        throw Exception('Invalid SOCKS version: 0x${greetingResponse[0].toRadixString(16)}');
      }
      
      final selectedMethod = greetingResponse[1];
      if (selectedMethod == 0xFF) {
        throw Exception('Proxy rejected all auth methods (Method 0xFF)');
      }
      onLog('Step 1: Selected Auth Method: 0x${selectedMethod.toRadixString(16).padLeft(2, '0')}');

      // 2. Authentication
      if (selectedMethod == 0x02) {
        if (username == null || password == null) {
          throw Exception('Proxy requested Username/Password auth but none provided');
        }
        onLog('Step 2: Sending Auth [0x01, ULEN, USER, PLEN, PASS]');
        final userBytes = utf8.encode(username!);
        final passBytes = utf8.encode(password!);
        
        final authRequest = [
          0x01, // Sub-negotiation version
          userBytes.length,
          ...userBytes,
          passBytes.length,
          ...passBytes,
        ];
        socket.add(authRequest);
        
        final authResponse = await _readExactly(socket, 2);
        onLog('Step 2: Received Auth Response: ${authResponse.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').toList()}');
        if (authResponse[1] != 0x00) {
          throw Exception('Auth Failed! Status: 0x${authResponse[1].toRadixString(16).padLeft(2, '0')}');
        }
        onLog('Step 2: Auth Successful.');
      } else if (selectedMethod != 0x00) {
        throw Exception('Unsupported auth method: 0x${selectedMethod.toRadixString(16)}');
      } else {
        onLog('Step 2: No Auth required by proxy.');
      }

      // 3. Connect Request
      onLog('Step 3: Sending CONNECT Request');
      final List<int> connectRequest = [0x05, 0x01, 0x00];
      
      final ip = InternetAddress.tryParse(targetHost);
      if (ip != null) {
        if (ip.type == InternetAddressType.IPv4) {
          onLog('Step 3: Target is IPv4, using ATYP 0x01');
          connectRequest.add(0x01);
          connectRequest.addAll(ip.rawAddress);
        } else {
          onLog('Step 3: Target is IPv6, using ATYP 0x04');
          connectRequest.add(0x04);
          connectRequest.addAll(ip.rawAddress);
        }
      } else {
        onLog('Step 3: Target is Domain, using ATYP 0x03');
        connectRequest.add(0x03);
        final hostBytes = utf8.encode(targetHost);
        connectRequest.add(hostBytes.length);
        connectRequest.addAll(hostBytes);
      }
      
      final portData = ByteData(2)..setUint16(0, targetPort);
      connectRequest.addAll(portData.buffer.asUint8List());
      
      socket.add(connectRequest);
      onLog('Step 3: Sent CONNECT packet.');
      
      // Read response header (first 4 bytes)
      final responseHeader = await _readExactly(socket, 4);
      onLog('Step 4: Received Response Header: ${responseHeader.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').toList()}');
      
      if (responseHeader[0] != 0x05) {
        throw Exception('Invalid SOCKS version in response: 0x${responseHeader[0].toRadixString(16)}');
      }
      
      final replyCode = responseHeader[1];
      if (replyCode != 0x00) {
        final errorMsg = _getReplyErrorMessage(replyCode);
        onLog('Step 4: !!! PROXY ERROR: $errorMsg (Reply Code: 0x${replyCode.toRadixString(16).padLeft(2, '0')})');
        throw Exception('SOCKS5 Connect Failed: $errorMsg');
      }
      
      // Consume the rest of the response
      final atyp = responseHeader[3];
      int remainingLen = 0;
      if (atyp == 0x01) remainingLen = 4 + 2; 
      else if (atyp == 0x03) {
        final lenByte = await _readExactly(socket, 1);
        remainingLen = lenByte[0] + 2;
      } else if (atyp == 0x04) remainingLen = 16 + 2;
      
      if (remainingLen > 0) {
        await _readExactly(socket, remainingLen);
      }
      
      onLog('Step 4: Handshake Complete. Returning Socket.');
      onLog('--- SOCKS5 HANDSHAKE SUCCESS ---');
      return _SocksSocket(socket);
    } catch (e) {
      onLog('Handshake Failed: $e');
      socket.destroy();
      rethrow;
    }
  }

  Future<Uint8List> _readExactly(Socket socket, int count) async {
    final completer = Completer<Uint8List>();
    final bytes = <int>[];
    
    StreamSubscription? sub;
    sub = socket.listen(
      (data) {
        bytes.addAll(data);
        if (bytes.length >= count) {
          final result = Uint8List.fromList(bytes.sublist(0, count));
          // If there's extra data, we'd lose it here if we were using the socket directly.
          // But during handshake, packets are usually discrete.
          sub?.cancel();
          completer.complete(result);
        }
      },
      onError: (e) {
        sub?.cancel();
        completer.completeError(e);
      },
      onDone: () {
        sub?.cancel();
        if (!completer.isCompleted) {
          completer.completeError(Exception('Socket closed prematurely'));
        }
      },
      cancelOnError: true,
    );
    
    return completer.future.timeout(const Duration(seconds: 10));
  }

  String _getReplyErrorMessage(int code) {
    switch (code) {
      case 0x01: return 'General SOCKS server failure (0x01)';
      case 0x02: return 'Connection not allowed by ruleset (0x02)';
      case 0x03: return 'Network unreachable (0x03)';
      case 0x04: return 'Host unreachable (0x04)';
      case 0x05: return 'Connection refused (0x05)';
      case 0x06: return 'TTL expired (0x06)';
      case 0x07: return 'Command not supported (0x07)';
      case 0x08: return 'Address type not supported (0x08)';
      default: return 'Unknown error (0x${code.toRadixString(16)})';
    }
  }
}

class _SocksSocket extends Stream<Uint8List> implements Socket {
  final Socket _inner;
  late final StreamController<Uint8List> _controller;
  StreamSubscription? _subscription;

  _SocksSocket(this._inner) {
    _controller = StreamController<Uint8List>(
      onListen: () {
        _subscription = _inner.listen(
          (data) => _controller.add(data),
          onError: (e) => _controller.addError(e),
          onDone: () => _controller.close(),
        );
      },
      onCancel: () {
        _subscription?.cancel();
      },
      onPause: () => _subscription?.pause(),
      onResume: () => _subscription?.resume(),
    );
  }

  @override
  void add(List<int> data) => _inner.add(data);

  @override
  void addError(Object error, [StackTrace? stackTrace]) => _inner.addError(error, stackTrace);

  @override
  Future addStream(Stream<List<int>> stream) => _inner.addStream(stream);

  @override
  Future close() => _inner.close();

  @override
  Future get done => _inner.done;

  @override
  void destroy() => _inner.destroy();

  @override
  bool setOption(SocketOption option, bool enabled) => _inner.setOption(option, enabled);

  @override
  void setRawOption(RawSocketOption option) => _inner.setRawOption(option);

  @override
  Uint8List getRawOption(RawSocketOption option) => _inner.getRawOption(option);

  @override
  InternetAddress get address => _inner.address;

  @override
  InternetAddress get remoteAddress => _inner.remoteAddress;

  @override
  int get port => _inner.port;

  @override
  int get remotePort => _inner.remotePort;

  @override
  StreamSubscription<Uint8List> listen(void Function(Uint8List event)? onData,
          {Function? onError, void Function()? onDone, bool? cancelOnError}) =>
      _controller.stream.listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);

  @override
  Encoding get encoding => _inner.encoding;

  @override
  set encoding(Encoding value) => _inner.encoding = value;

  @override
  Future flush() => _inner.flush();
}
