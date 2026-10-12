import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// [boundaryKey]の[RepaintBoundary]をPNGに書き出し、[text]と一緒にシェアする。
/// 描画対象が無い・書き出しに失敗した場合は何もせずfalseを返す。
Future<bool> shareBoundaryAsImage({
  required GlobalKey boundaryKey,
  required String text,
  String filePrefix = 'savepoint',
}) async {
  final boundary =
      boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) return false;
  final image = await boundary.toImage(pixelRatio: 3);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  if (byteData == null) return false;
  final dir = await getTemporaryDirectory();
  final file = File(
    '${dir.path}/${filePrefix}_${DateTime.now().millisecondsSinceEpoch}.png',
  );
  await file.writeAsBytes(byteData.buffer.asUint8List());
  await SharePlus.instance.share(
    ShareParams(files: [XFile(file.path)], text: text),
  );
  return true;
}
