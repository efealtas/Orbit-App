import 'package:flutter/material.dart';
import 'dart:math' as math;

class PlanetWidget extends StatefulWidget {
  final double size;
  final Color color;
  final bool isAnimated;
  final int level;

  const PlanetWidget({
    Key? key,
    this.size = 200,
    this.color = Colors.blue,
    this.isAnimated = true,
    this.level = 1,
  }) : super(key: key);

  @override
  State<PlanetWidget> createState() => _PlanetWidgetState();
}

class _PlanetWidgetState extends State<PlanetWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
    _rotationAnimation = Tween<double>(begin: 0, end: 2 * math.pi).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _rotationAnimation,
      builder: (context, child) {
        return Transform.rotate(
          angle: _rotationAnimation.value,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  widget.color.withOpacity(0.9),
                  widget.color.withOpacity(0.7),
                  widget.color.withOpacity(0.5),
                ],
                stops: const [0.0, 0.6, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withOpacity(0.3),
                  blurRadius: 30,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: Stack(
              children: [
                // Planet surface details
                Positioned.fill(
                  child: CustomPaint(
                    painter: PlanetSurfacePainter(
                      color: widget.color,
                      level: widget.level,
                    ),
                  ),
                ),
                // Atmosphere glow
                if (widget.isAnimated)
                  Positioned.fill(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.8, end: 1.2),
                      duration: const Duration(seconds: 3),
                      curve: Curves.easeInOut,
                      builder: (context, value, child) {
                        return Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                widget.color.withOpacity(0.3),
                                widget.color.withOpacity(0.0),
                              ],
                              stops: [0.0, value],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                // Level indicator
                Positioned(
                  bottom: 10,
                  right: 10,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Lvl ${widget.level}',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class PlanetSurfacePainter extends CustomPainter {
  final Color color;
  final int level;

  PlanetSurfacePainter({required this.color, required this.level});

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(level);
    final paint = Paint()
      ..color = color.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Draw continents
    for (var i = 0; i < 3 + level; i++) {
      final path = Path();
      final startX = size.width * (0.2 + random.nextDouble() * 0.6);
      final startY = size.height * (0.2 + random.nextDouble() * 0.6);
      path.moveTo(startX, startY);

      // Create a more natural-looking continent shape
      for (var j = 0; j < 5; j++) {
        final controlX = size.width * (0.3 + random.nextDouble() * 0.4);
        final controlY = size.height * (0.3 + random.nextDouble() * 0.4);
        final endX = size.width * (0.2 + random.nextDouble() * 0.6);
        final endY = size.height * (0.2 + random.nextDouble() * 0.6);
        path.quadraticBezierTo(controlX, controlY, endX, endY);
      }
      path.close();
      canvas.drawPath(path, paint);

      // Fill the continent
      final fillPaint = Paint()
        ..color = color.withOpacity(0.2)
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, fillPaint);
    }

    // Draw craters
    for (var i = 0; i < 2 + level; i++) {
      final x = size.width * (0.2 + random.nextDouble() * 0.6);
      final y = size.height * (0.2 + random.nextDouble() * 0.6);
      final radius = size.width * (0.05 + random.nextDouble() * 0.1);
      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()
          ..color = color.withOpacity(0.3)
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
