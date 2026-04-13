// Procedural asset generator — outputs per-frame PNGs from pure Canvas code.
//
// Run:  cd app && flutter test test/generate_asset.dart
//
// Reads asset_descriptor.json from app/ root.
// Outputs one PNG per frame to assets/generated/{name}/
//
// Descriptor fields:
//   name       — asset name (used as output subfolder)
//   width      — frame width in px
//   height     — frame height in px
//   frames     — number of animation frames
//   output_dir — root output directory (default: assets/generated)
//   type       — draw function to use (default: same as name)
//   colors     — hex color palette for the asset
//   style      — visual flags (glow, iridescent, etc.)

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('generate asset frames', () async {
    final descriptorFile = File('asset_descriptor.json');
    if (!descriptorFile.existsSync()) {
      fail('asset_descriptor.json not found in app/ root');
    }

    final desc =
        jsonDecode(descriptorFile.readAsStringSync()) as Map<String, dynamic>;

    final name = desc['name'] as String;
    final width = desc['width'] as int;
    final height = desc['height'] as int;
    final frames = desc['frames'] as int;
    final outputDir = (desc['output_dir'] as String?) ?? 'assets/generated';
    final assetType = (desc['type'] as String?) ?? name;
    final colors = Map<String, dynamic>.from(desc['colors'] as Map? ?? {});
    final style = Map<String, dynamic>.from(desc['style'] as Map? ?? {});

    final folder = Directory('$outputDir/$name');
    if (!folder.existsSync()) folder.createSync(recursive: true);

    debugPrint('Generating $frames frames for "$name" at ${width}x$height');
    debugPrint('Output → ${folder.path}');

    for (int i = 0; i < frames; i++) {
      final double progress = i / frames; // 0.0 → ~1.0

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(
        recorder,
        Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      );

      _drawAsset(
        type: assetType,
        canvas: canvas,
        width: width.toDouble(),
        height: height.toDouble(),
        progress: progress,
        colors: colors,
        style: style,
      );

      final picture = recorder.endRecording();
      final img = await picture.toImage(width, height);
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) fail('Failed to encode frame $i as PNG');

      final frameNum = (i + 1).toString().padLeft(3, '0');
      final file = File('${folder.path}/frame_$frameNum.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());
      debugPrint('  frame_$frameNum.png');
    }

    debugPrint('Done. $frames PNGs written to ${folder.path}');
  });
}

// ─── Asset dispatcher ──────────────────────────────────────────────

void _drawAsset({
  required String type,
  required Canvas canvas,
  required double width,
  required double height,
  required double progress,
  required Map<String, dynamic> colors,
  required Map<String, dynamic> style,
}) {
  switch (type) {
    case 'butterfly':
      _drawButterfly(
        canvas: canvas,
        width: width,
        height: height,
        progress: progress,
        colors: colors,
        style: style,
      );
    case 'devil':
      _drawDevil(
        canvas: canvas,
        width: width,
        height: height,
        progress: progress,
        colors: colors,
        style: style,
      );
    default:
      _drawButterfly(
        canvas: canvas,
        width: width,
        height: height,
        progress: progress,
        colors: colors,
        style: style,
      );
  }
}

// ─── Butterfly ─────────────────────────────────────────────────────

void _drawButterfly({
  required Canvas canvas,
  required double width,
  required double height,
  required double progress,
  required Map<String, dynamic> colors,
  required Map<String, dynamic> style,
}) {
  final cx = width / 2;
  final cy = height / 2;

  // One full flap cycle over all frames
  final flapAngle = sin(progress * 2 * pi) * 0.55;

  final glowEnabled = (style['glow_enabled'] as bool?) ?? true;
  final iridescent = (style['iridescent'] as bool?) ?? true;

  final wingPrimary = _hex(colors['wing_primary'] as String? ?? '#7B2FBE');
  final wingSecondary = _hex(colors['wing_secondary'] as String? ?? '#E040FB');
  final wingHighlight = _hex(colors['wing_highlight'] as String? ?? '#F8BBD9');
  final wingDark = _hex(colors['wing_dark'] as String? ?? '#4A148C');
  final bodyColor = _hex(colors['body'] as String? ?? '#1A237E');
  final antennaColor = _hex(colors['antenna'] as String? ?? '#311B92');
  final glowColor = _hex(colors['glow'] as String? ?? '#CE93D8');

  final iridShift = iridescent ? progress * 0.3 : 0.0;

  canvas.save();
  canvas.translate(cx, cy);

  // Glow pass
  if (glowEnabled) {
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: width * 0.85,
        height: height * 0.75,
      ),
      Paint()
        ..color = _withAlpha(glowColor, 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
  }

  // Upper wings
  _drawWingPair(
    canvas: canvas,
    width: width,
    height: height,
    flapAngle: flapAngle,
    isUpper: true,
    primary: _shiftHue(wingPrimary, iridShift),
    secondary: _shiftHue(wingSecondary, iridShift),
    highlight: wingHighlight,
    dark: wingDark,
    glowEnabled: glowEnabled,
    glowColor: glowColor,
  );

  // Lower wings
  _drawWingPair(
    canvas: canvas,
    width: width,
    height: height,
    flapAngle: flapAngle * 0.75,
    isUpper: false,
    primary: _shiftHue(wingSecondary, iridShift),
    secondary: _shiftHue(wingPrimary, iridShift),
    highlight: wingHighlight,
    dark: wingDark,
    glowEnabled: glowEnabled,
    glowColor: glowColor,
  );

  // Body
  _drawBody(
    canvas: canvas,
    width: width,
    height: height,
    bodyColor: bodyColor,
    antennaColor: antennaColor,
    flapAngle: flapAngle,
  );

  canvas.restore();
}

