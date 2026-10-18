import 'dart:async';
import 'dart:convert';

/// One Server-Sent Event: `event:` (default "message"), the joined `data:`
/// lines and the optional `id:`.
class SseEvent {
  const SseEvent({this.event = 'message', this.data = '', this.id});

  final String event;
  final String data;
  final String? id;

  @override
  String toString() => 'SseEvent($event, $data)';
}

/// Incremental `text/event-stream` parser (WHATWG rules).
///
/// Feed it bytes or text in any chunk sizes: lines may end with `\n`,
/// `\r\n` or `\r` (also split across chunks), several `data:` lines join with
/// `\n`, a blank line dispatches the event, and lines starting with `:` are
/// comments (the server's `: ping` keep-alive).
class SseParser {
  SseParser({required this.onEvent, this.onComment});

  final void Function(SseEvent event) onEvent;
  final void Function(String comment)? onComment;

  final _line = StringBuffer();
  final _data = StringBuffer();
  String _event = '';
  String? _id;
  String? _lastId;
  bool _hasData = false;
  bool _skipLf = false;

  late final ByteConversionSink _bytes = utf8.decoder.startChunkedConversion(
    _TextSink(addText),
  );

  /// The last `id:` seen (sent as `Last-Event-ID` by browsers; kept for
  /// completeness).
  String? get lastEventId => _lastId;

  void addBytes(List<int> chunk) => _bytes.add(chunk);

  void addText(String chunk) {
    var start = 0;
    for (var i = 0; i < chunk.length; i++) {
      final c = chunk.codeUnitAt(i);
      if (_skipLf) {
        _skipLf = false;
        if (c == 0x0A) {
          start = i + 1;
          continue;
        }
      }
      if (c == 0x0A || c == 0x0D) {
        _line.write(chunk.substring(start, i));
        _processLine(_line.toString());
        _line.clear();
        start = i + 1;
        if (c == 0x0D) _skipLf = true;
      }
    }
    if (start < chunk.length) _line.write(chunk.substring(start));
  }

  /// Forgets a half-received event (call when the connection is replaced).
  void reset() {
    _line.clear();
    _data.clear();
    _event = '';
    _id = null;
    _hasData = false;
    _skipLf = false;
  }

  void _processLine(String line) {
    if (line.isEmpty) {
      _dispatch();
      return;
    }
    if (line.startsWith(':')) {
      onComment?.call(line.substring(1).trimLeft());
      return;
    }
    final colon = line.indexOf(':');
    final field = colon < 0 ? line : line.substring(0, colon);
    var value = colon < 0 ? '' : line.substring(colon + 1);
    if (value.startsWith(' ')) value = value.substring(1);
    switch (field) {
      case 'event':
        _event = value;
      case 'data':
        if (_hasData) _data.write('\n');
        _data.write(value);
        _hasData = true;
      case 'id':
        if (!value.contains('\u0000')) _id = value;
      default:
      // `retry:` and unknown fields are ignored: the client has its own backoff.
    }
  }

  void _dispatch() {
    if (_id != null) _lastId = _id;
    if (_hasData) {
      onEvent(
        SseEvent(
          event: _event.isEmpty ? 'message' : _event,
          data: _data.toString(),
          id: _id ?? _lastId,
        ),
      );
    }
    _data.clear();
    _event = '';
    _id = null;
    _hasData = false;
  }
}

class _TextSink implements Sink<String> {
  _TextSink(this._add);

  final void Function(String) _add;

  @override
  void add(String data) => _add(data);

  @override
  void close() {}
}

/// Exponential reconnect delays: 1 s, 2 s, 4 s … up to 30 s.
class Backoff {
  Backoff({
    this.initial = const Duration(seconds: 1),
    this.max = const Duration(seconds: 30),
  });

  final Duration initial;
  final Duration max;
  int _attempt = 0;

  /// Failed attempts since the last [reset].
  int get attempt => _attempt;

  Duration next() {
    final ms = initial.inMilliseconds * (1 << _attempt.clamp(0, 20));
    _attempt++;
    return ms >= max.inMilliseconds ? max : Duration(milliseconds: ms);
  }

  void reset() => _attempt = 0;
}

/// An open event stream: its bytes and how to close it.
class SseStream {
  const SseStream(this.bytes, this.close);

  final Stream<List<int>> bytes;
  final void Function() close;
}

