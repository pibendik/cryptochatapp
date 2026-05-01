import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'push_service.dart';

/// Exposes [PushService] as a Riverpod provider.
///
/// Call [pushServiceProvider.notifier].init(serverUrl, authToken) after login.
/// The provider itself is stateless — it exists so that other providers can
/// depend on push initialisation being complete before using the WS client.
final pushServiceProvider = Provider<PushService>((ref) => PushService());