// ─── Wing pair (mirrored left & right) ─────────────────────────────

void _drawWingPair({
  required Canvas canvas,
  required double width,
  required double height,
  required double flapAngle,
  required bool isUpper,
  required Color primary,
  required Color secondary,
  required Color highlight,
  required Color dark,
  required bool glowEnabled,
  required Color glowColor,
}) {
  final ww = width * 0.42;
  final wh = isUpper ? height * 0.35 : height * 0.25;
  final yOffset = isUpper ? -height * 0.1 : height * 0.15;

  for (final side in <int>[-1, 1]) {
    canvas.save();
    canvas.scale(side.toDouble(), 1.0);

    canvas.save();
    canvas.translate(width * 0.04, yOffset);
    canvas.transform(Matrix4.rotationZ(flapAngle * side * -1).storage);

    final path = _wingPath(ww, wh, isUpper);

    // Gradient fill
    final gradient = ui.Gradient.radial(
      const Offset(0, 0) + Offset(ww * 0.3, 0),
      ww * 0.9,
      [
        _withAlpha(highlight, 0.95),
        _withAlpha(primary, 0.9),
        _withAlpha(secondary, 0.85),
        _withAlpha(dark, 0.8),
      ],
      [0.0, 0.3, 0.65, 1.0],
    );
    canvas.drawPath(path, Paint()..shader = gradient);

    // Wing veins
    _drawVeins(
      canvas,
      ww,
      Paint()
        ..color = _withAlpha(dark, 0.25)
        ..strokeWidth = width * 0.008
        ..style = PaintingStyle.stroke,
    );

    // Edge glow
    if (glowEnabled) {
      canvas.drawPath(
        path,
        Paint()
          ..color = _withAlpha(glowColor, 0.3)
          ..strokeWidth = width * 0.012
          ..style = PaintingStyle.stroke
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, width * 0.015),
      );
    }

    // Crisp edge
    canvas.drawPath(
      path,
      Paint()
        ..color = _withAlpha(dark, 0.5)
        ..strokeWidth = width * 0.008
        ..style = PaintingStyle.stroke,
    );

    // Highlight spots
    _drawWingSpots(canvas, ww, wh, highlight, isUpper);

    canvas.restore();
    canvas.restore();
  }
}

Path _wingPath(double ww, double wh, bool isUpper) {
  final path = Path();
  if (isUpper) {
    path.moveTo(0, 0);
    path.cubicTo(
        ww * 0.1, -wh * 0.8, ww * 0.7, -wh * 1.1, ww, -wh * 0.4);
    path.cubicTo(
        ww * 1.05, wh * 0.1, ww * 0.6, wh * 0.55, ww * 0.2, wh * 0.5);
    path.cubicTo(ww * 0.1, wh * 0.4, 0, wh * 0.2, 0, 0);
  } else {
    path.moveTo(0, 0);
    path.cubicTo(ww * 0.2, wh * 0.2, ww * 0.8, wh * 0.3, ww, wh * 0.1);
    path.cubicTo(
        ww * 1.05, -wh * 0.2, ww * 0.6, -wh * 0.9, ww * 0.15, -wh * 0.8);
    path.cubicTo(ww * 0.05, -wh * 0.5, 0, -wh * 0.2, 0, 0);
  }
  path.close();
  return path;
}

void _drawVeins(Canvas canvas, double ww, Paint paint) {
  for (int v = 0; v < 3; v++) {
    final angle = -0.4 + v * 0.35;
    final path = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(
        ww * 0.4 * cos(angle),
        ww * 0.4 * sin(angle),
        ww * 0.8 * cos(angle),
        ww * 0.75 * sin(angle),
      );
    canvas.drawPath(path, paint);
  }
}

