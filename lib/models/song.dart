/// Represents a song in the playlist.
/// 
/// This class models a single song with its metadata including
/// id, title, author, streaming URL, and duration.
class Song {
  final String id;
  final String title;
  final String author;
  final String url;
  final int duration; // Duration in seconds

  const Song({
    String? id,
    required this.title,
    required this.author,
    required this.url,
    required this.duration,
  }) : id = id ?? '';

  /// Creates a [Song] instance from a JSON object.
  /// 
  /// Expects a JSON map with the following keys:
  /// - id: String (optional)
  /// - title: String
  /// - author: String
  /// - url: String
  /// - duration: String (in "MM:SS" format) or int (in seconds)
  factory Song.fromJson(Map<String, dynamic> json, {String? generatedId}) {
    // Parse duration - can be either "MM:SS" string or int seconds
    int durationSeconds = 0;
    final durationValue = json['duration'];
    if (durationValue is String) {
      // Parse "MM:SS" format
      durationSeconds = _parseDurationString(durationValue);
    } else if (durationValue is int) {
      durationSeconds = durationValue;
    }

    return Song(
      id: json['id'] as String? ?? generatedId ?? '',
      title: json['title'] as String? ?? '',
      author: json['author'] as String? ?? '',
      url: json['url'] as String? ?? '',
      duration: durationSeconds,
    );
  }

  /// Parses a duration string in "MM:SS" format and converts it to seconds.
  static int _parseDurationString(String duration) {
    try {
      final parts = duration.split(':');
      if (parts.length == 2) {
        final minutes = int.parse(parts[0]);
        final seconds = int.parse(parts[1]);
        return minutes * 60 + seconds;
      }
    } catch (e) {
      // If parsing fails, return 0
    }
    return 0;
  }

  /// Converts this [Song] instance to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'author': author,
      'url': url,
      'duration': duration,
    };
  }

  @override
  String toString() {
    final durationStr = _formatDuration(duration);
    return 'Song(id: $id, title: $title, author: $author, duration: $durationStr)';
  }

  /// Formats duration in seconds to MM:SS format.
  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}

