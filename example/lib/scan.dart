import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:camera/camera.dart';
import 'package:image/image.dart' as imglib;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'package:simple_edge_detection/edge_detection.dart';
import 'package:simple_edge_detection_example/cropping_preview.dart';
import 'package:simple_edge_detection_example/edge_detection_shape/edge_detection_shape.dart';

import 'camera_view.dart';
import 'edge_detector.dart';
import 'image_view.dart';

class Scan extends StatefulWidget {
  @override
  _ScanState createState() => _ScanState();
}

class _ScanState extends State<Scan> {
  CameraController? controller;
  late List<CameraDescription> cameras;
  String? imagePath;
  String? croppedImagePath;
  EdgeDetectionResult? edgeDetectionResult;
  EdgeDetectionResult? liveEdgeDetectionResult;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    checkForCameras().then((value) {
      _initializeController();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: <Widget>[
          _getMainWidget(),
          _getBottomBar(),
        ],
      ),
    );
  }

  Widget _getMainWidget() {
    if (croppedImagePath != null) {
      return ImageView(imagePath: croppedImagePath!);
    }

    if (imagePath == null && edgeDetectionResult == null) {
      return Stack(
        children: [
          CameraView(controller: controller),
          if (liveEdgeDetectionResult != null)
            LayoutBuilder(builder: (context, constraints) {
              final double width = constraints.maxWidth;
              final double height =
                  constraints.maxWidth * controller!.value.aspectRatio;
              return Stack(
                children: [
                  Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: (constraints.maxHeight - height) / 2,
                        horizontal: (constraints.maxWidth - width) / 2,
                      ),
                      child: EdgeDetectionShape(
                        originalImageSize: Size(width, height),
                        renderedImageSize: Size(width, height),
                        edgeDetectionResult: liveEdgeDetectionResult!,
                      )),
                ],
              );
            })
        ],
      );
    }

    return ImagePreview(
      imagePath: imagePath!,
      edgeDetectionResult: edgeDetectionResult,
    );
  }

  Future<void> checkForCameras() async {
    cameras = await availableCameras();
  }

  void _initializeController() {
    checkForCameras();
    if (cameras.length == 0) {
      log('No cameras detected');
      return;
    }

    controller = CameraController(cameras[0], ResolutionPreset.medium,
        enableAudio: false);
    controller!.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {});
      controller!.setFlashMode(FlashMode.off);
      controller!.startImageStream(onCameraImageReceived);
    });
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  Future<void> onCameraImageReceived(CameraImage cameraImage) async {
    if (_isProcessing) {
      return;
    }
    try {
      final s = Stopwatch()..start();
      _isProcessing = true;
      liveEdgeDetectionResult =
          await EdgeDetector().detectEdgesFromCameraImage(cameraImage);
      s.stop();
      print('Edge detection took: ${s.elapsedMilliseconds}ms');
      await Future.delayed(Duration(milliseconds: 100));
      setState(() {});
    } catch (e) {
      print(e);
    } finally {
      _isProcessing = false;
    }
  }

  Widget _getButtonRow() {
    if (imagePath != null) {
      return Align(
        alignment: Alignment.bottomCenter,
        child: FloatingActionButton(
          child: Icon(Icons.check),
          onPressed: () async {
            if (croppedImagePath == null) {
              await _processImage(imagePath!, edgeDetectionResult!);
              return;
            }

            setState(() {
              imagePath = null;
              edgeDetectionResult = null;
              croppedImagePath = null;
            });
          },
        ),
      );
    }

    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      FloatingActionButton(
        foregroundColor: Colors.white,
        child: Icon(Icons.camera_alt),
        onPressed: onTakePictureButtonPressed,
      ),
      SizedBox(width: 16),
      FloatingActionButton(
        foregroundColor: Colors.white,
        child: Icon(Icons.image),
        onPressed: _onGalleryButtonPressed,
      ),
    ]);
  }

  String timestamp() => DateTime.now().millisecondsSinceEpoch.toString();

  Future<String?> takePicture() async {
    if (controller == null || !controller!.value.isInitialized) {
      log('Error: select a camera first.');
      return null;
    }

    final Directory extDir = await getTemporaryDirectory();
    final String dirPath = '${extDir.path}/Pictures/flutter_test';
    await Directory(dirPath).create(recursive: true);
    final String filePath;

    if (controller == null || controller!.value.isTakingPicture) {
      return null;
    }

    try {
      final XFile imagePath = await controller!.takePicture();
      filePath = imagePath.path;
    } on CameraException catch (e) {
      log(e.toString());
      return null;
    }
    return filePath;
  }

  Future _detectEdges(String? filePath) async {
    print('Detecting edges...');
    print(filePath);
    if (!mounted || filePath == null) {
      return;
    }

    setState(() {
      imagePath = filePath;
    });

    final imglib.Image image =
        imglib.decodeImage(File(filePath).readAsBytesSync())!;
    EdgeDetectionResult result = await EdgeDetector().detectEdges(image);
    print('Edge detection result: $result');

    setState(() {
      edgeDetectionResult = result;
    });
  }

  Future<void> _processImage(
      String? filePath, EdgeDetectionResult edgeDetectionResult) async {
    if (!mounted || filePath == null) {
      return;
    }

    bool result =
        await EdgeDetector().processImage(filePath, edgeDetectionResult);

    if (result == false) {
      return;
    }

    setState(() {
      imageCache.clearLiveImages();
      imageCache.clear();
      croppedImagePath = imagePath;
    });
  }

  void onTakePictureButtonPressed() async {
    String? filePath = await takePicture();

    log('Picture saved to $filePath');

    await _detectEdges(filePath);
  }

  void _onGalleryButtonPressed() async {
    ImagePicker picker = ImagePicker();
    final XFile? pickedFile =
        await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) {
      return;
    }
    final filePath = pickedFile.path;

    log('Picture saved to $filePath');

    _detectEdges(filePath);
  }

  Padding _getBottomBar() {
    return Padding(
        padding: EdgeInsets.only(bottom: 32),
        child:
            Align(alignment: Alignment.bottomCenter, child: _getButtonRow()));
  }
}