void _drawWingSpots(
    Canvas canvas, double ww, double wh, Color highlight, bool isUpper) {
  final spotPaint = Paint()
    ..color = _withAlpha(highlight, 0.45)
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, ww * 0.04);

  final spots = isUpper
      ? [Offset(ww * 0.55, -wh * 0.3), Offset(ww * 0.75, wh * 0.1)]
      : [Offset(ww * 0.5, wh * 0.05)];

  for (final spot in spots) {
    canvas.drawCircle(spot, ww * 0.08, spotPaint);
  }
}

// ─── Body, head, antennae ──────────────────────────────────────────

void _drawBody({
  required Canvas canvas,
  required double width,
  required double height,
  required Color bodyColor,
  required Color antennaColor,
  required double flapAngle,
}) {
  final bw = width * 0.07;
  final bh = height * 0.42;

  // Body gradient
  final bodyGrad = ui.Gradient.linear(
    Offset(-bw, -bh / 2),
    Offset(bw, bh / 2),
    [_withAlpha(bodyColor, 0.6), bodyColor, _withAlpha(bodyColor, 0.7)],
    [0.0, 0.5, 1.0],
  );
  canvas.drawOval(
    Rect.fromCenter(center: Offset.zero, width: bw, height: bh),
    Paint()..shader = bodyGrad,
  );

  // Body highlight
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(-bw * 0.15, -bh * 0.1),
      width: bw * 0.3,
      height: bh * 0.4,
    ),
    Paint()..color = _withAlpha(Colors.white, 0.18),
  );

  // Head
  canvas.drawCircle(
    Offset(0, -bh / 2 - bw * 0.4),
    bw * 0.55,
    Paint()..color = bodyColor,
  );

  // Antennae
  final antennaPaint = Paint()
    ..color = antennaColor
    ..strokeWidth = width * 0.012
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  final antennaSway = flapAngle * 0.3;
  for (final side in <int>[-1, 1]) {
    final tipX = side * width * 0.14 + antennaSway * side * 8;
    final tipY = -bh / 2 - bh * 0.42;

    final path = Path()
      ..moveTo(0, -bh / 2 - bw * 0.3)
      ..quadraticBezierTo(
        side * width * 0.08 + antennaSway * side * 5,
        -bh / 2 - bh * 0.28,
        tipX,
        tipY,
      );
    canvas.drawPath(path, antennaPaint);

    // Antenna tip bulb
    canvas.drawCircle(
      Offset(tipX, tipY),
      width * 0.022,
      Paint()..color = antennaColor,
    );
  }
}

// ─── Devil ────────────────────────────────────────────────────────

void _drawDevil({
  required Canvas canvas,
  required double width,
  required double height,
  required double progress,
  required Map<String, dynamic> colors,
  required Map<String, dynamic> style,
}) {
  final cx = width / 2;
  final cy = height / 2;

  // Colors from descriptor or defaults
  final skinColor = _hex(colors['skin'] as String? ?? '#F5E6E0');
  final skinShadow = _hex(colors['skin_shadow'] as String? ?? '#E8C4B8');
  final hairColor = _hex(colors['hair'] as String? ?? '#1A0A0A');
  final hornColor = _hex(colors['horn'] as String? ?? '#3D0C02');
  final hornTip = _hex(colors['horn_tip'] as String? ?? '#8B1A1A');
  final lipColor = _hex(colors['lips'] as String? ?? '#CC0033');
  final eyeColor = _hex(colors['eyes'] as String? ?? '#FF4500');
  final outfitColor = _hex(colors['outfit'] as String? ?? '#2D0014');
  final outfitAccent = _hex(colors['outfit_accent'] as String? ?? '#8B0000');
  final tailColor = _hex(colors['tail'] as String? ?? '#6B0020');
  final heartColor = _hex(colors['heart'] as String? ?? '#FF1744');
  final glowCol = _hex(colors['glow'] as String? ?? '#FF0044');

  final glowEnabled = (style['glow_enabled'] as bool?) ?? true;
  final tailSway = sin(progress * 2 * pi) * 0.3;
  final breathe = sin(progress * 2 * pi) * 0.008;
  final kissProgress = (sin(progress * 2 * pi * 0.5 + pi / 4) + 1) / 2;

  canvas.save();
  canvas.translate(cx, cy);

  // Ambient glow behind character
  if (glowEnabled) {
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, height * 0.05),
        width: width * 0.7,
        height: height * 0.85,
      ),
      Paint()
        ..color = _withAlpha(glowCol, 0.08)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, width * 0.08),
    );
  }

  // ─── Tail (behind body) ───
  _drawDevilTail(
    canvas: canvas,
    width: width,
    height: height,
    tailColor: tailColor,
    sway: tailSway,
  );

  // ─── Hair back layer (behind body) ───
  _drawDevilHairBack(
    canvas: canvas,
    width: width,
    height: height,
    hairColor: hairColor,
    progress: progress,
  );

  // ─── Body / outfit ───
  _drawDevilBody(
    canvas: canvas,
    width: width,
    height: height,
    skinColor: skinColor,
    skinShadow: skinShadow,
    outfitColor: outfitColor,
    outfitAccent: outfitAccent,
    breathe: breathe,
  );

  // ─── Neck & face ───
  _drawDevilFace(
    canvas: canvas,
    width: width,
    height: height,
    skinColor: skinColor,
    skinShadow: skinShadow,
    eyeColor: eyeColor,
    lipColor: lipColor,
    hairColor: hairColor,
    progress: progress,
  );

  // ─── Horns ───
  _drawDevilHorns(
    canvas: canvas,
    width: width,
    height: height,
    hornColor: hornColor,
    hornTip: hornTip,
  );

  // ─── Hair front layer ───
  _drawDevilHairFront(
    canvas: canvas,
    width: width,
    height: height,
    hairColor: hairColor,
    progress: progress,
  );

  // ─── Blowing kiss hand ───
  _drawDevilKissHand(
    canvas: canvas,
    width: width,
    height: height,
    skinColor: skinColor,
    skinShadow: skinShadow,
    lipColor: lipColor,
    kissProgress: kissProgress,
  );

  // ─── Floating hearts ───
  _drawFloatingHearts(
    canvas: canvas,
    width: width,
    height: height,
    heartColor: heartColor,
    progress: progress,
  );

  canvas.restore();
}

