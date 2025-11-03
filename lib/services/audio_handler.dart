import 'dart:async';
import 'dart:math';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:music_player/models/song.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Repeat mode for playlist playback
enum RepeatMode {
  off,    // No repeat
  one,    // Repeat current song
  all,    // Repeat entire playlist
}

/// Custom AudioHandler that bridges just_audio with audio_service.
/// 
/// This handler manages background audio playback and media notifications,
/// allowing the app to continue playing audio when it's in the background
/// or the screen is off.
class MyAudioHandler extends BaseAudioHandler with SeekHandler, QueueHandler {
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  // Original playlist (never shuffled)
  List<Song> _originalPlaylist = [];
  // Current playlist (may be shuffled)
  List<Song> _playlist = [];
  int _currentIndex = 0;

  // Shuffle and repeat state
  bool _isShuffled = false;
  RepeatMode _repeatMode = RepeatMode.off;
  final Random _random = Random();
  
  // Stream controllers for download and buffer state
  final _bufferingController = StreamController<bool>.broadcast();
  final _bufferedPositionController = StreamController<Duration>.broadcast();
  final _downloadProgressController = StreamController<double>.broadcast();
  final _shuffleController = StreamController<bool>.broadcast();
  final _repeatController = StreamController<RepeatMode>.broadcast();
  
  // Current download/buffer state
  bool _isBuffering = false;
  Duration _bufferedPosition = Duration.zero;
  double _downloadProgress = 0.0;

  MyAudioHandler() {
    // Pipe playback events from just_audio to audio_service
    _audioPlayer.playbackEventStream.listen((event) {
      try {
        final transformedState = _transformEvent(event);
        try {
          playbackState.value = transformedState;
        } catch (e) {
          playbackState.add(transformedState);
        }
      } catch (e) {
        print('Error transforming playback event: $e');
      }
    });

    // Handle player completion - skip to next song based on repeat mode
    _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (_repeatMode == RepeatMode.one) {
          // Repeat current song
          seek(Duration.zero);
          play();
        } else if (_repeatMode == RepeatMode.all) {
          // Repeat playlist - go to next or restart
          if (hasNext) {
            skipToNext();
          } else {
            // Restart from beginning
            _currentIndex = 0;
            _playSongAtIndex(_currentIndex);
          }
        } else if (hasNext) {
          // Normal: go to next if available
          skipToNext();
        } else {
          // Normal mode: wrap to beginning when last song finishes
          _currentIndex = 0;
          _playSongAtIndex(_currentIndex);
        }
      }
      
