import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../shared/widgets/in_app_camera.dart';

/// Beta 5.5: a meal photo for "Snap a meal", taken inside FITOS (beta 3.8)
/// or chosen from the gallery, as bytes. The file is deleted as soon as it
/// is read: FITOS never keeps the photo (owner). Behind a seam for tests.
abstract class MealPhotoSource {
  /// The photo, or none: with [MealPhotoPick.left] when the camera was
  /// closed, else the gallery was closed without one.
  Future<MealPhotoPick> pick({
    required bool camera,
    required NavigatorState navigator,
  });
}

/// Beta 5.7: a meal photo's bytes, or why there are none.
class MealPhotoPick {
  const MealPhotoPick.photo(Uint8List this.bytes) : left = false;

  /// No photo. [left]: the camera was closed, and Snap a meal closes with
  /// it. Otherwise the gallery was closed, and Snap a meal stays open.
  const MealPhotoPick.none({required this.left}) : bytes = null;

  final Uint8List? bytes;
  final bool left;
}

class DeviceMealPhotoSource implements MealPhotoSource {
  const DeviceMealPhotoSource();

  /// The in-app camera's photo is 720p; a gallery photo is shrunk to this.
  static const _side = 1280.0;
  static const _quality = 85;

  @override
  Future<MealPhotoPick> pick({
    required bool camera,
    required NavigatorState navigator,
  }) async {
    Future<String?> gallery() async => (await ImagePicker().pickImage(
          source: ImageSource.gallery,
          maxWidth: _side,
          maxHeight: _side,
          imageQuality: _quality,
          requestFullMetadata: false,
        ))
            ?.path;
    // Beta 5.6 (owner): the camera has a Gallery button of its own, so a
    // gallery photo needs no camera photo (and no reading) first. Beta 5.7:
    // the camera closes before the gallery opens.
    var path = camera ? await takePhotoInApp(navigator, gallery: true) : null;
    if (camera && path == null) return const MealPhotoPick.none(left: true);
    if (!camera || path == kCameraChoseGallery) path = await gallery();
    if (path == null) return const MealPhotoPick.none(left: false);
    final file = File(path);
    try {
      return MealPhotoPick.photo(await file.readAsBytes());
    } finally {
      try {
        await file.delete();
      } on FileSystemException {
        // Already gone; the cache is the phone's to clear.
      }
    }
  }
}

final mealPhotoSourceProvider = Provider<MealPhotoSource>(
  (_) => const DeviceMealPhotoSource(),
);

/// The photo's type from its first bytes: JPEG, PNG or WebP; null for
/// anything else (the server reads only those).
String? photoMimeOf(List<int> b) {
  bool at(int i, List<int> m) =>
      b.length >= i + m.length &&
      [for (var k = 0; k < m.length; k++) b[i + k] == m[k]].every((x) => x);
  if (at(0, const [0xff, 0xd8, 0xff])) return 'image/jpeg';
  if (at(0, const [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])) {
    return 'image/png';
  }
  if (at(0, 'RIFF'.codeUnits) && at(8, 'WEBP'.codeUnits)) return 'image/webp';
  return null;
}