// ─── Devil: Tail ──────────────────────────────────────────────────

void _drawDevilTail({
  required Canvas canvas,
  required double width,
  required double height,
  required Color tailColor,
  required double sway,
}) {
  final tailPaint = Paint()
    ..color = tailColor
    ..strokeWidth = width * 0.025
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  final tailStart = Offset(width * 0.05, height * 0.28);
  final tailMid1 = Offset(width * 0.25 + sway * width * 0.15, height * 0.35);
  final tailMid2 = Offset(-width * 0.15 + sway * width * 0.1, height * 0.42);
  final tailEnd = Offset(width * 0.3 + sway * width * 0.2, height * 0.38);

  final tailPath = Path()
    ..moveTo(tailStart.dx, tailStart.dy)
    ..cubicTo(
      tailMid1.dx, tailMid1.dy,
      tailMid2.dx, tailMid2.dy,
      tailEnd.dx, tailEnd.dy,
    );
  canvas.drawPath(tailPath, tailPaint);

  // Spade tip
  final tipSize = width * 0.04;
  final tipPath = Path()
    ..moveTo(tailEnd.dx, tailEnd.dy - tipSize)
    ..quadraticBezierTo(
      tailEnd.dx + tipSize * 1.2, tailEnd.dy,
      tailEnd.dx, tailEnd.dy + tipSize,
    )
    ..quadraticBezierTo(
      tailEnd.dx - tipSize * 1.2, tailEnd.dy,
      tailEnd.dx, tailEnd.dy - tipSize,
    );
  canvas.drawPath(tipPath, Paint()..color = tailColor);
}

// ─── Devil: Hair back layer ───────────────────────────────────────

void _drawDevilHairBack({
  required Canvas canvas,
  required double width,
  required double height,
  required Color hairColor,
  required double progress,
}) {
  final hairSway = sin(progress * 2 * pi) * width * 0.01;

  // Long flowing hair behind shoulders
  final hairPath = Path();
  hairPath.moveTo(-width * 0.15, -height * 0.22);
  hairPath.cubicTo(
    -width * 0.22 + hairSway, -height * 0.05,
    -width * 0.2 + hairSway, height * 0.15,
    -width * 0.14 + hairSway * 0.5, height * 0.25,
  );
  hairPath.lineTo(-width * 0.06, height * 0.22);
  hairPath.cubicTo(
    -width * 0.1, height * 0.1,
    -width * 0.12, -height * 0.05,
    -width * 0.1, -height * 0.2,
  );
  hairPath.close();
  canvas.drawPath(hairPath, Paint()..color = hairColor);

  // Right side
  final hairPath2 = Path();
  hairPath2.moveTo(width * 0.15, -height * 0.22);
  hairPath2.cubicTo(
    width * 0.22 - hairSway, -height * 0.05,
    width * 0.2 - hairSway, height * 0.15,
    width * 0.14 - hairSway * 0.5, height * 0.25,
  );
  hairPath2.lineTo(width * 0.06, height * 0.22);
  hairPath2.cubicTo(
    width * 0.1, height * 0.1,
    width * 0.12, -height * 0.05,
    width * 0.1, -height * 0.2,
  );
  hairPath2.close();
  canvas.drawPath(hairPath2, Paint()..color = hairColor);
}

// ─── Devil: Body & outfit ─────────────────────────────────────────

