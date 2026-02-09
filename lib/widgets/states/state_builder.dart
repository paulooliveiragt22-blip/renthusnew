import 'package:flutter/material.dart';
import 'loading_widget.dart';
import 'error_widget.dart';
import 'empty_widget.dart';

/// Helper para gerenciar estados de Loading/Error/Empty/Success
///
/// Uso:
/// ```dart
/// StateBuilder<List<Job>>(
///   future: jobRepository.getJobs(),
///   builder: (context, jobs) {
///     return ListView.builder(
///       itemCount: jobs.length,
///       itemBuilder: (context, index) => JobCard(jobs[index]),
///     );
///   },
///   emptyWidget: EmptyWidget.jobs(),
/// )
/// ```
class StateBuilder<T> extends StatelessWidget {
  final Future<T> future;
  final Widget Function(BuildContext context, T data) builder;
  final Widget? loadingWidget;
  final Widget? errorWidget;
  final Widget? emptyWidget;
  final bool Function(T data)? isEmpty;

  const StateBuilder({
    Key? key,
    required this.future,
    required this.builder,
    this.loadingWidget,
    this.errorWidget,
    this.emptyWidget,
    this.isEmpty,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snapshot) {
        // Loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return loadingWidget ?? LoadingWidget.fullScreen();
        }

        // Error
        if (snapshot.hasError) {
          return errorWidget ??
              ErrorStateWidget.generic(
                message: snapshot.error.toString(),
                onRetry: () {
                  // Trigger rebuild
                  (context as Element).markNeedsBuild();
                },
              );
        }

        // Success but no data
        if (!snapshot.hasData) {
          return emptyWidget ??
              EmptyWidget.generic(
                title: 'Sem dados',
                message: 'Não há dados disponíveis no momento.',
              );
        }

        final data = snapshot.data!;

        // Check if empty (for lists)
        if (isEmpty != null && isEmpty!(data)) {
          return emptyWidget ??
              EmptyWidget.generic(
                title: 'Lista vazia',
                message: 'Não há itens para exibir.',
              );
        }

        // Success with data
        return builder(context, data);
      },
    );
  }
}

/// Stream version
class StreamStateBuilder<T> extends StatelessWidget {
  final Stream<T> stream;
  final Widget Function(BuildContext context, T data) builder;
  final Widget? loadingWidget;
  final Widget? errorWidget;
  final Widget? emptyWidget;
  final bool Function(T data)? isEmpty;

  const StreamStateBuilder({
    Key? key,
    required this.stream,
    required this.builder,
    this.loadingWidget,
    this.errorWidget,
    this.emptyWidget,
    this.isEmpty,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<T>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return loadingWidget ?? LoadingWidget.fullScreen();
        }

        if (snapshot.hasError) {
          return errorWidget ??
              ErrorStateWidget.generic(
                message: snapshot.error.toString(),
              );
        }

        if (!snapshot.hasData) {
          return emptyWidget ??
              EmptyWidget.generic(
                title: 'Sem dados',
                message: 'Aguardando dados...',
              );
        }

        final data = snapshot.data!;

        if (isEmpty != null && isEmpty!(data)) {
          return emptyWidget ??
              EmptyWidget.generic(
                title: 'Lista vazia',
                message: 'Não há itens para exibir.',
              );
        }

        return builder(context, data);
      },
    );
  }
}

/// Wrapper simples para estados
class AsyncState<T> {
  final bool isLoading;
  final T? data;
  final Object? error;

  const AsyncState({
    this.isLoading = false,
    this.data,
    this.error,
  });

  const AsyncState.loading() : this(isLoading: true);
  const AsyncState.success(T data) : this(data: data);
  const AsyncState.error(Object error) : this(error: error);

  bool get hasData => data != null;
  bool get hasError => error != null;
}

/// Builder para AsyncState
class AsyncStateBuilder<T> extends StatelessWidget {
  final AsyncState<T> state;
  final Widget Function(BuildContext context, T data) builder;
  final Widget? loadingWidget;
  final Widget? errorWidget;
  final Widget? emptyWidget;

  const AsyncStateBuilder({
    Key? key,
    required this.state,
    required this.builder,
    this.loadingWidget,
    this.errorWidget,
    this.emptyWidget,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (state.isLoading) {
      return loadingWidget ?? LoadingWidget.fullScreen();
    }

    if (state.hasError) {
      return errorWidget ??
          ErrorStateWidget.generic(
            message: state.error.toString(),
          );
    }

    if (!state.hasData) {
      return emptyWidget ??
          EmptyWidget.generic(
            title: 'Sem dados',
            message: 'Não há dados disponíveis.',
          );
    }

    return builder(context, state.data as T);
  }
}

/// Extension para facilitar uso com Future
extension FutureStateExtension<T> on Future<T> {
  Widget toStateWidget({
    required Widget Function(BuildContext context, T data) builder,
    Widget? loadingWidget,
    Widget? errorWidget,
    Widget? emptyWidget,
  }) {
    return StateBuilder<T>(
      future: this,
      builder: builder,
      loadingWidget: loadingWidget,
      errorWidget: errorWidget,
      emptyWidget: emptyWidget,
    );
  }
}

/// Extension para facilitar uso com Stream
extension StreamStateExtension<T> on Stream<T> {
  Widget toStateWidget({
    required Widget Function(BuildContext context, T data) builder,
    Widget? loadingWidget,
    Widget? errorWidget,
    Widget? emptyWidget,
  }) {
    return StreamStateBuilder<T>(
      stream: this,
      builder: builder,
      loadingWidget: loadingWidget,
      errorWidget: errorWidget,
      emptyWidget: emptyWidget,
    );
  }
}
