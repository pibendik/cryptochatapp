// GENERATED CODE - DO NOT MODIFY BY HAND
//
// NOTE: riverpod_generator cannot resolve drift-generated types at codegen
// time, so InvalidType was corrected to UserProfilesTableData? by hand.
// If you need to re-run build_runner, apply this fix again afterward.

part of 'profile_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$profileNotifierHash() => r'd602e5fb5ba745853593a375435e82f9a7515dfe';

/// See also [ProfileNotifier].
@ProviderFor(ProfileNotifier)
final profileNotifierProvider =
    NotifierProvider<ProfileNotifier, AsyncValue<UserProfilesTableData?>>.internal(
  ProfileNotifier.new,
  name: r'profileNotifierProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$profileNotifierHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ProfileNotifier = Notifier<AsyncValue<UserProfilesTableData?>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
