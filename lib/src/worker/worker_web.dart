import 'dart:async';
import 'package:worker_manager/src/scheduling/task.dart';
import 'package:worker_manager/src/worker/worker.dart';

import '../../worker_manager.dart';

class WorkerImpl implements Worker {
  WorkerImpl();

  @override
  var initialized = false;

  @override
  String? taskId;

  void Function(Object value)? onMessage;

  @override
  Future<void> initialize() async {
    initialized = true;
  }

  @override
  Future<R> work<R>(Task<R> task) async {
    taskId = task.id;
    late var run = () async => task.execution();
    if (task is TaskWithPort) {
      onMessage = (task as TaskWithPort).onMessage;
    } else if (task is TaskGentle) {
      run = () async => await task.execution(() => task.canceled);
    }

    final resultValue = await run().whenComplete(() {
      _cleanUp();
    });
    return resultValue;
  }

  @override
  void cancelGentle() {
    _cleanUp();
  }

  @override
  void kill() {
    _cleanUp();
    initialized = false;
  }

  void _cleanUp() {
    onMessage = null;
    taskId = null;
  }

  @override
  bool get initializing => false;
}
