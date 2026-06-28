import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/proxy_provider.dart';
import '../models/proxy_config.dart';

class ProxyTab extends StatefulWidget {
  const ProxyTab({super.key});

  @override
  State<ProxyTab> createState() => _ProxyTabState();
}

class _ProxyTabState extends State<ProxyTab> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _serverController;
  late TextEditingController _portController;
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;
  final TextEditingController _yamlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    final config = context.read<ProxyProvider>().currentConfig;
    _serverController = TextEditingController(text: config.server);
    _portController = TextEditingController(text: config.port.toString());
    _usernameController = TextEditingController(text: config.username);
    _passwordController = TextEditingController(text: config.password);
  }

  @override
  void dispose() {
    _serverController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _yamlController.dispose();
    super.dispose();
  }

  void _showYamlDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import YAML Config'),
        content: TextField(
          controller: _yamlController,
          maxLines: 10,
          decoration: const InputDecoration(
            hintText: 'Paste Clash-style YAML here...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              try {
                context.read<ProxyProvider>().importFromYaml(_yamlController.text);
                Navigator.pop(context);
                setState(() {
                  _initControllers();
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Proxies imported successfully')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('Import'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProxyProvider>();
    final config = provider.currentConfig;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Proxy Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            onPressed: _showYamlDialog,
            tooltip: 'Import YAML',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: ListView.builder(
              itemCount: provider.proxies.length,
              itemBuilder: (context, index) {
                final p = provider.proxies[index];
                return ListTile(
                  title: Text(p.name),
                  subtitle: Text('${p.server}:${p.port}'),
                  selected: provider.selectedIndex == index,
                  trailing: provider.selectedIndex == index 
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : null,
                  onTap: () {
                    provider.selectProxy(index);
                    setState(() {
                      _initControllers();
                    });
                  },
                );
              },
            ),
          ),
          const Divider(),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    Text('Editing: ${config.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _serverController,
                      decoration: const InputDecoration(labelText: 'Server Host'),
                      onChanged: (v) => config.server = v,
                    ),
                    TextFormField(
                      controller: _portController,
                      decoration: const InputDecoration(labelText: 'Port'),
                      keyboardType: TextInputType.number,
                      onChanged: (v) => config.port = int.tryParse(v) ?? config.port,
                    ),
                    TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(labelText: 'Username'),
                      onChanged: (v) => config.username = v,
                    ),
                    TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(labelText: 'Password'),
                      obscureText: true,
                      onChanged: (v) => config.password = v,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        provider.updateCurrentConfig(config);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Settings saved')),
                        );
                      },
                      child: const Text('Save Manual Changes'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
