import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  String _cacheSize = 'Calculating...';
  final String _version = '1.0.1';
  final String _developer = 'RAKIB';

  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
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
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Advanced', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.bug_report_outlined),
            title: const Text('Debug Logging'),
            subtitle: const Text('Enable detailed logs for troubleshooting'),
            value: false,
            onChanged: (v) {},
          ),
        ],
      ),
    );
  }
}
