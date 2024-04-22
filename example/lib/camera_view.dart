import 'package:flutter/material.dart';

import 'package:camera/camera.dart';

class CameraView extends StatelessWidget {
  CameraView({required this.controller});

  final CameraController? controller;

  @override
  Widget build(BuildContext context) {
    return _getCameraPreview();
  }

  Widget _getCameraPreview() {
    if (controller == null || !controller!.value.isInitialized) {
      return Container();
    }

    return Center(
        child: AspectRatio(
            aspectRatio: 1 / controller!.value.aspectRatio,
            child: CameraPreview(controller!)));
  }
}
