import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:path_provider/path_provider.dart';
import '../providers/app_proxy_provider.dart';
import '../providers/download_provider.dart';
import '../providers/settings_provider.dart';

class BrowserTab extends StatefulWidget {
  const BrowserTab({super.key});

  @override
  State<BrowserTab> createState() => _BrowserTabState();
}

class _BrowserTabState extends State<BrowserTab> {
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = false;
  String? _error;
  late String _currentUrl;

  @override
  void initState() {
    super.initState();
    _currentUrl = context.read<SettingsProvider>().currentServer;
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

  void _showServerList() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Consumer<SettingsProvider>(
          builder: (context, settings, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Select HTTP Server', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: settings.httpServers.length,
                    itemBuilder: (context, index) {
                      final server = settings.httpServers[index];
                      return ListTile(
                        title: Text(server),
                        selected: settings.selectedServerIndex == index,
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => settings.removeServer(index),
                        ),
                        onTap: () {
                          settings.selectServer(index);
                          _navigate(server);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.add),
                  title: const Text('Add New Server'),
                  onTap: () {
                    Navigator.pop(context);
                    _showAddServerDialog();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddServerDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add HTTP Server'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'http://example.com/'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                context.read<SettingsProvider>().addServer(controller.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    
    return Scaffold(
      appBar: AppBar(
        title: Text(_currentUrl, style: const TextStyle(fontSize: 14)),
        actions: [
          IconButton(icon: const Icon(Icons.dns), onPressed: _showServerList),
        ],
        leading: _currentUrl != settings.currentServer
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
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
