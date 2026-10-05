import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/models.dart';

/// App-wide record of pin changes so every list shows fresh data without
/// refetching: edited pins replace the cached copy, deleted pins disappear,
/// and `created` lets feeds refresh after a new pin is published.
class PinUpdates {
  const PinUpdates({
    this.updated = const {},
    this.deleted = const {},
    this.created = 0,
  });

  final Map<int, Pin> updated;
  final Set<int> deleted;
  final int created;

  Pin resolve(Pin pin) => updated[pin.id] ?? pin;
}

class PinUpdatesNotifier extends Notifier<PinUpdates> {
  @override
  PinUpdates build() => const PinUpdates();

  void updated(Pin pin) => state = PinUpdates(
    updated: {...state.updated, pin.id: pin},
    deleted: state.deleted,
    created: state.created,
  );

  void deleted(int id) => state = PinUpdates(
    updated: state.updated,
    deleted: {...state.deleted, id},
    created: state.created,
  );

  void created(Pin pin) => state = PinUpdates(
    updated: {...state.updated, pin.id: pin},
    deleted: state.deleted,
    created: state.created + 1,
  );
}

final pinUpdatesProvider = NotifierProvider<PinUpdatesNotifier, PinUpdates>(
  PinUpdatesNotifier.new,
);

/// Bumped when the user's boards change (created, edited, deleted, pins saved).
class BoardsVersionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final boardsVersionProvider = NotifierProvider<BoardsVersionNotifier, int>(
  BoardsVersionNotifier.new,
);
