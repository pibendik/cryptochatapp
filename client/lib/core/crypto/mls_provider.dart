import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mls_service.dart';

/// Provides the active [MlsService] implementation.
///
/// Swap [StubMlsService] for the real openmls-backed service in Phase 4.
final mlsServiceProvider = Provider<MlsService>((ref) => StubMlsService());
