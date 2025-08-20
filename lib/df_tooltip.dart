import 'dart:developer';

import 'package:flutter/material.dart';

// Enum to define the four possible directions for tooltip positioning
enum TooltipDirection { up, down, left, right }

// Helper widget to measure the actual rendered size of the tooltip
// This is crucial for accurate positioning calculations
class TooltipBox extends StatefulWidget {
  final Widget child;
  final void Function(Size)? onSize; // Callback that returns the measured size
  const TooltipBox({super.key, required this.child, this.onSize});

  @override
  State<TooltipBox> createState() => _TooltipBoxState();
}

class _TooltipBoxState extends State<TooltipBox> {
  @override
  void initState() {
    super.initState();
    // Wait for the widget to be fully rendered, then measure its size
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Get the RenderBox to access the actual rendered size
      final box = context.findRenderObject() as RenderBox?;
      if (box != null && widget.onSize != null) {
        // Call the callback with the measured size
        widget.onSize!(box.size);
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child; // Just return the child unchanged
}

class DFTooltip extends StatefulWidget {
  final Widget child; // The widget that triggers the tooltip when tapped
  final Widget content; // The content to display inside the tooltip
  final TooltipDirection
  preferredDirection; // User's preferred direction (can be overridden if no space)
  final bool showOnTap; // Whether to show tooltip on tap (vs other triggers)
  final Duration? duration; // Auto-hide duration (null = manual hide only)
  final double margin; // Space between tooltip and target widget
  final double?
  sideTooltipWidth; // Custom width for left/right tooltips (null = use default 50% screen width)
  final double?
  upnDownTooltipWidth; // Custom width for up/down tooltips (null = use default full width minus margins)
  final Color?
  bgColor; // Background color for the tooltip (optional is Black with opacity)
  final BorderRadius? borderRadius; // Optional border radius for the tooltip

  // Static const color for default background
  static const Color _defaultBgColor = Color(
    0xCC000000,
  ); // Black with alpha 200

  // Static const border radius for default tooltip
  static const BorderRadius _defaultBorderRadius = BorderRadius.all(
    Radius.circular(8),
  ); // Default border radius for tooltip

  /// Creates a tooltip widget that displays content when the child widget is tapped.
  /// [child] is the widget that triggers the tooltip.
  /// [content] is the content displayed inside the tooltip.
  /// [preferredDirection] specifies the preferred direction for the tooltip (up, down, left, right).
  /// [showOnTap] determines if the tooltip should be shown on tap (default is true).
  /// [duration] specifies how long the tooltip should be visible before auto-hiding (null means manual hide only).
  /// [margin] is the space between the tooltip and the target widget (default is 0.0).
  /// [sideTooltipWidth] is the custom width for left/right tooltips (default is null, which means it will use 50% of the screen width).
  /// [upnDownTooltipWidth] is the custom width for up/down tooltips (default is null, which means it will use full width minus margins).
  /// [bgColor] is the background color for the tooltip (default is black with opacity).
  /// [borderRadius] is the border radius for the tooltip (default is 8.0).
  ///
  /// The tooltip will automatically adjust its position based on available space,
  /// ensuring it does not overflow the screen edges.
  /// It also listens to scroll events to hide the tooltip when the user scrolls,
  /// making it suitable for use in scrollable contexts.

  const DFTooltip({
    super.key,
    required this.child,
    required this.content,
    this.preferredDirection = TooltipDirection.up,
    this.showOnTap = true,
    this.duration,
    this.margin = 0.0,
    this.sideTooltipWidth,
    this.upnDownTooltipWidth,
    this.bgColor = _defaultBgColor,
    this.borderRadius = _defaultBorderRadius,
  });

  @override
  State<DFTooltip> createState() => _DFTooltipState();
}

class _DFTooltipState extends State<DFTooltip> {
  // The overlay entry that contains the tooltip
  OverlayEntry? _overlayEntry;
  // Flag to track tooltip visibility state
  bool _isTooltipVisible = false;
  // list of references to scroll position for hiding on scroll, if any of the scrolls moves, the tooltip will hide

  final List<ScrollPosition> _scrollPositions = [];

  // Subscribe to ALL scroll events in the widget hierarchy
  void _subscribeScroll() {
    try {
      BuildContext? currentContext = context;
      _scrollPositions.clear(); // Clear any existing subscriptions

      // Search for ALL scrollables in the hierarchy
      while (currentContext != null) {
        final scrollableState = Scrollable.maybeOf(currentContext);

        if (scrollableState != null) {
          final position = scrollableState.position;
          final canScroll = position.maxScrollExtent > 0;

          // Subscribe to ALL scrollables that can scroll, not just the first one
          // in case there are multiple scrollables in the hierarchy
          if (canScroll) {
            _scrollPositions.add(position);
            position.addListener(_onScroll);
          }
        }

        // Continue searching for parent scrollables
        try {
          currentContext = _findParentContext(currentContext);
        } catch (e) {
          break;
        }
      }
    } catch (e) {
      log('Error in _subscribeScroll: $e');
    }
  }

  // Helper method to find parent context in the widget tree
  BuildContext? _findParentContext(BuildContext context) {
    BuildContext? parent;

    context.visitAncestorElements((element) {
      parent = element;
      return false; // Stop after finding the first parent
    });

    return parent;
  }

  // Unsubscribe from ALL scroll events and clean up
  void _unsubscribeScroll() {
    for (final position in _scrollPositions) {
      position.removeListener(_onScroll);
    }
    _scrollPositions.clear();
  }

  // Called when any scroll event occurs - hides the tooltip
  void _onScroll() {
    if (_isTooltipVisible) {
      log('Scroll detected - hiding tooltip');
      _hideTooltip();
    }
  }

  // Main method to show the tooltip using a two-pass approach
  void _showTooltip() {
    // Prevent multiple tooltips from being shown simultaneously
    if (_overlayEntry != null) return;

    // Subscribe to scroll events so tooltip hides when user scrolls
    _subscribeScroll();

    // Get the position and size of the target widget (the child that was tapped)
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    // Convert local coordinates to global screen coordinates
    final target = renderBox.localToGlobal(Offset.zero);
    final targetSize = renderBox.size;

    // FIRST PASS: Show tooltip off-screen to measure its actual size
    OverlayEntry? measureEntry;
    measureEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: -9999, // Position far off-screen so it's not visible
        top: -9999,
        child: Material(
          color: Colors.transparent,
          child: TooltipBox(
            // Callback that receives the measured size after rendering
            onSize: (tooltipSize) {
              // Remove the measurement overlay since we got the size
              measureEntry?.remove();

              // SECOND PASS: Show tooltip at correct position using measured size
              _overlayEntry = OverlayEntry(
                builder: (context) {
                  // Get screen size for positioning calculations
                  final overlaySize = MediaQuery.of(context).size;
                  // Calculate the best position and direction for the tooltip
                  final result = _calculateTooltipPosition(
                    overlaySize,
                    target,
                    targetSize,
                    tooltipSize,
                    widget.preferredDirection,
                    widget.margin,
                  );
                  return GestureDetector(
                    behavior: HitTestBehavior
                        .translucent, // Allow taps to pass through
                    onTap: _hideTooltip, // Hide tooltip when user taps outside
                    child: Stack(
                      children: [
                        Positioned(
                          left: result.position.dx, // X position calculated
                          top: result.position.dy, // Y position calculated
                          child: Material(
                            color: Colors.transparent,
                            // Build tooltip with actual direction (may be flipped from preferred)
                            child: _buildTooltip(
                              result.actualDirection,
                              tooltipSize,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
              // Insert the properly positioned tooltip into the overlay
              Overlay.of(context).insert(_overlayEntry!);
              _isTooltipVisible = true;

              // Set up auto-hide if duration is specified
              if (widget.duration != null) {
                Future.delayed(widget.duration!, _hideTooltip);
              }
            },
            // Build tooltip for measurement (direction doesn't matter for sizing)
            child: _buildTooltip(widget.preferredDirection, Size.zero),
          ),
        ),
      ),
    );
    // Insert the measurement overlay
    Overlay.of(context).insert(measureEntry);
  }

  // Calculate the optimal position and direction for the tooltip
  ({Offset position, TooltipDirection actualDirection})
  _calculateTooltipPosition(
    Size overlaySize, // Screen size
    Offset target, // Target widget's top-left corner
    Size targetSize, // Target widget's size
    Size tooltipSize, // Measured tooltip size
    TooltipDirection direction, // User's preferred direction
    double margin, // Margin between tooltip and target
  ) {
    const minScreenMargin = 16.0; // Minimum distance from screen edges
    double left = 0, top = 0;
    TooltipDirection dir = direction; // Start with preferred direction

    // Check if tooltip fits in each direction
    bool fitsAbove = target.dy - tooltipSize.height - margin > minScreenMargin;
    bool fitsBelow =
        target.dy + targetSize.height + tooltipSize.height + margin <
        overlaySize.height - minScreenMargin;
    bool fitsLeft = target.dx - tooltipSize.width - margin > minScreenMargin;
    bool fitsRight =
        target.dx + targetSize.width + tooltipSize.width + margin <
        overlaySize.width - minScreenMargin;

    // Flip direction if preferred direction doesn't fit
    switch (direction) {
      case TooltipDirection.up:
        if (!fitsAbove && fitsBelow) dir = TooltipDirection.down;
        break;
      case TooltipDirection.down:
        if (!fitsBelow && fitsAbove) dir = TooltipDirection.up;
        break;
      case TooltipDirection.left:
        if (!fitsLeft && fitsRight) dir = TooltipDirection.right;
        break;
      case TooltipDirection.right:
        if (!fitsRight && fitsLeft) dir = TooltipDirection.left;
        break;
    }

    // Calculate position based on actual direction
    switch (dir) {
      case TooltipDirection.up:
        left =
            target.dx +
            targetSize.width / 2 -
            tooltipSize.width / 2; // Center horizontally
        top = target.dy - tooltipSize.height - margin; // Position above target
        break;
      case TooltipDirection.down:
        left =
            target.dx +
            targetSize.width / 2 -
            tooltipSize.width / 2; // Center horizontally
        top = target.dy + targetSize.height + margin; // Position below target
        break;
      case TooltipDirection.left:
        left = target.dx - tooltipSize.width - margin; // Position to the left
        top =
            target.dy +
            targetSize.height / 2 -
            tooltipSize.height / 2; // Center vertically
        break;
      case TooltipDirection.right:
        left = target.dx + targetSize.width + margin; // Position to the right
        top =
            target.dy +
            targetSize.height / 2 -
            tooltipSize.height / 2; // Center vertically
        break;
    }

    // Clamp position to screen bounds to prevent overflow
    double maxLeft = overlaySize.width - tooltipSize.width - minScreenMargin;
    left = maxLeft <= minScreenMargin
        ? minScreenMargin
        : left.clamp(minScreenMargin, maxLeft);

    double maxTop = overlaySize.height - tooltipSize.height - minScreenMargin;
    top = maxTop <= minScreenMargin
        ? minScreenMargin
        : top.clamp(minScreenMargin, maxTop);

    // Return both the calculated position and the actual direction used
    return (position: Offset(left, top), actualDirection: dir);
  }

  // Build the visual tooltip with arrow pointing in the correct direction
  Widget _buildTooltip(TooltipDirection direction, Size tooltipSize) {
    final screenSize = MediaQuery.of(context).size;

    // Set maximum width based on direction
    double maxWidth;
    switch (direction) {
      case TooltipDirection.up:
      case TooltipDirection.down:
        maxWidth =
            widget.upnDownTooltipWidth ??
            (screenSize.width -
                32); // Full width minus 16px margins on each side
        break;
      case TooltipDirection.left:
      case TooltipDirection.right:
        // Use custom width if provided, otherwise default to 50% of screen width
        maxWidth = widget.sideTooltipWidth ?? (screenSize.width * 0.5);
        break;
    }

    // Ensure minimum width to avoid constraint errors
    maxWidth = maxWidth.clamp(100.0, double.infinity);

    // Build the main tooltip box with content
    Widget tooltipBox = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color:
              widget.bgColor ??
              DFTooltip._defaultBgColor, // Use widget's bgColor or default
          borderRadius: widget.borderRadius ?? DFTooltip._defaultBorderRadius,
        ),
        child: widget.content, // User's custom content
      ),
    );

    // Combine tooltip box with arrow based on direction
    final arrowColor = widget.bgColor ?? DFTooltip._defaultBgColor;

    switch (direction) {
      case TooltipDirection.up:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            tooltipBox, // Tooltip box on top
            CustomPaint(
              // Arrow pointing down (tooltip is above target)
              size: const Size(16, 8),
              painter: _TrianglePainter(
                color: arrowColor,
                direction: TooltipDirection.up,
              ),
            ),
          ],
        );
      case TooltipDirection.down:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomPaint(
              // Arrow pointing up (tooltip is below target)
              size: const Size(16, 8),
              painter: _TrianglePainter(
                color: arrowColor,
                direction: TooltipDirection.down,
              ),
            ),
            tooltipBox, // Tooltip box on bottom
          ],
        );
      case TooltipDirection.left:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            tooltipBox, // Tooltip box on left
            CustomPaint(
              // Arrow pointing right (tooltip is left of target)
              size: const Size(8, 16),
              painter: _TrianglePainter(
                color: arrowColor,
                direction: TooltipDirection.left,
              ),
            ),
          ],
        );
      case TooltipDirection.right:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomPaint(
              // Arrow pointing left (tooltip is right of target)
              size: const Size(8, 16),
              painter: _TrianglePainter(
                color: arrowColor,
                direction: TooltipDirection.right,
              ),
            ),
            tooltipBox, // Tooltip box on right
          ],
        );
    }
  }

  // Hide the tooltip and clean up resources
  void _hideTooltip() {
    _unsubscribeScroll(); // Stop listening to scroll events
    _overlayEntry?.remove(); // Remove overlay from screen
    _overlayEntry = null; // Clear reference
    _isTooltipVisible = false; // Update visibility flag
  }

  @override
  void dispose() {
    _hideTooltip(); // Clean up when widget is disposed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent, // Allow taps to be detected
      onTap: widget.showOnTap && !_isTooltipVisible ? _showTooltip : null,
      child: widget.child, // The trigger widget
    );
  }
}

