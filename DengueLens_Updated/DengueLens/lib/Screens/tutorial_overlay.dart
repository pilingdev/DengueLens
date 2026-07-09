import 'package:flutter/material.dart';
import '../services/tutorial_service.dart';

/// Data class representing a single tutorial step.
class _TutorialStep {
  final String title;
  final String description;
  final IconData icon;
  final GlobalKey? targetKey; // null for full-screen welcome step

  const _TutorialStep({
    required this.title,
    required this.description,
    required this.icon,
    this.targetKey,
  });
}

/// Full-screen overlay that guides the user through the app features
/// using a coach-mark style spotlight on key UI elements.
class TutorialOverlay extends StatefulWidget {
  /// GlobalKey attached to the Scan button.
  final GlobalKey scanKey;

  /// GlobalKey attached to the Upload button.
  final GlobalKey uploadKey;

  /// GlobalKey attached to the bottom NavigationBar.
  final GlobalKey navBarKey;

  /// GlobalKey attached to the replay-tutorial FAB.
  final GlobalKey fabKey;

  /// Called when the tutorial is dismissed (completed or skipped).
  final VoidCallback onDismiss;

  const TutorialOverlay({
    super.key,
    required this.scanKey,
    required this.uploadKey,
    required this.navBarKey,
    required this.fabKey,
    required this.onDismiss,
  });

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0;
  late final List<_TutorialStep> _steps;
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _steps = [
      const _TutorialStep(
        title: 'Welcome to Dengue Lens!',
        description:
            "Let's take a quick tour so you can start identifying mosquitoes and assessing dengue risk right away.",
        icon: Icons.waving_hand_rounded,
        targetKey: null, // full-screen welcome
      ),
      _TutorialStep(
        title: 'Scan a Mosquito',
        description:
            'Tap here to capture a mosquito photo using your camera for instant AI-powered analysis.',
        icon: Icons.camera_alt_outlined,
        targetKey: widget.scanKey,
      ),
      _TutorialStep(
        title: 'Upload from Gallery',
        description:
            'Already have a photo? Upload it from your gallery instead for the same accurate detection.',
        icon: Icons.photo_library_outlined,
        targetKey: widget.uploadKey,
      ),
      _TutorialStep(
        title: 'Explore the App',
        description:
            'Use the navigation bar to view your scan history, the mosquito sighting map, risk assessment, and educational library.',
        icon: Icons.explore_outlined,
        targetKey: widget.navBarKey,
      ),
      _TutorialStep(
        title: 'Replay Anytime',
        description:
            'You can replay this tutorial anytime by tapping this button. Enjoy using Dengue Lens!',
        icon: Icons.school_outlined,
        targetKey: widget.fabKey,
      ),
    ];

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeInOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  /// Returns the bounding rectangle of a widget identified by its [GlobalKey].
  Rect? _getTargetRect(GlobalKey key) {
    final renderObject = key.currentContext?.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      final offset = renderObject.localToGlobal(Offset.zero);
      return offset & renderObject.size;
    }
    return null;
  }

  void _goToStep(int step) {
    _animController.reverse().then((_) {
      if (!mounted) return;
      setState(() => _currentStep = step);
      _animController.forward();
    });
  }

  void _next() {
    if (_currentStep < _steps.length - 1) {
      _goToStep(_currentStep + 1);
    } else {
      _finish();
    }
  }

  void _skip() => _finish();

  void _finish() {
    TutorialService().markTutorialSeen();
    _animController.reverse().then((_) {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_currentStep];
    final targetRect =
        step.targetKey != null ? _getTargetRect(step.targetKey!) : null;
    final isWelcome = step.targetKey == null;
    final isLastStep = _currentStep == _steps.length - 1;
    final screenSize = MediaQuery.of(context).size;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // ── Dark backdrop with spotlight cutout ──────────────────
            Positioned.fill(
              child: CustomPaint(
                painter: _SpotlightPainter(
                  targetRect: targetRect,
                  overlayColor: Colors.black.withValues(alpha: 0.72),
                ),
              ),
            ),

            // ── Tap barrier (absorb taps on the dark area) ──────────
            Positioned.fill(
              child: GestureDetector(
                onTap: () {}, // absorb taps
                behavior: HitTestBehavior.translucent,
              ),
            ),

            // ── Pulsing ring around spotlight target ────────────────
            if (targetRect != null)
              Positioned(
                left: targetRect.left - 8,
                top: targetRect.top - 8,
                child: _PulsingRing(
                  width: targetRect.width + 16,
                  height: targetRect.height + 16,
                  borderRadius: _isCircularTarget(targetRect) ? 100 : 16,
                ),
              ),

            // ── Tooltip Card ────────────────────────────────────────
            _buildTooltip(
              context,
              step: step,
              targetRect: targetRect,
              isWelcome: isWelcome,
              isLastStep: isLastStep,
              screenSize: screenSize,
            ),
          ],
        ),
      ),
    );
  }

  bool _isCircularTarget(Rect rect) {
    // Consider it circular if width & height are roughly equal
    return (rect.width - rect.height).abs() < 20;
  }

  Widget _buildTooltip(
    BuildContext context, {
    required _TutorialStep step,
    required Rect? targetRect,
    required bool isWelcome,
    required bool isLastStep,
    required Size screenSize,
  }) {
    // Calculate tooltip position relative to the target
    double? top;
    double? bottom;

    if (isWelcome || targetRect == null) {
      // Centred
      top = screenSize.height * 0.3;
    } else {
      // Position below or above the target depending on available space
      final spaceBelow = screenSize.height - targetRect.bottom;
      if (spaceBelow > 260) {
        top = targetRect.bottom + 20;
      } else {
        bottom = screenSize.height - targetRect.top + 20;
      }
    }

    return Positioned(
      left: 24,
      right: 24,
      top: top,
      bottom: bottom,
      child: TweenAnimationBuilder<double>(
        key: ValueKey(_currentStep),
        tween: Tween(begin: 20, end: 0),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
        builder: (context, offset, child) {
          return Transform.translate(
            offset: Offset(0, offset),
            child: child,
          );
        },
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2ECC71).withValues(alpha: 0.15),
                blurRadius: 30,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2ECC71), Color(0xFF27AE60)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(step.icon, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                step.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 10),

              // Description
              Text(
                step.description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.5,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 24),

              // Step indicator dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_steps.length, (i) {
                  final isActive = i == _currentStep;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isActive ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isActive
                          ? const Color(0xFF2ECC71)
                          : Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 20),

              // Action buttons
              Row(
                children: [
                  // Skip button (hide on last step)
                  if (!isLastStep)
                    Expanded(
                      child: TextButton(
                        onPressed: _skip,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Skip',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[500],
                          ),
                        ),
                      ),
                    ),
                  if (!isLastStep) const SizedBox(width: 12),
                  // Next / Done button
                  Expanded(
                    flex: isLastStep ? 1 : 1,
                    child: ElevatedButton(
                      onPressed: _next,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2ECC71),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        isLastStep ? 'Get Started' : 'Next',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Draws a semi-transparent overlay with a rounded-rect or circular cutout
/// (spotlight) around the [targetRect].
class _SpotlightPainter extends CustomPainter {
  final Rect? targetRect;
  final Color overlayColor;

  _SpotlightPainter({this.targetRect, required this.overlayColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = overlayColor;

    // Full screen path
    final fullScreen = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    if (targetRect != null) {
      // Determine if the target is roughly circular
      final isCircle = (targetRect!.width - targetRect!.height).abs() < 20;
      final padding = 8.0;
      final paddedRect = targetRect!.inflate(padding);

      final cutout = Path();
      if (isCircle) {
        cutout.addOval(paddedRect);
      } else {
        cutout.addRRect(
          RRect.fromRectAndRadius(paddedRect, const Radius.circular(16)),
        );
      }

      // Subtract the cutout from the full screen
      final combined = Path.combine(PathOperation.difference, fullScreen, cutout);
      canvas.drawPath(combined, paint);
    } else {
      canvas.drawPath(fullScreen, paint);
    }
  }

  @override
  bool shouldRepaint(_SpotlightPainter oldDelegate) =>
      targetRect != oldDelegate.targetRect ||
      overlayColor != oldDelegate.overlayColor;
}

/// An animated pulsing ring that draws attention to the spotlighted element.
class _PulsingRing extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const _PulsingRing({
    required this.width,
    required this.height,
    required this.borderRadius,
  });

  @override
  State<_PulsingRing> createState() => _PulsingRingState();
}

class _PulsingRingState extends State<_PulsingRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _scaleAnim = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _opacityAnim = Tween<double>(begin: 0.6, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnim.value,
          child: Opacity(
            opacity: _opacityAnim.value,
            child: Container(
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.borderRadius),
                border: Border.all(
                  color: const Color(0xFF2ECC71),
                  width: 3,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
