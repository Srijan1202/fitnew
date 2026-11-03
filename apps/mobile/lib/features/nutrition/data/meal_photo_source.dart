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
  /// The photo's bytes, or null when the person closed the camera or the
  /// gallery.
  Future<Uint8List?> pick({
    required bool camera,
    required NavigatorState navigator,
  });
}

class DeviceMealPhotoSource implements MealPhotoSource {
  const DeviceMealPhotoSource();

  /// The in-app camera's photo is 720p; a gallery photo is shrunk to this.
  static const _side = 1280.0;
  static const _quality = 85;

  @override
  Future<Uint8List?> pick({
    required bool camera,
    required NavigatorState navigator,
  }) async {
    final path = camera
        ? await takePhotoInApp(navigator)
        : (await ImagePicker().pickImage(
            source: ImageSource.gallery,
            maxWidth: _side,
            maxHeight: _side,
            imageQuality: _quality,
            requestFullMetadata: false,
          ))
            ?.path;
    if (path == null) return null;
    final file = File(path);
    try {
      return await file.readAsBytes();
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
