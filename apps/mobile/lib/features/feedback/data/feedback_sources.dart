import 'dart:io';
import 'dart:typed_data';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:image_picker/image_picker.dart';

import 'feedback_api.dart';

/// Beta 3.6: pictures for feedback (screenshots from the gallery, or the
/// camera), resized on the phone; behind a seam for tests.
abstract class FeedbackPictureSource {
  /// At most [max] pictures' bytes; empty when the person cancelled.
  Future<List<Uint8List>> pick({required bool camera, required int max});
}

class DeviceFeedbackPictureSource implements FeedbackPictureSource {
  const DeviceFeedbackPictureSource();

  static const _side = 1600.0;
  static const _quality = 80;

  @override
  Future<List<Uint8List>> pick({required bool camera, required int max}) async {
    if (max <= 0) return const [];
    final picker = ImagePicker();
    final files = camera
        ? [
            await picker.pickImage(
              source: ImageSource.camera,
              maxWidth: _side,
              maxHeight: _side,
              imageQuality: _quality,
              requestFullMetadata: false,
            ),
          ].whereType<XFile>().toList()
        : max == 1
            ? [
                await picker.pickImage(
                  source: ImageSource.gallery,
                  maxWidth: _side,
                  maxHeight: _side,
                  imageQuality: _quality,
                  requestFullMetadata: false,
                ),
              ].whereType<XFile>().toList()
            : await picker.pickMultiImage(
                maxWidth: _side,
                maxHeight: _side,
                imageQuality: _quality,
                limit: max,
                requestFullMetadata: false,
              );
    return [for (final f in files.take(max)) await f.readAsBytes()];
  }
}

/// Beta 3.6: the phone's model and Android version; null where unknown.
abstract class FeedbackDeviceSource {
  Future<FeedbackDevice?> device({String? screen});
}

class PlatformFeedbackDeviceSource implements FeedbackDeviceSource {
  const PlatformFeedbackDeviceSource();

  @override
  Future<FeedbackDevice?> device({String? screen}) async {
    if (!Platform.isAndroid) return null;
    try {
      final a = await DeviceInfoPlugin().androidInfo;
      final maker = a.manufacturer.isEmpty
          ? ''
          : '${a.manufacturer[0].toUpperCase()}${a.manufacturer.substring(1)} ';
      String clip(String s, int n) => s.length <= n ? s : s.substring(0, n);
      return FeedbackDevice(
        model: clip('$maker${a.model}'.trim(), 80),
        os: clip('Android ${a.version.release}', 40),
        screen: screen == null ? null : clip(screen, 80),
      );
    } on Object {
      return null;
    }
  }
}
