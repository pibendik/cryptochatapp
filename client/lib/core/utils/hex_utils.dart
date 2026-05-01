import 'dart:typed_data';

/// Shared hex encoding/decoding utilities.
/// Use these instead of manual implementations to avoid edge-case bugs.

String bytesToHex(Uint8List bytes) {
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

Uint8List hexToBytes(String hex) {
  if (hex.length % 2 != 0) throw ArgumentError('Odd hex string length');
  final result = Uint8List(hex.length ~/ 2);
  for (var i = 0; i < hex.length; i += 2) {
    result[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
  }
  return result;
}

/// Returns a short fingerprint for display (20 hex chars = 10 bytes = 80 bits)
/// Use for human-readable key verification — NOT for crypto operations.
String keyFingerprint(Uint8List publicKey) {
  return bytesToHex(publicKey).substring(0, 20);
}
