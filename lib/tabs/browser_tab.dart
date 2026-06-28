import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:path_provider/path_provider.dart';
import '../providers/app_proxy_provider.dart';
import '../providers/download_provider.dart';

class BrowserTab extends StatefulWidget {
  const BrowserTab({super.key});

  @override
  State<BrowserTab> createState() => _BrowserTabState();
}

class _BrowserTabState extends State<BrowserTab> {
  String _currentUrl = 'http://172.16.50.4/';
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchDirectory();
  }

  Future<void> _fetchDirectory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final dio = context.read<AppProxyProvider>().getDio();
      final response = await dio.get(_currentUrl);
      final document = html_parser.parse(response.data);
      final links = document.getElementsByTagName('a');

      final List<Map<String, dynamic>> items = [];
      for (var link in links) {
        final href = link.attributes['href'];
        if (href == null || href == '../' || href.startsWith('?')) continue;

        final text = link.text.trim();
        final isDirectory = href.endsWith('/');
        
        items.add({
          'name': text.isEmpty ? href : text,
          'url': Uri.parse(_currentUrl).resolve(href).toString(),
          'isDirectory': isDirectory,
        });
      }

      setState(() {
        _items = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _navigate(String url) {
    setState(() {
      _currentUrl = url;
    });
    _fetchDirectory();
  }

  Future<void> _download(String url) async {
    final saveDir = (await getApplicationDocumentsDirectory()).path;
    if (!mounted) return;
    context.read<DownloadProvider>().startDownload(
      url, 
      saveDir, 
      context.read<AppProxyProvider>()
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Download started')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentUrl),
        leading: _currentUrl != 'http://172.16.50.4/' 
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                // Simplified back navigation
                final uri = Uri.parse(_currentUrl);
                var segments = List<String>.from(uri.pathSegments);
                if (segments.isNotEmpty && segments.last.isEmpty) segments.removeLast();
                if (segments.isNotEmpty) {
                  segments.removeLast();
                  if (segments.isEmpty) {
                    _navigate(uri.replace(pathSegments: ['']).toString());
                  } else {
                    segments.add('');
                    _navigate(uri.replace(pathSegments: segments).toString());
                  }
                }
              },
            )
          : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : ListView.builder(
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return ListTile(
                      leading: Icon(item['isDirectory'] ? Icons.folder : Icons.insert_drive_file),
                      title: Text(item['name']),
                      onTap: () {
                        if (item['isDirectory']) {
                          _navigate(item['url']);
                        } else {
                          _download(item['url']);
                        }
                      },
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _fetchDirectory,
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
