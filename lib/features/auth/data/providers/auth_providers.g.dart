// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$authRepositoryHash() => r'6f0806bb07a6077bed24718f6185d5a096b7dd49';

/// Provider do AuthRepository
///
/// Copied from [authRepository].
@ProviderFor(authRepository)
final authRepositoryProvider = AutoDisposeProvider<AuthRepository>.internal(
  authRepository,
  name: r'authRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$authRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AuthRepositoryRef = AutoDisposeProviderRef<AuthRepository>;
String _$clientRepositoryHash() => r'de9afc80cd32653dad6ee969975b12bc6ef2146b';

/// Provider do ClientRepository
///
/// Copied from [clientRepository].
@ProviderFor(clientRepository)
final clientRepositoryProvider = AutoDisposeProvider<ClientRepository>.internal(
  clientRepository,
  name: r'clientRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$clientRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ClientRepositoryRef = AutoDisposeProviderRef<ClientRepository>;
String _$providerRepositoryHash() =>
    r'f554e31bde9127159a03c80d53e3bfa309ab7ed8';

/// Provider do ProviderRepository
///
/// Copied from [providerRepository].
@ProviderFor(providerRepository)
final providerRepositoryProvider =
    AutoDisposeProvider<ProviderRepository>.internal(
  providerRepository,
  name: r'providerRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$providerRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ProviderRepositoryRef = AutoDisposeProviderRef<ProviderRepository>;
String _$authActionsHash() => r'a3695f621d75ac7e1dd69bb8a93701ea745f9cea';

/// Provider de ações de autenticação (login, logout)
///
/// Copied from [AuthActions].
@ProviderFor(AuthActions)
final authActionsProvider =
    AutoDisposeAsyncNotifierProvider<AuthActions, LoginDestination?>.internal(
  AuthActions.new,
  name: r'authActionsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$authActionsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$AuthActions = AutoDisposeAsyncNotifier<LoginDestination?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