void _drawDevilBody({
  required Canvas canvas,
  required double width,
  required double height,
  required Color skinColor,
  required Color skinShadow,
  required Color outfitColor,
  required Color outfitAccent,
  required double breathe,
}) {
  // Neck
  canvas.drawRect(
    Rect.fromCenter(
      center: Offset(0, -height * 0.15),
      width: width * 0.06,
      height: height * 0.06,
    ),
    Paint()..color = skinColor,
  );

  // Shoulders / upper body
  final bodyPath = Path();
  bodyPath.moveTo(-width * 0.04, -height * 0.14);
  // Left shoulder
  bodyPath.cubicTo(
    -width * 0.12, -height * 0.12,
    -width * (0.18 + breathe), -height * 0.08,
    -width * (0.17 + breathe), height * 0.0,
  );
  // Left side
  bodyPath.cubicTo(
    -width * (0.15 + breathe), height * 0.12,
    -width * (0.12 + breathe), height * 0.25,
    -width * 0.1, height * 0.45,
  );
  // Bottom
  bodyPath.lineTo(width * 0.1, height * 0.45);
  // Right side
  bodyPath.cubicTo(
    width * (0.12 + breathe), height * 0.25,
    width * (0.15 + breathe), height * 0.12,
    width * (0.17 + breathe), height * 0.0,
  );
  // Right shoulder
  bodyPath.cubicTo(
    width * (0.18 + breathe), -height * 0.08,
    width * 0.12, -height * 0.12,
    width * 0.04, -height * 0.14,
  );
  bodyPath.close();

  // Outfit gradient
  final outfitGrad = ui.Gradient.linear(
    Offset(0, -height * 0.14),
    Offset(0, height * 0.45),
    [outfitColor, outfitAccent, outfitColor],
    [0.0, 0.5, 1.0],
  );
  canvas.drawPath(bodyPath, Paint()..shader = outfitGrad);

  // Neckline V-cut (skin showing)
  final necklinePath = Path();
  necklinePath.moveTo(-width * 0.06, -height * 0.13);
  necklinePath.lineTo(0, -height * 0.05);
  necklinePath.lineTo(width * 0.06, -height * 0.13);
  canvas.drawPath(
    necklinePath,
    Paint()
      ..color = skinColor
      ..style = PaintingStyle.fill,
  );

  // Collarbone shadow
  canvas.drawPath(
    necklinePath,
    Paint()
      ..color = _withAlpha(skinShadow, 0.4)
      ..strokeWidth = width * 0.004
      ..style = PaintingStyle.stroke,
  );

  // Outfit edge accent lines
  canvas.drawPath(
    bodyPath,
    Paint()
      ..color = _withAlpha(outfitAccent, 0.6)
      ..strokeWidth = width * 0.006
      ..style = PaintingStyle.stroke,
  );

  // Shoulders skin (bare shoulders)
  for (final side in [-1.0, 1.0]) {
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(side * width * 0.15, -height * 0.1),
        width: width * 0.08,
        height: height * 0.04,
      ),
      Paint()..color = skinColor,
    );
    // Shoulder shadow
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(side * width * 0.155, -height * 0.09),
        width: width * 0.06,
        height: height * 0.015,
      ),
      Paint()..color = _withAlpha(skinShadow, 0.3),
    );
  }
}

// ─── Devil: Face ──────────────────────────────────────────────────

