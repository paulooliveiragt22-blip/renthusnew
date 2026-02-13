// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'job_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$legacyChatRepositoryHash() =>
    r'e5300670461baf83ee44a1377ff097e08a62adde';

/// Repositório legado de chat (upsertConversationForJob, etc.)
///
/// Copied from [legacyChatRepository].
@ProviderFor(legacyChatRepository)
final legacyChatRepositoryProvider =
    AutoDisposeProvider<LegacyChatRepository>.internal(
  legacyChatRepository,
  name: r'legacyChatRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$legacyChatRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef LegacyChatRepositoryRef = AutoDisposeProviderRef<LegacyChatRepository>;
String _$jobRepositoryHash() => r'5c56664b9f53f378b24c5d0bc871fd0e198b0f7f';

/// See also [jobRepository].
@ProviderFor(jobRepository)
final jobRepositoryProvider = AutoDisposeProvider<JobRepository>.internal(
  jobRepository,
  name: r'jobRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$jobRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef JobRepositoryRef = AutoDisposeProviderRef<JobRepository>;
String _$appJobRepositoryHash() => r'71b4468240eabe1cbec9f143cc118824af2b3973';

/// Repositório legado (views v_provider_jobs_*) para job_details do prestador
///
/// Copied from [appJobRepository].
@ProviderFor(appJobRepository)
final appJobRepositoryProvider = AutoDisposeProvider<AppJobRepository>.internal(
  appJobRepository,
  name: r'appJobRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$appJobRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AppJobRepositoryRef = AutoDisposeProviderRef<AppJobRepository>;
String _$providerJobByIdHash() => r'0b513ecf031df0bd0aa654d1bb35887507b62abb';

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

/// Job do prestador (accepted ou public) - Map para compatibilidade com JobBottomBar/JobValuesSection
///
/// Copied from [providerJobById].
@ProviderFor(providerJobById)
const providerJobByIdProvider = ProviderJobByIdFamily();

/// Job do prestador (accepted ou public) - Map para compatibilidade com JobBottomBar/JobValuesSection
///
/// Copied from [providerJobById].
class ProviderJobByIdFamily extends Family<AsyncValue<Map<String, dynamic>?>> {
  /// Job do prestador (accepted ou public) - Map para compatibilidade com JobBottomBar/JobValuesSection
  ///
  /// Copied from [providerJobById].
  const ProviderJobByIdFamily();

  /// Job do prestador (accepted ou public) - Map para compatibilidade com JobBottomBar/JobValuesSection
  ///
  /// Copied from [providerJobById].
  ProviderJobByIdProvider call(
    String jobId,
  ) {
    return ProviderJobByIdProvider(
      jobId,
    );
  }

  @override
  ProviderJobByIdProvider getProviderOverride(
    covariant ProviderJobByIdProvider provider,
  ) {
    return call(
      provider.jobId,
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
  String? get name => r'providerJobByIdProvider';
}

/// Job do prestador (accepted ou public) - Map para compatibilidade com JobBottomBar/JobValuesSection
///
/// Copied from [providerJobById].
class ProviderJobByIdProvider
    extends AutoDisposeFutureProvider<Map<String, dynamic>?> {
  /// Job do prestador (accepted ou public) - Map para compatibilidade com JobBottomBar/JobValuesSection
  ///
  /// Copied from [providerJobById].
  ProviderJobByIdProvider(
    String jobId,
  ) : this._internal(
          (ref) => providerJobById(
            ref as ProviderJobByIdRef,
            jobId,
          ),
          from: providerJobByIdProvider,
          name: r'providerJobByIdProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$providerJobByIdHash,
          dependencies: ProviderJobByIdFamily._dependencies,
          allTransitiveDependencies:
              ProviderJobByIdFamily._allTransitiveDependencies,
          jobId: jobId,
        );

  ProviderJobByIdProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.jobId,
  }) : super.internal();

  final String jobId;

  @override
  Override overrideWith(
    FutureOr<Map<String, dynamic>?> Function(ProviderJobByIdRef provider)
        create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ProviderJobByIdProvider._internal(
        (ref) => create(ref as ProviderJobByIdRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        jobId: jobId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<Map<String, dynamic>?> createElement() {
    return _ProviderJobByIdProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ProviderJobByIdProvider && other.jobId == jobId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, jobId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ProviderJobByIdRef
    on AutoDisposeFutureProviderRef<Map<String, dynamic>?> {
  /// The parameter `jobId` of this provider.
  String get jobId;
}

class _ProviderJobByIdProviderElement
    extends AutoDisposeFutureProviderElement<Map<String, dynamic>?>
    with ProviderJobByIdRef {
  _ProviderJobByIdProviderElement(super.provider);

  @override
  String get jobId => (origin as ProviderJobByIdProvider).jobId;
}

String _$providerJobsPublicHash() =>
    r'3f889171c638279c921b803efd7198f347add9f5';

/// Lista de jobs públicos para home do prestador (v_provider_jobs_public)
///
/// Copied from [providerJobsPublic].
@ProviderFor(providerJobsPublic)
final providerJobsPublicProvider =
    AutoDisposeFutureProvider<List<Map<String, dynamic>>>.internal(
  providerJobsPublic,
  name: r'providerJobsPublicProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$providerJobsPublicHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ProviderJobsPublicRef
    = AutoDisposeFutureProviderRef<List<Map<String, dynamic>>>;
String _$providerMeHash() => r'd69c657551418c6cc73499d9a5fdfd8cc7074f04';

/// Dados do header do prestador (v_provider_me)
///
/// Copied from [providerMe].
@ProviderFor(providerMe)
final providerMeProvider =
    AutoDisposeFutureProvider<Map<String, dynamic>?>.internal(
  providerMe,
  name: r'providerMeProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$providerMeHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ProviderMeRef = AutoDisposeFutureProviderRef<Map<String, dynamic>?>;
String _$providerBannersHash() => r'4ce7af500a3dcdd0f15be539654b38c728d60a9b';

/// Banners ativos (partner_banners) com URLs resolvidas
///
/// Copied from [providerBanners].
@ProviderFor(providerBanners)
final providerBannersProvider =
    AutoDisposeFutureProvider<List<Map<String, dynamic>>>.internal(
  providerBanners,
  name: r'providerBannersProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$providerBannersHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ProviderBannersRef
    = AutoDisposeFutureProviderRef<List<Map<String, dynamic>>>;
String _$providerMyJobsHash() => r'89e17293811a810f54deaba5daca678b155f7060';

/// Jobs + disputas do prestador com filtro de período (v_provider_my_jobs + v_provider_disputes)
///
/// Copied from [providerMyJobs].
@ProviderFor(providerMyJobs)
const providerMyJobsProvider = ProviderMyJobsFamily();

/// Jobs + disputas do prestador com filtro de período (v_provider_my_jobs + v_provider_disputes)
///
/// Copied from [providerMyJobs].
class ProviderMyJobsFamily extends Family<AsyncValue<ProviderMyJobsResult>> {
  /// Jobs + disputas do prestador com filtro de período (v_provider_my_jobs + v_provider_disputes)
  ///
  /// Copied from [providerMyJobs].
  const ProviderMyJobsFamily();

  /// Jobs + disputas do prestador com filtro de período (v_provider_my_jobs + v_provider_disputes)
  ///
  /// Copied from [providerMyJobs].
  ProviderMyJobsProvider call(
    int selectedDays,
  ) {
    return ProviderMyJobsProvider(
      selectedDays,
    );
  }

  @override
  ProviderMyJobsProvider getProviderOverride(
    covariant ProviderMyJobsProvider provider,
  ) {
    return call(
      provider.selectedDays,
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
  String? get name => r'providerMyJobsProvider';
}

/// Jobs + disputas do prestador com filtro de período (v_provider_my_jobs + v_provider_disputes)
///
/// Copied from [providerMyJobs].
class ProviderMyJobsProvider
    extends AutoDisposeFutureProvider<ProviderMyJobsResult> {
  /// Jobs + disputas do prestador com filtro de período (v_provider_my_jobs + v_provider_disputes)
  ///
  /// Copied from [providerMyJobs].
  ProviderMyJobsProvider(
    int selectedDays,
  ) : this._internal(
          (ref) => providerMyJobs(
            ref as ProviderMyJobsRef,
            selectedDays,
          ),
          from: providerMyJobsProvider,
          name: r'providerMyJobsProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$providerMyJobsHash,
          dependencies: ProviderMyJobsFamily._dependencies,
          allTransitiveDependencies:
              ProviderMyJobsFamily._allTransitiveDependencies,
          selectedDays: selectedDays,
        );

  ProviderMyJobsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.selectedDays,
  }) : super.internal();

  final int selectedDays;

  @override
  Override overrideWith(
    FutureOr<ProviderMyJobsResult> Function(ProviderMyJobsRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ProviderMyJobsProvider._internal(
        (ref) => create(ref as ProviderMyJobsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        selectedDays: selectedDays,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<ProviderMyJobsResult> createElement() {
    return _ProviderMyJobsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ProviderMyJobsProvider &&
        other.selectedDays == selectedDays;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, selectedDays.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ProviderMyJobsRef on AutoDisposeFutureProviderRef<ProviderMyJobsResult> {
  /// The parameter `selectedDays` of this provider.
  int get selectedDays;
}

class _ProviderMyJobsProviderElement
    extends AutoDisposeFutureProviderElement<ProviderMyJobsResult>
    with ProviderMyJobsRef {
  _ProviderMyJobsProviderElement(super.provider);

  @override
  int get selectedDays => (origin as ProviderMyJobsProvider).selectedDays;
}

String _$clientMyJobsHash() => r'ec4d5dfb99e816354818dd3215804e518dad7adf';

/// Jobs do cliente (v_client_my_jobs_dashboard) com filtro de período
///
/// Copied from [clientMyJobs].
@ProviderFor(clientMyJobs)
const clientMyJobsProvider = ClientMyJobsFamily();

/// Jobs do cliente (v_client_my_jobs_dashboard) com filtro de período
///
/// Copied from [clientMyJobs].
class ClientMyJobsFamily extends Family<AsyncValue<ClientMyJobsResult>> {
  /// Jobs do cliente (v_client_my_jobs_dashboard) com filtro de período
  ///
  /// Copied from [clientMyJobs].
  const ClientMyJobsFamily();

  /// Jobs do cliente (v_client_my_jobs_dashboard) com filtro de período
  ///
  /// Copied from [clientMyJobs].
  ClientMyJobsProvider call(
    int selectedDays,
  ) {
    return ClientMyJobsProvider(
      selectedDays,
    );
  }

  @override
  ClientMyJobsProvider getProviderOverride(
    covariant ClientMyJobsProvider provider,
  ) {
    return call(
      provider.selectedDays,
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
  String? get name => r'clientMyJobsProvider';
}

/// Jobs do cliente (v_client_my_jobs_dashboard) com filtro de período
///
/// Copied from [clientMyJobs].
class ClientMyJobsProvider
    extends AutoDisposeFutureProvider<ClientMyJobsResult> {
  /// Jobs do cliente (v_client_my_jobs_dashboard) com filtro de período
  ///
  /// Copied from [clientMyJobs].
  ClientMyJobsProvider(
    int selectedDays,
  ) : this._internal(
          (ref) => clientMyJobs(
            ref as ClientMyJobsRef,
            selectedDays,
          ),
          from: clientMyJobsProvider,
          name: r'clientMyJobsProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$clientMyJobsHash,
          dependencies: ClientMyJobsFamily._dependencies,
          allTransitiveDependencies:
              ClientMyJobsFamily._allTransitiveDependencies,
          selectedDays: selectedDays,
        );

  ClientMyJobsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.selectedDays,
  }) : super.internal();

  final int selectedDays;

  @override
  Override overrideWith(
    FutureOr<ClientMyJobsResult> Function(ClientMyJobsRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ClientMyJobsProvider._internal(
        (ref) => create(ref as ClientMyJobsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        selectedDays: selectedDays,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<ClientMyJobsResult> createElement() {
    return _ClientMyJobsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ClientMyJobsProvider && other.selectedDays == selectedDays;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, selectedDays.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ClientMyJobsRef on AutoDisposeFutureProviderRef<ClientMyJobsResult> {
  /// The parameter `selectedDays` of this provider.
  int get selectedDays;
}

class _ClientMyJobsProviderElement
    extends AutoDisposeFutureProviderElement<ClientMyJobsResult>
    with ClientMyJobsRef {
  _ClientMyJobsProviderElement(super.provider);

  @override
  int get selectedDays => (origin as ClientMyJobsProvider).selectedDays;
}

String _$clientJobDetailsHash() => r'7861d715174b88afc98c6ed13c8bfe7ad27c446f';

/// Detalhes do job para o cliente (v_client_jobs + v_client_job_quotes + v_client_job_payments)
///
/// Copied from [clientJobDetails].
@ProviderFor(clientJobDetails)
const clientJobDetailsProvider = ClientJobDetailsFamily();

/// Detalhes do job para o cliente (v_client_jobs + v_client_job_quotes + v_client_job_payments)
///
/// Copied from [clientJobDetails].
class ClientJobDetailsFamily
    extends Family<AsyncValue<ClientJobDetailsResult>> {
  /// Detalhes do job para o cliente (v_client_jobs + v_client_job_quotes + v_client_job_payments)
  ///
  /// Copied from [clientJobDetails].
  const ClientJobDetailsFamily();

  /// Detalhes do job para o cliente (v_client_jobs + v_client_job_quotes + v_client_job_payments)
  ///
  /// Copied from [clientJobDetails].
  ClientJobDetailsProvider call(
    String jobId,
  ) {
    return ClientJobDetailsProvider(
      jobId,
    );
  }

  @override
  ClientJobDetailsProvider getProviderOverride(
    covariant ClientJobDetailsProvider provider,
  ) {
    return call(
      provider.jobId,
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
  String? get name => r'clientJobDetailsProvider';
}

/// Detalhes do job para o cliente (v_client_jobs + v_client_job_quotes + v_client_job_payments)
///
/// Copied from [clientJobDetails].
class ClientJobDetailsProvider
    extends AutoDisposeFutureProvider<ClientJobDetailsResult> {
  /// Detalhes do job para o cliente (v_client_jobs + v_client_job_quotes + v_client_job_payments)
  ///
  /// Copied from [clientJobDetails].
  ClientJobDetailsProvider(
    String jobId,
  ) : this._internal(
          (ref) => clientJobDetails(
            ref as ClientJobDetailsRef,
            jobId,
          ),
          from: clientJobDetailsProvider,
          name: r'clientJobDetailsProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$clientJobDetailsHash,
          dependencies: ClientJobDetailsFamily._dependencies,
          allTransitiveDependencies:
              ClientJobDetailsFamily._allTransitiveDependencies,
          jobId: jobId,
        );

  ClientJobDetailsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.jobId,
  }) : super.internal();

  final String jobId;

  @override
  Override overrideWith(
    FutureOr<ClientJobDetailsResult> Function(ClientJobDetailsRef provider)
        create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ClientJobDetailsProvider._internal(
        (ref) => create(ref as ClientJobDetailsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        jobId: jobId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<ClientJobDetailsResult> createElement() {
    return _ClientJobDetailsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ClientJobDetailsProvider && other.jobId == jobId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, jobId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ClientJobDetailsRef
    on AutoDisposeFutureProviderRef<ClientJobDetailsResult> {
  /// The parameter `jobId` of this provider.
  String get jobId;
}

class _ClientJobDetailsProviderElement
    extends AutoDisposeFutureProviderElement<ClientJobDetailsResult>
    with ClientJobDetailsRef {
  _ClientJobDetailsProviderElement(super.provider);

  @override
  String get jobId => (origin as ClientJobDetailsProvider).jobId;
}

String _$adminJobsHash() => r'f69cd0969fd7c40b2f2b32ba01c216300b97c78a';

/// Jobs para painel admin (tabela jobs, limit 500)
///
/// Copied from [adminJobs].
@ProviderFor(adminJobs)
final adminJobsProvider =
    AutoDisposeFutureProvider<List<Map<String, dynamic>>>.internal(
  adminJobs,
  name: r'adminJobsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$adminJobsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AdminJobsRef = AutoDisposeFutureProviderRef<List<Map<String, dynamic>>>;
String _$providerHomeUnreadCountHash() =>
    r'1478ccbf90e222a1cbbe473078eec676332fb2a4';

/// Contagem de notificações não lidas para a home do prestador (0 se não logado)
///
/// Copied from [providerHomeUnreadCount].
@ProviderFor(providerHomeUnreadCount)
final providerHomeUnreadCountProvider = AutoDisposeProvider<int>.internal(
  providerHomeUnreadCount,
  name: r'providerHomeUnreadCountProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$providerHomeUnreadCountHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ProviderHomeUnreadCountRef = AutoDisposeProviderRef<int>;
String _$jobsListHash() => r'48775a5ce243423d95b47e8cc6ae992b05762923';

/// See also [jobsList].
@ProviderFor(jobsList)
const jobsListProvider = JobsListFamily();

/// See also [jobsList].
class JobsListFamily extends Family<AsyncValue<List<Job>>> {
  /// See also [jobsList].
  const JobsListFamily();

  /// See also [jobsList].
  JobsListProvider call({
    String? city,
    String? status,
  }) {
    return JobsListProvider(
      city: city,
      status: status,
    );
  }

  @override
  JobsListProvider getProviderOverride(
    covariant JobsListProvider provider,
  ) {
    return call(
      city: provider.city,
      status: provider.status,
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
  String? get name => r'jobsListProvider';
}

/// See also [jobsList].
class JobsListProvider extends AutoDisposeFutureProvider<List<Job>> {
  /// See also [jobsList].
  JobsListProvider({
    String? city,
    String? status,
  }) : this._internal(
          (ref) => jobsList(
            ref as JobsListRef,
            city: city,
            status: status,
          ),
          from: jobsListProvider,
          name: r'jobsListProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$jobsListHash,
          dependencies: JobsListFamily._dependencies,
          allTransitiveDependencies: JobsListFamily._allTransitiveDependencies,
          city: city,
          status: status,
        );

  JobsListProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.city,
    required this.status,
  }) : super.internal();

  final String? city;
  final String? status;

  @override
  Override overrideWith(
    FutureOr<List<Job>> Function(JobsListRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: JobsListProvider._internal(
        (ref) => create(ref as JobsListRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        city: city,
        status: status,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<List<Job>> createElement() {
    return _JobsListProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is JobsListProvider &&
        other.city == city &&
        other.status == status;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, city.hashCode);
    hash = _SystemHash.combine(hash, status.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin JobsListRef on AutoDisposeFutureProviderRef<List<Job>> {
  /// The parameter `city` of this provider.
  String? get city;

  /// The parameter `status` of this provider.
  String? get status;
}

class _JobsListProviderElement
    extends AutoDisposeFutureProviderElement<List<Job>> with JobsListRef {
  _JobsListProviderElement(super.provider);

  @override
  String? get city => (origin as JobsListProvider).city;
  @override
  String? get status => (origin as JobsListProvider).status;
}

String _$jobByIdHash() => r'641c4e373f0c989ecda93d5f65d94b362987e367';

/// See also [jobById].
@ProviderFor(jobById)
const jobByIdProvider = JobByIdFamily();

/// See also [jobById].
class JobByIdFamily extends Family<AsyncValue<Job>> {
  /// See also [jobById].
  const JobByIdFamily();

  /// See also [jobById].
  JobByIdProvider call(
    String id,
  ) {
    return JobByIdProvider(
      id,
    );
  }

  @override
  JobByIdProvider getProviderOverride(
    covariant JobByIdProvider provider,
  ) {
    return call(
      provider.id,
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
  String? get name => r'jobByIdProvider';
}

/// See also [jobById].
class JobByIdProvider extends AutoDisposeFutureProvider<Job> {
  /// See also [jobById].
  JobByIdProvider(
    String id,
  ) : this._internal(
          (ref) => jobById(
            ref as JobByIdRef,
            id,
          ),
          from: jobByIdProvider,
          name: r'jobByIdProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$jobByIdHash,
          dependencies: JobByIdFamily._dependencies,
          allTransitiveDependencies: JobByIdFamily._allTransitiveDependencies,
          id: id,
        );

  JobByIdProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.id,
  }) : super.internal();

  final String id;

  @override
  Override overrideWith(
    FutureOr<Job> Function(JobByIdRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: JobByIdProvider._internal(
        (ref) => create(ref as JobByIdRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        id: id,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<Job> createElement() {
    return _JobByIdProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is JobByIdProvider && other.id == id;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, id.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin JobByIdRef on AutoDisposeFutureProviderRef<Job> {
  /// The parameter `id` of this provider.
  String get id;
}

class _JobByIdProviderElement extends AutoDisposeFutureProviderElement<Job>
    with JobByIdRef {
  _JobByIdProviderElement(super.provider);

  @override
  String get id => (origin as JobByIdProvider).id;
}

String _$jobsStreamHash() => r'21c0fb6de1090a59f503a75918a514f7bf57a340';

/// See also [jobsStream].
@ProviderFor(jobsStream)
const jobsStreamProvider = JobsStreamFamily();

/// See also [jobsStream].
class JobsStreamFamily extends Family<AsyncValue<List<Job>>> {
  /// See also [jobsStream].
  const JobsStreamFamily();

  /// See also [jobsStream].
  JobsStreamProvider call({
    String? city,
  }) {
    return JobsStreamProvider(
      city: city,
    );
  }

  @override
  JobsStreamProvider getProviderOverride(
    covariant JobsStreamProvider provider,
  ) {
    return call(
      city: provider.city,
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
  String? get name => r'jobsStreamProvider';
}

/// See also [jobsStream].
class JobsStreamProvider extends AutoDisposeStreamProvider<List<Job>> {
  /// See also [jobsStream].
  JobsStreamProvider({
    String? city,
  }) : this._internal(
          (ref) => jobsStream(
            ref as JobsStreamRef,
            city: city,
          ),
          from: jobsStreamProvider,
          name: r'jobsStreamProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$jobsStreamHash,
          dependencies: JobsStreamFamily._dependencies,
          allTransitiveDependencies:
              JobsStreamFamily._allTransitiveDependencies,
          city: city,
        );

  JobsStreamProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.city,
  }) : super.internal();

  final String? city;

  @override
  Override overrideWith(
    Stream<List<Job>> Function(JobsStreamRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: JobsStreamProvider._internal(
        (ref) => create(ref as JobsStreamRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        city: city,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<List<Job>> createElement() {
    return _JobsStreamProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is JobsStreamProvider && other.city == city;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, city.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin JobsStreamRef on AutoDisposeStreamProviderRef<List<Job>> {
  /// The parameter `city` of this provider.
  String? get city;
}

class _JobsStreamProviderElement
    extends AutoDisposeStreamProviderElement<List<Job>> with JobsStreamRef {
  _JobsStreamProviderElement(super.provider);

  @override
  String? get city => (origin as JobsStreamProvider).city;
}

String _$jobActionsHash() => r'539191534f680744cf358ebc60734040434461e1';

/// See also [JobActions].
@ProviderFor(JobActions)
final jobActionsProvider =
    AutoDisposeAsyncNotifierProvider<JobActions, void>.internal(
  JobActions.new,
  name: r'jobActionsProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$jobActionsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$JobActions = AutoDisposeAsyncNotifier<void>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
