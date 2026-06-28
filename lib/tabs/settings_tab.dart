import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import '../providers/app_proxy_provider.dart';
import '../providers/settings_provider.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  String _cacheSize = 'Calculating...';
  String _version = '1.0.1';
  final String _developer = 'RAKIB';

  @override
  void initState() {
    super.initState();
    _initInfo();
  }

  Future<void> _initInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _version = info.version;
    });
    _calculateCacheSize();
  }

  Future<void> _calculateCacheSize() async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      int totalSize = 0;
      if (docDir.existsSync()) {
        docDir.listSync(recursive: true).forEach((entity) {
          if (entity is File) {
            totalSize += entity.lengthSync();
          }
        });
      }
      setState(() {
        _cacheSize = '${(totalSize / (1024 * 1024)).toStringAsFixed(2)} MB';
      });
    } catch (e) {
      setState(() {
        _cacheSize = 'Error';
      });
    }
  }

  Future<void> _clearDownloads() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Downloads'),
        content: const Text('Are you sure you want to delete all downloaded files?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Clear', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final docDir = await getApplicationDocumentsDirectory();
        if (docDir.existsSync()) {
          docDir.listSync().forEach((entity) {
            if (entity is File) {
              entity.deleteSync();
            }
          });
        }
        _calculateCacheSize();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Downloads cleared')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  void _showLogs() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Consumer<AppProxyProvider>(
          builder: (context, provider, _) {
            final settings = context.read<SettingsProvider>();
            final logs = settings.debugLogging 
              ? provider.logs 
              : provider.logs.where((l) => !l.contains('[DEBUG]')).toList();
            
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return Column(
                  children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Proxy Connection Logs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => context.read<AppProxyProvider>().clearLogs(),
                        tooltip: 'Clear Logs',
                      ),
                      IconButton(
                        icon: const Icon(Icons.share),
                        onPressed: () {
                          final text = logs.join('\n');
                          Share.share(text, subject: 'App Proxy Logs');
                        },
                      ),
                    ],
                  ),
                ),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: logs.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                            child: Text(logs[index], style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Appearance', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
          ),
          ListTile(
            leading: const Icon(Icons.brightness_6),
            title: const Text('Theme Mode'),
            trailing: DropdownButton<ThemeMode>(
              value: settings.themeMode,
              onChanged: (mode) => settings.setThemeMode(mode!),
              items: const [
                DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
                DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
              ],
            ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('App Information', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Version'),
            trailing: Text(_version),
          ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Developer'),
            trailing: Text(_developer, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Diagnostics', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('View Connection Logs'),
            subtitle: const Text('Detailed proxy transaction history'),
            onTap: _showLogs,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.bug_report_outlined),
            title: const Text('Debug Logging'),
            subtitle: const Text('Enable detailed logs for troubleshooting'),
            value: settings.debugLogging,
            onChanged: (v) => settings.setDebugLogging(v),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Storage & Cache', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
          ),
          ListTile(
            leading: const Icon(Icons.storage),
            title: const Text('Downloads Size'),
            subtitle: const Text('Total size of files in documents folder'),
            trailing: Text(_cacheSize),
            onTap: _calculateCacheSize,
          ),
          ListTile(
            leading: const Icon(Icons.delete_sweep, color: Colors.red),
            title: const Text('Clear All Downloads', style: TextStyle(color: Colors.red)),
            onTap: _clearDownloads,
          ),
        ],
      ),
    );
  }
}
