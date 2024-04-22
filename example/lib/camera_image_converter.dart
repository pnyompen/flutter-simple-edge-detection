import 'dart:ffi';

import 'package:camera/camera.dart';
import 'package:image/image.dart' as imglib;

typedef ConvertFunc = Pointer<Uint32> Function(
    Pointer<Uint8>, Pointer<Uint8>, Pointer<Uint8>, Int32, Int32, Int32, Int32);
typedef Convert = Pointer<Uint32> Function(
    Pointer<Uint8>, Pointer<Uint8>, Pointer<Uint8>, int, int, int, int);

class UnsupportedImageFormat implements Exception {}

class CameraImageConverter {
  late DynamicLibrary convertImageLib;
  Convert? conv;
  CameraImageConverter();

  static imglib.Image convert(CameraImage cameraImage) {
    if (cameraImage.format.group == ImageFormatGroup.yuv420) {
      return convertYUV(cameraImage);
    } else if (cameraImage.format.group == ImageFormatGroup.bgra8888) {
      return convertBGRA(cameraImage);
    } else {
      print(cameraImage.format.group);
      throw UnsupportedImageFormat();
    }
  }

  /// Converts a [CameraImage] in YUV420 format to [imglib.Image] in RGB format
  static imglib.Image convertYUV(CameraImage cameraImage) {
    var img = imglib.Image(
        width: cameraImage.width,
        height: cameraImage.height); // Create Image buffer

    final int width = cameraImage.width;
    final int height = cameraImage.height;
    final int uvRowStride = cameraImage.planes[1].bytesPerRow;
    final int uvPixelStride = cameraImage.planes[1].bytesPerPixel!;

    for (int x = 0; x < width; x++) {
      for (int y = 0; y < height; y++) {
        final int uvIndex =
            uvPixelStride * (x / 2).floor() + uvRowStride * (y / 2).floor();
        final int index = y * width + x;

        final yp = cameraImage.planes[0].bytes[index];
        final up = cameraImage.planes[1].bytes[uvIndex];
        final vp = cameraImage.planes[2].bytes[uvIndex];
        // Calculate pixel color
        int r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255);
        int g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91)
            .round()
            .clamp(0, 255);
        int b = (yp + up * 1814 / 1024 - 227).round().clamp(0, 255);
        // color: 0x FF  FF  FF  FF
        //           A   B   G   R
        img.setPixel(x, y, imglib.ColorRgba8(r, g, b, 0xFF));
      }
    }
    img = imglib.copyRotate(img, angle: 90);
    return img;
  }

  /// Converts a [CameraImage] in BGRA888 format to [imglib.Image] in RGB format
  static imglib.Image convertBGRA(CameraImage cameraImage) {
    imglib.Image img = imglib.Image.fromBytes(
        width: cameraImage.planes[0].width!.toInt(),
        height: cameraImage.planes[0].height!.toInt(),
        bytes: cameraImage.planes[0].bytes.buffer,
        format: imglib.Format.uint8);
    return img;
  }
}
