import 'package:flutter/material.dart';

/// Widget de Loading State
///
/// Uso:
/// ```dart
/// LoadingWidget()
/// LoadingWidget.small()
/// LoadingWidget.fullScreen()
/// LoadingWidget.overlay(message: 'Carregando...')
/// ```
class LoadingWidget extends StatelessWidget {

  const LoadingWidget({
    super.key,
    this.message,
    this.size,
    this.fullScreen = false,
  });

  /// Loading pequeno (para cards, botões)
  const LoadingWidget.small({
    super.key,
    this.message,
  })  : size = 20,
        fullScreen = false;

  /// Loading fullscreen (tela inteira)
  const LoadingWidget.fullScreen({
    super.key,
    this.message = 'Carregando...',
  })  : size = 40,
        fullScreen = true;

  /// Loading overlay (por cima de conteúdo)
  const LoadingWidget.overlay({
    super.key,
    this.message = 'Processando...',
  })  : size = 40,
        fullScreen = true;
  final String? message;
  final double? size;
  final bool fullScreen;

  @override
  Widget build(BuildContext context) {
    final loadingIndicator = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: size ?? 32,
          height: size ?? 32,
          child: CircularProgressIndicator(
            strokeWidth: (size ?? 32) / 8,
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).primaryColor,
            ),
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: 16),
          Text(
            message!,
            style: TextStyle(
              fontSize: fullScreen ? 16 : 14,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );

    if (fullScreen) {
      return ColoredBox(
        color: Colors.white,
        child: Center(child: loadingIndicator),
      );
    }

    return Center(child: loadingIndicator);
  }
}

/// Loading Shimmer (efeito de carregamento)
class LoadingShimmer extends StatefulWidget {

  const LoadingShimmer({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  /// Shimmer para Card
  const LoadingShimmer.card({
    super.key,
  })  : width = double.infinity,
        height = 120,
        borderRadius = const BorderRadius.all(Radius.circular(12));

  /// Shimmer para Avatar
  const LoadingShimmer.avatar({
    super.key,
    double size = 48,
  })  : width = size,
        height = size,
        borderRadius = const BorderRadius.all(Radius.circular(24));

  /// Shimmer para Texto
  const LoadingShimmer.text({
    super.key,
    double width = 200,
    double height = 16,
  })  : width = width,
        height = height,
        borderRadius = const BorderRadius.all(Radius.circular(4));
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  @override
  State<LoadingShimmer> createState() => _LoadingShimmerState();
}

class _LoadingShimmerState extends State<LoadingShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _animation = Tween<double>(begin: -1, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.grey[300]!,
                Colors.grey[100]!,
                Colors.grey[300]!,
              ],
              stops: [
                _animation.value - 0.3,
                _animation.value,
                _animation.value + 0.3,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Lista de Shimmer Cards (para listas)
class LoadingShimmerList extends StatelessWidget {

  const LoadingShimmerList({
    super.key,
    this.itemCount = 5,
    this.itemHeight = 120,
    this.padding = const EdgeInsets.all(16),
  });
  final int itemCount;
  final double itemHeight;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: padding,
      itemCount: itemCount,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return LoadingShimmer(
          width: double.infinity,
          height: itemHeight,
          borderRadius: BorderRadius.circular(12),
        );
      },
    );
  }
}

/// Loading Inline (para substituir texto)
class LoadingInline extends StatelessWidget {

  const LoadingInline({
    super.key,
    this.width = 100,
    this.height = 16,
  });
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return LoadingShimmer(
      width: width,
      height: height,
      borderRadius: BorderRadius.circular(4),
    );
  }
}
