// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'isar_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$isarHash() => r'496e736b33bfa8667255783eb53b0cc680f99c7e';

/// Provider do Isar (banco de dados local)
///
/// Fornece acesso ao Isar para operações de cache local
///
/// Copied from [isar].
@ProviderFor(isar)
final isarProvider = FutureProvider<Isar>.internal(
  isar,
  name: r'isarProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$isarHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef IsarRef = FutureProviderRef<Isar>;
String _$cacheServiceHash() => r'570db9d8fe1b7764a30d49544b579b997f88fd84';

/// Provider de cache service
///
/// Serviço de alto nível para operações de cache
///
/// Copied from [cacheService].
@ProviderFor(cacheService)
final cacheServiceProvider = AutoDisposeProvider<CacheService>.internal(
  cacheService,
  name: r'cacheServiceProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$cacheServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CacheServiceRef = AutoDisposeProviderRef<CacheService>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
