import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mls_service.dart';

/// Provides the active [MlsService] implementation.
///
/// Currently uses [StubMlsService] so the app builds without native libraries.
/// To enable real MLS: change StubMlsService() to RealMlsService(identityKeyHex: ...)
/// after running: dart run flutter_rust_bridge_codegen generate
/// in the client/ directory.
final mlsServiceProvider = Provider<MlsService>((ref) => StubMlsService());
