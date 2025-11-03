import 'package:flutter/material.dart';

/// Represents the playback state of a song.
enum SongPlaybackState {
  idle,      // Not loaded
  loading,   // Currently loading/buffering
  ready,     // Loaded and ready to play
  playing,   // Currently playing
  paused,    // Paused
  error,     // Error occurred
}

/// Extended information about a song's current state.
class SongStateInfo {
  final SongPlaybackState playbackState;
  final double downloadProgress; // 0.0 to 1.0
  final double playbackPosition; // 0.0 to 1.0
  final String? errorMessage;

  const SongStateInfo({
    this.playbackState = SongPlaybackState.idle,
    this.downloadProgress = 0.0,
    this.playbackPosition = 0.0,
    this.errorMessage,
  });

  SongStateInfo copyWith({
    SongPlaybackState? playbackState,
    double? downloadProgress,
    double? playbackPosition,
    String? errorMessage,
  }) {
    return SongStateInfo(
      playbackState: playbackState ?? this.playbackState,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      playbackPosition: playbackPosition ?? this.playbackPosition,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  /// Get icon for current state
  IconData get icon {
    switch (playbackState) {
      case SongPlaybackState.idle:
        return Icons.music_note;
      case SongPlaybackState.loading:
        return Icons.download;
      case SongPlaybackState.ready:
        return Icons.check_circle;
      case SongPlaybackState.playing:
        return Icons.equalizer;
      case SongPlaybackState.paused:
        return Icons.pause_circle;
      case SongPlaybackState.error:
        return Icons.error;
    }
  }

  /// Get color for current state
  Color get color {
    switch (playbackState) {
      case SongPlaybackState.idle:
        return Colors.grey;
      case SongPlaybackState.loading:
        return Colors.blue;
      case SongPlaybackState.ready:
        return Colors.green;
      case SongPlaybackState.playing:
        return Colors.purple;
      case SongPlaybackState.paused:
        return Colors.orange;
      case SongPlaybackState.error:
        return Colors.red;
    }
  }

  /// Whether the song is currently being played
  bool get isPlaying => playbackState == SongPlaybackState.playing;

  /// Whether the song is currently loading or buffering
  bool get isLoading => playbackState == SongPlaybackState.loading;

  /// Whether there was an error
  bool get hasError => playbackState == SongPlaybackState.error;
}
