// Platform-conditional database connection.
//
// On native (iOS / Android / desktop / server) → NativeDatabase backed by
// sqlite3_flutter_libs (dart:ffi).
// On web → no-op in-memory executor so the UI compiles and renders without
// any SQLite dependency (data does not persist across page refreshes).
export 'connection_native.dart'
    if (dart.library.html) 'connection_web.dart';
