import 'package:flutter/cupertino.dart';
import '../../core/utils/scroll_utils.dart';

class RefreshScrollView extends StatelessWidget {
  const RefreshScrollView({
    super.key,
    required this.onRefresh,
    required this.slivers,
  });

  final Future<void> Function() onRefresh;
  final List<Widget> slivers;

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: const NoGlowScrollBehavior(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: CappedBouncingScrollPhysics(maxOverscroll: 48),
        ),
        slivers: [
          CupertinoSliverRefreshControl(
            onRefresh: onRefresh,
            builder: buildPullRefreshIndicator,
          ),
          ...slivers,
        ],
      ),
    );
  }
}
