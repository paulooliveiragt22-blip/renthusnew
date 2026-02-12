// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$notificationRepositoryHash() =>
    r'4afa91845a108a71b501d44133aa44b868d88aad';

/// See also [notificationRepository].
@ProviderFor(notificationRepository)
final notificationRepositoryProvider =
    AutoDisposeProvider<NotificationRepository>.internal(
  notificationRepository,
  name: r'notificationRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$notificationRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef NotificationRepositoryRef
    = AutoDisposeProviderRef<NotificationRepository>;
String _$notificationsListHash() => r'56b44cef3c37fd23bf23981d23ddefdfbd8220c5';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// See also [notificationsList].
@ProviderFor(notificationsList)
const notificationsListProvider = NotificationsListFamily();

/// See also [notificationsList].
class NotificationsListFamily
    extends Family<AsyncValue<List<AppNotification>>> {
  /// See also [notificationsList].
  const NotificationsListFamily();

  /// See also [notificationsList].
  NotificationsListProvider call(
    String userId,
  ) {
    return NotificationsListProvider(
      userId,
    );
  }

  @override
  NotificationsListProvider getProviderOverride(
    covariant NotificationsListProvider provider,
  ) {
    return call(
      provider.userId,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'notificationsListProvider';
}

/// See also [notificationsList].
class NotificationsListProvider
    extends AutoDisposeFutureProvider<List<AppNotification>> {
  /// See also [notificationsList].
  NotificationsListProvider(
    String userId,
  ) : this._internal(
          (ref) => notificationsList(
            ref as NotificationsListRef,
            userId,
          ),
          from: notificationsListProvider,
          name: r'notificationsListProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$notificationsListHash,
          dependencies: NotificationsListFamily._dependencies,
          allTransitiveDependencies:
              NotificationsListFamily._allTransitiveDependencies,
          userId: userId,
        );

  NotificationsListProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.userId,
  }) : super.internal();

  final String userId;

  @override
  Override overrideWith(
    FutureOr<List<AppNotification>> Function(NotificationsListRef provider)
        create,
  ) {
    return ProviderOverride(
      origin: this,
      override: NotificationsListProvider._internal(
        (ref) => create(ref as NotificationsListRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        userId: userId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<AppNotification>> createElement() {
    return _NotificationsListProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is NotificationsListProvider && other.userId == userId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, userId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin NotificationsListRef
    on AutoDisposeFutureProviderRef<List<AppNotification>> {
  /// The parameter `userId` of this provider.
  String get userId;
}

class _NotificationsListProviderElement
    extends AutoDisposeFutureProviderElement<List<AppNotification>>
    with NotificationsListRef {
  _NotificationsListProviderElement(super.provider);

  @override
  String get userId => (origin as NotificationsListProvider).userId;
}

String _$notificationsStreamHash() =>
    r'c4e8b9b86347ff2348120db2020ac1933c61974d';

/// See also [notificationsStream].
@ProviderFor(notificationsStream)
const notificationsStreamProvider = NotificationsStreamFamily();

/// See also [notificationsStream].
class NotificationsStreamFamily
    extends Family<AsyncValue<List<AppNotification>>> {
  /// See also [notificationsStream].
  const NotificationsStreamFamily();

  /// See also [notificationsStream].
  NotificationsStreamProvider call(
    String userId,
  ) {
    return NotificationsStreamProvider(
      userId,
    );
  }

  @override
  NotificationsStreamProvider getProviderOverride(
    covariant NotificationsStreamProvider provider,
  ) {
    return call(
      provider.userId,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'notificationsStreamProvider';
}

/// See also [notificationsStream].
class NotificationsStreamProvider
    extends AutoDisposeStreamProvider<List<AppNotification>> {
  /// See also [notificationsStream].
  NotificationsStreamProvider(
    String userId,
  ) : this._internal(
          (ref) => notificationsStream(
            ref as NotificationsStreamRef,
            userId,
          ),
          from: notificationsStreamProvider,
          name: r'notificationsStreamProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$notificationsStreamHash,
          dependencies: NotificationsStreamFamily._dependencies,
          allTransitiveDependencies:
              NotificationsStreamFamily._allTransitiveDependencies,
          userId: userId,
        );

  NotificationsStreamProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.userId,
  }) : super.internal();

  final String userId;

  @override
  Override overrideWith(
    Stream<List<AppNotification>> Function(NotificationsStreamRef provider)
        create,
  ) {
    return ProviderOverride(
      origin: this,
      override: NotificationsStreamProvider._internal(
        (ref) => create(ref as NotificationsStreamRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        userId: userId,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<List<AppNotification>> createElement() {
    return _NotificationsStreamProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is NotificationsStreamProvider && other.userId == userId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, userId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin NotificationsStreamRef
    on AutoDisposeStreamProviderRef<List<AppNotification>> {
  /// The parameter `userId` of this provider.
  String get userId;
}

class _NotificationsStreamProviderElement
    extends AutoDisposeStreamProviderElement<List<AppNotification>>
    with NotificationsStreamRef {
  _NotificationsStreamProviderElement(super.provider);

  @override
  String get userId => (origin as NotificationsStreamProvider).userId;
}

String _$unreadNotificationsCountHash() =>
    r'703587b2797e9a29088c710ad3e4ac6ad8ce93f3';

/// See also [unreadNotificationsCount].
@ProviderFor(unreadNotificationsCount)
const unreadNotificationsCountProvider = UnreadNotificationsCountFamily();

/// See also [unreadNotificationsCount].
class UnreadNotificationsCountFamily extends Family<AsyncValue<int>> {
  /// See also [unreadNotificationsCount].
  const UnreadNotificationsCountFamily();

  /// See also [unreadNotificationsCount].
  UnreadNotificationsCountProvider call(
    String userId,
  ) {
    return UnreadNotificationsCountProvider(
      userId,
    );
  }

  @override
  UnreadNotificationsCountProvider getProviderOverride(
    covariant UnreadNotificationsCountProvider provider,
  ) {
    return call(
      provider.userId,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'unreadNotificationsCountProvider';
}

/// See also [unreadNotificationsCount].
class UnreadNotificationsCountProvider extends AutoDisposeFutureProvider<int> {
  /// See also [unreadNotificationsCount].
  UnreadNotificationsCountProvider(
    String userId,
  ) : this._internal(
          (ref) => unreadNotificationsCount(
            ref as UnreadNotificationsCountRef,
            userId,
          ),
          from: unreadNotificationsCountProvider,
          name: r'unreadNotificationsCountProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$unreadNotificationsCountHash,
          dependencies: UnreadNotificationsCountFamily._dependencies,
          allTransitiveDependencies:
              UnreadNotificationsCountFamily._allTransitiveDependencies,
          userId: userId,
        );

  UnreadNotificationsCountProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.userId,
  }) : super.internal();

  final String userId;

  @override
  Override overrideWith(
    FutureOr<int> Function(UnreadNotificationsCountRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: UnreadNotificationsCountProvider._internal(
        (ref) => create(ref as UnreadNotificationsCountRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        userId: userId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<int> createElement() {
    return _UnreadNotificationsCountProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is UnreadNotificationsCountProvider && other.userId == userId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, userId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin UnreadNotificationsCountRef on AutoDisposeFutureProviderRef<int> {
  /// The parameter `userId` of this provider.
  String get userId;
}

class _UnreadNotificationsCountProviderElement
    extends AutoDisposeFutureProviderElement<int>
    with UnreadNotificationsCountRef {
  _UnreadNotificationsCountProviderElement(super.provider);

  @override
  String get userId => (origin as UnreadNotificationsCountProvider).userId;
}

String _$notificationActionsHash() =>
    r'768984817fb063f805e2a5a1c4382763646d2c34';

/// See also [NotificationActions].
@ProviderFor(NotificationActions)
final notificationActionsProvider =
    AutoDisposeAsyncNotifierProvider<NotificationActions, void>.internal(
  NotificationActions.new,
  name: r'notificationActionsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$notificationActionsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$NotificationActions = AutoDisposeAsyncNotifier<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
