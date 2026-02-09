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
  final String? message;
  final double? size;
  final bool fullScreen;

  const LoadingWidget({
    Key? key,
    this.message,
    this.size,
    this.fullScreen = false,
  }) : super(key: key);

  /// Loading pequeno (para cards, botões)
  const LoadingWidget.small({
    Key? key,
    this.message,
  })  : size = 20,
        fullScreen = false,
        super(key: key);

  /// Loading fullscreen (tela inteira)
  const LoadingWidget.fullScreen({
    Key? key,
    this.message = 'Carregando...',
  })  : size = 40,
        fullScreen = true,
        super(key: key);

  /// Loading overlay (por cima de conteúdo)
  const LoadingWidget.overlay({
    Key? key,
    this.message = 'Processando...',
  })  : size = 40,
        fullScreen = true,
        super(key: key);

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
          SizedBox(height: 16),
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
      return Container(
        color: Colors.white,
        child: Center(child: loadingIndicator),
      );
    }

    return Center(child: loadingIndicator);
  }
}

/// Loading Shimmer (efeito de carregamento)
class LoadingShimmer extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const LoadingShimmer({
    Key? key,
    required this.width,
    required this.height,
    this.borderRadius,
  }) : super(key: key);

  /// Shimmer para Card
  const LoadingShimmer.card({
    Key? key,
  })  : width = double.infinity,
        height = 120,
        borderRadius = const BorderRadius.all(Radius.circular(12)),
        super(key: key);

  /// Shimmer para Avatar
  const LoadingShimmer.avatar({
    Key? key,
    double size = 48,
  })  : width = size,
        height = size,
        borderRadius = const BorderRadius.all(Radius.circular(24)),
        super(key: key);

  /// Shimmer para Texto
  const LoadingShimmer.text({
    Key? key,
    double width = 200,
    double height = 16,
  })  : this.width = width,
        this.height = height,
        borderRadius = const BorderRadius.all(Radius.circular(4)),
        super(key: key);

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
      duration: Duration(milliseconds: 1500),
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
  final int itemCount;
  final double itemHeight;
  final EdgeInsets padding;

  const LoadingShimmerList({
    Key? key,
    this.itemCount = 5,
    this.itemHeight = 120,
    this.padding = const EdgeInsets.all(16),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: padding,
      itemCount: itemCount,
      separatorBuilder: (context, index) => SizedBox(height: 12),
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
  final double width;
  final double height;

  const LoadingInline({
    Key? key,
    this.width = 100,
    this.height = 16,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LoadingShimmer(
      width: width,
      height: height,
      borderRadius: BorderRadius.circular(4),
    );
  }
}
