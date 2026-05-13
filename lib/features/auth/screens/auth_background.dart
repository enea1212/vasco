import 'package:flutter/material.dart';
import 'package:vasco/core/constants/app_colors.dart';

class LimitedBouncingScrollPhysics extends BouncingScrollPhysics {
  const LimitedBouncingScrollPhysics({super.parent, this.maxOverscroll = 60.0});

  final double maxOverscroll;

  @override
  LimitedBouncingScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return LimitedBouncingScrollPhysics(
      parent: buildParent(ancestor),
      maxOverscroll: maxOverscroll,
    );
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    if (value < position.minScrollExtent - maxOverscroll) {
      return value - (position.minScrollExtent - maxOverscroll);
    }
    if (value > position.maxScrollExtent + maxOverscroll) {
      return value - (position.maxScrollExtent + maxOverscroll);
    }
    return 0.0;
  }
}

class AuthBackground extends StatelessWidget {
  const AuthBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07071A),
      body: Stack(
        children: [
          Positioned(
            top: -110,
            right: -110,
            child: _Glow(color: AppColors.primary, size: 340, opacity: 0.22),
          ),
          Positioned(
            bottom: -90,
            left: -90,
            child: _Glow(color: AppColors.purple, size: 300, opacity: 0.22),
          ),
          Positioned(
            top: MediaQuery.of(context).size.height * 0.45,
            right: -50,
            child: _Glow(color: AppColors.primary, size: 140, opacity: 0.14),
          ),
          SafeArea(child: child),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size, required this.opacity});
  final Color color;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: opacity),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}
