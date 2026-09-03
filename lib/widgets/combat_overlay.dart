// SPDX-License-Identifier: MIT

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../provider/room_notifier.dart';
import '../ui/theme.dart';
import '../utils/strings.dart';

/// Full-body combat ambience shown on every client while
/// `pauseReason == 'combat'`. Fade 280 ms, danger pulse 450 ms,
/// `easeOutCubic` only (T5.3 motion contract).
class CombatOverlay extends StatefulWidget {
  const CombatOverlay({super.key});

  @override
  State<CombatOverlay> createState() => _CombatOverlayState();
}

class _CombatOverlayState extends State<CombatOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    )..repeat(reverse: true);
    _pulseAnim = CurvedAnimation(parent: _pulse, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = context.watch<RoomNotifier>();
    return Positioned.fill(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        builder: (context, opacity, child) =>
            Opacity(opacity: opacity, child: child),
        child: AnimatedBuilder(
          animation: _pulseAnim,
          builder: (context, child) {
            final t = _pulseAnim.value;
            final rim = Color.lerp(
              ScytheColors.rustDeep,
              ScytheColors.danger,
              t,
            )!;
            return DecoratedBox(
              decoration: BoxDecoration(
                color: ScytheColors.coal.withValues(alpha: 0.92),
                border: Border.all(color: rim, width: 3),
              ),
              child: child,
            );
          },
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 96,
                    height: 96,
                    child: CustomPaint(
                      painter: CrossedBladesPainter(
                        fill: ScytheColors.brass,
                        edge: ScytheColors.rustDeep,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    CombatStrings.overlayTitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: ScytheColors.danger,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 6,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    CombatStrings.overlayBody,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: ScytheColors.parchment,
                      fontSize: 16,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (notifier.isMyTurn)
                    ElevatedButton(
                      key: const ValueKey('combat-resolved'),
                      onPressed: notifier.resume,
                      child: const Text(CombatStrings.resolved),
                    )
                  else
                    const Text(
                      CombatStrings.waiting,
                      style: TextStyle(
                        color: ScytheColors.parchmentDim,
                        fontSize: 14,
                        letterSpacing: 1,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Original crossed-blades geometry — not a Stonemaier or Material icon.
class CrossedBladesPainter extends CustomPainter {
  const CrossedBladesPainter({required this.fill, required this.edge});

  final Color fill;
  final Color edge;

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = fill
      ..style = PaintingStyle.fill;
    final edgePaint = Paint()
      ..color = edge
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeJoin = StrokeJoin.round;

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    _paintBlade(canvas, size, -0.72, fillPaint, edgePaint);
    _paintBlade(canvas, size, 0.72, fillPaint, edgePaint);
    canvas.restore();
  }

  void _paintBlade(
    Canvas canvas,
    Size size,
    double angle,
    Paint fillPaint,
    Paint edgePaint,
  ) {
    canvas.save();
    canvas.rotate(angle);
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(0, -h * 0.44)
      ..quadraticBezierTo(w * 0.055, -h * 0.12, w * 0.05, h * 0.18)
      ..lineTo(w * 0.12, h * 0.26)
      ..lineTo(w * 0.04, h * 0.28)
      ..lineTo(0, h * 0.42)
      ..lineTo(-w * 0.04, h * 0.28)
      ..lineTo(-w * 0.12, h * 0.26)
      ..lineTo(-w * 0.05, h * 0.18)
      ..quadraticBezierTo(-w * 0.055, -h * 0.12, 0, -h * 0.44)
      ..close();
    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, edgePaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CrossedBladesPainter oldDelegate) =>
      oldDelegate.fill != fill || oldDelegate.edge != edge;
}
