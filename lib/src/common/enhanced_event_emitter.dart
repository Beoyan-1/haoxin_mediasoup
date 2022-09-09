
import 'dart:async';

import 'package:events2/events2.dart';
import 'package:haoxin_mediasoup/src/common/logger.dart';

Logger _logger = Logger('EnhancedEventEmitter');

class EnhancedEventEmitter extends EventEmitter {
  EnhancedEventEmitter() : super();
  void safeEmit(String event, [Map<String, dynamic>? args]) {
    try {
      emit(event, args);
    } catch (error) {
      _logger.error(
        'safeEmit() event listener threw an error [event:$event]:$error',
      );
    }
  }

  Future<dynamic> safeEmitAsFuture(String event,
      [Map<String, dynamic>? args]) async {
    try {
      final Completer<dynamic> completer = Completer<dynamic>();
      Map<String, dynamic> cargs = {
        'callback': completer.complete,
        'errback': completer.completeError,
        ...?args,
      };
      emitAsFuture(event, cargs);
      return completer.future;
    } catch (error) {
      _logger.error(
        'safeEmitAsFuture() event listener threw an error [event:$event]:$error',
      );
    }
  }
}
