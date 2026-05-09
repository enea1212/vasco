import 'package:flutter/cupertino.dart' show RefreshIndicatorMode;
import 'package:flutter/material.dart';

/// Permite overscroll maxim de [maxOverscroll] px — necesar pentru
/// CupertinoSliverRefreshControl, dar fără tragere infinită.
class CappedBouncingScrollPhysics extends BouncingScrollPhysics {
  const CappedBouncingScrollPhysics({super.parent, this.maxOverscroll = 48.0});

  final double maxOverscroll;

  @override
  CappedBouncingScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return CappedBouncingScrollPhysics(
      parent: buildParent(ancestor),
      maxOverscroll: maxOverscroll,
    );
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    final delta = value - position.pixels;
    if (delta == 0) return 0;

    // Limitează overscroll-ul, dar nu returna niciodată o corecție mai mare
    // decât delta-ul curent. Flutter cere ca physics-ul să reducă mișcarea,
    // nu să o inverseze.
    if (value < position.minScrollExtent - maxOverscroll) {
      final overscroll = value - (position.minScrollExtent - maxOverscroll);
      return delta < 0 ? overscroll.clamp(delta, 0.0) : 0.0;
    }
    if (value > position.maxScrollExtent + maxOverscroll) {
      final overscroll = value - (position.maxScrollExtent + maxOverscroll);
      return delta > 0 ? overscroll.clamp(0.0, delta) : 0.0;
    }
    return super.applyBoundaryConditions(position, value);
  }
}

/// Elimină efectul de glow/stretch la overscroll pe Android.
class NoGlowScrollBehavior extends ScrollBehavior {
  const NoGlowScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

/// Spinner indigo care crește progresiv la pull, apoi se rotește la refresh.
Widget buildPullRefreshIndicator(
  BuildContext context,
  RefreshIndicatorMode refreshState,
  double pulledExtent,
  double refreshTriggerPullDistance,
  double refreshIndicatorExtent,
) {
  if (refreshState == RefreshIndicatorMode.inactive) {
    return const SizedBox.shrink();
  }
  return Center(
    child: SizedBox(
      width: 22,
      height: 22,
      child: CircularProgressIndicator(
        value: refreshState == RefreshIndicatorMode.drag
            ? (pulledExtent / refreshTriggerPullDistance).clamp(0.0, 1.0)
            : null,
        color: const Color(0xFF4F46E5),
        strokeWidth: 2.5,
      ),
    ),
  );
}
