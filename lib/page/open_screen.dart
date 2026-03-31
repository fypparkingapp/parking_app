import 'package:flutter/material.dart';

class OpenScreen extends StatelessWidget {
  const OpenScreen({
    super.key,
    this.message,
    this.accentColor,
    this.backgroundColor,
  });

  final String? message;
  final Color? accentColor;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final base = backgroundColor ?? const Color(0xFFADD8E6);
    final accent = accentColor ?? const Color(0xFF00008B);

    return Scaffold(
      backgroundColor: base,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(1.1, 0.7),
            radius: 0.9,
            colors: [
              accent.withAlpha(0x8B),
              accent.withAlpha(0x00),
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Center(
            child: Column(
              children: [
                const Spacer(flex: 2),
                Image.asset(
                  'assets/appicon.png',
                  width: 140,
                  height: 140,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 22),
                const Text(
                  '車位易',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontFamily: 'SF Pro',
                    fontWeight: FontWeight.w400,
                    letterSpacing: 5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Parking space',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontFamily: 'SF Pro',
                    fontWeight: FontWeight.w400,
                  ),
                ),
                if (message != null && message!.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    message!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: 'SF Pro',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
                const Spacer(flex: 3),
                const Text(
                  'by HSU of HK Student',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontFamily: 'SF Pro',
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
