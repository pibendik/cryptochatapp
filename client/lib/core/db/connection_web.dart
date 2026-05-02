import 'package:drift/backends.dart';
import 'package:drift/drift.dart';

/// Returns an in-memory no-op executor for web builds.
///
/// The app compiles and all screens render, but nothing is persisted —
/// every read returns an empty result set and writes are silently dropped.
/// This is intentional: the web target is for UI development and QA only.
/// A full WASM-backed SQLite (drift/wasm.dart + sqlite3.wasm) can replace
/// this once needed.
QueryExecutor openDatabaseConnection() => _WebNoOpExecutor();

// ─── No-op executor ──────────────────────────────────────────────────────────

class _WebNoOpExecutor extends QueryExecutor {
  @override
  SqlDialect get dialect => SqlDialect.sqlite;

  @override
  Future<bool> ensureOpen(QueryExecutorUser user) async => true;

  @override
  Future<List<Map<String, Object?>>> runSelect(
    String statement,
    List<Object?> args,
  ) async =>
      const [];

  @override
  Future<int> runInsert(String statement, List<Object?> args) async => 0;

  @override
  Future<int> runUpdate(String statement, List<Object?> args) async => 0;

  @override
  Future<int> runDelete(String statement, List<Object?> args) async => 0;

  @override
  Future<void> runCustom(String statement, [List<Object?>? args]) async {}

  @override
  Future<void> runBatched(BatchedStatements statements) async {}

  @override
  TransactionExecutor beginTransaction() => _WebNoOpTransaction();

  @override
  Future<void> close() async {}
}

class _WebNoOpTransaction extends _WebNoOpExecutor
    implements TransactionExecutor {
  @override
  Future<void> send() async {}

  @override
  Future<void> rollback() async {}

  @override
  bool get supportsNestedTransactions => false;
}