// Custom painter to draw triangular arrows pointing toward the target
class _TrianglePainter extends CustomPainter {
  final Color color;
  final TooltipDirection direction;

  _TrianglePainter({required this.color, required this.direction});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();

    // Draw triangle pointing in the correct direction
    switch (direction) {
      case TooltipDirection.up:
        // Arrow pointing down (tooltip is above, arrow points to target below)
        path.moveTo(0, 0);
        path.lineTo(size.width / 2, size.height);
        path.lineTo(size.width, 0);
        break;
      case TooltipDirection.down:
        // Arrow pointing up (tooltip is below, arrow points to target above)
        path.moveTo(0, size.height);
        path.lineTo(size.width / 2, 0);
        path.lineTo(size.width, size.height);
        break;
      case TooltipDirection.left:
        // Arrow pointing right (tooltip is left, arrow points to target right)
        path.moveTo(size.width, size.height / 2);
        path.lineTo(0, 0);
        path.lineTo(0, size.height);
        break;
      case TooltipDirection.right:
        // Arrow pointing left (tooltip is right, arrow points to target left)
        path.moveTo(0, size.height / 2);
        path.lineTo(size.width, 0);
        path.lineTo(size.width, size.height);
        break;
    }
    path.close();
    canvas.drawPath(path, paint); // Draw the triangle
  }

  @override
  bool shouldRepaint(_TrianglePainter oldDelegate) => false;
}
