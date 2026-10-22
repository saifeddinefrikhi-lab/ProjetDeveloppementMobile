import 'dart:io';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:waste_classification/core/theme/app_colors.dart';
import 'package:waste_classification/data/local/local_image_store.dart';
import 'package:waste_classification/data/local/scan_repository.dart';
import 'package:waste_classification/data/models/scan_result.dart';
import 'package:waste_classification/features/auth/auth_provider.dart';
import 'package:waste_classification/features/result/result_screen.dart';
import 'package:waste_classification/features/scan/scan_frame_geometry.dart';
import 'package:waste_classification/services/classifier/classifier_providers.dart';
import 'package:waste_classification/services/classifier/waste_classifier_service.dart';
import 'package:waste_classification/services/image/camera_frame_cropper.dart';
import 'package:waste_classification/services/permission/camera_permission_service.dart';

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  CameraPermissionState? _permissionState;
  _ScanViewState _state = _ScanViewState.initializing;
  String? _errorKey;
  bool _initializing = false;
  bool _torchEnabled = false;
  final GlobalKey _cameraPreviewKey = GlobalKey();

  bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _disposeController();
    } else if (state == AppLifecycleState.resumed &&
        _state != _ScanViewState.analyzing) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    if (_initializing) return;
    _initializing = true;
    if (mounted) {
      setState(() {
        _state = _ScanViewState.initializing;
        _errorKey = null;
      });
    }

    try {
      final permission = await cameraPermissionService.request();
      _permissionState = permission;
      if (permission != CameraPermissionState.granted) {
        if (mounted) {
          setState(() => _state = _ScanViewState.permissionDenied);
        }
        return;
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException('camera_not_found', 'No camera found');
      }

      // On desktop, cameras are typically external or front-facing webcams
      final selected = _isDesktop
          ? cameras.first
          : cameras.firstWhere(
              (camera) => camera.lensDirection == CameraLensDirection.back,
              orElse: () => cameras.first,
            );

      CameraController controller;
      try {
        controller = CameraController(
          selected,
          ResolutionPreset.high,
          enableAudio: false,
          imageFormatGroup: ImageFormatGroup.jpeg,
        );
        await controller.initialize();
      } catch (_) {
        controller = CameraController(
          selected,
          ResolutionPreset.medium,
          enableAudio: false,
        );
        await controller.initialize();
      }

      if (!mounted) {
        await controller.dispose();
        return;
      }
      await _controller?.dispose();
      setState(() {
        _controller = controller;
        _state = _ScanViewState.ready;
      });
    } on CameraException {
      if (mounted) {
        setState(() {
          _state = _ScanViewState.error;
          _errorKey = 'scan.camera_error';
        });
      }
    } on Object {
      if (mounted) {
        setState(() {
          _state = _ScanViewState.error;
          _errorKey = 'scan.camera_error';
        });
      }
    } finally {
      _initializing = false;
    }
  }

  Future<void> _disposeController() async {
    final controller = _controller;
    _controller = null;
    if (controller != null) await controller.dispose();
  }

  Future<void> _toggleTorch() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _isDesktop) {
      return;
    }
    try {
      final next = !_torchEnabled;
      await controller.setFlashMode(next ? FlashMode.torch : FlashMode.off);
      if (mounted) setState(() => _torchEnabled = next);
    } on CameraException {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('scan.torch_unavailable'.tr())));
      }
    }
  }

  /// Pick an image file from disk (ideal for desktop testing or gallery selection).
  Future<void> _pickImage() async {
    File? storedImage;
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      setState(() => _state = _ScanViewState.analyzing);

      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        final service = ref.read(classifierServiceProvider);
        final classification = await service.classifyBytes(bytes);
        final scan = ScanResult(
          id: const Uuid().v4(),
          imagePath: '',
          scannedAt: DateTime.now(),
          categoryId: classification.categoryId,
          modelLabel: classification.modelLabel,
          confidence: classification.confidence,
        );
        if (!mounted) return;
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) =>
                ResultScreen(scanResult: scan, classification: classification),
          ),
        );
        return;
      }

      storedImage = await localImageStore.persist(picked.path);
      final classification = await ref
          .read(classifierServiceProvider)
          .classify(storedImage);
      final scan = ScanResult(
        id: const Uuid().v4(),
        imagePath: storedImage.path,
        scannedAt: DateTime.now(),
        categoryId: classification.categoryId,
        modelLabel: classification.modelLabel,
        confidence: classification.confidence,
        userId: ref.read(authProvider).user?.id,
      );
      await scanRepository.insert(scan);

      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) =>
              ResultScreen(scanResult: scan, classification: classification),
        ),
      );
    } on ClassificationException catch (error) {
      if (storedImage != null) {
        await localImageStore.deleteIfExists(storedImage);
      }
      debugPrint('[ScanScreen] ClassificationException: ${error.code} — ${error.cause}');
      if (mounted) {
        setState(() {
          _state = _ScanViewState.error;
          if (error.cause == 'groq_api_key_missing') {
            _errorKey = 'errors.groq_key_missing';
          } else if (error.cause == 'groq_invalid_key') {
            _errorKey = 'errors.groq_invalid_key';
          } else if (error.cause == 'groq_rate_limit') {
            _errorKey = 'errors.groq_rate_limit';
          } else if (error.cause == 'gemini_api_key_missing') {
            _errorKey = 'errors.gemini_key_missing';
          } else if (error.cause == 'gemini_invalid_key') {
            _errorKey = 'errors.gemini_invalid_key';
          } else {
            _errorKey = switch (error.code) {
              ClassificationErrorCode.noConnection => 'errors.no_connection',
              ClassificationErrorCode.timeout => 'errors.timeout',
              ClassificationErrorCode.invalidResponse =>
                'errors.invalid_response',
              ClassificationErrorCode.unavailable => 'errors.model_unavailable',
            };
          }
        });
      }
    } on Object catch (e, st) {
      if (storedImage != null) {
        await localImageStore.deleteIfExists(storedImage);
      }
      debugPrint('[ScanScreen] Unexpected error during pick: $e\n$st');
      if (mounted) {
        setState(() {
          _state = _ScanViewState.error;
          _errorKey = 'errors.model_unavailable';
        });
      }
    }
  }

  Future<void> _captureAndClassify() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture ||
        _state == _ScanViewState.analyzing) {
      return;
    }

    File? storedImage;
    File? croppedCapture;
    ui.Image? previewImage;
    try {
      final preview = _cameraPreviewKey.currentContext?.findRenderObject();
      if (preview is! RenderRepaintBoundary || !preview.hasSize) {
        throw StateError('Camera preview is not available.');
      }
      final viewportSize = preview.size;
      final frameRect = ScanFrameGeometry.frameFor(viewportSize).outerRect;
      final pixelRatio = View.of(context).devicePixelRatio;
      setState(() => _state = _ScanViewState.analyzing);
      previewImage = await preview.toImage(pixelRatio: pixelRatio);
      if (kIsWeb) {
        final bytes = await cameraFrameCropper.cropPreviewBytes(
          image: previewImage,
          viewportSize: viewportSize,
          frameRect: frameRect,
        );
        final service = ref.read(classifierServiceProvider);
        final classification = await service.classifyBytes(bytes);
        final scan = ScanResult(
          id: const Uuid().v4(),
          imagePath: '',
          scannedAt: DateTime.now(),
          categoryId: classification.categoryId,
          modelLabel: classification.modelLabel,
          confidence: classification.confidence,
        );
        if (!mounted) return;
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) =>
                ResultScreen(scanResult: scan, classification: classification),
          ),
        );
        return;
      }
      croppedCapture = await cameraFrameCropper.cropPreview(
        image: previewImage,
        viewportSize: viewportSize,
        frameRect: frameRect,
      );
      if (_torchEnabled && !_isDesktop) {
        await controller.setFlashMode(FlashMode.off);
        _torchEnabled = false;
      }

      storedImage = await localImageStore.persist(croppedCapture.path);
      final classification = await ref
          .read(classifierServiceProvider)
          .classify(storedImage);
      final scan = ScanResult(
        id: const Uuid().v4(),
        imagePath: storedImage.path,
        scannedAt: DateTime.now(),
        categoryId: classification.categoryId,
        modelLabel: classification.modelLabel,
        confidence: classification.confidence,
        userId: ref.read(authProvider).user?.id,
      );
      await scanRepository.insert(scan);

      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) =>
              ResultScreen(scanResult: scan, classification: classification),
        ),
      );
    } on ClassificationException catch (error) {
      if (storedImage != null) {
        await localImageStore.deleteIfExists(storedImage);
      }
      if (mounted) {
        setState(() {
          _state = _ScanViewState.error;
          if (error.cause == 'groq_api_key_missing') {
            _errorKey = 'errors.groq_key_missing';
          } else if (error.cause == 'groq_invalid_key') {
            _errorKey = 'errors.groq_invalid_key';
          } else if (error.cause == 'groq_rate_limit') {
            _errorKey = 'errors.groq_rate_limit';
          } else if (error.cause == 'gemini_api_key_missing') {
            _errorKey = 'errors.gemini_key_missing';
          } else if (error.cause == 'gemini_invalid_key') {
            _errorKey = 'errors.gemini_invalid_key';
          } else if (error.cause == 'gemini_api_not_enabled') {
            _errorKey = 'errors.gemini_api_not_enabled';
          } else {
            _errorKey = switch (error.code) {
              ClassificationErrorCode.noConnection => 'errors.no_connection',
              ClassificationErrorCode.timeout => 'errors.timeout',
              ClassificationErrorCode.invalidResponse =>
                'errors.invalid_response',
              ClassificationErrorCode.unavailable => 'errors.model_unavailable',
            };
          }
        });
      }
    } on Object catch (e, st) {
      if (storedImage != null) {
        await localImageStore.deleteIfExists(storedImage);
      }
      debugPrint('[ScanScreen] Unexpected error during capture: $e\n$st');
      if (mounted) {
        setState(() {
          _state = _ScanViewState.error;
          _errorKey = 'errors.model_unavailable';
        });
      }
    } finally {
      previewImage?.dispose();
      await _deleteTemporaryFile(croppedCapture);
    }
  }

  Future<void> _deleteTemporaryFile(File? file) async {
    if (file == null) return;
    try {
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // Cleanup failure must not replace the classification result or error.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_state == _ScanViewState.permissionDenied) {
      return _PermissionDeniedView(
        permanentlyDenied:
            _permissionState == CameraPermissionState.permanentlyDenied,
        onRetry: _initializeCamera,
        onOpenSettings: cameraPermissionService.openSettings,
        onPickFile: _pickImage,
      );
    }
    if (_state == _ScanViewState.error) {
      return _ScanErrorView(
        messageKey: _errorKey ?? 'errors.model_unavailable',
        onRetry: _initializeCamera,
        onPickFile: _pickImage,
      );
    }

    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (controller != null && controller.value.isInitialized)
            RepaintBoundary(
              key: _cameraPreviewKey,
              child: _CoverCameraPreview(controller: controller),
            )
          else
            const ColoredBox(
              color: Color(0xFF101713),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_state == _ScanViewState.ready) ...[
            const _CameraShade(),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _CameraIconButton(
                          tooltip: 'common.back'.tr(),
                          icon: Icons.arrow_back_rounded,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        Row(
                          children: [
                            _CameraIconButton(
                              tooltip: 'Choose photo from device',
                              icon: Icons.photo_library_rounded,
                              onPressed: _pickImage,
                            ),
                            if (!_isDesktop) ...[
                              const SizedBox(width: 8),
                              _CameraIconButton(
                                tooltip: 'scan.torch'.tr(),
                                icon: _torchEnabled
                                    ? Icons.flash_on_rounded
                                    : Icons.flash_off_rounded,
                                onPressed: _toggleTorch,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      'scan.instruction'.tr(),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        shadows: const [Shadow(blurRadius: 8)],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _CaptureButton(onPressed: _captureAndClassify),
                    const SizedBox(height: 12),
                    Text(
                      'scan.capture'.tr(),
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (_state == _ScanViewState.analyzing) const _AnalyzingOverlay(),
        ],
      ),
    );
  }
}

enum _ScanViewState { initializing, permissionDenied, ready, analyzing, error }

class _CoverCameraPreview extends StatelessWidget {
  const _CoverCameraPreview({required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    final size = controller.value.previewSize;
    if (size == null) return CameraPreview(controller);
    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.center,
        maxWidth: double.infinity,
        maxHeight: double.infinity,
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: size.height,
            height: size.width,
            child: CameraPreview(controller),
          ),
        ),
      ),
    );
  }
}