enum SseStatus { idle, connecting, connected, waiting }

typedef SseOpen = Future<SseStream> Function();
typedef SseSchedule = Timer Function(Duration delay, void Function() run);

Timer _defaultSchedule(Duration d, void Function() run) => Timer(d, run);

/// Keeps one event stream open: connects, parses, and reconnects with
/// [Backoff] when the stream fails or ends. A stream that stays silent for
/// [idleTimeout] (the server pings every 25 s) counts as dead.
class SseConnection {
  SseConnection({
    required this.open,
    required this.onEvent,
    this.onConnected,
    this.onStatus,
    Backoff? backoff,
    SseSchedule? schedule,
    this.idleTimeout = const Duration(seconds: 75),
  }) : backoff = backoff ?? Backoff(),
       _schedule = schedule ?? _defaultSchedule;

  final SseOpen open;
  final void Function(SseEvent event) onEvent;

  /// The stream is open (first connect and every reconnect): refetch state,
  /// events sent while offline are not replayed.
  final void Function()? onConnected;
  final void Function(SseStatus status)? onStatus;
  final Backoff backoff;
  final Duration idleTimeout;
  final SseSchedule _schedule;

  SseStatus _status = SseStatus.idle;
  bool _running = false;
  int _generation = 0;
  Timer? _retry;
  Timer? _watchdog;
  SseStream? _stream;
  StreamSubscription<List<int>>? _sub;

  SseStatus get status => _status;
  bool get running => _running;

  /// Delay of the reconnect that is waiting, if any.
  Duration? nextDelay;

  void start() {
    if (_running) return;
    _running = true;
    unawaited(_connect());
  }

  void stop() {
    _running = false;
    _generation++;
    _teardown();
    _retry?.cancel();
    _retry = null;
    nextDelay = null;
    _setStatus(SseStatus.idle);
  }

  /// Connects right away (app resumed, network back), unless the stream is
  /// already open. [force] also replaces an open stream (new server).
  void reconnectNow({bool force = false}) {
    if (!_running) return;
    if (!force &&
        (_status == SseStatus.connected || _status == SseStatus.connecting)) {
      return;
    }
    _retry?.cancel();
    _retry = null;
    backoff.reset();
    _generation++;
    _teardown();
    unawaited(_connect());
  }

  Future<void> _connect() async {
    final gen = ++_generation;
    nextDelay = null;
    _setStatus(SseStatus.connecting);
    final SseStream stream;
    try {
      stream = await open();
    } catch (_) {
      if (gen == _generation && _running) _scheduleRetry();
      return;
    }
    if (gen != _generation || !_running) {
      stream.close();
      return;
    }
    _stream = stream;
    final parser = SseParser(
      onEvent: (e) {
        if (gen != _generation) return;
        backoff.reset();
        onEvent(e);
      },
      onComment: (_) {
        if (gen == _generation) backoff.reset();
      },
    );
    void ended() {
      if (gen != _generation || !_running) return;
      _teardown();
      _scheduleRetry();
    }

    _sub = stream.bytes.listen(
      (chunk) {
        if (gen != _generation) return;
        _kickWatchdog(gen);
        parser.addBytes(chunk);
      },
      onError: (Object _) => ended(),
      onDone: ended,
      cancelOnError: true,
    );
    _kickWatchdog(gen);
    _setStatus(SseStatus.connected);
    onConnected?.call();
  }

  void _kickWatchdog(int gen) {
    _watchdog?.cancel();
    _watchdog = _schedule(idleTimeout, () {
      if (gen != _generation || !_running) return;
      _generation++;
      _teardown();
      _scheduleRetry();
    });
  }

  void _scheduleRetry() {
    if (!_running) return;
    final delay = backoff.next();
    nextDelay = delay;
    _setStatus(SseStatus.waiting);
    _retry?.cancel();
    _retry = _schedule(delay, () {
      _retry = null;
      if (_running) unawaited(_connect());
    });
  }

  void _teardown() {
    _watchdog?.cancel();
    _watchdog = null;
    unawaited(_sub?.cancel());
    _sub = null;
    final s = _stream;
    _stream = null;
    if (s != null) {
      try {
        s.close();
      } catch (_) {}
    }
  }

  void _setStatus(SseStatus s) {
    if (_status == s) return;
    _status = s;
    onStatus?.call(s);
  }
}
