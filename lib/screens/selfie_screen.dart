import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../app/app_scope.dart';
import '../app/theme.dart';
import '../data/models.dart';
import '../widgets/common.dart';
import 'dashboard_screen.dart';

enum _Phase { starting, denied, blocked, noCamera, failed, preview, captured }

/// Selfie step. The camera plugin's temporary file is deleted straight after
/// capture; the photo is then saved in the app's private storage on this
/// phone (see SelfieStore). Nothing is uploaded and no face matching is done.
class SelfieScreen extends StatefulWidget {
  const SelfieScreen({super.key, required this.person});

  final Person person;

  @override
  State<SelfieScreen> createState() => _SelfieScreenState();
}

class _SelfieScreenState extends State<SelfieScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  _Phase _phase = _Phase.starting;
  bool _starting = false;
  bool _capturing = false;
  bool _mirror = false;
  Uint8List? _photo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      // Release the camera while the app is in the background.
      if (_controller != null && !_starting) {
        final controller = _controller;
        _controller = null;
        controller?.dispose();
        if (_phase == _Phase.preview) setState(() => _phase = _Phase.starting);
      }
    } else if (state == AppLifecycleState.resumed) {
      // Reopens a camera released in the background, and picks up a
      // permission granted in system settings. A plain "denied" is not
      // re-prompted automatically; the user taps "Allow camera".
      const restartable = {_Phase.starting, _Phase.blocked, _Phase.captured};
      if (_controller == null && !_starting && restartable.contains(_phase)) {
        _startCamera();
      }
    }
  }

  Future<void> _startCamera() async {
    if (_starting) return;
    _starting = true;
    if (_photo == null) setState(() => _phase = _Phase.starting);
    try {
      final status = await Permission.camera.request();
      if (!mounted) return;
      if (status.isPermanentlyDenied || status.isRestricted) {
        setState(() => _phase = _Phase.blocked);
        return;
      }
      if (!status.isGranted && !status.isLimited) {
        setState(() => _phase = _Phase.denied);
        return;
      }

      final cameras = await availableCameras();
      if (!mounted) return;
      if (cameras.isEmpty) {
        setState(() => _phase = _Phase.noCamera);
        return;
      }
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      if (_photo != null) await controller.pausePreview();
      setState(() {
        _controller = controller;
        _mirror = camera.lensDirection == CameraLensDirection.front;
        _phase = _photo == null ? _Phase.preview : _Phase.captured;
      });
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(
        () => _phase = e.code.contains('AccessDenied')
            ? _Phase.denied
            : _Phase.failed,
      );
    } catch (_) {
      if (mounted) setState(() => _phase = _Phase.failed);
    } finally {
      _starting = false;
    }
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _capturing) {
      return;
    }
    setState(() => _capturing = true);
    try {
      final file = await controller.takePicture();
      final bytes = await file.readAsBytes();
      // Do not leave the photo in the app's cache directory.
      try {
        await File(file.path).delete();
      } catch (_) {}
      await controller.pausePreview();
      if (!mounted) return;
      setState(() {
        _photo = bytes;
        _phase = _Phase.captured;
      });
    } on CameraException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not take the photo. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _retake() async {
    setState(() {
      _photo = null;
      _phase = _controller == null ? _Phase.starting : _Phase.preview;
    });
    final controller = _controller;
    if (controller == null) {
      await _startCamera();
    } else {
      await controller.resumePreview();
    }
  }

  Future<void> _finish({required bool withPhoto}) async {
    final scope = AppScope.of(context);
    final photo = withPhoto ? _photo : null;
    if (photo != null) {
      try {
        await scope.selfies.save(widget.person.email, photo);
      } catch (_) {
        // Still usable for this session if the file cannot be written.
      }
    }
    scope.session.setSelfie(photo);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => DashboardScreen(person: widget.person),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Take a selfie')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          children: [
            const Text(
              'Position your face inside the oval, in good light.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 15),
            ),
            const SizedBox(height: 14),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: AspectRatio(aspectRatio: 3 / 4, child: _buildFrame()),
              ),
            ),
            const SizedBox(height: 18),
            ..._buildActions(),
            const SizedBox(height: 18),
            const NoticeBanner(
              tone: NoticeTone.info,
              icon: Icons.lock_outline,
              message:
                  'Your selfie is saved only on this phone and appears on '
                  'your profile and pass. It is not uploaded or used for face '
                  'recognition, and it is deleted when you sign out.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFrame() {
    final Widget content;
    switch (_phase) {
      case _Phase.preview:
        final controller = _controller!;
        final size = controller.value.previewSize;
        content = Stack(
          fit: StackFit.expand,
          children: [
            if (size != null)
              FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                // previewSize is reported in landscape orientation.
                child: SizedBox(
                  width: size.height,
                  height: size.width,
                  child: CameraPreview(controller),
                ),
              )
            else
              CameraPreview(controller),
            const CustomPaint(painter: _FaceGuidePainter()),
          ],
        );
      case _Phase.captured:
        content = Stack(
          fit: StackFit.expand,
          children: [
            Transform.flip(
              flipX: _mirror, // match the mirrored live preview
              child: Image.memory(
                _photo!,
                key: const Key('selfiePreview'),
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            ),
            const Positioned(
              left: 12,
              top: 12,
              child: LabelChip(
                label: 'Captured',
                icon: Icons.check_circle,
                background: Colors.white,
              ),
            ),
          ],
        );
      case _Phase.starting:
        content = const Center(
          child: CircularProgressIndicator(color: Colors.white),
        );
      case _Phase.denied:
        content = const _FrameMessage(
          icon: Icons.no_photography_outlined,
          text: 'Camera permission is needed to take the selfie.',
        );
      case _Phase.blocked:
        content = const _FrameMessage(
          icon: Icons.no_photography_outlined,
          text:
              'Camera access is turned off for CONE. Allow it in system '
              'settings, then return to the app.',
        );
      case _Phase.noCamera:
        content = const _FrameMessage(
          icon: Icons.videocam_off_outlined,
          text: 'No camera was found on this device.',
        );
      case _Phase.failed:
        content = const _FrameMessage(
          icon: Icons.error_outline,
          text: 'The camera could not be started.',
        );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: ColoredBox(color: AppColors.navy, child: content),
    );
  }

  List<Widget> _buildActions() {
    final skip = TextButton(
      key: const Key('skipSelfie'),
      onPressed: () => _finish(withPhoto: false),
      child: const Text('Continue without a selfie'),
    );
    switch (_phase) {
      case _Phase.preview:
        return [
          FilledButton.icon(
            key: const Key('captureButton'),
            onPressed: _capturing ? null : _capture,
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('Capture'),
          ),
        ];
      case _Phase.captured:
        return [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('retakeButton'),
                  onPressed: _retake,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retake'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  key: const Key('selfieContinue'),
                  onPressed: () => _finish(withPhoto: true),
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Continue'),
                ),
              ),
            ],
          ),
        ];
      case _Phase.starting:
        return const [];
      case _Phase.denied:
        return [
          FilledButton(
            onPressed: _startCamera,
            child: const Text('Allow camera'),
          ),
          skip,
        ];
      case _Phase.blocked:
        return [
          FilledButton(
            onPressed: openAppSettings,
            child: const Text('Open settings'),
          ),
          skip,
        ];
      case _Phase.noCamera:
        return [skip];
      case _Phase.failed:
        return [
          OutlinedButton(
            onPressed: _startCamera,
            child: const Text('Try again'),
          ),
          skip,
        ];
    }
  }
}

class _FrameMessage extends StatelessWidget {
  const _FrameMessage({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.tealBright, size: 48),
          const SizedBox(height: 14),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dims everything outside a face-shaped oval and outlines it.
class _FaceGuidePainter extends CustomPainter {
  const _FaceGuidePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final oval = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.45),
      width: size.width * 0.62,
      height: size.height * 0.6,
    );
    final mask = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addOval(oval);
    canvas.drawPath(mask, Paint()..color = const Color(0x8C052543));
    canvas.drawOval(
      oval,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = AppColors.tealBright,
    );
  }

  @override
  bool shouldRepaint(_FaceGuidePainter oldDelegate) => false;
}
