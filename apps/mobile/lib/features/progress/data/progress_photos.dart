import 'dart:convert';
import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Beta 3.4 (ADR-035): progress photos live on this phone only — in the
/// app's private files (`files/progress_photos/<account>/`, excluded from
/// Android backup), never uploaded anywhere. Each account has its own
/// folder and its own `index.json`, so signing out keeps them and another
/// account never sees them; deleting the account deletes the folder.
enum PhotoPose {
  front('Front'),
  side('Side'),
  back('Back'),
  other('Other');

  const PhotoPose(this.label);

  final String label;

  static PhotoPose byName(String? name) =>
      values.firstWhere((v) => v.name == name, orElse: () => other);
}

class ProgressPhoto {
  const ProgressPhoto({
    required this.id,
    required this.date,
    required this.pose,
    required this.path,
    required this.weightKg,
  });

  factory ProgressPhoto.fromJson(Map<String, dynamic> j, String dir) =>
      ProgressPhoto(
        id: j['id'] as String,
        date: j['date'] as String,
        pose: PhotoPose.byName(j['pose'] as String?),
        path: p.join(dir, j['file'] as String),
        weightKg: (j['weightKg'] as num?)?.toDouble(),
      );

  final String id;

  /// yyyy-mm-dd, the day it shows (editable when adding).
  final String date;
  final PhotoPose pose;

  /// The JPEG on this phone.
  final String path;

  /// The trend weight known for that day when the photo was added, if any.
  final double? weightKg;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'date': date,
        'pose': pose.name,
        'file': p.basename(path),
        if (weightKg != null) 'weightKg': weightKg,
      };
}

/// Where photos come from (camera or gallery), behind a seam for tests.
abstract class PhotoSource {
  /// A resized JPEG's path, or null when the person cancelled.
  Future<String?> pick({required bool camera});
}

class DevicePhotoSource implements PhotoSource {
  const DevicePhotoSource();

  @override
  Future<String?> pick({required bool camera}) async {
    final file = await ImagePicker().pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
      requestFullMetadata: false,
    );
    return file?.path;
  }
}

/// One account's photos: a folder of JPEGs and its index. The files are
/// small (≤ 1600 px JPEGs), so plain synchronous file calls are used: no
/// half-written state between awaits, and widget tests run them as is.
class PhotoStore {
  PhotoStore(this.dir);

  /// `files/progress_photos/<account>` on the phone (a temp folder in tests).
  final Directory dir;

  File get _index => File(p.join(dir.path, 'index.json'));

  /// Newest day first.
  Future<List<ProgressPhoto>> list() async {
    if (!_index.existsSync()) return const [];
    try {
      final rows = (jsonDecode(_index.readAsStringSync()) as List<dynamic>)
          .cast<Map<String, dynamic>>();
      final photos = [
        for (final r in rows) ProgressPhoto.fromJson(r, dir.path),
      ]..sort((a, b) => b.date.compareTo(a.date));
      return photos;
    } on Object {
      return const [];
    }
  }

  Future<void> _write(List<ProgressPhoto> photos) async {
    dir.createSync(recursive: true);
    final tmp = File('${_index.path}.tmp')
      ..writeAsStringSync(jsonEncode([for (final x in photos) x.toJson()]));
    tmp.renameSync(_index.path);
  }

  /// Copies [source] in, then records it.
  Future<ProgressPhoto> add({
    required String source,
    required String date,
    required PhotoPose pose,
    double? weightKg,
  }) async {
    dir.createSync(recursive: true);
    final id = const Uuid().v4();
    final target = p.join(dir.path, '$id.jpg');
    File(source).copySync(target);
    final photo = ProgressPhoto(
      id: id,
      date: date,
      pose: pose,
      path: target,
      weightKg: weightKg,
    );
    await _write([...await list(), photo]);
    return photo;
  }

  Future<void> delete(String id) async {
    final photos = await list();
    for (final x in photos.where((x) => x.id == id)) {
      final f = File(x.path);
      if (f.existsSync()) f.deleteSync();
    }
    await _write(photos.where((x) => x.id != id).toList());
  }

  /// Everything of this account (account deletion).
  Future<void> deleteAll() async {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }
}

/// `files/progress_photos/<account>`: Android's `getFilesDir()`, the folder
/// the backup rules exclude.
Future<Directory> photoDirFor(String account) async {
  final base = await getApplicationSupportDirectory();
  return Directory(p.join(base.path, 'progress_photos', account));
}