      // Track buffering state from processing state
      final isBuffering = state.processingState == ProcessingState.buffering || state.processingState == ProcessingState.loading;
      if (_isBuffering != isBuffering) {
        _isBuffering = isBuffering;
        _bufferingController.add(isBuffering);
      }
    });

    // Listen to buffered position
    _audioPlayer.bufferedPositionStream.listen((bufferedPosition) {
      _bufferedPosition = bufferedPosition;
      _bufferedPositionController.add(bufferedPosition);
    });

    // Update media item duration once the player knows it
    _audioPlayer.durationStream.listen((duration) {
      if (duration == null) return;
      try {
        final currentItem = mediaItem.valueOrNull ?? mediaItem.value;
        if (currentItem != null && currentItem.duration != duration) {
          final updated = currentItem.copyWith(duration: duration);
          try {
            mediaItem.value = updated;
          } catch (_) {
            mediaItem.add(updated);
          }
        }
      } catch (e) {
        // Ignore duration update errors
      }
    });
    
    // Initialize with idle state
    try {
      final idleState = PlaybackState(
        controls: [],
        systemActions: const {},
        processingState: AudioProcessingState.idle,
        playing: false,
        updatePosition: Duration.zero,
        bufferedPosition: Duration.zero,
        speed: 1.0,
      );
      try {
        playbackState.value = idleState;
      } catch (e) {
        playbackState.add(idleState);
      }
    } catch (e) {
      print('Warning: Could not initialize playback state: $e');
    }
    
    print('MyAudioHandler initialized');
  }

  /// Transforms just_audio PlaybackEvent to audio_service PlaybackState
  PlaybackState _transformEvent(PlaybackEvent event) {
    final playing = _audioPlayer.playing;
    final processingState = _audioPlayer.processingState;
    
    // Map just_audio's ProcessingState to audio_service's ProcessingState
    AudioProcessingState audioProcessingState;
    switch (processingState) {
      case ProcessingState.idle:
        audioProcessingState = AudioProcessingState.idle;
        break;
      case ProcessingState.loading:
        audioProcessingState = AudioProcessingState.loading;
        break;
      case ProcessingState.buffering:
        audioProcessingState = AudioProcessingState.buffering;
        break;
      case ProcessingState.ready:
        audioProcessingState = AudioProcessingState.ready;
        break;
      case ProcessingState.completed:
        audioProcessingState = AudioProcessingState.completed;
        break;
    }

    // Get current position and buffered position from the audio player
    // The playback event stream emits regularly, so these will be updated frequently
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      // Compact actions: previous, play/pause, next
      // Show Previous, Play/Pause, Next in compact notification controls
      androidCompactActionIndices: const [0, 1, 2],
      processingState: audioProcessingState,
      playing: playing,
      updatePosition: _audioPlayer.position, // Current playback position
      bufferedPosition: _audioPlayer.bufferedPosition, // Buffered position
      speed: _audioPlayer.speed,
      queueIndex: _currentIndex >= 0 && _currentIndex < _playlist.length ? _currentIndex : null,
    );
  }

  /// Updates the media item directly from a Song object
  void _updateMediaItemFromSong(Song song) {
    try {
      final item = MediaItem(
        id: song.id.isEmpty ? song.url : song.id,
        album: song.author,
        title: song.title,
        artist: song.author,
        duration: Duration(seconds: song.duration),
        // Omit artUri if no artwork URL is available to avoid platform issues
      );
      // BaseAudioHandler exposes mediaItem as a BehaviorSubject
      // Try using .value setter first, fallback to .add()
      try {
        mediaItem.value = item;
        print('Updated mediaItem via value: ${item.title} by ${item.artist}');
      } catch (e) {
        try {
          mediaItem.add(item);
          print('Updated mediaItem via add: ${item.title} by ${item.artist}');
        } catch (e2) {
          print('Failed to update mediaItem: $e2');
          rethrow;
        }
      }
    } catch (e, stackTrace) {
      print('Error updating mediaItem from song: $e');
      print('Stack trace: $stackTrace');
    }
  }

  /// Updates the media item based on the current song in playlist
  void _updateMediaItem() {
    try {
      if (_currentIndex >= 0 && _currentIndex < _playlist.length) {
        final song = _playlist[_currentIndex];
        _updateMediaItemFromSong(song);
      } else {
        try {
          mediaItem.value = null;
          print('Cleared mediaItem via value');
        } catch (e) {
          try {
            mediaItem.add(null);
            print('Cleared mediaItem via add');
          } catch (e2) {
            print('Failed to clear mediaItem: $e2');
          }
        }
      }
    } catch (e, stackTrace) {
      print('Error updating mediaItem: $e');
      print('Stack trace: $stackTrace');
    }
  }

  @override
  Future<void> play() async {
    try {
      print('Play button pressed');
      await _audioPlayer.play();
      print('Audio player play() completed, updating state...');
      // Force a playback state update after playing
      final transformedState = _transformEvent(_audioPlayer.playbackEvent);
      try {
        playbackState.value = transformedState;
        print('Playback state updated via value');
      } catch (e) {
        playbackState.add(transformedState);
        print('Playback state updated via add');
      }
    } catch (e, stackTrace) {
      print('Error in play(): $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  @override
  Future<void> pause() async {
    try {
      print('Pause button pressed');
      await _audioPlayer.pause();
      print('Audio player pause() completed, updating state...');
      // Force a playback state update after pausing
      final transformedState = _transformEvent(_audioPlayer.playbackEvent);
      try {
        playbackState.value = transformedState;
        print('Playback state updated via value');
      } catch (e) {
        playbackState.add(transformedState);
        print('Playback state updated via add');
      }
    } catch (e, stackTrace) {
      print('Error in pause(): $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  @override
  Future<void> stop() async {
    try {
      print('Stop button pressed');
      await _audioPlayer.stop();
      print('Audio player stop() completed, updating state...');
      // Force a playback state update after stopping
      final transformedState = _transformEvent(_audioPlayer.playbackEvent);
      try {
        playbackState.value = transformedState;
        print('Playback state updated via value');
      } catch (e) {
        playbackState.add(transformedState);
        print('Playback state updated via add');
      }
    } catch (e, stackTrace) {
      print('Error in stop(): $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  @override
  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  /// Plays a song from a URL using progressive streaming
  /// 
  /// This method loads and plays a song from the given URL using LockCachingAudioSource
  /// for progressive streaming on mobile, or UriAudioSource on web.
  /// The audio will start playing as soon as enough data is buffered.
  /// It also updates the media item to reflect the current song.
  /// This is a custom method for our app's use case.
  Future<void> playSongFromUrl(String url, Song song, {List<Song>? fullPlaylist}) async {
    try {
      print('playSongFromUrl called: ${song.title} - $url');
      
      // If a full playlist is provided and current playlist is empty or different, update it
      if (fullPlaylist != null && fullPlaylist.isNotEmpty) {
        // Check if playlists are different by comparing lengths and URLs
        final playlistChanged = _originalPlaylist.isEmpty || 
            _originalPlaylist.length != fullPlaylist.length ||
            !fullPlaylist.every((s) => _originalPlaylist.any((p) => p.url == s.url));
        
        if (playlistChanged) {
          print('Updating playlist with provided full playlist (${fullPlaylist.length} songs). Previous: ${_originalPlaylist.length} songs');
          _originalPlaylist = List.from(fullPlaylist);
          _applyShuffle();
          _updateQueue();
        } else {
          print('Playlist unchanged (${fullPlaylist.length} songs)');
        }
      }
      
      // Update the current index and find the song in playlist FIRST
      final index = _playlist.indexWhere((s) => s.url == url);
      if (index >= 0) {
        _currentIndex = index;
        print('Song found in playlist at index $index');
      } else if (_originalPlaylist.isEmpty) {
        // If playlist is empty and no full playlist was provided, create a single-song playlist as fallback
        print('Warning: Playlist is empty and no full playlist provided. Creating single-song playlist.');
        _originalPlaylist = [song];
        _applyShuffle();
        _currentIndex = 0;
        _updateQueue();
      } else {
        // Song not in playlist but playlist exists
        // This shouldn't happen if the full playlist was provided correctly
        print('Warning: Song not found in playlist. Current playlist has ${_originalPlaylist.length} songs.');
        // Try to find by title/author as fallback
        final altIndex = _playlist.indexWhere((s) => s.title == song.title && s.author == song.author);
        if (altIndex >= 0) {
          _currentIndex = altIndex;
          print('Found song by title/author at index $altIndex');
        } else {
          print('Error: Song not in playlist and no match found. Playlist may need to be updated.');
        }
      }
      
      // Update media item IMMEDIATELY before loading audio source
      // This ensures the UI shows the correct song info even if audio loading fails
      print('Updating media item directly from song: ${song.title}');
      _updateMediaItemFromSong(song);
      
      // Stop any currently playing audio
      await _audioPlayer.stop();
      
      // Create audio source - use setUrl on web (simpler and works on all platforms),
      // LockCachingAudioSource on mobile for better caching
      if (kIsWeb) {
        print('Running on web - using setUrl');
        print('Loading audio source...');
        await _audioPlayer.setUrl(url);
        print('Audio source loaded successfully - ready for playback');
      } else {
        print('Running on mobile - using LockCachingAudioSource');
        final audioSource = LockCachingAudioSource(Uri.parse(url));
        // Listen to download progress (only available for LockCachingAudioSource)
        audioSource.downloadProgressStream.listen((progress) {
          _downloadProgress = progress;
          _downloadProgressController.add(progress);
        });
        print('Loading audio source...');
        await _audioPlayer.setAudioSource(audioSource);
        print('Audio source loaded successfully - ready for playback');
      }
      
      print('Starting playback...');
      await _audioPlayer.play();
      print('Playback started');
    } catch (e, stackTrace) {
      print('Error in playSongFromUrl: $e');
      print('Stack trace: $stackTrace');
      // Media item should already be updated, so UI will show correct info
      throw Exception('Failed to play song: $e');
    }
  }

  /// Sets the playlist and prepares for playback
  void setPlaylist(List<Song> songs) {
    _originalPlaylist = List.from(songs);
    _applyShuffle();
    _updateQueue();
    _updateMediaItem();
  }
  
  /// Applies shuffle to the playlist if enabled
  void _applyShuffle() {
    if (_isShuffled && _originalPlaylist.isNotEmpty) {
      // Create a shuffled copy
      _playlist = List.from(_originalPlaylist);
      _playlist.shuffle(_random);
      
      // If there's a currently playing song, try to keep it at the same relative position
      // by finding it in the shuffled list and adjusting current index
      if (_currentIndex >= 0 && _currentIndex < _originalPlaylist.length) {
        final currentSong = _originalPlaylist[_currentIndex];
        final newIndex = _playlist.indexWhere((s) => s.url == currentSong.url);
        if (newIndex >= 0) {
          _currentIndex = newIndex;
        }
      }
    } else {
      _playlist = List.from(_originalPlaylist);
    }
  }
  
  /// Updates the queue with current playlist
  void _updateQueue() {
    final queueItems = _playlist.map((song) {
      return MediaItem(
        id: song.id.isEmpty ? song.url : song.id,
        album: song.author,
        title: song.title,
        artist: song.author,
        duration: Duration(seconds: song.duration),
      );
    }).toList();
    try {
      queue.value = queueItems;
      print('Playlist queue set via value');
    } catch (e) {
      try {
        queue.add(queueItems);
        print('Playlist queue set via add');
      } catch (e2) {
        print('Warning: Failed to set playlist queue: $e2');
      }
    }
  }
  
  /// Toggles shuffle mode
  void toggleShuffle() {
    _isShuffled = !_isShuffled;
    _applyShuffle();
    _updateQueue();
    _shuffleController.add(_isShuffled);
    print('Shuffle ${_isShuffled ? "enabled" : "disabled"}');
  }
  
  /// Toggles repeat mode: off -> one -> all -> off
  void toggleRepeat() {
    switch (_repeatMode) {
      case RepeatMode.off:
        _repeatMode = RepeatMode.one;
        break;
      case RepeatMode.one:
        _repeatMode = RepeatMode.all;
        break;
      case RepeatMode.all:
        _repeatMode = RepeatMode.off;
        break;
    }
    _repeatController.add(_repeatMode);
    print('Repeat mode: $_repeatMode');
  }
  
  /// Gets current shuffle state
  bool get isShuffled => _isShuffled;
  
  /// Gets current repeat mode
  RepeatMode get repeatMode => _repeatMode;
  
  /// Stream that emits shuffle state changes
  Stream<bool> get shuffleStream => _shuffleController.stream;
  
  /// Stream that emits repeat mode changes
  Stream<RepeatMode> get repeatStream => _repeatController.stream;

  @override
  Future<void> skipToNext() async {
    try {
      if (_playlist.isEmpty) {
        print('skipToNext: playlist is empty');
        return;
      }

      // Shuffle mode: jump to a random song different from the current one
      if (_isShuffled && _playlist.length > 1) {
        int nextIndex = _currentIndex;
        // Ensure a different index is chosen
        while (nextIndex == _currentIndex) {
          nextIndex = _random.nextInt(_playlist.length);
        }
        _currentIndex = nextIndex;
        print('skipToNext: shuffle pick -> index=$_currentIndex');
        await _playSongAtIndex(_currentIndex);
        return;
      }

      if (_repeatMode == RepeatMode.all && _currentIndex >= _playlist.length - 1) {
        // If repeating all and at end, go to beginning
        _currentIndex = 0;
        print('skipToNext: wrapping to start (repeat all) -> index=$_currentIndex');
        await _playSongAtIndex(_currentIndex);
      } else if (_currentIndex < _playlist.length - 1) {
        _currentIndex++;
        print('skipToNext: advancing to index=$_currentIndex');
        await _playSongAtIndex(_currentIndex);
      } else {
        // At end and not repeating: log and keep current
        print('skipToNext: at end of playlist and repeat is not all');
      }
    } catch (e, st) {
      print('Error in skipToNext: $e');
      print(st);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    try {
      if (_playlist.isEmpty) {
        print('skipToPrevious: playlist is empty');
        return;
      }

      if (_repeatMode == RepeatMode.all && _currentIndex == 0) {
        // If repeating all and at beginning, go to end
        _currentIndex = _playlist.length - 1;
        print('skipToPrevious: wrapping to end (repeat all) -> index=$_currentIndex');
        await _playSongAtIndex(_currentIndex);
      } else if (_currentIndex > 0) {
        _currentIndex--;
        print('skipToPrevious: moving back to index=$_currentIndex');
        await _playSongAtIndex(_currentIndex);
      } else {
        // If at the beginning, restart the current song
        print('skipToPrevious: at start of playlist, seeking to 0');
        await seek(Duration.zero);
      }
    } catch (e, st) {
      print('Error in skipToPrevious: $e');
      print(st);
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index >= 0 && index < _playlist.length) {
      _currentIndex = index;
      await _playSongAtIndex(_currentIndex);
    }
  }

  /// Plays the song at the given index in the playlist
  Future<void> _playSongAtIndex(int index) async {
    if (index >= 0 && index < _playlist.length) {
      final song = _playlist[index];
      await playSongFromUrl(song.url, song);
    }
  }

  /// Checks if there's a next song in the playlist
  bool get hasNext => _currentIndex < _playlist.length - 1;

  /// Checks if there's a previous song in the playlist
  bool get hasPrevious => _currentIndex > 0;

  /// Stream that emits the current buffering state
  /// 
  /// Emits true when the player is buffering/downloading data,
  /// and false when buffering is complete.
  Stream<bool> get bufferingStream => _bufferingController.stream;

  /// Stream that emits the current buffered position
  /// 
  /// Emits a Duration representing how much of the audio has been
  /// downloaded/buffered so far.
  Stream<Duration> get bufferedPositionStream => _bufferedPositionController.stream;

  /// Stream that emits the download progress
  /// 
  /// Emits a double value from 0.0 (no data downloaded) to 1.0 (download complete).
  Stream<double> get downloadProgressStream => _downloadProgressController.stream;

  /// Gets the current buffering state synchronously
  bool get isBuffering => _isBuffering;

  /// Gets the current buffered position synchronously
  Duration get bufferedPosition => _bufferedPosition;

  /// Gets the current download progress synchronously (0.0 to 1.0)
  double get downloadProgress => _downloadProgress;

  /// Stream that emits the current playback position continuously
  Stream<Duration> get positionStream => _audioPlayer.positionStream;

  /// Gets the current playback position synchronously
  Duration get position => _audioPlayer.position;

  /// Disposes resources
  Future<void> dispose() async {
    await _bufferingController.close();
    await _bufferedPositionController.close();
    await _downloadProgressController.close();
    await _shuffleController.close();
    await _repeatController.close();
    await _audioPlayer.dispose();
  }
}
