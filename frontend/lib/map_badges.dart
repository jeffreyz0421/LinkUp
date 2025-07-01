import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

Future<Uint8List> buildBadgeImage({
  required String text,
  required Color bg,
  required Color fg,
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

  final width = tp.width + pad.horizontal;
  final height = tp.height + pad.vertical;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final rRect =
      RRect.fromLTRBR(0, 0, width, height, Radius.circular(radius));
  final paint = Paint()..color = bg;
  canvas.drawRRect(rRect, paint);

  tp.paint(canvas, Offset(pad.left, pad.top));
  final img = await recorder
      .endRecording()
      .toImage(width.ceil(), height.ceil());
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  return bytes!.buffer.asUint8List();
}
