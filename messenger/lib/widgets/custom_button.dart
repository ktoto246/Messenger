import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final Color color;
  final double width;
  final double height;
  final VoidCallback onTap;

  const CustomButton({
    super.key,
    required this.text,
    required this.color,
    required this.width,
    required this.height,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: ShapeDecoration(
          color: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(1000),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w400,
            letterSpacing: -0.23,
          ),
        ),
      ),
    );
  }
}