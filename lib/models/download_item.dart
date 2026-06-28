enum DownloadStatus { pending, downloading, completed, failed }

class DownloadItem {
  final String id;
  final String url;
  final String fileName;
  final String savePath;
  double progress;
  DownloadStatus status;
  String? errorMessage;

  DownloadItem({
    required this.id,
    required this.url,
    required this.fileName,
    required this.savePath,
    this.progress = 0.0,
    this.status = DownloadStatus.pending,
    this.errorMessage,
  });
}
