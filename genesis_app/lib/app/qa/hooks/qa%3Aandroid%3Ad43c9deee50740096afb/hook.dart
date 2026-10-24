import 'package:flutter/material.dart';
import 'browse_gesture.dart';
import '../qa%253Aandroid%253A28713c7d903a049a3cd4/view.dart';
import '../qa%253Aandroid%253Ab52779ced20b49ce5378/resource.dart' show resource;

class BrowseObservation {
  BrowseObservation(this.attempt, this.before, this.after, this.succeeded);
  final String attempt;
  final double before, after;
  final bool succeeded;
}

final browsing = Expando<BrowseObservation>();
Future<Object?> invoke(
  Map<String, dynamic> p,
  bool prepared,
  bool started,
) async {
  validate(p, started, 'interact');
  final r = resource();
  await r.requireOwner();
  browsing[r] = null;
  final panel = eventsPanel();
  if (panel == null || visibleEvents().isEmpty)
    throw StateError('Rendered event panel required');
  final state = eventScrollable(visibleEvents().first);
  if (state == null || !state.position.hasContentDimensions) {
    throw StateError('Event scrolling unavailable');
  }
  final result = await browseByTouch(state);
  browsing[r] = BrowseObservation(
    r.attempt,
    result.from,
    result.to,
    result.succeeded,
  );
  return {
    'browsePerformed': result.succeeded,
    'scrollRequired': result.scrollRequired,
    'from': result.from,
    'to': result.to,
    'attempt': r.attempt,
  };
}

/// The event content owns the inner scroller; the outer event pager has
/// NeverScrollableScrollPhysics and is not the user's content drag target.
ScrollableState? eventScrollable(Element event) =>
    Scrollable.maybeOf(event, axis: Axis.vertical);
