import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/camera_service.dart';
import '../supabase_tables.dart';

class SupabaseStorageService {
  SupabaseStorageService(this._client);

  final SupabaseClient _client;

  Future<String> uploadProfileAvatar({
    required String userId,
    required String imagePath,
  }) {
    return _upload(
      bucket: SupabaseTables.profileAvatarsBucket,
      objectPath: '$userId/${path.basename(imagePath)}',
      image: PickedProofImage(
        path: imagePath,
        fileName: path.basename(imagePath),
      ),
    );
  }

  Future<String> uploadProductImage({
    required String businessId,
    required String productId,
    required String imagePath,
  }) {
    return _upload(
      bucket: SupabaseTables.productImagesBucket,
      objectPath: '$businessId/$productId/${path.basename(imagePath)}',
      image: PickedProofImage(
        path: imagePath,
        fileName: path.basename(imagePath),
      ),
    );
  }

  Future<String> uploadBusinessImage({
    required String businessId,
    required String imagePath,
  }) {
    return _upload(
      bucket: SupabaseTables.businessImagesBucket,
      objectPath: '$businessId/${path.basename(imagePath)}',
      image: PickedProofImage(
        path: imagePath,
        fileName: path.basename(imagePath),
      ),
    );
  }

  Future<String> uploadProofImage({
    required String orderId,
    required String label,
    required PickedProofImage image,
  }) {
    final resolvedName = image.fileName.trim().isNotEmpty
        ? image.fileName.trim()
        : image.path.trim().isNotEmpty
        ? path.basename(image.path)
        : '$label-${DateTime.now().millisecondsSinceEpoch}.jpg';
    return _upload(
      bucket: SupabaseTables.deliveryProofsBucket,
      objectPath: '$orderId/$label-$resolvedName',
      image: image,
    );
  }

  Future<String> _upload({
    required String bucket,
    required String objectPath,
    required PickedProofImage image,
  }) async {
    if (image.path.startsWith('http')) {
      return image.path;
    }

    final uploadBytes = await _validatedBytesFor(image);

    await _client.storage.from(bucket).uploadBinary(
      objectPath,
      uploadBytes,
      fileOptions: FileOptions(
        upsert: true,
        contentType: _contentTypeFor(image),
      ),
    );
    return _client.storage.from(bucket).getPublicUrl(objectPath);
  }

  Future<Uint8List> _validatedBytesFor(PickedProofImage image) async {
    if (image.bytes != null && image.bytes!.isNotEmpty) {
      return image.bytes!;
    }
    if (image.path.trim().isEmpty) {
      throw StateError('Selected image is no longer available.');
    }
    final file = File(image.path);
    if (!await file.exists()) {
      debugPrint(
        'QuickDeliver proof upload missing file at path: ${image.path}',
      );
      throw StateError('Selected image is no longer available.');
    }
    final fileBytes = await file.readAsBytes();
    if (fileBytes.isEmpty) {
      throw StateError('Selected image is empty.');
    }
    return fileBytes;
  }

  String _contentTypeFor(PickedProofImage image) {
    final candidate = image.fileName.trim().isNotEmpty
        ? image.fileName
        : image.path;
    if (candidate.trim().isEmpty) {
      return 'image/jpeg';
    }
    final extension = path.extension(candidate).toLowerCase();
    return switch (extension) {
      '.png' => 'image/png',
      '.webp' => 'image/webp',
      '.gif' => 'image/gif',
      _ => 'image/jpeg',
    };
  }
}
