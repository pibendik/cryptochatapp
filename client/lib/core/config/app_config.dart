import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Application-wide server configuration.
///
/// Pass `--dart-define=SERVER_URL=https://chat.example.com` at build time
/// to override the default dev values without touching source code.
class AppConfig {
  const AppConfig({required this.serverUrl, required this.wsUrl});

  /// HTTP base URL, e.g. `https://chat.example.com`.
  final String serverUrl;

  /// WebSocket endpoint, e.g. `wss://chat.example.com/ws`.
  final String wsUrl;

  /// Development defaults pointing to the local Rust server.
  factory AppConfig.dev() => const AppConfig(
        serverUrl: 'http://localhost:8000',
        wsUrl: 'ws://localhost:8000/ws',
      );

  /// Reads build-time `--dart-define` variables; falls back to dev values.
  factory AppConfig.fromEnv() {
    const serverUrl = String.fromEnvironment(
      'SERVER_URL',
      defaultValue: 'http://localhost:8000',
    );
    const wsUrl = String.fromEnvironment(
      'WS_URL',
      defaultValue: 'ws://localhost:8000/ws',
    );
    return const AppConfig(serverUrl: serverUrl, wsUrl: wsUrl);
  }
}

/// Global app configuration provider.
///
/// Override in tests with `ProviderScope(overrides: [appConfigProvider.overrideWithValue(...)])`.
final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnv(),
);
