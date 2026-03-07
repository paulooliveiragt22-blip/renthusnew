import 'package:logger/logger.dart';

/// Logger centralizado do app.
/// Use em vez de print() para logs com níveis e formatação.
final appLogger = Logger(
  printer: PrettyPrinter(
    methodCount: 0,
    errorMethodCount: 5,
    lineLength: 80,
    colors: true,
    printEmojis: true,
  ),
);
