import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:ffi/ffi.dart';
import 'package:image/image.dart' as imglib;

class Coordinate extends Struct {
  @Double()
  external double x;

  @Double()
  external double y;

  factory Coordinate.allocate(double x, double y) => malloc<Coordinate>().ref
    ..x = x
    ..y = y;
}

class NativeDetectionResult extends Struct {
  external Pointer<Coordinate> topLeft;
  external Pointer<Coordinate> topRight;
  external Pointer<Coordinate> bottomLeft;
  external Pointer<Coordinate> bottomRight;

  factory NativeDetectionResult.allocate(
          Pointer<Coordinate> topLeft,
          Pointer<Coordinate> topRight,
          Pointer<Coordinate> bottomLeft,
          Pointer<Coordinate> bottomRight) =>
      malloc<NativeDetectionResult>().ref
        ..topLeft = topLeft
        ..topRight = topRight
        ..bottomLeft = bottomLeft
        ..bottomRight = bottomRight;
}

class EdgeDetectionResult {
  EdgeDetectionResult({
    required this.topLeft,
    required this.topRight,
    required this.bottomLeft,
    required this.bottomRight,
  });

  final Offset topLeft;
  final Offset topRight;
  final Offset bottomLeft;
  final Offset bottomRight;

  EdgeDetectionResult copyWith({
    Offset? topLeft,
    Offset? topRight,
    Offset? bottomLeft,
    Offset? bottomRight,
  }) {
    return EdgeDetectionResult(
      topLeft: topLeft ?? this.topLeft,
      topRight: topRight ?? this.topRight,
      bottomLeft: bottomLeft ?? this.bottomLeft,
      bottomRight: bottomRight ?? this.bottomRight,
    );
  }

  EdgeDetectionResult copy() {
    return EdgeDetectionResult(
      topLeft: topLeft,
      topRight: topRight,
      bottomLeft: bottomLeft,
      bottomRight: bottomRight,
    );
  }

  EdgeDetectionResult updateOffsetByIndex(int index, Offset offset) {
    switch (index) {
      case 0:
        return copyWith(topLeft: offset);
      case 1:
        return copyWith(topRight: offset);
      case 2:
        return copyWith(bottomRight: offset);
      case 3:
        return copyWith(bottomLeft: offset);
      default:
        throw Exception('Invalid index');
    }
  }

