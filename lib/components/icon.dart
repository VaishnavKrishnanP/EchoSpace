import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SvgIcon extends StatelessWidget {
  final double size;
  final Color color;

  const SvgIcon({
    super.key,
    this.size = 48.0, // Default size
    this.color = Colors.blue, // Default color
  });

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/icon.svg',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn), // Apply color
    );
  }
}