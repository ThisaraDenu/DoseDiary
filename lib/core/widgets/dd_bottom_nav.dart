import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';
import '../router/route_names.dart';

/// Navigation item definition for DdBottomNav.
class DdNavItem {
  const DdNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// Floating pill-shaped bottom navigation bar with a smooth sliding
/// active capsule animation, styled with DoseDiary's Crimson brand theme.
class DdBottomNav extends StatefulWidget {
  const DdBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.items = _defaultItems,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<DdNavItem> items;

  static const _defaultItems = [
    DdNavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Home',
    ),
    DdNavItem(
      icon: Icons.medication_outlined,
      activeIcon: Icons.medication_rounded,
      label: 'Medications',
    ),
    DdNavItem(
      icon: Icons.history_outlined,
      activeIcon: Icons.history_rounded,
      label: 'History',
    ),
    DdNavItem(
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings_rounded,
      label: 'Settings',
    ),
  ];

  @override
  State<DdBottomNav> createState() => _DdBottomNavState();
}

class _DdBottomNavState extends State<DdBottomNav>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;
  int _fromIndex = 0;
  int _toIndex = 0;

  @override
  void initState() {
    super.initState();
    _fromIndex = widget.currentIndex;
    _toIndex = widget.currentIndex;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );
    _controller.value = 1.0;
  }

  @override
  void didUpdateWidget(DdBottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _fromIndex = _toIndex;
      _toIndex = widget.currentIndex;
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _getItemCenter(
    int itemIndex,
    int activeIndex,
    double inactiveWidth,
    double activeWidth,
  ) {
    if (itemIndex < activeIndex) {
      return (itemIndex + 0.5) * inactiveWidth;
    } else if (itemIndex == activeIndex) {
      return activeIndex * inactiveWidth + (0.5 * activeWidth);
    } else {
      return activeIndex * inactiveWidth +
          activeWidth +
          (itemIndex - activeIndex - 0.5) * inactiveWidth;
    }
  }

  @override
  Widget build(BuildContext context) {
    const double barHeight = 64.0;
    const double horizontalPadding = 6.0;
    const double verticalPadding = 6.0;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 12.0),
        child: Container(
          height: barHeight,
          decoration: BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.circular(32.0),
            border: Border.all(
              color: AppColors.borderLight.withOpacity(0.9),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 18.0,
                offset: const Offset(0, 5),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 4.0,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double totalWidth = constraints.maxWidth;
              final double innerWidth = totalWidth - (horizontalPadding * 2);
              const double innerHeight = barHeight - (verticalPadding * 2);
              final int itemCount = widget.items.length;

              if (itemCount == 0 || innerWidth <= 0) {
                return const SizedBox.shrink();
              }

              // Compute dimensions: active pill takes ~36% of space, remainder split among inactive items.
              final double activeWidth =
                  (innerWidth * 0.36).clamp(112.0, 138.0);
              final double inactiveWidth = itemCount > 1
                  ? (innerWidth - activeWidth) / (itemCount - 1)
                  : innerWidth;

              return AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  final double t = _animation.value;

                  // Interpolate sliding capsule indicator position
                  final double fromLeft = _fromIndex * inactiveWidth;
                  final double toLeft = _toIndex * inactiveWidth;
                  final double currentCapsuleLeft =
                      ui.lerpDouble(fromLeft, toLeft, t)!;

                  // Determine which content to show in the sliding capsule
                  final bool showTargetInPill = t >= 0.5;
                  final int pillContentIndex =
                      showTargetInPill ? _toIndex : _fromIndex;
                  final DdNavItem activeItem =
                      widget.items[pillContentIndex.clamp(0, itemCount - 1)];

                  // Active capsule text/icon crossfade opacity
                  final double pillContentOpacity = showTargetInPill
                      ? ((t - 0.5) * 2.0).clamp(0.0, 1.0)
                      : (1.0 - (t * 2.0)).clamp(0.0, 1.0);

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // 1. Sliding active capsule indicator
                      Positioned(
                        left: horizontalPadding + currentCapsuleLeft,
                        top: verticalPadding,
                        width: activeWidth,
                        height: innerHeight,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFE53935),
                                Color(0xFFDC143C),
                                Color(0xFFB91032),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius:
                                BorderRadius.circular(innerHeight / 2),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    AppColors.primaryAction.withOpacity(0.36),
                                blurRadius: 10.0,
                                offset: const Offset(0, 3),
                              ),
                              BoxShadow(
                                color:
                                    AppColors.primaryAction.withOpacity(0.14),
                                blurRadius: 4.0,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 10.0),
                          child: Opacity(
                            opacity: pillContentOpacity,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  activeItem.activeIcon,
                                  color: Colors.white,
                                  size: 21.0,
                                ),
                                const SizedBox(width: 6.0),
                                Flexible(
                                  child: Text(
                                    activeItem.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13.0,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // 2. Inactive icons with animated center positions
                      for (int i = 0; i < itemCount; i++) ...[
                        () {
                          final double fromCenter = _getItemCenter(
                            i,
                            _fromIndex,
                            inactiveWidth,
                            activeWidth,
                          );
                          final double toCenter = _getItemCenter(
                            i,
                            _toIndex,
                            inactiveWidth,
                            activeWidth,
                          );
                          final double currentCenter =
                              ui.lerpDouble(fromCenter, toCenter, t)!;

                          // Inactive icon opacity: fades out when becoming active, fades in when becoming inactive
                          double inactiveOpacity = 1.0;
                          if (i == _toIndex) {
                            inactiveOpacity = (1.0 - (t * 2.0)).clamp(0.0, 1.0);
                          } else if (i == _fromIndex) {
                            inactiveOpacity =
                                ((t - 0.5) * 2.0).clamp(0.0, 1.0);
                          }

                          return Positioned(
                            left: horizontalPadding + currentCenter - 20.0,
                            top: verticalPadding + (innerHeight - 40.0) / 2,
                            width: 40.0,
                            height: 40.0,
                            child: IgnorePointer(
                              child: Opacity(
                                opacity: inactiveOpacity,
                                child: Center(
                                  child: Icon(
                                    widget.items[i].icon,
                                    color: AppColors.navBarInactive,
                                    size: 23.0,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }(),
                      ],

                      // 3. Touch targets matching current active index layout
                      for (int i = 0; i < itemCount; i++) ...[
                        () {
                          double targetLeft;
                          double targetWidth;
                          if (i < widget.currentIndex) {
                            targetLeft = i * inactiveWidth;
                            targetWidth = inactiveWidth;
                          } else if (i == widget.currentIndex) {
                            targetLeft = widget.currentIndex * inactiveWidth;
                            targetWidth = activeWidth;
                          } else {
                            targetLeft = widget.currentIndex * inactiveWidth +
                                activeWidth +
                                (i - widget.currentIndex - 1) * inactiveWidth;
                            targetWidth = inactiveWidth;
                          }

                          return Positioned(
                            left: horizontalPadding + targetLeft,
                            top: 0,
                            width: targetWidth,
                            height: barHeight,
                            child: Semantics(
                              button: true,
                              selected: i == widget.currentIndex,
                              label: widget.items[i].label,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius:
                                      BorderRadius.circular(innerHeight / 2),
                                  splashColor:
                                      AppColors.primaryAction.withOpacity(0.08),
                                  highlightColor: Colors.transparent,
                                  onTap: () {
                                    if (i != widget.currentIndex) {
                                      HapticFeedback.lightImpact();
                                      widget.onTap(i);
                                    }
                                  },
                                ),
                              ),
                            ),
                          );
                        }(),
                      ],
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Shell scaffold with fixed bottom navigation.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.child});
  final Widget child;

  static const _routes = [
    RouteNames.home,
    RouteNames.medications,
    RouteNames.history,
    RouteNames.settings,
  ];

  int _calculateIndex(String location) {
    if (location.startsWith(RouteNames.medications)) return 1;
    if (location.startsWith(RouteNames.history)) return 2;
    if (location.startsWith(RouteNames.settings)) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final currentIndex = _calculateIndex(location);

    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      extendBody: true,
      body: child,
      bottomNavigationBar: DdBottomNav(
        currentIndex: currentIndex,
        onTap: (index) {
          if (index == currentIndex) return;
          context.go(_routes[index]);
        },
      ),
    );
  }
}
