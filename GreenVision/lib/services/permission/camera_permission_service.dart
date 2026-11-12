import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraPermissionService {
  const CameraPermissionService();

  Future<CameraPermissionState> request() async {
    if (kIsWeb || Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return CameraPermissionState.granted;
    }
    var status = await Permission.camera.status;
    if (status.isDenied) {
      status = await Permission.camera.request();
    }
    if (status.isGranted) return CameraPermissionState.granted;
    if (status.isPermanentlyDenied) {
      return CameraPermissionState.permanentlyDenied;
    }
    if (status.isRestricted) return CameraPermissionState.restricted;
    return CameraPermissionState.denied;
  }

  Future<bool> openSettings() => openAppSettings();
}

enum CameraPermissionState { granted, denied, permanentlyDenied, restricted }

final cameraPermissionService = CameraPermissionService();
