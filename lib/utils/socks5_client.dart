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
    } catch (e) {
      onLog('Socket Error: $e');
      rethrow;
    }

    final reader = _SocketReader(socket);

    try {
      // 1. Greeting
      socket.add([0x05, 0x01, 0x02]);
      final greetingResponse = await reader.readExactly(2);
      if (greetingResponse[0] != 0x05) throw Exception('Invalid SOCKS version');
      
      final method = greetingResponse[1];
      if (method == 0xFF) throw Exception('No acceptable auth methods');

      // 2. Auth
      if (method == 0x02) {
        if (username == null) throw Exception('Credentials required');
        final u = utf8.encode(username!);
        final p = utf8.encode(password ?? '');
        socket.add([0x01, u.length, ...u, p.length, ...p]);
        final authRes = await reader.readExactly(2);
        if (authRes[1] != 0x00) throw Exception('Auth Failed (0x${authRes[1].toRadixString(16)})');
      }

      // 3. Connect
      final List<int> req = [0x05, 0x01, 0x00];
      final ip = InternetAddress.tryParse(targetHost);
      if (ip != null) {
        req.add(ip.type == InternetAddressType.IPv4 ? 0x01 : 0x04);
        req.addAll(ip.rawAddress);
      } else {
        req.add(0x03);
        final host = utf8.encode(targetHost);
        req.add(host.length);
        req.addAll(host);
      }
      final portData = ByteData(2)..setUint16(0, targetPort);
      req.addAll(portData.buffer.asUint8List());
      socket.add(req);

      final resHeader = await reader.readExactly(4);
      if (resHeader[1] != 0x00) throw Exception('Connect Failed (0x${resHeader[1].toRadixString(16)})');

      final atyp = resHeader[3];
      if (atyp == 0x01) await reader.readExactly(4 + 2);
      else if (atyp == 0x03) {
        final len = await reader.readExactly(1);
        await reader.readExactly(len[0] + 2);
      } else if (atyp == 0x04) await reader.readExactly(16 + 2);

      onLog('--- SOCKS5 HANDSHAKE SUCCESS ---');
      return _SocksSocket(socket, reader);
    } catch (e) {
      onLog('Handshake Error: $e');
      socket.destroy();
      rethrow;
    }
  }
}

class _SocketReader {
  final Socket _socket;
  final _controller = StreamController<Uint8List>();
  final _buffer = <int>[];
  Completer<Uint8List>? _completer;
  int _targetCount = 0;
  StreamSubscription? _sub;

  _SocketReader(this._socket) {
    _sub = _socket.listen(
      (data) {
        if (_completer != null) {
          _buffer.addAll(data);
          if (_buffer.length >= _targetCount) {
            final result = Uint8List.fromList(_buffer.sublist(0, _targetCount));
            final remaining = _buffer.sublist(_targetCount);
            _buffer.clear();
            _buffer.addAll(remaining);
            
            final c = _completer!;
            _completer = null;
            c.complete(result);
          }
        } else {
          _controller.add(data);
        }
      },
      onError: (e) => _completer?.completeError(e) ?? _controller.addError(e),
      onDone: () => _completer?.completeError(Exception('Closed')) ?? _controller.close(),
    );
  }

  Future<Uint8List> readExactly(int count) {
    if (_buffer.length >= count) {
      final result = Uint8List.fromList(_buffer.sublist(0, count));
      final remaining = _buffer.sublist(count);
      _buffer.clear();
      _buffer.addAll(remaining);
      return Future.value(result);
    }
    _targetCount = count;
    _completer = Completer<Uint8List>();
    return _completer!.future.timeout(const Duration(seconds: 10));
  }

  Stream<Uint8List> get stream async* {
    if (_buffer.isNotEmpty) {
      yield Uint8List.fromList(_buffer);
      _buffer.clear();
    }
    yield* _controller.stream;
  }

  void stop() {
    _sub?.cancel();
  }
}

class _SocksSocket extends Stream<Uint8List> implements Socket {
  final Socket _inner;
  final _SocketReader _reader;

  _SocksSocket(this._inner, this._reader);

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
  Encoding get encoding => _inner.encoding;
  @override
  set encoding(Encoding value) => _inner.encoding = value;
  @override
  Future flush() => _inner.flush();

  @override
  StreamSubscription<Uint8List> listen(void Function(Uint8List event)? onData,
          {Function? onError, void Function()? onDone, bool? cancelOnError}) =>
      _reader.stream.listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
}
