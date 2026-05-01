// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$flutterSecureStorageHash() =>
    r'b16e4e9f4ba958131f81a8d1b6f1e7d83106b786';

/// See also [flutterSecureStorage].
@ProviderFor(flutterSecureStorage)
final flutterSecureStorageProvider =
    AutoDisposeProvider<FlutterSecureStorage>.internal(
  flutterSecureStorage,
  name: r'flutterSecureStorageProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$flutterSecureStorageHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef FlutterSecureStorageRef = AutoDisposeProviderRef<FlutterSecureStorage>;
String _$secureStorageHash() => r'f2104577efe42fb0efefc61cbd1ec362d991d629';

/// See also [secureStorage].
@ProviderFor(secureStorage)
final secureStorageProvider =
    AutoDisposeProvider<SecureStorageService>.internal(
  secureStorage,
  name: r'secureStorageProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$secureStorageHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef SecureStorageRef = AutoDisposeProviderRef<SecureStorageService>;
String _$cryptoServiceHash() => r'0858b41656abee8800844d1365be9419eaa8fca4';

/// See also [cryptoService].
@ProviderFor(cryptoService)
final cryptoServiceProvider = AutoDisposeProvider<CryptoService>.internal(
  cryptoService,
  name: r'cryptoServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$cryptoServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef CryptoServiceRef = AutoDisposeProviderRef<CryptoService>;
String _$authHash() => r'67fc82c194f063dbf72087bd71f90db03507575f';

/// See also [Auth].
@ProviderFor(Auth)
final authProvider = NotifierProvider<Auth, AuthState>.internal(
  Auth.new,
  name: r'authProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$authHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$Auth = Notifier<AuthState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
