import 'package:flutter/material.dart';
import 'meetup.dart';
import 'pullup.dart';
import 'linkup.dart';
import 'main_screen_ui.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'dart:ui';

// Screens your logic already uses. Make sure these paths are still correct.

/// Combined version of CAS.dart that keeps your original navigation / business
/// logic while adopting your friend’s polished UI design.
///
/// • Buttons navigate to their respective pages (Meetup, Linkup, Pull‑up).
/// • Back arrow returns to the map (or pops if you push this screen).
/// • All custom painters from the design are preserved.

class CASScreen extends StatelessWidget {
  const CASScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ------------------------------------------------------------------
          // Background blobs
          // ------------------------------------------------------------------
          const _BlurCircle(
            diameter: 934,
            sigma: 295.5,
            offset: Offset(27, 419),
            color: Color(0xFF9EF4E2),
          ),
          const _BlurCircle(
            diameter: 582,
            sigma: 184.14,
            offset: Offset(-229, -163),
            color: Color(0xFF6F87FF),
          ),

          // ------------------------------------------------------------------
          // Main content
          // ------------------------------------------------------------------
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back arrow
                  GestureDetector(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const MapScreen()),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: CustomPaint(
                        size: const Size(36, 34),
                        painter: BackArrowPainter(),
                      ),
                    ),
                  ),

                  const SizedBox(height: 48),

                  // Title
                  Center(
                    child: Text(
                      "What's the vibe today?",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                        color: Color(0xFF3535D1),
                      ),
                    ),
                  ),

                  const SizedBox(height: 48),

                  // Action buttons
                  _ActionButton(
                    title: 'Meetup',
                    subtitle: 'Find people, make plans',
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                    ),
                    shadowColor: const Color(0xFF3B82F6),
                    icon: const Icon(Icons.groups, color: Colors.white, size: 28),
                    onTap: () => _open(context, const MeetupScreen()),
                  ),
                  const SizedBox(height: 32),
                  _ActionButton(
                    title: 'Linkup',
                    subtitle: 'Chill, vibe or just say hey',
                    gradient: const LinearGradient(
                      colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                    ),
                    shadowColor: const Color(0xFF22C55E),
                    icon: const Icon(Icons.link, color: Colors.white, size: 26),
                    onTap: () => _open(context, const LinkupScreen()),
                  ),
                  const SizedBox(height: 32),
                  _ActionButton(
                    title: 'Pull up',
                    subtitle: 'Throw a party!',
                    gradient: const LinearGradient(
                      colors: [Color(0xFFA855F7), Color(0xFF9333EA)],
                    ),
                    shadowColor: const Color(0xFFA855F7),
                    icon:
                        const Icon(Icons.arrow_upward, color: Colors.white, size: 26),
                    onTap: () => _open(context, const PullupScreen()),
                  ),

                  const SizedBox(height: 48),

                  // Bottom helper text
                  const Center(
                    child: Text(
                      'Tap any button to get started',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _open(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }
}

// ============================================================================
// Widgets & painters
// ============================================================================

class _BlurCircle extends StatelessWidget {
  const _BlurCircle({
    required this.diameter,
    required this.sigma,
    required this.offset,
    required this.color,
  });

  final double diameter;
  final double sigma;
  final Offset offset;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: offset.dx,
      top: offset.dy,
      child: ClipOval(
        child: Container(
          width: diameter,
          height: diameter,
          color: color.withOpacity(0.8),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
            child: const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.shadowColor,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final Gradient gradient;
  final Color shadowColor;
  final Widget icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 104,
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 336),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF3F4F6)),
          boxShadow: [
            BoxShadow(
              color: shadowColor.withOpacity(0.2),
              blurRadius: 6,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: shadowColor.withOpacity(0.2),
              blurRadius: 15,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Padding(
          padding: const EdgeInsets.all(25),
          child: Row(
            children: [
              // Icon container
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Center(child: icon),
              ),
              const SizedBox(width: 16),
              // Text column
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                        height: 1.3,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF6B7280),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              CustomPaint(
                size: const Size(10, 16),
                painter: ChevronRightPainter(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- painters for arrow & chevron (unchanged) -------------------------------

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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ChevronRightPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF9CA3AF)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(9.70624, 7.29377)
      ..cubicTo(10.0969, 7.6844, 10.0969, 8.31877, 9.70624, 8.7094)
      ..lineTo(3.70624, 14.7094)
      ..cubicTo(3.31562, 15.1, 2.68124, 15.1, 2.29062, 14.7094)
      ..cubicTo(1.89999, 14.3188, 1.89999, 13.6844, 2.29062, 13.2938)
      ..lineTo(7.58437, 8.00002)
      ..lineTo(2.29374, 2.70627)
      ..cubicTo(1.90312, 2.31565, 1.90312, 1.68127, 2.29374, 1.29065)
      ..cubicTo(2.68437, 0.900024, 3.31874, 0.900024, 3.70937, 1.29065)
      ..lineTo(9.70937, 7.29065)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
