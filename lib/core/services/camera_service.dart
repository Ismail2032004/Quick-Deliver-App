import 'dart:typed_data';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

final cameraServiceProvider = Provider<CameraService>((ref) => CameraService());

class PickedProofImage {
  const PickedProofImage({
    required this.path,
    required this.fileName,
    this.bytes,
  });

  final String path;
  final String fileName;
  final Uint8List? bytes;
}

class CameraService {
  CameraService() : _picker = ImagePicker();

  final ImagePicker _picker;

  Future<PickedProofImage?> pickProofImage({
    required String label,
    required ImageSource source,
  }) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        imageQuality: 70,
      );
      if (file == null) {
        return null;
      }
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        return null;
      }
      final fileName = _normalizedFileName(
        label: label,
        originalPath: file.path,
        originalName: file.name,
      );
      final stablePath = await _persistStableCopy(
        fileName: fileName,
        bytes: bytes,
      );
      return PickedProofImage(
        path: stablePath,
        fileName: fileName,
        bytes: bytes,
      );
    } catch (error) {
      debugPrint('QuickDeliver proof image pick failed: $error');
      return null;
    }
  }

  Future<PickedProofImage?> captureProofImage({required String label}) async {
    return pickProofImage(label: label, source: ImageSource.camera);
  }

  String _normalizedFileName({
    required String label,
    required String originalPath,
    required String originalName,
  }) {
    final trimmedName = originalName.trim();
    final trimmedPath = originalPath.trim();
    final rawName = trimmedName.isNotEmpty
        ? trimmedName
        : trimmedPath.isNotEmpty
        ? path.basename(trimmedPath)
        : 'quickdeliver-$label-${DateTime.now().millisecondsSinceEpoch}.jpg';
    final extension = path.extension(rawName).trim().isEmpty
        ? '.jpg'
        : path.extension(rawName).toLowerCase();
    final baseName = path.basenameWithoutExtension(rawName);
    final sanitizedBase = baseName
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '-')
        .replaceAll(RegExp(r'-{2,}'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final resolvedBase = sanitizedBase.isEmpty
        ? 'quickdeliver-$label-${DateTime.now().millisecondsSinceEpoch}'
        : sanitizedBase;
    return '$resolvedBase$extension';
  }

  Future<String> _persistStableCopy({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final directory = Directory(
      path.join(Directory.systemTemp.path, 'quickdeliver-proof-images'),
    );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    final stableFile = File(
      path.join(
        directory.path,
        '${DateTime.now().millisecondsSinceEpoch}-$fileName',
      ),
    );
    await stableFile.writeAsBytes(bytes, flush: true);
    return stableFile.path;
  }
}
