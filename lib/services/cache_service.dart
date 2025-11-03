import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Service responsible for managing audio cache directories.
/// 
/// This service provides methods to get cache directories where audio files
/// will be stored for progressive streaming and offline playback.
class CacheService {
  static Directory? _cacheDirectory;

  /// Gets the cache directory for storing audio files.
  /// 
  /// Creates a dedicated subdirectory within the app's temporary/cache directory
  /// specifically for audio files. The directory is created if it doesn't exist.
  /// 
  /// Returns a [Directory] where audio files can be cached.
  /// 
  /// Throws an [Exception] if the cache directory cannot be created.
  static Future<Directory> getCacheDirectory() async {
    if (_cacheDirectory != null && await _cacheDirectory!.exists()) {
      return _cacheDirectory!;
    }

    try {
      // Get the application's temporary directory
      final tempDir = await getTemporaryDirectory();
      
      // Create a subdirectory for audio cache
      final audioCachePath = '${tempDir.path}${Platform.pathSeparator}audio_cache';
      final audioCacheDir = Directory(audioCachePath);
      
      // Create the directory if it doesn't exist
      if (!await audioCacheDir.exists()) {
        await audioCacheDir.create(recursive: true);
      }
      
      _cacheDirectory = audioCacheDir;
      return audioCacheDir;
    } catch (e) {
      throw Exception('Failed to create cache directory: $e');
    }
  }

  /// Clears all cached audio files.
  /// 
  /// Deletes all files in the audio cache directory.
  /// Useful for freeing up storage space or clearing corrupted cache.
  /// 
  /// Returns the number of files deleted.
  static Future<int> clearCache() async {
    try {
      final cacheDir = await getCacheDirectory();
      if (!await cacheDir.exists()) {
        return 0;
      }

      int deletedCount = 0;
      await for (final entity in cacheDir.list()) {
        if (entity is File) {
          await entity.delete();
          deletedCount++;
        }
      }
      
      return deletedCount;
    } catch (e) {
      throw Exception('Failed to clear cache: $e');
    }
  }

  /// Gets the size of the cache directory in bytes.
  /// 
  /// Calculates the total size of all files in the audio cache directory.
  /// 
  /// Returns the total size in bytes.
  static Future<int> getCacheSize() async {
    try {
      final cacheDir = await getCacheDirectory();
      if (!await cacheDir.exists()) {
        return 0;
      }

      int totalSize = 0;
      await for (final entity in cacheDir.list()) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
      
      return totalSize;
    } catch (e) {
      return 0;
    }
  }
}

