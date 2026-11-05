import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

/// Beta 3.8 (tester feedback: "camera keeps closing and opening"): a photo
/// taken inside FITOS. The phone's camera app is never opened, so Android
/// has no reason to close FITOS while it is away. Viewfinder, shutter, front
/// or back, then the photo to keep or retake. The picture is the camera's
/// own JPEG at the high preset (720p on Android), so it is already within
/// the 1600 px FITOS keeps, and is saved in the app's cache.
///
/// Returns the JPEG's path, or null when the person closed it. With
/// [gallery], a Gallery button beside the shutter returns the path of a photo
/// chosen there instead (beta 5.6, owner: Snap a meal from the gallery
/// without taking a photo first).
Future<String?> takePhotoInApp(
  NavigatorState navigator, {
  bool front = false,
  Future<String?> Function()? gallery,
}) =>
    navigator.push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => InAppCameraScreen(front: front, gallery: gallery),
      ),
    );

/// Where the cameras come from, behind a seam for tests.
typedef CameraList = Future<List<CameraDescription>> Function();

/// The controller for one camera, behind a seam for tests (beta 5.6.3).
typedef CameraControllerFor = CameraController Function(CameraDescription);

CameraController _jpegController(CameraDescription camera) => CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

class InAppCameraScreen extends StatefulWidget {
  const InAppCameraScreen({
    this.front = false,
    this.cameras = availableCameras,
    this.controllerFor = _jpegController,
    this.gallery,
    super.key,
  });

  /// Start on the front camera (a selfie in the mirror needs the back one).
  final bool front;
  final CameraList cameras;
  final CameraControllerFor controllerFor;

  /// A photo from the gallery instead: its path, or null when none was
  /// chosen (the camera stays open).
  final Future<String?> Function()? gallery;

  @override
  State<InAppCameraScreen> createState() => _InAppCameraScreenState();
}

class _InAppCameraScreenState extends State<InAppCameraScreen>
    with WidgetsBindingObserver {
  List<CameraDescription> _all = const [];
  CameraController? _controller;
  int _index = 0;
  String? _taken;
  String? _problem;
  bool _busy = false;

  /// The camera is starting (its permission dialog may be up) or the
  /// gallery is open: leaving and coming back must not start it again.
  /// Beta 5.6.3 (owner: the camera came back over the gallery on the S24;
  /// on first use the permission dialog started it twice and it failed).
  bool _opening = false;
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  /// The plugin's advice: let the camera go when FITOS is not in front, and
  /// take it again on return.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_opening || _picking) return;
    final c = _controller;
    if (state == AppLifecycleState.inactive) {
      _controller = null;
      c?.dispose();
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.resumed &&
        c == null &&
        _taken == null) {
      _open(_index);
    }
  }

  Future<void> _start() async {
    try {
      _all = await widget.cameras();
    } on CameraException catch (e) {
      _fail(e);
      return;
    }
    if (_all.isEmpty) {
      setState(() => _problem = 'This phone has no camera FITOS can use.');
      return;
    }
    final want =
        widget.front ? CameraLensDirection.front : CameraLensDirection.back;
    final i = _all.indexWhere((c) => c.lensDirection == want);
    await _open(i < 0 ? 0 : i);
  }

  Future<void> _open(int index) async {
    if (_opening) return;
    _opening = true;
    final old = _controller;
    _controller = null;
    final CameraController c;
    try {
      await old?.dispose();
      c = widget.controllerFor(_all[index]);
      try {
        await c.initialize();
      } on CameraException catch (e) {
        await c.dispose();
        _fail(e);
        return;
      }
    } finally {
      _opening = false;
    }
    if (!mounted || _picking) {
      await c.dispose();
      return;
    }
    setState(() {
      _index = index;
      _controller = c;
      _problem = null;
    });
  }

  void _fail(CameraException e) {
    if (!mounted) return;
    setState(
      () => _problem = switch (e.code) {
        'CameraAccessDenied' ||
        'CameraAccessDeniedWithoutPrompt' ||
        'CameraAccessRestricted' =>
          'FITOS needs the camera to take a photo. Allow it in your phone\'s settings for FITOS, or choose one from the gallery.',
        _ => 'The camera could not start. Close this and try again.',
      },
    );
  }

  Future<void> _shoot() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || _busy) return;
    setState(() => _busy = true);
    try {
      final file = await c.takePicture();
      if (mounted) setState(() => _taken = file.path);
    } on CameraException catch (e) {
      _fail(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The camera is let go before the gallery opens and stays off while it
  /// is up; with no photo chosen it starts again.
  Future<void> _fromGallery() async {
    if (_picking) return;
    final c = _controller;
    setState(() {
      _picking = true;
      _controller = null;
    });
    await c?.dispose();
    String? path;
    try {
      path = await widget.gallery!();
    } finally {
      _picking = false;
    }
    if (!mounted) return;
    if (path != null) {
      Navigator.of(context).pop(path);
    } else if (_problem == null && _all.isNotEmpty) {
      await _open(_index);
    } else {
      setState(() {});
    }
  }

  void _retake() {
    final path = _taken;
    setState(() => _taken = null);
    if (path != null) File(path).delete().ignore();
    if (_controller == null) _open(_index);
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final taken = _taken;
    return Scaffold(
      key: const ValueKey('camera.screen'),
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                key: const ValueKey('camera.close'),
                tooltip: 'Close',
                color: Colors.white,
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Expanded(
              child: Center(
                child: taken != null
                    ? Image.file(
                        File(taken),
                        key: const ValueKey('camera.taken'),
                      )
                    : _problem != null
                        ? Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              _problem!,
                              key: const ValueKey('camera.problem'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white),
                            ),
                          )
                        : c != null && c.value.isInitialized
                            ? CameraPreview(c)
                            : const CircularProgressIndicator(
                                color: Colors.white,
                              ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: taken != null
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        TextButton(
                          key: const ValueKey('camera.retake'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _retake,
                          child: const Text('Retake'),
                        ),
                        FilledButton(
                          key: const ValueKey('camera.use'),
                          onPressed: () => Navigator.of(context).pop(taken),
                          child: const Text('Use photo'),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        if (widget.gallery == null)
                          const SizedBox(width: 48)
                        else
                          IconButton(
                            key: const ValueKey('camera.gallery'),
                            tooltip: 'Choose from gallery',
                            color: Colors.white,
                            icon: const Icon(Icons.photo_library_outlined),
                            onPressed: _busy ? null : _fromGallery,
                          ),
                        Semantics(
                          button: true,
                          label: 'Take photo',
                          child: GestureDetector(
                            key: const ValueKey('camera.shutter'),
                            onTap: c == null || _busy ? null : _shoot,
                            child: Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 4),
                                color: _busy ? Colors.white54 : Colors.white24,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          key: const ValueKey('camera.flip'),
                          tooltip: 'Switch camera',
                          color: Colors.white,
                          icon: const Icon(Icons.cameraswitch_outlined),
                          onPressed: _all.length < 2 || _busy
                              ? null
                              : () => _open((_index + 1) % _all.length),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