class _CameraShade extends StatelessWidget {
  const _CameraShade();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(child: CustomPaint(painter: _CameraShadePainter()));
  }
}

class _CameraShadePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final frame = ScanFrameGeometry.frameFor(size);
    final overlay = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(frame)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(overlay, Paint()..color = AppColors.cameraOverlay);
    canvas.drawRRect(
      frame,
      Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CaptureButton extends StatelessWidget {
  const _CaptureButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'scan.capture'.tr(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Container(
          width: 82,
          height: 82,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
          ),
          child: const DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _CameraIconButton extends StatelessWidget {
  const _CameraIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      style: IconButton.styleFrom(
        backgroundColor: Colors.black.withValues(alpha: 0.42),
        foregroundColor: Colors.white,
      ),
    );
  }
}

class _AnalyzingOverlay extends StatelessWidget {
  const _AnalyzingOverlay();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xD91B2821),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(28),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 30),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(strokeWidth: 4),
              ),
              const SizedBox(height: 20),
              Text(
                'scan.analyzing'.tr(),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'scan.analyzing_hint'.tr(),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionDeniedView extends StatelessWidget {
  const _PermissionDeniedView({
    required this.permanentlyDenied,
    required this.onRetry,
    required this.onOpenSettings,
    required this.onPickFile,
  });

  final bool permanentlyDenied;
  final VoidCallback onRetry;
  final Future<bool> Function() onOpenSettings;
  final VoidCallback onPickFile;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.no_photography_outlined,
                  size: 38,
                  color: AppColors.errorText,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'permissions.camera_title'.tr(),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 10),
              Text(
                'permissions.camera_description'.tr(),
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 26),
              FilledButton(
                onPressed: permanentlyDenied ? onOpenSettings : onRetry,
                child: Text(
                  (permanentlyDenied
                          ? 'permissions.open_settings'
                          : 'permissions.try_again')
                      .tr(),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onPickFile,
                icon: const Icon(Icons.photo_library_rounded),
                label: const Text('Choose Photo from Computer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanErrorView extends StatelessWidget {
  const _ScanErrorView({
    required this.messageKey,
    required this.onRetry,
    required this.onPickFile,
  });

  final String messageKey;
  final VoidCallback onRetry;
  final VoidCallback onPickFile;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.center_focus_weak_rounded,
                  size: 38,
                  color: AppColors.errorText,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'errors.title'.tr(),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 10),
              Text(
                messageKey.tr(),
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 26),
              FilledButton(
                onPressed: onRetry,
                child: Text('common.try_again'.tr()),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onPickFile,
                icon: const Icon(Icons.photo_library_rounded),
                label: const Text('Choose Photo from Computer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
