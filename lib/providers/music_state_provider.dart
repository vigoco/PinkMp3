import 'package:flutter/material.dart';
import '../models/song.dart';
import '../models/song_state.dart';
import '../services/audio_handler.dart';

/// Provider that manages the state of all songs in the playlist.
/// 
/// This provider tracks:
/// - The currently playing song
/// - The playback state of each song
/// - Download/buffer progress for each song
/// - Any errors that occurred
class MusicStateProvider extends ChangeNotifier {
  final MyAudioHandler? audioHandler;
  
  // Map of song URL to its state
  final Map<String, SongStateInfo> _songStates = {};
  
  // Currently playing song URL
  String? _currentSongUrl;
  
  // All songs in the playlist
  List<Song> _playlist = [];

  MusicStateProvider({this.audioHandler}) {
    // Listen to audio handler state changes
    _setupAudioHandlerListeners();
  }

  /// Setup listeners for audio handler state changes
  void _setupAudioHandlerListeners() {
    if (audioHandler == null) return;

    // Listen to media item changes to know which song is playing
    audioHandler!.mediaItem.listen((mediaItem) {
      if (mediaItem != null) {
        // Find the song by URL
        Song foundSong;
        try {
          foundSong = _playlist.firstWhere(
            (s) => s.url == mediaItem.id || s.id == mediaItem.id,
          );
        } catch (e) {
          // Not found by URL, try by title and author
          try {
            foundSong = _playlist.firstWhere(
              (s) => s.title == mediaItem.title && s.author == mediaItem.artist,
            );
          } catch (e2) {
            // MediaItem fields might be nullable, but let's assume they're not
            // since we created them with non-null values in MyAudioHandler
            foundSong = Song(
              id: mediaItem.id,
              title: mediaItem.title ?? '',
              author: mediaItem.artist ?? '',
              url: mediaItem.id,
              duration: mediaItem.duration?.inSeconds ?? 0,
            );
          }
        }
        
        if (foundSong.url != _currentSongUrl) {
          _updateCurrentSong(foundSong.url);
        }
      } else {
        _currentSongUrl = null;
        notifyListeners();
      }
    });

    // Listen to playback state
    audioHandler!.playbackState.listen((playbackState) {
      if (_currentSongUrl != null) {
        _updatePlaybackState(playbackState.playing, playbackState.processingState);
      }
    });

    // Listen to buffering state
    audioHandler!.bufferingStream.listen((isBuffering) {
      if (_currentSongUrl != null) {
        _updateBufferingState(isBuffering);
      }
    });

    // Listen to download progress
    audioHandler!.downloadProgressStream.listen((progress) {
      if (_currentSongUrl != null) {
        _updateDownloadProgress(progress);
      }
    });
  }

  /// Update the currently playing song
  void _updateCurrentSong(String songUrl) {
    // Reset previous playing song if any
    if (_currentSongUrl != null && _songStates.containsKey(_currentSongUrl!)) {
      final previousState = _songStates[_currentSongUrl!]!;
      if (previousState.isPlaying) {
        _songStates[_currentSongUrl!] = previousState.copyWith(
          playbackState: SongPlaybackState.ready,
        );
      }
    }

    // Set new current song
    _currentSongUrl = songUrl;
    if (!_songStates.containsKey(songUrl)) {
      _songStates[songUrl] = const SongStateInfo();
    }

    notifyListeners();
  }

  /// Update playback state for current song
  void _updatePlaybackState(bool playing, dynamic processingState) {
    if (_currentSongUrl == null) return;

    SongPlaybackState newState;
    
    if (processingState.toString().contains('buffering') || 
        processingState.toString().contains('loading')) {
      newState = SongPlaybackState.loading;
    } else if (processingState.toString().contains('completed')) {
      newState = SongPlaybackState.ready;
    } else if (processingState.toString().contains('error')) {
      newState = SongPlaybackState.error;
    } else if (playing) {
      newState = SongPlaybackState.playing;
    } else if (processingState.toString().contains('ready')) {
      newState = SongPlaybackState.paused;
    } else {
      newState = SongPlaybackState.ready;
    }

    _updateSongState(_currentSongUrl!, playbackState: newState);
  }

  /// Update buffering state for current song
  void _updateBufferingState(bool isBuffering) {
    if (_currentSongUrl == null) return;
    
    final currentState = _songStates[_currentSongUrl] ?? const SongStateInfo();
    
    // Only update if not in error state
    if (!currentState.hasError) {
      final newState = isBuffering 
          ? SongPlaybackState.loading 
          : currentState.isPlaying 
              ? SongPlaybackState.playing 
              : SongPlaybackState.ready;
      
      _updateSongState(_currentSongUrl!, playbackState: newState);
    }
  }

  /// Update download progress for current song
  void _updateDownloadProgress(double progress) {
    if (_currentSongUrl == null) return;
    _updateSongState(_currentSongUrl!, downloadProgress: progress);
  }

  /// Update state for a specific song
  void _updateSongState(String songUrl, {
    SongPlaybackState? playbackState,
    double? downloadProgress,
  }) {
    final currentState = _songStates[songUrl] ?? const SongStateInfo();
    _songStates[songUrl] = currentState.copyWith(
      playbackState: playbackState,
      downloadProgress: downloadProgress,
    );
    notifyListeners();
  }

  /// Set an error state for a song
  void setSongError(String songUrl, String errorMessage) {
    _songStates[songUrl] = SongStateInfo(
      playbackState: SongPlaybackState.error,
      errorMessage: errorMessage,
    );
    notifyListeners();
  }

  /// Mark a song as loading
  void setSongLoading(String songUrl) {
    _songStates[songUrl] = SongStateInfo(
      playbackState: SongPlaybackState.loading,
    );
    notifyListeners();
  }

  /// Set the playlist
  void setPlaylist(List<Song> songs) {
    _playlist = songs;
    // Initialize all songs with idle state if not already present
    for (final song in songs) {
      if (!_songStates.containsKey(song.url)) {
        _songStates[song.url] = const SongStateInfo();
      }
    }
    notifyListeners();
  }

  /// Get state for a specific song
  SongStateInfo getSongState(String songUrl) {
    return _songStates[songUrl] ?? const SongStateInfo();
  }

  /// Check if a song is currently playing
  bool isCurrentlyPlaying(String songUrl) {
    return _currentSongUrl == songUrl;
  }

  /// Get the currently playing song URL
  String? get currentSongUrl => _currentSongUrl;

  /// Get all songs
  List<Song> get playlist => _playlist;
}