void _drawDevilFace({
  required Canvas canvas,
  required double width,
  required double height,
  required Color skinColor,
  required Color skinShadow,
  required Color eyeColor,
  required Color lipColor,
  required Color hairColor,
  required double progress,
}) {
  final headCy = -height * 0.26;
  final headW = width * 0.17;
  final headH = height * 0.12;

  // Head shape (oval, slightly narrower at chin)
  final headPath = Path();
  headPath.moveTo(0, headCy - headH);
  headPath.cubicTo(
    headW, headCy - headH,
    headW * 1.05, headCy + headH * 0.3,
    headW * 0.65, headCy + headH,
  );
  headPath.cubicTo(
    headW * 0.3, headCy + headH * 1.3,
    -headW * 0.3, headCy + headH * 1.3,
    -headW * 0.65, headCy + headH,
  );
  headPath.cubicTo(
    -headW * 1.05, headCy + headH * 0.3,
    -headW, headCy - headH,
    0, headCy - headH,
  );
  headPath.close();

  // Face skin gradient
  final faceGrad = ui.Gradient.radial(
    Offset(-headW * 0.15, headCy - headH * 0.2),
    headW * 1.3,
    [skinColor, skinShadow],
    [0.6, 1.0],
  );
  canvas.drawPath(headPath, Paint()..shader = faceGrad);

  // Cheek blush
  for (final side in [-1.0, 1.0]) {
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(side * headW * 0.55, headCy + headH * 0.4),
        width: headW * 0.35,
        height: headH * 0.25,
      ),
      Paint()
        ..color = _withAlpha(_hex('#FFB3B3'), 0.25)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, headW * 0.1),
    );
  }

  // Eyes
  final eyeY = headCy - headH * 0.05;
  final eyeSpacing = headW * 0.42;
  for (final side in [-1.0, 1.0]) {
    final eyeX = side * eyeSpacing;

    // Eye white
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(eyeX, eyeY),
        width: headW * 0.38,
        height: headH * 0.32,
      ),
      Paint()..color = Colors.white,
    );

    // Iris
    canvas.drawCircle(
      Offset(eyeX + side * headW * 0.02, eyeY),
      headW * 0.13,
      Paint()..color = eyeColor,
    );

    // Pupil
    canvas.drawCircle(
      Offset(eyeX + side * headW * 0.02, eyeY),
      headW * 0.06,
      Paint()..color = _hex('#0A0A0A'),
    );

    // Pupil highlight
    canvas.drawCircle(
      Offset(eyeX + side * headW * 0.06, eyeY - headH * 0.08),
      headW * 0.035,
      Paint()..color = _withAlpha(Colors.white, 0.85),
    );

    // Eyelashes (top)
    final lashPaint = Paint()
      ..color = _withAlpha(hairColor, 0.9)
      ..strokeWidth = width * 0.006
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final lashPath = Path();
    lashPath.moveTo(eyeX - headW * 0.2, eyeY);
    lashPath.cubicTo(
      eyeX - headW * 0.1, eyeY - headH * 0.25,
      eyeX + headW * 0.1, eyeY - headH * 0.25,
      eyeX + headW * 0.2, eyeY - headH * 0.05,
    );
    canvas.drawPath(lashPath, lashPaint);

    // Wing eyeliner (outer corner)
    final wingPath = Path()
      ..moveTo(eyeX + side * headW * 0.18, eyeY - headH * 0.05)
      ..lineTo(eyeX + side * headW * 0.25, eyeY - headH * 0.14);
    canvas.drawPath(wingPath, lashPaint);

    // Wink on left eye (subtle)
    final winkPhase = sin(progress * 2 * pi * 2);
    if (side < 0 && winkPhase > 0.85) {
      // Close left eye for a wink
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(eyeX, eyeY),
          width: headW * 0.38,
          height: headH * 0.32,
        ),
        Paint()..color = skinColor,
      );
      // Wink line
      canvas.drawPath(lashPath, lashPaint..strokeWidth = width * 0.008);
    }
  }

  // Eyebrows
  for (final side in [-1.0, 1.0]) {
    final browPath = Path()
      ..moveTo(side * (eyeSpacing - headW * 0.2), eyeY - headH * 0.35)
      ..quadraticBezierTo(
        side * eyeSpacing, eyeY - headH * 0.52,
        side * (eyeSpacing + headW * 0.22), eyeY - headH * 0.3,
      );
    canvas.drawPath(
      browPath,
      Paint()
        ..color = hairColor
        ..strokeWidth = width * 0.008
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  // Nose (subtle)
  canvas.drawPath(
    Path()
      ..moveTo(0, headCy + headH * 0.1)
      ..lineTo(headW * 0.06, headCy + headH * 0.35)
      ..lineTo(-headW * 0.02, headCy + headH * 0.38),
    Paint()
      ..color = _withAlpha(skinShadow, 0.4)
      ..strokeWidth = width * 0.004
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round,
  );

  // Lips (kiss pose — pursed)
  final lipCy = headCy + headH * 0.65;
  final lipW = headW * 0.3;
  final lipH = headH * 0.2;

  // Upper lip (cupid's bow, slightly pursed)
  final upperLipPath = Path();
  upperLipPath.moveTo(-lipW, lipCy);
  upperLipPath.cubicTo(
    -lipW * 0.5, lipCy - lipH * 1.2,
    0, lipCy - lipH * 0.5,
    0, lipCy - lipH * 0.3,
  );
  upperLipPath.cubicTo(
    0, lipCy - lipH * 0.5,
    lipW * 0.5, lipCy - lipH * 1.2,
    lipW, lipCy,
  );
  canvas.drawPath(upperLipPath, Paint()..color = lipColor);

  // Lower lip
  final lowerLipPath = Path();
  lowerLipPath.moveTo(-lipW, lipCy);
  lowerLipPath.cubicTo(
    -lipW * 0.4, lipCy + lipH * 1.5,
    lipW * 0.4, lipCy + lipH * 1.5,
    lipW, lipCy,
  );
  canvas.drawPath(lowerLipPath, Paint()..color = lipColor);

  // Lip highlight
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(lipW * 0.1, lipCy + lipH * 0.3),
      width: lipW * 0.5,
      height: lipH * 0.5,
    ),
    Paint()..color = _withAlpha(Colors.white, 0.2),
  );
}

// ─── Devil: Horns ─────────────────────────────────────────────────

