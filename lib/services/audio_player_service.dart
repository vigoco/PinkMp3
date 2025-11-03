import 'package:just_audio/just_audio.dart';
import '../models/song.dart';

/// Service responsible for audio playback functionality.
/// 
/// This service manages audio playback using the just_audio package.
/// It provides a simple interface to play songs from URLs.
class AudioPlayerService {
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Keep minimal metadata so UI can show something in fallback mode
  Song? _currentSong;

  /// Plays a song from the given URL.
  /// 
  /// Sets the audio source to the provided URL and starts playback.
  /// 
  /// Parameters:
  /// - [url]: The URL of the audio file to play
  /// 
  /// Throws an exception if the URL cannot be loaded or played.
  Future<void> playSong(String url) async {
    try {
      await _audioPlayer.setUrl(url);
      await _audioPlayer.play();
    } catch (e) {
      throw Exception('Failed to play song: $e');
    }
  }

  /// Plays the given song and retains its metadata for UI display.
  Future<void> playSongFromSong(Song song) async {
    _currentSong = song;
    await playSong(song.url);
  }

  /// Expose player controls for the fallback path
  Future<void> play() => _audioPlayer.play();
  Future<void> pause() => _audioPlayer.pause();
  Future<void> seek(Duration position) => _audioPlayer.seek(position);

  /// Expose key streams/state for UI bindings
  Stream<PlayerState> get playerStateStream => _audioPlayer.playerStateStream;
  Stream<Duration> get positionStream => _audioPlayer.positionStream;
  Stream<Duration?> get durationStream => _audioPlayer.durationStream;
  // Buffered position stream to reflect how much audio is cached/downloaded
  Stream<Duration> get bufferedPositionStream => _audioPlayer.bufferedPositionStream;
  Duration get position => _audioPlayer.position;
  Duration get bufferedPosition => _audioPlayer.bufferedPosition;
  Duration? get duration => _audioPlayer.duration;
  bool get isPlaying => _audioPlayer.playing;
  Song? get currentSong => _currentSong;

  /// Disposes the audio player and releases resources.
  /// 
  /// Should be called when the service is no longer needed
  /// to prevent memory leaks.
  Future<void> dispose() async {
    await _audioPlayer.dispose();
  }
}

