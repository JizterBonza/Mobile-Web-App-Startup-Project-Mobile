import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class GamefowlIcon extends StatelessWidget {
  const GamefowlIcon({super.key, this.size = 24, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/icons/chicken.svg',
      width: size,
      height: size,
      colorFilter:
          color == null ? null : ColorFilter.mode(color!, BlendMode.srcIn),
    );
  }
}