void _drawDevilHorns({
  required Canvas canvas,
  required double width,
  required double height,
  required Color hornColor,
  required Color hornTip,
}) {
  final headTop = -height * 0.38;
  final hornH = height * 0.12;

  for (final side in [-1.0, 1.0]) {
    final baseX = side * width * 0.1;
    final baseY = headTop + height * 0.02;

    // Horn shape
    final hornPath = Path();
    hornPath.moveTo(baseX - side * width * 0.03, baseY);
    hornPath.cubicTo(
      baseX + side * width * 0.01, baseY - hornH * 0.5,
      baseX + side * width * 0.08, baseY - hornH * 0.8,
      baseX + side * width * 0.1, baseY - hornH,
    );
    hornPath.cubicTo(
      baseX + side * width * 0.07, baseY - hornH * 0.7,
      baseX + side * width * 0.03, baseY - hornH * 0.4,
      baseX + side * width * 0.02, baseY,
    );
    hornPath.close();

    // Horn gradient (dark at base, reddish at tip)
    final hornGrad = ui.Gradient.linear(
      Offset(baseX, baseY),
      Offset(baseX + side * width * 0.1, baseY - hornH),
      [hornColor, hornTip],
    );
    canvas.drawPath(hornPath, Paint()..shader = hornGrad);

    // Horn edge
    canvas.drawPath(
      hornPath,
      Paint()
        ..color = _withAlpha(hornColor, 0.6)
        ..strokeWidth = width * 0.004
        ..style = PaintingStyle.stroke,
    );

    // Horn highlight
    canvas.drawPath(
      Path()
        ..moveTo(baseX - side * width * 0.01, baseY - hornH * 0.1)
        ..quadraticBezierTo(
          baseX + side * width * 0.04, baseY - hornH * 0.5,
          baseX + side * width * 0.08, baseY - hornH * 0.85,
        ),
      Paint()
        ..color = _withAlpha(Colors.white, 0.15)
        ..strokeWidth = width * 0.005
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }
}

// ─── Devil: Hair front layer ──────────────────────────────────────

void _drawDevilHairFront({
  required Canvas canvas,
  required double width,
  required double height,
  required Color hairColor,
  required double progress,
}) {
  final hairSway = sin(progress * 2 * pi) * width * 0.005;
  final headTop = -height * 0.38;

  // Bangs / fringe
  final bangPath = Path();
  bangPath.moveTo(-width * 0.16, -height * 0.22);
  bangPath.cubicTo(
    -width * 0.14, headTop,
    -width * 0.05, headTop - height * 0.02,
    0, headTop,
  );
  bangPath.cubicTo(
    width * 0.05, headTop - height * 0.02,
    width * 0.14, headTop,
    width * 0.16, -height * 0.22,
  );
  bangPath.lineTo(width * 0.12, -height * 0.2);
  bangPath.cubicTo(
    width * 0.08, headTop + height * 0.04,
    width * 0.02, headTop + height * 0.03,
    0, headTop + height * 0.05,
  );
  bangPath.cubicTo(
    -width * 0.02, headTop + height * 0.03,
    -width * 0.08, headTop + height * 0.04,
    -width * 0.12, -height * 0.2,
  );
  bangPath.close();
  canvas.drawPath(bangPath, Paint()..color = hairColor);

  // Side strands falling in front of shoulders
  for (final side in [-1.0, 1.0]) {
    final strandPath = Path();
    strandPath.moveTo(side * width * 0.14, -height * 0.2);
    strandPath.cubicTo(
      side * width * 0.17 + hairSway, -height * 0.1,
      side * width * 0.16 + hairSway, height * 0.0,
      side * width * 0.13 + hairSway, height * 0.08,
    );
    strandPath.lineTo(side * width * 0.1 + hairSway, height * 0.06);
    strandPath.cubicTo(
      side * width * 0.12, -height * 0.02,
      side * width * 0.13, -height * 0.12,
      side * width * 0.11, -height * 0.2,
    );
    strandPath.close();
    canvas.drawPath(strandPath, Paint()..color = hairColor);
  }

  // Hair highlight streaks
  final highlightPaint = Paint()
    ..color = _withAlpha(Colors.white, 0.06)
    ..strokeWidth = width * 0.008
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  for (final offset in [-0.06, 0.03]) {
    canvas.drawPath(
      Path()
        ..moveTo(width * offset, headTop + height * 0.01)
        ..quadraticBezierTo(
          width * offset + hairSway, headTop + height * 0.06,
          width * offset + width * 0.01, -height * 0.18,
        ),
      highlightPaint,
    );
  }
}

// ─── Devil: Blowing kiss hand ─────────────────────────────────────

void _drawDevilKissHand({
  required Canvas canvas,
  required double width,
  required double height,
  required Color skinColor,
  required Color skinShadow,
  required Color lipColor,
  required double kissProgress,
}) {
  // Right hand raised near lips, palm facing camera
  final handX = width * 0.12 + kissProgress * width * 0.04;
  final handY = -height * 0.15 - kissProgress * height * 0.02;
  final handSize = width * 0.045;

  // Forearm
  final armPath = Path()
    ..moveTo(width * 0.17, height * 0.0)
    ..cubicTo(
      width * 0.18, -height * 0.05,
      width * 0.16, -height * 0.1,
      handX, handY,
    );
  canvas.drawPath(
    armPath,
    Paint()
      ..color = skinColor
      ..strokeWidth = width * 0.035
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round,
  );

  // Palm
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(handX, handY),
      width: handSize * 1.6,
      height: handSize * 1.8,
    ),
    Paint()..color = skinColor,
  );

  // Fingers (simplified — 4 fingers curled slightly)
  for (int f = 0; f < 4; f++) {
    final angle = -0.4 + f * 0.25;
    final fingerLen = handSize * 0.8;
    final fx = handX + cos(angle) * fingerLen;
    final fy = handY - sin(angle) * fingerLen - handSize * 0.5;
    canvas.drawLine(
      Offset(handX + cos(angle) * handSize * 0.3,
          handY - handSize * 0.5),
      Offset(fx, fy),
      Paint()
        ..color = skinColor
        ..strokeWidth = width * 0.012
        ..strokeCap = StrokeCap.round,
    );
  }

  // Thumb
  canvas.drawLine(
    Offset(handX - handSize * 0.5, handY),
    Offset(handX - handSize * 0.9, handY - handSize * 0.5),
    Paint()
      ..color = skinColor
      ..strokeWidth = width * 0.012
      ..strokeCap = StrokeCap.round,
  );

  // Lipstick mark on palm
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(handX, handY),
      width: handSize * 0.5,
      height: handSize * 0.35,
    ),
    Paint()..color = _withAlpha(lipColor, 0.3 + kissProgress * 0.2),
  );
}

