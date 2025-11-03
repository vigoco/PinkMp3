import 'package:flutter/services.dart';
import 'dart:convert';
import '../models/song.dart';

/// Service responsible for loading playlist data from local assets.
/// 
/// This service handles loading and parsing JSON data from the local
/// asset bundle to retrieve the list of songs.
class NetworkService {
  /// The path to the playlist JSON file in the asset bundle.
  static const String playlistAssetPath = 'music_list.json';

  /// Loads the playlist from the local asset file and returns a list of [Song] objects.
  /// 
  /// Reads the JSON file from the asset bundle and parses the JSON response.
  /// The response is expected to be a JSON array of song objects.
  /// 
  /// Returns a [List<Song>] containing all songs in the playlist.
  /// 
  /// Throws an [Exception] if the asset file cannot be loaded or if the response
  /// cannot be parsed.
  Future<List<Song>> fetchPlaylist() async {
    try {
      // Load the JSON string from the asset bundle
      final String jsonString =
          await rootBundle.loadString(playlistAssetPath);

      // Parse the JSON string into a list of dynamic objects
      final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;

      // Parse each JSON object in the array into a Song instance
      // Generate an ID from the index if not provided
      final List<Song> songs = jsonList.asMap().entries.map((entry) {
        final index = entry.key;
        final json = entry.value as Map<String, dynamic>;
        return Song.fromJson(json, generatedId: index.toString());
      }).toList();

      return songs;
    } on PlatformException catch (e) {
      // Handle platform-specific errors (e.g., asset not found)
      throw Exception('Failed to load playlist asset: ${e.message}');
    } on FormatException catch (e) {
      // Handle JSON parsing errors
      throw Exception('Failed to parse playlist JSON: ${e.message}');
    } catch (e) {
      // Handle any other errors
      throw Exception('Failed to load playlist: $e');
    }
  }
}

