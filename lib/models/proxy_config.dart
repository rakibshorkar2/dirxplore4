class ProxyConfig {
  String server;
  int port;
  String username;
  String password;
  String type; // always socks5 for now

  ProxyConfig({
    required this.server,
    required this.port,
    required this.username,
    required this.password,
    this.type = 'socks5',
  });
}
