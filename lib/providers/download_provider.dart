import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import '../models/download_item.dart';
import 'app_proxy_provider.dart';

class DownloadProvider with ChangeNotifier {
  final List<DownloadItem> _items = [];

  List<DownloadItem> get items => _items;

  Future<void> startDownload(String url, String saveDir, AppProxyProvider proxyProvider) async {
    final fileName = p.basename(Uri.parse(url).path);
    final savePath = p.join(saveDir, fileName);
    
    final item = DownloadItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      url: url,
      fileName: fileName,
      savePath: savePath,
      status: DownloadStatus.downloading,
    );

    _items.insert(0, item);
    notifyListeners();

    try {
      final dio = proxyProvider.getDio();
      await dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            item.progress = received / total;
            notifyListeners();
          }
        },
      );
      item.status = DownloadStatus.completed;
      item.progress = 1.0;
    } catch (e) {
      item.status = DownloadStatus.failed;
      item.errorMessage = e.toString();
    }
    notifyListeners();
  }

  void removeItem(DownloadItem item) {
    _items.remove(item);
    final file = File(item.savePath);
    if (file.existsSync()) {
      file.deleteSync();
    }
    notifyListeners();
  }
}
