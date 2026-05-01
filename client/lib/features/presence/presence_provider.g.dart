// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'presence_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$presenceHash() => r'ca5bb335311fb5d84ea5f9f7a5bfe363a11b5315';

/// See also [Presence].
@ProviderFor(Presence)
final presenceProvider =
    AutoDisposeNotifierProvider<Presence, Map<String, PresenceStatus>>.internal(
  Presence.new,
  name: r'presenceProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$presenceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$Presence = AutoDisposeNotifier<Map<String, PresenceStatus>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
