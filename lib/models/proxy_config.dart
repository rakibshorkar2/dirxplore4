class ProxyConfig {
  final String name;
  String server;
  int port;
  String username;
  String password;
  String type; // e.g., socks5

  ProxyConfig({
    required this.name,
    required this.server,
    required this.port,
    required this.username,
    required this.password,
    this.type = 'socks5',
  });

  factory ProxyConfig.fromYaml(Map<dynamic, dynamic> yaml) {
    return ProxyConfig(
      name: yaml['name']?.toString() ?? 'Unnamed',
      server: yaml['server']?.toString() ?? '',
      port: int.tryParse(yaml['port']?.toString() ?? '1080') ?? 1080,
      username: yaml['username']?.toString() ?? '',
      password: yaml['password']?.toString() ?? '',
      type: yaml['type']?.toString() ?? 'socks5',
    );
  }

  ProxyConfig copyWith({
    String? name,
    String? server,
    int? port,
    String? username,
    String? password,
    String? type,
  }) {
    return ProxyConfig(
      name: name ?? this.name,
      server: server ?? this.server,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
      type: type ?? this.type,
    );
  }
}
