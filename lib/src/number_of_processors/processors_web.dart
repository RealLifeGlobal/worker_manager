import 'dart:math';
import 'package:web/web.dart' as web;

int get numberOfProcessors {
  final concurrency = web.window.navigator.hardwareConcurrency;
  return max(concurrency - 1, 1);
}
