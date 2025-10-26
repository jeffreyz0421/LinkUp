
// lib/cas.dart

import 'dart:ui';
import 'package:flutter/material.dart';

import 'main_screen_ui.dart';   // MapScreen
import 'Meetup_master_and_vibe.dart';          // MeetupFlow
import 'linkup.dart';          // LinkupScreen
import 'pullup.dart';          // PullupScreen

/// CAS Screen: one-word labels, straight edges on flush sides, and inline icons.
class CASScreen extends StatelessWidget {
  const CASScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.white,
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Back arrow
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: CustomPaint(
                      size: const Size(36, 34),
                      painter: BackArrowPainter(),
                    ),
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const MapScreen()),
                      );
                    },
                  ),
                ),

                // Lift content up slightly
                const SizedBox(height: 40),

                // Title
                Text(
                  'CHOOSE YOUR VIBE',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF590099),
                    fontFamily: 'LuckiestGuy',
                    fontSize: 36,
                    height: 1,
                  ),
                ),

                // Subtitle
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Connect with your campus\ncommunity',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xCC000000),
                      fontFamily: 'Poppins',
                      fontSize: 20,
                      height: 1.4,
                    ),
                    maxLines: 2,
                  ),
                ),

                // Space before cards
                const SizedBox(height: 40),

                // Meetup: straight left edge
                Align(
                  alignment: Alignment.centerLeft,
                  child: _ActionCard(
                    width: 342,
                    colorStart: const Color(0xFFEC4899),
                    colorEnd: const Color(0xFFF43F5E),
                    assetName: 'assets/images/CASIcon_Meetup.png',
                    label: 'MEETUP',
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                    onTap: () => _open(context, const MeetupFlow()),
                  ),
                ),
                const SizedBox(height: 32),

                // Linkup: straight right edge
                Align(
                  alignment: Alignment.centerRight,
                  child: _ActionCard(
                    width: 342,
                    colorStart: const Color(0xFF06B6D4),
                    colorEnd: const Color(0xFF3B82F6),
                    assetName: 'assets/images/CASIcon_LinkUp.png',
                    label: 'LINKUP',
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      bottomLeft: Radius.circular(24),
                    ),
                    onTap: () => _open(context, const LinkupScreen()),
                  ),
                ),
                const SizedBox(height: 32),

                // Pullup: straight left edge
                Align(
                  alignment: Alignment.centerLeft,
                  child: _ActionCard(
                    width: 342,
                    colorStart: const Color(0xFF10B981),
                    colorEnd: const Color(0xFF14B8A6),
                    assetName: 'assets/images/CASIcon_PullUp.png',
                    label: 'PULLUP',
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                    onTap: () => _open(context, const PullupScreen()),
                  ),
                ),

                // Footer hint
                const SizedBox(height: 40),
                Text(
                  'Tap any button to get started',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }
}

/// Single card with custom straight-edge radius and inline icon.
class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.width,
    required this.colorStart,
    required this.colorEnd,
    required this.assetName,
    required this.label,
    required this.borderRadius,
    required this.onTap,
  });

  final double width;
  final Color colorStart;
  final Color colorEnd;
  final String assetName;
  final String label;
  final BorderRadius borderRadius;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: 104,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [colorStart, colorEnd],
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
          ),
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              offset: const Offset(0, 25),
              blurRadius: 50,
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: [
            Image.asset(
              assetName,
              width: 60,
              height: 60,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'LuckiestGuy',
                fontSize: 40,
                height: 0.7,
              ),
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward, color: Colors.white, size: 24),
          ],
        ),
      ),
    );
  }
}

// Custom painter for back arrow
class BackArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF424866)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(28.5, 17)
      ..lineTo(7.5, 17)
      ..moveTo(7.5, 17)
      ..lineTo(18, 26.9166)
      ..moveTo(7.5, 17)
      ..lineTo(18, 7.08331);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
