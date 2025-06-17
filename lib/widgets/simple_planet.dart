import 'package:flutter/material.dart';

class SimplePlanet extends StatelessWidget {
  final double size;
  final Color color;
  final int level;

  const SimplePlanet({
    Key? key,
    this.size = 200,
    this.color = Colors.blue,
    this.level = 1,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
      child: Center(
        child: Text(
          'Level $level',
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
} 