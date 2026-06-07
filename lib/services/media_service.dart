import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_compress/video_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class MediaService {
  static Future<io.File?> compressImage(io.File file, {int quality = 70}) async {
    if (kIsWeb) {
      // Compression on web requires different libraries (like image)
      // For now, return the original file to allow build to pass
      return file;
    }
    
    try {
      final tempDir = await getTemporaryDirectory();
      final fileName = 'compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final targetPath = p.join(tempDir.path, fileName);

      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: quality,
      );

      if (result == null) return null;
      return io.File(result.path);
    } catch (e) {
      print('Image compression failed: $e');
      return file;
    }
  }

  static Future<io.File?> generateThumbnail(io.File file, String type) async {
    if (kIsWeb) return file;

    try {
      if (type == 'image') {
        final tempDir = await getTemporaryDirectory();
        final fileName = 'thumb_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final targetPath = p.join(tempDir.path, fileName);

        final result = await FlutterImageCompress.compressAndGetFile(
          file.absolute.path,
          targetPath,
          quality: 20,
          minWidth: 100,
          minHeight: 100,
        );
        return result != null ? io.File(result.path) : null;
      } else if (type == 'video') {
        final thumbnailFile = await VideoCompress.getFileThumbnail(
          file.path,
          quality: 50,
          position: -1,
        );
        return thumbnailFile;
      }
    } catch (e) {
      print('Thumbnail generation failed: $e');
    }
    return null;
  }

  static Future<io.File?> compressVideo(io.File file) async {
    if (kIsWeb) return file;

    try {
      final info = await VideoCompress.compressVideo(
        file.path,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
        includeAudio: true,
      );

      if (info == null || info.file == null) return null;
      return info.file;
    } catch (e) {
      print('Video compression failed: $e');
      return file;
    }
  }

  static Object get videoCompressionProgress => kIsWeb ? Stream.empty() : VideoCompress.compressProgress$;

  static void cancelCompression() {
    if (!kIsWeb) VideoCompress.cancelCompression();
  }
}
