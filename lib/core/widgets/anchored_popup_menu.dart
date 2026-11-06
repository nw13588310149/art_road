import 'package:flutter/material.dart';

import '../../features/shell/ui/shell_layout.dart';

/// Anchor geometry for a popup menu anchored to a trigger widget.
class AnchoredPopupPosition {
  const AnchoredPopupPosition({
    required this.left,
    required this.top,
    required this.menuWidth,
    required this.approxMenuHeight,
    required this.above,
  });

  final double left;
  final double top;
  final double menuWidth;
  final double approxMenuHeight;

  /// Whether the menu visually sits above the trigger center. Used to pick
  /// slide direction so the entrance matches [music_play_page] speed menus.
  final bool above;
}

/// Computes popup anchor from [triggerKey], matching the cloud-disk / notes /
/// collection action-menu placement rules.
AnchoredPopupPosition? computeAnchoredPopupPosition({
  required BuildContext context,
  required GlobalKey triggerKey,
  required double menuWidth,
  required double approxMenuHeight,
}) {
  final triggerCtx = triggerKey.currentContext;
  if (triggerCtx == null) {
    return null;
  }
  final renderBox = triggerCtx.findRenderObject() as RenderBox;
  final overlayBox =
      Overlay.of(context, rootOverlay: true).context.findRenderObject()
          as RenderBox;

  final origin = renderBox.localToGlobal(Offset.zero, ancestor: overlayBox);
  final size = renderBox.size;
  final scale = DashboardScaleScope.of(context);
  final edge = scale.ui(8);

  var left = origin.dx + size.width / 2;
  var top = origin.dy + size.height / 2;

  if (left + menuWidth > overlayBox.size.width - edge) {
    left = origin.dx + size.width / 2 - menuWidth;
  }
  if (left < edge) {
    left = edge;
  }
  if (top + approxMenuHeight > overlayBox.size.height - edge) {
    top = overlayBox.size.height - approxMenuHeight - edge;
  }
  if (top < edge) {
    top = edge;
  }

  final triggerCenterY = origin.dy + size.height / 2;
  final menuCenterY = top + approxMenuHeight / 2;
  final above = menuCenterY < triggerCenterY;

  return AnchoredPopupPosition(
    left: left,
    top: top,
    menuWidth: menuWidth,
    approxMenuHeight: approxMenuHeight,
    above: above,
  );
}

/// Shows an anchored popup with the same fade + slide transition used by
/// musicPlay speed / pitch pickers.
Future<T?> showAnchoredPopupMenu<T>({
  required BuildContext context,
  required GlobalKey triggerKey,
  required double menuWidth,
  required double approxMenuHeight,
  required Widget Function(BuildContext dialogContext, VoidCallback dismiss)
  builder,
}) {
  final scale = DashboardScaleScope.of(context);
  final position = computeAnchoredPopupPosition(
    context: context,
    triggerKey: triggerKey,
    menuWidth: menuWidth,
    approxMenuHeight: approxMenuHeight,
  );
  if (position == null) {
    return Future<T?>.value(null);
  }

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'anchored_popup_menu',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (dialogContext, animation, secondary) {
      return DashboardScaleScope(
        data: scale,
        child: Stack(
          children: [
            Positioned(
              left: position.left,
              top: position.top,
              width: position.menuWidth,
              child: Material(
                color: Colors.transparent,
                child: builder(
                  dialogContext,
                  () => Navigator.of(dialogContext).pop(),
                ),
              ),
            ),
          ],
        ),
      );
    },
    transitionBuilder: (context, animation, secondary, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      final offsetTween = position.above
          ? Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
          : Tween<Offset>(begin: const Offset(0, -0.04), end: Offset.zero);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: offsetTween.animate(curved),
          child: child,
        ),
      );
    },
  );
}
