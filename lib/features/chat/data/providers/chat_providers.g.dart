// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$chatRepositoryHash() => r'14157770a2cc5ed04c669b4a6ff970d26abcc9c0';

/// See also [chatRepository].
@ProviderFor(chatRepository)
final chatRepositoryProvider = AutoDisposeProvider<ChatRepository>.internal(
  chatRepository,
  name: r'chatRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$chatRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ChatRepositoryRef = AutoDisposeProviderRef<ChatRepository>;
String _$conversationsListHash() => r'3f579837c9867b4b3d7d47b0ebd4fff7aea5c814';

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

/// See also [conversationsList].
@ProviderFor(conversationsList)
const conversationsListProvider = ConversationsListFamily();

/// See also [conversationsList].
class ConversationsListFamily extends Family<AsyncValue<List<Conversation>>> {
  /// See also [conversationsList].
  const ConversationsListFamily();

  /// See also [conversationsList].
  ConversationsListProvider call(
    String userId,
  ) {
    return ConversationsListProvider(
      userId,
    );
  }

  @override
  ConversationsListProvider getProviderOverride(
    covariant ConversationsListProvider provider,
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
  String? get name => r'conversationsListProvider';
}

/// See also [conversationsList].
class ConversationsListProvider
    extends AutoDisposeFutureProvider<List<Conversation>> {
  /// See also [conversationsList].
  ConversationsListProvider(
    String userId,
  ) : this._internal(
          (ref) => conversationsList(
            ref as ConversationsListRef,
            userId,
          ),
          from: conversationsListProvider,
          name: r'conversationsListProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$conversationsListHash,
          dependencies: ConversationsListFamily._dependencies,
          allTransitiveDependencies:
              ConversationsListFamily._allTransitiveDependencies,
          userId: userId,
        );

  ConversationsListProvider._internal(
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
    FutureOr<List<Conversation>> Function(ConversationsListRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ConversationsListProvider._internal(
        (ref) => create(ref as ConversationsListRef),
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
  AutoDisposeFutureProviderElement<List<Conversation>> createElement() {
    return _ConversationsListProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ConversationsListProvider && other.userId == userId;
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
mixin ConversationsListRef on AutoDisposeFutureProviderRef<List<Conversation>> {
  /// The parameter `userId` of this provider.
  String get userId;
}

class _ConversationsListProviderElement
    extends AutoDisposeFutureProviderElement<List<Conversation>>
    with ConversationsListRef {
  _ConversationsListProviderElement(super.provider);

  @override
  String get userId => (origin as ConversationsListProvider).userId;
}

String _$conversationsStreamHash() =>
    r'4a25198d1b1b7ef629d2d0f7a423ee4e925845eb';

/// See also [conversationsStream].
@ProviderFor(conversationsStream)
const conversationsStreamProvider = ConversationsStreamFamily();

/// See also [conversationsStream].
class ConversationsStreamFamily extends Family<AsyncValue<List<Conversation>>> {
  /// See also [conversationsStream].
  const ConversationsStreamFamily();

  /// See also [conversationsStream].
  ConversationsStreamProvider call(
    String userId,
  ) {
    return ConversationsStreamProvider(
      userId,
    );
  }

  @override
  ConversationsStreamProvider getProviderOverride(
    covariant ConversationsStreamProvider provider,
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
  String? get name => r'conversationsStreamProvider';
}

/// See also [conversationsStream].
class ConversationsStreamProvider
    extends AutoDisposeStreamProvider<List<Conversation>> {
  /// See also [conversationsStream].
  ConversationsStreamProvider(
    String userId,
  ) : this._internal(
          (ref) => conversationsStream(
            ref as ConversationsStreamRef,
            userId,
          ),
          from: conversationsStreamProvider,
          name: r'conversationsStreamProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$conversationsStreamHash,
          dependencies: ConversationsStreamFamily._dependencies,
          allTransitiveDependencies:
              ConversationsStreamFamily._allTransitiveDependencies,
          userId: userId,
        );

  ConversationsStreamProvider._internal(
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
    Stream<List<Conversation>> Function(ConversationsStreamRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ConversationsStreamProvider._internal(
        (ref) => create(ref as ConversationsStreamRef),
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
  AutoDisposeStreamProviderElement<List<Conversation>> createElement() {
    return _ConversationsStreamProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ConversationsStreamProvider && other.userId == userId;
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
mixin ConversationsStreamRef
    on AutoDisposeStreamProviderRef<List<Conversation>> {
  /// The parameter `userId` of this provider.
  String get userId;
}

class _ConversationsStreamProviderElement
    extends AutoDisposeStreamProviderElement<List<Conversation>>
    with ConversationsStreamRef {
  _ConversationsStreamProviderElement(super.provider);

  @override
  String get userId => (origin as ConversationsStreamProvider).userId;
}

String _$messagesListHash() => r'd2824865eb1e196befe52490fa34ee679675fcec';

/// See also [messagesList].
@ProviderFor(messagesList)
const messagesListProvider = MessagesListFamily();

/// See also [messagesList].
class MessagesListFamily extends Family<AsyncValue<List<Message>>> {
  /// See also [messagesList].
  const MessagesListFamily();

  /// See also [messagesList].
  MessagesListProvider call(
    String conversationId,
  ) {
    return MessagesListProvider(
      conversationId,
    );
  }

  @override
  MessagesListProvider getProviderOverride(
    covariant MessagesListProvider provider,
  ) {
    return call(
      provider.conversationId,
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
  String? get name => r'messagesListProvider';
}

/// See also [messagesList].
class MessagesListProvider extends AutoDisposeFutureProvider<List<Message>> {
  /// See also [messagesList].
  MessagesListProvider(
    String conversationId,
  ) : this._internal(
          (ref) => messagesList(
            ref as MessagesListRef,
            conversationId,
          ),
          from: messagesListProvider,
          name: r'messagesListProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$messagesListHash,
          dependencies: MessagesListFamily._dependencies,
          allTransitiveDependencies:
              MessagesListFamily._allTransitiveDependencies,
          conversationId: conversationId,
        );

  MessagesListProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.conversationId,
  }) : super.internal();

  final String conversationId;

  @override
  Override overrideWith(
    FutureOr<List<Message>> Function(MessagesListRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: MessagesListProvider._internal(
        (ref) => create(ref as MessagesListRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        conversationId: conversationId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<Message>> createElement() {
    return _MessagesListProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is MessagesListProvider &&
        other.conversationId == conversationId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, conversationId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin MessagesListRef on AutoDisposeFutureProviderRef<List<Message>> {
  /// The parameter `conversationId` of this provider.
  String get conversationId;
}

class _MessagesListProviderElement
    extends AutoDisposeFutureProviderElement<List<Message>>
    with MessagesListRef {
  _MessagesListProviderElement(super.provider);

  @override
  String get conversationId => (origin as MessagesListProvider).conversationId;
}

String _$messagesStreamHash() => r'37fb77a1fb29f5b67a58685c21187c17e368c7de';

/// See also [messagesStream].
@ProviderFor(messagesStream)
const messagesStreamProvider = MessagesStreamFamily();

/// See also [messagesStream].
class MessagesStreamFamily extends Family<AsyncValue<List<Message>>> {
  /// See also [messagesStream].
  const MessagesStreamFamily();

  /// See also [messagesStream].
  MessagesStreamProvider call(
    String conversationId,
  ) {
    return MessagesStreamProvider(
      conversationId,
    );
  }

  @override
  MessagesStreamProvider getProviderOverride(
    covariant MessagesStreamProvider provider,
  ) {
    return call(
      provider.conversationId,
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
  String? get name => r'messagesStreamProvider';
}

/// See also [messagesStream].
class MessagesStreamProvider extends AutoDisposeStreamProvider<List<Message>> {
  /// See also [messagesStream].
  MessagesStreamProvider(
    String conversationId,
  ) : this._internal(
          (ref) => messagesStream(
            ref as MessagesStreamRef,
            conversationId,
          ),
          from: messagesStreamProvider,
          name: r'messagesStreamProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$messagesStreamHash,
          dependencies: MessagesStreamFamily._dependencies,
          allTransitiveDependencies:
              MessagesStreamFamily._allTransitiveDependencies,
          conversationId: conversationId,
        );

  MessagesStreamProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.conversationId,
  }) : super.internal();

  final String conversationId;

  @override
  Override overrideWith(
    Stream<List<Message>> Function(MessagesStreamRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: MessagesStreamProvider._internal(
        (ref) => create(ref as MessagesStreamRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        conversationId: conversationId,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<List<Message>> createElement() {
    return _MessagesStreamProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is MessagesStreamProvider &&
        other.conversationId == conversationId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, conversationId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin MessagesStreamRef on AutoDisposeStreamProviderRef<List<Message>> {
  /// The parameter `conversationId` of this provider.
  String get conversationId;
}

class _MessagesStreamProviderElement
    extends AutoDisposeStreamProviderElement<List<Message>>
    with MessagesStreamRef {
  _MessagesStreamProviderElement(super.provider);

  @override
  String get conversationId =>
      (origin as MessagesStreamProvider).conversationId;
}

String _$unreadMessagesCountHash() =>
    r'230c465580fb03945b8b8a742654aa009ed12f23';

/// See also [unreadMessagesCount].
@ProviderFor(unreadMessagesCount)
const unreadMessagesCountProvider = UnreadMessagesCountFamily();

/// See also [unreadMessagesCount].
class UnreadMessagesCountFamily extends Family<AsyncValue<int>> {
  /// See also [unreadMessagesCount].
  const UnreadMessagesCountFamily();

  /// See also [unreadMessagesCount].
  UnreadMessagesCountProvider call(
    String userId,
  ) {
    return UnreadMessagesCountProvider(
      userId,
    );
  }

  @override
  UnreadMessagesCountProvider getProviderOverride(
    covariant UnreadMessagesCountProvider provider,
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
  String? get name => r'unreadMessagesCountProvider';
}

/// See also [unreadMessagesCount].
class UnreadMessagesCountProvider extends AutoDisposeFutureProvider<int> {
  /// See also [unreadMessagesCount].
  UnreadMessagesCountProvider(
    String userId,
  ) : this._internal(
          (ref) => unreadMessagesCount(
            ref as UnreadMessagesCountRef,
            userId,
          ),
          from: unreadMessagesCountProvider,
          name: r'unreadMessagesCountProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$unreadMessagesCountHash,
          dependencies: UnreadMessagesCountFamily._dependencies,
          allTransitiveDependencies:
              UnreadMessagesCountFamily._allTransitiveDependencies,
          userId: userId,
        );

  UnreadMessagesCountProvider._internal(
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
    FutureOr<int> Function(UnreadMessagesCountRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: UnreadMessagesCountProvider._internal(
        (ref) => create(ref as UnreadMessagesCountRef),
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
    return _UnreadMessagesCountProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is UnreadMessagesCountProvider && other.userId == userId;
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
mixin UnreadMessagesCountRef on AutoDisposeFutureProviderRef<int> {
  /// The parameter `userId` of this provider.
  String get userId;
}

class _UnreadMessagesCountProviderElement
    extends AutoDisposeFutureProviderElement<int> with UnreadMessagesCountRef {
  _UnreadMessagesCountProviderElement(super.provider);

  @override
  String get userId => (origin as UnreadMessagesCountProvider).userId;
}

String _$chatActionsHash() => r'30dfcd1486426b3e3b592e0ce489333b8e132140';

/// See also [ChatActions].
@ProviderFor(ChatActions)
final chatActionsProvider =
    AutoDisposeAsyncNotifierProvider<ChatActions, void>.internal(
  ChatActions.new,
  name: r'chatActionsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$chatActionsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$ChatActions = AutoDisposeAsyncNotifier<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