// ─── Devil: Floating hearts ───────────────────────────────────────

void _drawFloatingHearts({
  required Canvas canvas,
  required double width,
  required double height,
  required Color heartColor,
  required double progress,
}) {
  // 3 hearts at different phases, floating up and to the right
  for (int h = 0; h < 3; h++) {
    final phase = (progress + h * 0.33) % 1.0;
    final heartSize = width * (0.03 - phase * 0.01);
    final alpha = (1.0 - phase).clamp(0.0, 1.0);

    // Float from hand area upward and to the right
    final hx = width * 0.2 + phase * width * 0.15 + sin(phase * pi * 2 + h) * width * 0.03;
    final hy = -height * 0.2 - phase * height * 0.2;

    if (alpha < 0.05) continue;

    _drawHeart(
      canvas: canvas,
      center: Offset(hx, hy),
      size: heartSize,
      color: _withAlpha(heartColor, alpha * 0.8),
    );
  }
}

void _drawHeart({
  required Canvas canvas,
  required Offset center,
  required double size,
  required Color color,
}) {
  final path = Path();
  path.moveTo(center.dx, center.dy + size * 0.4);
  path.cubicTo(
    center.dx - size, center.dy - size * 0.2,
    center.dx - size * 0.5, center.dy - size,
    center.dx, center.dy - size * 0.4,
  );
  path.cubicTo(
    center.dx + size * 0.5, center.dy - size,
    center.dx + size, center.dy - size * 0.2,
    center.dx, center.dy + size * 0.4,
  );
  path.close();
  canvas.drawPath(path, Paint()..color = color);

  // Heart highlight
  canvas.drawCircle(
    Offset(center.dx - size * 0.25, center.dy - size * 0.3),
    size * 0.15,
    Paint()..color = _withAlpha(Colors.white, 0.3),
  );
}

// ─── Helpers ───────────────────────────────────────────────────────

/// Parse hex color string (#RRGGBB or #AARRGGBB) to Color.
Color _hex(String hex) {
  hex = hex.replaceAll('#', '');
  if (hex.length == 6) hex = 'FF$hex';
  final value = int.parse(hex, radix: 16);
  return Color.fromARGB(
    (value >> 24) & 0xFF,
    (value >> 16) & 0xFF,
    (value >> 8) & 0xFF,
    value & 0xFF,
  );
}

/// Return [color] with the given [opacity] (0.0–1.0).
Color _withAlpha(Color color, double opacity) {
  return Color.from(
    alpha: opacity,
    red: color.r,
    green: color.g,
    blue: color.b,
  );
}

/// Shift the hue of [color] by [shift] (0.0–1.0 maps to 0–360 degrees).
Color _shiftHue(Color color, double shift) {
  if (shift == 0) return color;
  final hsl = HSLColor.fromColor(color);
  return hsl.withHue((hsl.hue + shift * 360) % 360).toColor();
}
