import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:open_file_plus/open_file_plus.dart';
import '../providers/download_provider.dart';
import '../models/download_item.dart';

class DownloadTab extends StatelessWidget {
  const DownloadTab({super.key});

  @override
  Widget build(BuildContext context) {
    final downloads = context.watch<DownloadProvider>().items;

    return Scaffold(
      appBar: AppBar(title: const Text('Downloads')),
      body: downloads.isEmpty
          ? const Center(child: Text('No downloads yet'))
          : ListView.builder(
              itemCount: downloads.length,
              itemBuilder: (context, index) {
                final item = downloads[index];
                return ListTile(
                  title: Text(item.fileName),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (item.status == DownloadStatus.downloading)
                        LinearProgressIndicator(value: item.progress),
                      Text(item.status == DownloadStatus.failed 
                          ? 'Failed: ${item.errorMessage}' 
                          : item.status.name),
                    ],
                  ),
                  onTap: item.status == DownloadStatus.completed
                      ? () => OpenFile.open(item.savePath)
                      : null,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => context.read<DownloadProvider>().removeItem(item),
                  ),
                );
              },
            ),
    );
  }
}
