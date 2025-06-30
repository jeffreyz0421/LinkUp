import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

Future<Uint8List> buildBadgeImage({
  required String text,
  required Color bg,
  required Color fg,
  required Color border,
  required double borderW,
  double fontSize = 14,
  EdgeInsets pad = const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
  double radius = 10,
}) async {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: 'ChalkboardSE-Bold',
        fontSize: fontSize,
        color: fg,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  final w = tp.width  + pad.horizontal;
  final h = tp.height + pad.vertical;

  final rec = ui.PictureRecorder();
  final c   = Canvas(rec);
  final r   = RRect.fromLTRBR(0, 0, w, h, Radius.circular(radius));

  // border
  final borderPaint = Paint()
    ..color   = border
    ..style   = PaintingStyle.stroke
    ..strokeWidth = borderW;
  c.drawRRect(r, borderPaint);

  // fill
  final fillPaint = Paint()..color = bg;
  c.drawRRect(r.deflate(borderW / 2), fillPaint);

  tp.paint(c, Offset(pad.left, pad.top));

  final img   = await rec.endRecording().toImage(w.ceil(), h.ceil());
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  return bytes!.buffer.asUint8List();
}