  Offset getOffsetByIndex(int index) {
    switch (index) {
      case 0:
        return topLeft;
      case 1:
        return topRight;
      case 2:
        return bottomRight;
      case 3:
        return bottomLeft;
      default:
        throw Exception('Invalid index');
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is EdgeDetectionResult &&
        other.topLeft == topLeft &&
        other.topRight == topRight &&
        other.bottomLeft == bottomLeft &&
        other.bottomRight == bottomRight;
  }

  @override
  String toString() {
    return 'EdgeDetectionResult{$topLeft, $topRight, $bottomLeft, $bottomRight}';
  }
}

class DebugSquaresResult extends Struct {
  external Pointer<Uint8> data;
  @Int32()
  external int width;
  @Int32()
  external int height;
}

typedef detect_edges_function = Pointer<NativeDetectionResult> Function(
    Pointer<Uint8> imageData, Int32 width, Int32 height);
typedef DetectEdgesFunction = Pointer<NativeDetectionResult> Function(
    Pointer<Uint8> imageData, int width, int height);

typedef debug_squares_func = Pointer<DebugSquaresResult> Function(
    Pointer<Uint8> data, Int32 width, Int32 height);
typedef DebugSquaresFunc = Pointer<DebugSquaresResult> Function(
    Pointer<Uint8> data, int width, int height);

typedef process_image_function = Int8 Function(
    Pointer<Utf8> imagePath,
    Double topLeftX,
    Double topLeftY,
    Double topRightX,
    Double topRightY,
    Double bottomLeftX,
    Double bottomLeftY,
    Double bottomRightX,
    Double bottomRightY);

typedef ProcessImageFunction = int Function(
    Pointer<Utf8> imagePath,
    double topLeftX,
    double topLeftY,
    double topRightX,
    double topRightY,
    double bottomLeftX,
    double bottomLeftY,
    double bottomRightX,
    double bottomRightY);

// https://github.com/dart-lang/samples/blob/master/ffi/structs/structs.dart

class EdgeDetection {
  static Future<EdgeDetectionResult?> detectEdges(imglib.Image image) async {
    DynamicLibrary nativeEdgeDetection = _getDynamicLibrary();

    final detectEdges = nativeEdgeDetection
        .lookup<NativeFunction<detect_edges_function>>("detect_edges")
        .asFunction<DetectEdgesFunction>();

    // Convert the image to a byte array
    var imageData = image.getBytes();

    // Allocate memory for the image data
    final imageDataPointer = calloc<Uint8>(imageData.length);

    // Copy the image data to the allocated memory
    for (var i = 0; i < imageData.length; i++) {
      imageDataPointer[i] = imageData[i];
    }

    NativeDetectionResult detectionResult =
        detectEdges(imageDataPointer, image.width, image.height).ref;

    // Don't forget to free the allocated memory
    calloc.free(imageDataPointer);

    if (detectionResult.topLeft.ref.x == 0 &&
        detectionResult.topLeft.ref.y == 0 &&
        detectionResult.topRight.ref.x == 0 &&
        detectionResult.topRight.ref.y == 0 &&
        detectionResult.bottomLeft.ref.x == 0 &&
        detectionResult.bottomLeft.ref.y == 0 &&
        detectionResult.bottomRight.ref.x == 0 &&
        detectionResult.bottomRight.ref.y == 0) {
      return null;
    }

    return EdgeDetectionResult(
        topLeft: Offset(
            detectionResult.topLeft.ref.x, detectionResult.topLeft.ref.y),
        topRight: Offset(
            detectionResult.topRight.ref.x, detectionResult.topRight.ref.y),
        bottomLeft: Offset(
            detectionResult.bottomLeft.ref.x, detectionResult.bottomLeft.ref.y),
        bottomRight: Offset(detectionResult.bottomRight.ref.x,
            detectionResult.bottomRight.ref.y));
  }

  static Future<bool> processImage(
      String path, EdgeDetectionResult result) async {
    DynamicLibrary nativeEdgeDetection = _getDynamicLibrary();

    final processImage = nativeEdgeDetection
        .lookup<NativeFunction<process_image_function>>("process_image")
        .asFunction<ProcessImageFunction>();

    return processImage(
            path.toNativeUtf8(),
            result.topLeft.dx,
            result.topLeft.dy,
            result.topRight.dx,
            result.topRight.dy,
            result.bottomLeft.dx,
            result.bottomLeft.dy,
            result.bottomRight.dx,
            result.bottomRight.dy) ==
        1;
  }

  static Future<imglib.Image> debugSquares(imglib.Image image) async {
    DynamicLibrary nativeEdgeDetection = _getDynamicLibrary();
    final debugSquares = nativeEdgeDetection
        .lookup<NativeFunction<debug_squares_func>>("debug_squares")
        .asFunction<DebugSquaresFunc>();

    // Convert the image to a byte array
    var imageData = image.getBytes();

    // Allocate memory for the image data
    final imageDataPointer = calloc<Uint8>(imageData.length);

    // Copy the image data to the allocated memory
    for (var i = 0; i < imageData.length; i++) {
      imageDataPointer[i] = imageData[i];
    }

    // Call the native function
    final resultPointer =
        debugSquares(imageDataPointer, image.width, image.height);

    // Convert the result back to an Image
    final resultBytes = resultPointer.ref.data
        .asTypedList(resultPointer.ref.width * resultPointer.ref.height * 4);
    final resultImage = imglib.Image.fromBytes(
        width: resultPointer.ref.width,
        height: resultPointer.ref.height,
        bytes: resultBytes.buffer);

    // Don't forget to free the allocated memory
    calloc.free(imageDataPointer);

    return resultImage;
  }

  static DynamicLibrary _getDynamicLibrary() {
    final DynamicLibrary nativeEdgeDetection = Platform.isAndroid
        ? DynamicLibrary.open("libnative_edge_detection.so")
        : DynamicLibrary.process();
    return nativeEdgeDetection;
  }
}
