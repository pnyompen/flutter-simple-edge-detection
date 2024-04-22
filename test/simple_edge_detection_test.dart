import 'package:flutter/services.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as imglib;

import 'package:simple_edge_detection/edge_detection.dart';

void main() {
  const MethodChannel channel = MethodChannel('simple_edge_detection');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      return '42';
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });

  test('detectEdges', () async {
    final imglib.Image image = imglib.Image(width: 100, height: 100);
    expect(
        await EdgeDetection.detectEdges(image),
        EdgeDetectionResult(
            topLeft: Offset(0, 0),
            topRight: Offset(1, 0),
            bottomLeft: Offset(0, 1),
            bottomRight: Offset(1, 1)));
  });
}
