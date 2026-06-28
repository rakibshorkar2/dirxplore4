import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  bool _debugLogging = false;
  List<String> _httpServers = ['http://172.16.50.4/'];
  int _selectedServerIndex = 0;

  ThemeMode get themeMode => _themeMode;
  bool get debugLogging => _debugLogging;
  List<String> get httpServers => _httpServers;
  int get selectedServerIndex => _selectedServerIndex;
  String get currentServer => _httpServers[_selectedServerIndex];

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt('themeMode') ?? 0;
    _themeMode = ThemeMode.values[themeIndex];
    _debugLogging = prefs.getBool('debugLogging') ?? false;
    _httpServers = prefs.getStringList('httpServers') ?? ['http://172.16.50.4/'];
    _selectedServerIndex = prefs.getInt('selectedServerIndex') ?? 0;
    if (_selectedServerIndex >= _httpServers.length) _selectedServerIndex = 0;
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt('themeMode', mode.index);
  }

  void setDebugLogging(bool value) async {
    _debugLogging = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('debugLogging', value);
  }

  void addServer(String url) async {
    if (!url.startsWith('http')) url = 'http://$url';
    if (!url.endsWith('/')) url = '$url/';
    _httpServers.add(url);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    prefs.setStringList('httpServers', _httpServers);
  }

  void removeServer(int index) async {
    // Ensure we don't remove the default server if it's the last one,
    // and specifically protect the mandatory default server.
    final serverToRemove = _httpServers[index];
    if (serverToRemove == 'http://172.16.50.4/') {
      return; // Do not allow removing the default server
    }

    if (_httpServers.length > 1) {
      _httpServers.removeAt(index);
      if (_selectedServerIndex >= index && _selectedServerIndex > 0) {
        _selectedServerIndex--;
      }
      notifyListeners();
      final prefs = await SharedPreferences.getInstance();
      prefs.setStringList('httpServers', _httpServers);
      prefs.setInt('selectedServerIndex', _selectedServerIndex);
    }
  }

  void selectServer(int index) async {
    _selectedServerIndex = index;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt('selectedServerIndex', index);
  }
}
