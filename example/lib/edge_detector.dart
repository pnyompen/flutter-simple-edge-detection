import 'dart:async';
import 'dart:isolate';

import 'package:camera/camera.dart';
import 'package:image/image.dart' as imglib;

import 'package:simple_edge_detection/edge_detection.dart';
import 'package:simple_edge_detection_example/camera_image_converter.dart';

class EdgeDetector {
  static Future<void> startEdgeDetectionIsolate(
      EdgeDetectionInput edgeDetectionInput) async {
    final imglib.Image image;
    if (edgeDetectionInput.cameraImage != null) {
      image = CameraImageConverter.convert(edgeDetectionInput.cameraImage!);
    } else {
      image = edgeDetectionInput.image!;
    }
    EdgeDetectionResult result = await EdgeDetection.detectEdges(image);
    edgeDetectionInput.sendPort.send(result);
  }

  static Future<void> processImageIsolate(
      ProcessImageInput processImageInput) async {
    EdgeDetection.processImage(
        processImageInput.inputPath, processImageInput.edgeDetectionResult);
    processImageInput.sendPort.send(true);
  }

  Future<EdgeDetectionResult> detectEdges(imglib.Image image) async {
    final port = ReceivePort();

    _spawnIsolate<EdgeDetectionInput>(startEdgeDetectionIsolate,
        EdgeDetectionInput(image: image, sendPort: port.sendPort), port);

    return await _subscribeToPort<EdgeDetectionResult>(port);
  }

  Future<EdgeDetectionResult> detectEdgesFromCameraImage(
      CameraImage image) async {
    final port = ReceivePort();

    _spawnIsolate<EdgeDetectionInput>(startEdgeDetectionIsolate,
        EdgeDetectionInput(cameraImage: image, sendPort: port.sendPort), port);

    return await _subscribeToPort<EdgeDetectionResult>(port);
  }

  Future<bool> processImage(
      String filePath, EdgeDetectionResult edgeDetectionResult) async {
    final port = ReceivePort();

    _spawnIsolate<ProcessImageInput>(
        processImageIsolate,
        ProcessImageInput(
            inputPath: filePath,
            edgeDetectionResult: edgeDetectionResult,
            sendPort: port.sendPort),
        port);

    return await _subscribeToPort<bool>(port);
  }

  void _spawnIsolate<T>(
      void Function(T) function, dynamic input, ReceivePort port) {
    Isolate.spawn<T>(function, input,
        onError: port.sendPort, onExit: port.sendPort);
  }

  Future<T> _subscribeToPort<T>(ReceivePort port) async {
    StreamSubscription? sub;

    var completer = new Completer<T>();

    sub = port.listen((result) async {
      await sub?.cancel();
      completer.complete(await result);
    });

    return completer.future;
  }
}

class EdgeDetectionInput {
  EdgeDetectionInput({this.image, this.cameraImage, required this.sendPort}) {
    if (image == null && cameraImage == null) {
      throw ArgumentError('Either image or cameraImage must be provided');
    }
  }

  imglib.Image? image;
  CameraImage? cameraImage;
  SendPort sendPort;
}

class ProcessImageInput {
  ProcessImageInput(
      {required this.inputPath,
      required this.edgeDetectionResult,
      required this.sendPort});

  String inputPath;
  EdgeDetectionResult edgeDetectionResult;
  SendPort sendPort;
}
