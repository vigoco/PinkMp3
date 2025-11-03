import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart' show PlayerState;
import 'package:provider/provider.dart';
import 'theme.dart';
import 'package:audio_session/audio_session.dart';
import 'models/song.dart';
import 'models/song_state.dart';
import 'services/network_service.dart';
import 'services/audio_handler.dart';
import 'services/audio_player_service.dart';
import 'services/location_service.dart';
import 'providers/music_state_provider.dart';
import 'package:permission_handler/permission_handler.dart';

MyAudioHandler? globalAudioHandler;
AudioPlayerService? fallbackAudioService;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Configure audio session for proper background behavior
  try {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
  } catch (e) {
    print('AudioSession configuration failed: $e');
  }
  // Request notification permission on Android 13+
  try {
    final status = await Permission.notification.status;
    if (!status.isGranted) {
      await Permission.notification.request();
    }
  } catch (e) {
    print('Notification permission request failed: $e');
  }
  
  print('Starting AudioService initialization...');
  
  // Initialize the audio service with our custom handler
  // Note: audio_service only works on mobile platforms (Android/iOS), not on web
  try {
    print('Calling AudioService.init...');
    final handler = await AudioService.init(
      builder: () {
        print('Creating MyAudioHandler instance...');
        return MyAudioHandler();
      },
      config: AudioServiceConfig(
        androidNotificationChannelId: 'com.example.music_player.audio',
        androidNotificationChannelName: 'Pink Player',
        androidNotificationChannelDescription: 'Music playback controls',
        androidNotificationOngoing: false,
        androidStopForegroundOnPause: false
      ),
    ).timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        print('AudioService initialization timed out');
        throw TimeoutException('AudioService initialization timed out');
      },
    );
    
    print('AudioService.init returned handler: $handler');
    print('Handler type: ${handler.runtimeType}');
    
    // Store the handler
    // Ensure the concrete type is preserved for MyAudioHandler-specific streams
    globalAudioHandler = handler;
    print('AudioHandler successfully initialized and stored');
  } catch (e, stackTrace) {
    // If audio_service fails to initialize, we can't use MyAudioHandler
    // because it extends BaseAudioHandler which requires audio_service
    print('AudioService initialization failed: $e');
    print('Error type: ${e.runtimeType}');
    print('Stack trace: $stackTrace');
    print('Continuing without background audio service');
    globalAudioHandler = null;
  }
  
  print('Global audio handler after init: $globalAudioHandler');
  
  // Run the app regardless of audio service initialization status
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Create and provide the music state provider
    return ChangeNotifierProvider(
      create: (_) => MusicStateProvider(audioHandler: globalAudioHandler),
      child: MaterialApp(
        title: 'Pink Player',
        home: const PlaylistScreen(),
      ),
    );
  }
}

class _GradientCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;

  const _GradientCircleButton({
    required this.icon,
    required this.onPressed,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: PinkSpotifyTheme.magentaGradient,
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(255, 166, 201, 0.35),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
      ),
    );
  }
}

class _PlayerDrawer extends StatelessWidget {
  final AudioHandler? audioHandler;

  const _PlayerDrawer({required this.audioHandler});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, controller) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Stack(
            children: [
              // Gradient background
              Container(
                decoration: const BoxDecoration(
                  gradient: PinkSpotifyTheme.backgroundGradient,
                ),
              ),
              // Soft overlay
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0x33FFC1D9), Color(0x33D7B0E6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              // Content
              ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Artwork placeholder with glow
                  Container(
                    height: 260,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: PinkSpotifyTheme.magentaGradient,
                      boxShadow: const [
                        BoxShadow(
                          color: Color.fromRGBO(255, 166, 201, 0.3),
                          blurRadius: 30,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.music_note, size: 72, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Title & artist
                  // Support both audio_service handler and fallback just_audio service
                  if (audioHandler == null && fallbackAudioService != null)
                    StreamBuilder<Duration?>(
                      stream: fallbackAudioService!.durationStream,
                      initialData: fallbackAudioService!.duration,
                      builder: (context, _) {
                        final fa = fallbackAudioService!;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(fa.currentSong?.title ?? 'Unknown', style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 6),
                            Text(
                              fa.currentSong?.author ?? 'Unknown Artist',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        );
                      },
                    )
                  else
                    // Sync metadata with audio player: use valueOrNull to safely get initial data
                    // without throwing if BehaviorSubject hasn't been initialized yet
                    StreamBuilder<MediaItem?>(
                      stream: audioHandler?.mediaItem,
                      initialData: audioHandler?.mediaItem.valueOrNull,
                      builder: (context, snapshot) {
                        final item = snapshot.data;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(item?.title ?? 'Unknown', style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 6),
                            Text(
                              item?.artist ?? 'Unknown Artist',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        );
                      },
                    ),
                  const SizedBox(height: 16),
                  _DrawerControls(audioHandler: audioHandler),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DrawerControls extends StatefulWidget {
  final AudioHandler? audioHandler;
  const _DrawerControls({required this.audioHandler});

  @override
  State<_DrawerControls> createState() => _DrawerControlsState();
}

class _DrawerControlsState extends State<_DrawerControls> {
  double? _sliderValue;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    // Fallback path: direct just_audio via AudioPlayerService
    if (widget.audioHandler == null && fallbackAudioService != null) {
      final fa = fallbackAudioService!;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          StreamBuilder<Duration?>(
            stream: fa.durationStream,
            initialData: fa.duration,
            builder: (context, durationSnap) {
              final d = durationSnap.data;
              if (d == null || d == Duration.zero) {
                return const SizedBox(height: 20);
              }
              return StreamBuilder<Duration>(
                stream: fa.positionStream,
                initialData: fa.position,
                builder: (context, positionSnapshot) {
                  final position = positionSnapshot.data ?? Duration.zero;
                  final durationMs = d.inMilliseconds;
                  final positionMs = position.inMilliseconds;
                  final currentProgress = durationMs > 0
                      ? (positionMs / durationMs).clamp(0.0, 1.0)
                      : 0.0;
                  if (!_isDragging) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && !_isDragging) {
                        setState(() => _sliderValue = currentProgress);
                      }
                    });
                  }
                  final sliderValue = _isDragging && _sliderValue != null ? _sliderValue! : currentProgress;
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Slider(
                          value: sliderValue,
                          min: 0.0,
                          max: 1.0,
                          activeColor: PinkSpotifyTheme.primaryPink,
                          inactiveColor: Colors.white24,
                          onChanged: (value) {
                            setState(() {
                              _sliderValue = value;
                              _isDragging = true;
                            });
                          },
                          onChangeEnd: (value) async {
                            final seek = Duration(milliseconds: (value * durationMs).round());
                            try { await fa.seek(seek); } catch (_) {}
                            setState(() => _isDragging = false);
                          },
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _GradientCircleButton(
                            icon: Icons.skip_previous,
                            onPressed: null, // no playlist navigation in fallback
                          ),
                          StreamBuilder<PlayerState>(
                            stream: fa.playerStateStream,
                            initialData: null,
                            builder: (context, _) {
                              final playing = fa.isPlaying;
                              return _GradientCircleButton(
                                icon: playing ? Icons.pause : Icons.play_arrow,
                                size: 64,
                                onPressed: () async {
                                  try {
                                    if (playing) {
                                      await fa.pause();
                                    } else {
                                      await fa.play();
                                    }
                                  } catch (_) {}
                                },
                              );
                            },
                          ),
                          _GradientCircleButton(
                            icon: Icons.skip_next,
                            onPressed: null, // no playlist navigation in fallback
                          ),
                        ],
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Sync metadata and playback state: use valueOrNull for safe initialization
        StreamBuilder<MediaItem?>(
          stream: widget.audioHandler?.mediaItem,
          initialData: widget.audioHandler?.mediaItem.valueOrNull,
          builder: (context, mediaItemSnapshot) {
            return StreamBuilder<PlaybackState>(
              stream: widget.audioHandler?.playbackState,
              initialData: widget.audioHandler?.playbackState.valueOrNull,
              builder: (context, playbackSnapshot) {
                final playbackState = playbackSnapshot.data;
                final mediaItem = mediaItemSnapshot.data;
                if (playbackState == null) return const SizedBox.shrink();
                final duration = mediaItem?.duration;
                final hasDuration = duration != null && duration != Duration.zero;
                if (!hasDuration) return const SizedBox(height: 20);

                final positionStream = widget.audioHandler is MyAudioHandler
                    ? (widget.audioHandler as MyAudioHandler).positionStream
                    : AudioService.position;

                return StreamBuilder<Duration>(
                  stream: positionStream,
                  initialData: playbackState.updatePosition,
                  builder: (context, positionSnapshot) {
                    final position = positionSnapshot.data ?? Duration.zero;
                    final durationMs = duration.inMilliseconds;
                    final positionMs = position.inMilliseconds;
                    final currentProgress = durationMs > 0
                        ? (positionMs / durationMs).clamp(0.0, 1.0)
                        : 0.0;
                    if (!_isDragging) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted && !_isDragging) {
                          setState(() => _sliderValue = currentProgress);
                        }
                      });
                    }
                    final sliderValue = _isDragging && _sliderValue != null ? _sliderValue! : currentProgress;
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Slider(
                            value: sliderValue,
                            min: 0.0,
                            max: 1.0,
                            activeColor: PinkSpotifyTheme.primaryPink,
                            inactiveColor: Colors.white24,
                            onChanged: (value) {
                              setState(() {
                                _sliderValue = value;
                                _isDragging = true;
                              });
                            },
                            onChangeEnd: (value) async {
                              if (widget.audioHandler != null) {
                                final seek = Duration(milliseconds: (value * durationMs).round());
                                try {
                                  await widget.audioHandler!.seek(seek);
                                } catch (_) {}
                              }
                              setState(() => _isDragging = false);
                            },
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _GradientCircleButton(
                              icon: Icons.skip_previous,
                              onPressed: widget.audioHandler == null ? null : () => widget.audioHandler!.skipToPrevious(),
                            ),
                            StreamBuilder<PlaybackState>(
                              stream: widget.audioHandler?.playbackState,
                              initialData: widget.audioHandler?.playbackState.valueOrNull,
                              builder: (context, s) {
                                final playing = s.data?.playing ?? false;
                                return _GradientCircleButton(
                                  icon: playing ? Icons.pause : Icons.play_arrow,
                                  size: 64,
                                  onPressed: widget.audioHandler == null
                                      ? null
                                      : () => playing ? widget.audioHandler!.pause() : widget.audioHandler!.play(),
                                );
                              },
                            ),
                            _GradientCircleButton(
                              icon: Icons.skip_next,
                              onPressed: widget.audioHandler == null ? null : () => widget.audioHandler!.skipToNext(),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class PlaylistScreen extends StatefulWidget {
  const PlaylistScreen({super.key});

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  final NetworkService _networkService = NetworkService();
  final LocationService _locationService = LocationService();
  late Future<List<Song>> _playlistFuture;
  AudioHandler? _audioHandler;

  /// Creates the secret song "Os Bilias" for the Easter egg.
  Song _createSecretSong() {
    return Song(
      id: 'easter_egg_secret',
      title: 'Os Bilias',
      author: 'Secret',
      url: 'https://www.rafaelamorim.com.br/mobile2/musicas/Os%20Bilias.mp3',
      duration: 180, // 3:00 default duration
    );
  }

  /// Fetches the playlist and checks location to add secret song if applicable.
  Future<List<Song>> _fetchPlaylistWithLocationCheck() async {
    // First, fetch the regular playlist
    List<Song> songs = await _networkService.fetchPlaylist();
    
    // Check if user is within range of the campus
    try {
      final isWithinRange = await _locationService.isWithinCampusRange();
      
      if (isWithinRange == true) {
        print('User is within range! Adding secret song...');
        // Add the secret song to the end of the playlist
        final secretSong = _createSecretSong();
        songs = [...songs, secretSong];
        print('Secret song "${secretSong.title}" added to playlist');
      } else {
        print('User is not within range of campus (or location unavailable)');
      }
    } catch (e) {
      print('Error checking location for Easter egg: $e');
      // Continue without the secret song if location check fails
    }
    
    return songs;
  }

  @override
  void initState() {
    super.initState();
    // Get the audio handler instance from the global variable
    _audioHandler = globalAudioHandler;
    print('PlaylistScreen initState: _audioHandler = $_audioHandler');
    print('Global audio handler: $globalAudioHandler');
    // Fetch playlist with location check when the screen loads
    _playlistFuture = _fetchPlaylistWithLocationCheck();
    
    // Initialize the provider with the playlist once loaded
    _playlistFuture.then((songs) {
      if (mounted) {
        final provider = Provider.of<MusicStateProvider>(context, listen: false);
        provider.setPlaylist(songs);
        if (_audioHandler != null && _audioHandler is MyAudioHandler) {
          (_audioHandler as MyAudioHandler).setPlaylist(songs);
          print('Printing playlist song titles:');
          for (var s in songs) {
            print(s.title);
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: PinkSpotifyTheme.backgroundGradient,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Playlist'),
        ),
        body: FutureBuilder<List<Song>>(
        future: _playlistFuture,
        builder: (context, snapshot) {
          // Loading state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // Error state
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading playlist',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      // Retry fetching the playlist with location check
                      setState(() {
                        _playlistFuture = _fetchPlaylistWithLocationCheck();
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          // Success state
          if (snapshot.hasData) {
            final songs = snapshot.data!;

            if (songs.isEmpty) {
              return const Center(
                child: Text('No songs found in playlist'),
              );
            }

            return Consumer<MusicStateProvider>(
              builder: (context, musicProvider, child) {
                return Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: songs.length,
                        itemBuilder: (context, index) {
                          final song = songs[index];
                          final state = musicProvider.getSongState(song.url);
                          final isPlaying = musicProvider.isCurrentlyPlaying(song.url);
                          
                          return _SongListItem(
                            song: song,
                            state: state,
                            isPlaying: isPlaying,
                            audioHandler: _audioHandler,
                          );
                        },
                      ),
                    ),
                    // Buffering bar + Now playing bar (mini-player)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        StreamBuilder<MediaItem?>(
                          stream: _audioHandler?.mediaItem,
                          initialData: _audioHandler?.mediaItem.valueOrNull,
                          builder: (context, snapshot) {
                            return _NowPlayingBar(audioHandler: _audioHandler);
                          },
                        ),
                      ],
                    ),
                  ],
                );
              },
            );
          }

          // Fallback (should not reach here)
          return const Center(
            child: Text('Unexpected state'),
          );
        },
      ),
    ),
    );
  }
}

/// Formats duration in seconds to MM:SS format.
String _formatDuration(int seconds) {
  final minutes = seconds ~/ 60;
  final remainingSeconds = seconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
}

/// Enhanced song list item with state indicators
class _SongListItem extends StatelessWidget {
  final Song song;
  final SongStateInfo state;
  final bool isPlaying;
  final AudioHandler? audioHandler;

  const _SongListItem({
    required this.song,
    required this.state,
    required this.isPlaying,
    required this.audioHandler,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color.fromRGBO(255, 166, 201, 0.35).withOpacity(isPlaying ? 0.55 : 0.25),
            blurRadius: isPlaying ? 20 : 12,
            spreadRadius: isPlaying ? 1 : 0,
            offset: const Offset(0, 6),
          ),
        ],
        border: isPlaying
            ? Border.all(color: PinkSpotifyTheme.primaryPink.withOpacity(0.9), width: 1.5)
            : null,
      ),
      child: ListTile(
        leading: Icon(
          state.icon,
          color: state.color,
        ),
        title: Text(
          song.title,
          style: TextStyle(
            fontWeight: isPlaying ? FontWeight.w700 : FontWeight.w500,
            color: Colors.white,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              song.author,
              style: TextStyle(color: Colors.white.withOpacity(0.85)),
            ),
            if (state.isLoading && state.downloadProgress > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: LinearProgressIndicator(
                  value: state.downloadProgress,
                  minHeight: 2,
                  backgroundColor: Colors.white.withOpacity(0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(PinkSpotifyTheme.primaryPink),
                ),
              ),
            if (state.hasError && state.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Row(
                  children: [
                    Icon(Icons.error, size: 14, color: state.color),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        state.errorMessage!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        trailing: Text(
          _formatDuration(song.duration),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
        ),
        onTap: () async {
          _handleSongTap(context, song);
        },
      ),
    );
  }

  void _handleSongTap(BuildContext context, Song song) {
    // Mark song as loading in provider
    final musicProvider = Provider.of<MusicStateProvider>(context, listen: false);
    musicProvider.setSongLoading(song.url);

    // Play the song
    print('Song tapped: ${song.title}');
    // Always try to use AudioHandler first
    if (audioHandler != null) {
      print('AudioHandler is available: ${audioHandler.runtimeType}');
      try {
        // Try to cast to MyAudioHandler and use progressive streaming
        if (audioHandler is MyAudioHandler) {
          // Get the full playlist from the provider to ensure playlist is complete
          final fullPlaylist = musicProvider.playlist;
          
          (audioHandler as MyAudioHandler)
              .playSongFromUrl(song.url, song, fullPlaylist: fullPlaylist)
              .catchError((error) {
            print('Error playing song with AudioHandler: $error');
            musicProvider.setSongError(song.url, 'Failed to play: $error');
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to play song: $error'),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 5),
                ),
              );
            }
          });
          print('Playback initiated successfully with MyAudioHandler');
        } else {
          throw Exception('Unsupported audio handler type');
        }
      } catch (error, stackTrace) {
        print('Error playing song with AudioHandler: $error');
        print('Stack trace: $stackTrace');
        musicProvider.setSongError(song.url, 'Failed to play: $error');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to play song: $error'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } else {
      print('AudioHandler is null, using fallback');
      // Fallback to direct just_audio playback if audio_service isn't available
      try {
        if (fallbackAudioService == null) {
          fallbackAudioService = AudioPlayerService();
        }
        fallbackAudioService!.playSongFromSong(song).catchError((error) {
          musicProvider.setSongError(song.url, 'Failed to play: $error');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to play song: $error'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        });
        print('Playback started using fallback service');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Playing in foreground mode (background playback not available)'),
              backgroundColor: Colors.blue,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (error) {
        print('Fallback playback also failed: $error');
        musicProvider.setSongError(song.url, 'Failed to play: $error');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to play song: $error'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } finally {
        print('Printing playlist song titles:');
        for (var s in musicProvider.playlist) {
          print(s.title);
        }
      }	
    }
  }
}

/// Widget that displays the currently playing song and playback controls
class _NowPlayingBar extends StatefulWidget {
  final AudioHandler? audioHandler;

  const _NowPlayingBar({required this.audioHandler});

  @override
  State<_NowPlayingBar> createState() => _NowPlayingBarState();
}

class _AnimatedThinBar extends StatelessWidget {
  final double percent; // 0.0 to 1.0
  final bool showPercent;

  const _AnimatedThinBar({required this.percent, required this.showPercent});

  @override
  Widget build(BuildContext context) {
    // Height allocation: small room for percent text + 2–3px bar
    return Container(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedOpacity(
            opacity: showPercent && percent > 0.0 && percent < 1.0 ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: Text(
              '${(percent * 100).clamp(0, 100).toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 2.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                return Stack(
                  children: [
                    // Unbuffered background track
                    Container(
                      width: width,
                      height: 3,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    // Buffered foreground with smooth animation
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.0, end: percent.clamp(0.0, 1.0)),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        return Container(
                          width: width * value,
                          height: 3,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF3CAC), Color(0xFF784BA0)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NowPlayingBarState extends State<_NowPlayingBar> {
  double? _sliderValue;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openPlayerDrawer(context),
      child: Container(
        decoration: const BoxDecoration(
          gradient: PinkSpotifyTheme.magentaGradient,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Color.fromRGBO(255, 166, 201, 0.35),
              blurRadius: 16,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Interactive progress slider with buffer status
            if (widget.audioHandler == null && fallbackAudioService != null)
              // Fallback path (no background handler): use just_audio streams directly
              Builder(builder: (context) {
                final fa = fallbackAudioService;
                if (fa == null) return const SizedBox.shrink();
                return StreamBuilder<Duration?>(
                stream: fa.durationStream,
                initialData: fa.duration,
                builder: (context, durationSnapshot) {
                  final d = durationSnapshot.data;
                  if (d == null || d == Duration.zero) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                      child: const LinearProgressIndicator(
                        value: null,
                        minHeight: 2,
                      ),
                    );
                  }
                  return StreamBuilder<Duration>(
                    stream: fa.positionStream,
                    initialData: fa.position,
                    builder: (context, positionSnapshot) {
                      final position = positionSnapshot.data ?? Duration.zero;
                      final Duration safeDuration = d;
                      final durationMs = safeDuration.inMilliseconds;
                      final positionMs = position.inMilliseconds;
                      final currentProgress = durationMs > 0
                          ? (positionMs / durationMs).clamp(0.0, 1.0)
                          : 0.0;
                      if (!_isDragging) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted && !_isDragging) {
                            setState(() => _sliderValue = currentProgress);
                          }
                        });
                      }
                      final sliderValue = _isDragging && _sliderValue != null ? _sliderValue! : currentProgress;
                      final displayPosition = _isDragging && _sliderValue != null
                          ? Duration(milliseconds: (_sliderValue! * durationMs).round())
                          : position;
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Time display and interactive playback position slider
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatDuration(displayPosition.inSeconds),
                                  style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.9)),
                                ),
                                Text(
                                  _formatDuration(safeDuration.inSeconds),
                                  style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.9)),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                            child: Slider(
                              value: sliderValue,
                              min: 0.0,
                              max: 1.0,
                              activeColor: PinkSpotifyTheme.primaryPink,
                              inactiveColor: Colors.white.withOpacity(0.25),
                              onChanged: (value) {
                                setState(() {
                                  _sliderValue = value;
                                  _isDragging = true;
                                });
                              },
                              onChangeEnd: (value) async {
                                final seekPosition = Duration(milliseconds: (value * durationMs).round());
                                try { await fa.seek(seekPosition); } catch (_) {}
                                setState(() => _isDragging = false);
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              );
              })
            else
              StreamBuilder<MediaItem?>(
                stream: widget.audioHandler?.mediaItem,
                initialData: widget.audioHandler?.mediaItem.valueOrNull,
                builder: (context, mediaItemSnapshot) {
                  return StreamBuilder<PlaybackState>(
                    stream: widget.audioHandler?.playbackState,
                    initialData: widget.audioHandler?.playbackState.valueOrNull,
                    builder: (context, playbackSnapshot) {
                      final playbackState = playbackSnapshot.data;
                      final mediaItem = mediaItemSnapshot.data;

                      if (playbackState == null) {
                        return const SizedBox.shrink();
                      }

                      final duration = mediaItem?.duration;
                      final hasDuration = duration != null && duration != Duration.zero;

                      if (!hasDuration) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                          child: LinearProgressIndicator(
                            value: null,
                            minHeight: 2,
                          ),
                        );
                      }

                      // Listen to a continuous position stream for live updates
                      final positionStream = widget.audioHandler is MyAudioHandler
                          ? (widget.audioHandler as MyAudioHandler).positionStream
                          : AudioService.position;

                      return StreamBuilder<Duration>(
                        stream: positionStream,
                        initialData: playbackState.updatePosition,
                        builder: (context, positionSnapshot) {
                          final position = positionSnapshot.data ?? Duration.zero;

                          // Calculate current progress value
                          final durationMs = duration.inMilliseconds;
                          final positionMs = position.inMilliseconds;
                          final currentProgress = durationMs > 0
                              ? (positionMs / durationMs).clamp(0.0, 1.0)
                              : 0.0;

                          if (!_isDragging) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted && !_isDragging) {
                                setState(() {
                                  _sliderValue = currentProgress;
                                });
                              }
                            });
                          }

                          final sliderValue = _isDragging && _sliderValue != null ? _sliderValue! : currentProgress;

                          final displayPosition = _isDragging && _sliderValue != null
                              ? Duration(milliseconds: (_sliderValue! * durationMs).round())
                              : position;

                          return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Download/Buffer progress indicator (background)
                        if (widget.audioHandler is MyAudioHandler)
                          StreamBuilder<bool>(
                            stream: (widget.audioHandler as MyAudioHandler).bufferingStream,
                            initialData: (widget.audioHandler as MyAudioHandler).isBuffering,
                            builder: (context, bufferingSnapshot) {
                              final isBuffering = bufferingSnapshot.data ?? false;
                              return StreamBuilder<double>(
                                stream: (widget.audioHandler as MyAudioHandler).downloadProgressStream,
                                initialData: (widget.audioHandler as MyAudioHandler).downloadProgress,
                                builder: (context, downloadSnapshot) {
                                  final downloadProgress = downloadSnapshot.data ?? 0.0;
                                  return StreamBuilder<Duration>(
                                    stream: (widget.audioHandler as MyAudioHandler).bufferedPositionStream,
                                    initialData: (widget.audioHandler as MyAudioHandler).bufferedPosition,
                                    builder: (context, bufferedSnapshot) {
                                      final buffered = bufferedSnapshot.data ?? Duration.zero;
                                      final bufferedProgress = durationMs > 0
                                          ? (buffered.inMilliseconds / durationMs).clamp(0.0, 1.0)
                                          : 0.0;
                                      
                                      // Use download progress if available, otherwise use buffer progress
                                      final progressToShow = downloadProgress > 0.0 
                                          ? downloadProgress 
                                          : bufferedProgress;
                                      
                                      return Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // Download/Buffer progress (lighter color, background)
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(2),
                                              child: LinearProgressIndicator(
                                                value: progressToShow.clamp(0.0, 1.0),
                                                minHeight: 3,
                                                backgroundColor: Colors.white.withOpacity(0.12),
                                                valueColor: AlwaysStoppedAnimation<Color>(PinkSpotifyTheme.primaryPink.withOpacity(0.6)),
                                              ),
                                            ),
                                            // Download/Buffer status text
                                            if (isBuffering || progressToShow < 1.0)
                                              Padding(
                                                padding: const EdgeInsets.only(top: 2.0),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    if (isBuffering)
                                                      const SizedBox(
                                                        width: 12,
                                                        height: 12,
                                                        child: CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          valueColor: AlwaysStoppedAnimation<Color>(PinkSpotifyTheme.primaryPink),
                                                        ),
                                                      ),
                                                    if (isBuffering) const SizedBox(width: 4),
                                                    Text(
                                                      isBuffering
                                                          ? 'Downloading... ${(progressToShow * 100).toStringAsFixed(0)}%'
                                                          : 'Cached: ${(progressToShow * 100).toStringAsFixed(0)}%',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: Colors.white.withOpacity(0.85),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                          ],
                                        ),
                                      );
                                    },
                                  );
                                },
                              );
                            },
                          ),
                        // Time display and interactive playback position slider
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Current time and total duration
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // Current time
                                  Text(
                                    _formatDuration(displayPosition.inSeconds),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white.withOpacity(0.9),
                                    ),
                                  ),
                                  // Total duration
                                  Text(
                                    _formatDuration(duration.inSeconds),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white.withOpacity(0.9),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Interactive playback position slider
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 4.0,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8.0),
                                ),
                                child: Slider(
                                  value: sliderValue,
                                  min: 0.0,
                                  max: 1.0,
                                  activeColor: PinkSpotifyTheme.primaryPink,
                                  inactiveColor: Colors.white.withOpacity(0.25),
                                  onChanged: (value) {
                                    setState(() {
                                      _sliderValue = value;
                                      _isDragging = true;
                                    });
                                  },
                                  onChangeEnd: (value) async {
                                    // Seek to the new position when user finishes dragging
                                    if (widget.audioHandler != null) {
                                      final seekPosition = Duration(
                                        milliseconds: (value * durationMs).round(),
                                      );
                                      try {
                                        await widget.audioHandler!.seek(seekPosition);
                                      } catch (e) {
                                        print('Error seeking: $e');
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Error seeking: $e'),
                                              backgroundColor: Colors.red,
                                              duration: const Duration(seconds: 2),
                                            ),
                                          );
                                        }
                                      }
                                    }
                                    setState(() {
                                      _isDragging = false;
                                    });
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                          );
                        },
                      );
                    },
                  );
                },
              ),
            // Controls and song info
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  // Song info
                  if (widget.audioHandler == null && fallbackAudioService != null)
                    Builder(builder: (context) {
                      final fa = fallbackAudioService;
                      return Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            fa?.currentSong?.title ?? 'Unknown',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            fa?.currentSong?.author ?? 'Unknown Artist',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    );
                    })
                  else
                    StreamBuilder<MediaItem?>(
                      stream: widget.audioHandler?.mediaItem,
                      initialData: widget.audioHandler?.mediaItem.valueOrNull,
                      builder: (context, snapshot) {
                        final mediaItem = snapshot.data;
                        return Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                mediaItem?.title ?? 'Unknown',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                mediaItem?.artist ?? 'Unknown Artist',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  
                  // Shuffle button
                  if (widget.audioHandler is MyAudioHandler)
                    StreamBuilder<bool>(
                      stream: (widget.audioHandler as MyAudioHandler).shuffleStream,
                      initialData: (widget.audioHandler as MyAudioHandler).isShuffled,
                      builder: (context, snapshot) {
                        final isShuffled = snapshot.data ?? false;
                        return IconButton(
                          icon: Icon(
                            Icons.shuffle,
                            color: isShuffled 
                                ? Theme.of(context).colorScheme.primary 
                                : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          ),
                          onPressed: () {
                            (widget.audioHandler as MyAudioHandler).toggleShuffle();
                          },
                          tooltip: isShuffled ? 'Shuffle On' : 'Shuffle Off',
                        );
                      },
                    ),
                  // Previous button
                  IconButton(
                    icon: const Icon(Icons.skip_previous),
                    onPressed: widget.audioHandler == null ? null : () async {
                      try {
                        print('UI: Calling skipToPrevious()');
                        await widget.audioHandler!.skipToPrevious();
                      } catch (e) {
                        print('UI: Error in previous button: $e');
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                  ),
                  // Play/Pause button
                  if (widget.audioHandler == null && fallbackAudioService != null)
                    Builder(builder: (context) {
                      final fa = fallbackAudioService;
                      if (fa == null) return const SizedBox.shrink();
                      return StreamBuilder<PlayerState>(
                        stream: fa.playerStateStream,
                        initialData: null,
                        builder: (context, snapshot) {
                          final playing = fa.isPlaying;
                          return IconButton(
                            icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                            iconSize: 32,
                            onPressed: () async {
                              try {
                                if (playing) {
                                  await fa.pause();
                                } else {
                                  await fa.play();
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                          );
                        },
                      );
                    })
                  else
                    StreamBuilder<PlaybackState>(
                      stream: widget.audioHandler?.playbackState,
                      initialData: widget.audioHandler?.playbackState.valueOrNull,
                      builder: (context, snapshot) {
                        final playing = snapshot.data?.playing ?? false;
                        return IconButton(
                          icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                          iconSize: 32,
                          onPressed: widget.audioHandler == null ? null : () async {
                            try {
                              if (playing) {
                                print('UI: Calling pause()');
                                await widget.audioHandler!.pause();
                              } else {
                                print('UI: Calling play()');
                                await widget.audioHandler!.play();
                              }
                            } catch (e) {
                              print('UI: Error in play/pause button: $e');
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                        );
                      },
                    ),
                  // Next button
                  IconButton(
                    icon: const Icon(Icons.skip_next),
                    onPressed: widget.audioHandler == null ? null : () async {
                      try {
                        print('UI: Calling skipToNext()');
                        await widget.audioHandler!.skipToNext();
                      } catch (e) {
                        print('UI: Error in next button: $e');
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                  ),
                  // Repeat button
                  if (widget.audioHandler is MyAudioHandler)
                    StreamBuilder<RepeatMode>(
                      stream: (widget.audioHandler as MyAudioHandler).repeatStream,
                      initialData: (widget.audioHandler as MyAudioHandler).repeatMode,
                      builder: (context, snapshot) {
                        final repeatMode = snapshot.data ?? RepeatMode.off;
                        IconData iconData;
                        String tooltip;
                        Color iconColor;
                        
                        switch (repeatMode) {
                          case RepeatMode.off:
                            iconData = Icons.repeat;
                            tooltip = 'Repeat Off';
                            iconColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.6);
                            break;
                          case RepeatMode.one:
                            iconData = Icons.repeat_one;
                            tooltip = 'Repeat One';
                            iconColor = Theme.of(context).colorScheme.primary;
                            break;
                          case RepeatMode.all:
                            iconData = Icons.repeat;
                            tooltip = 'Repeat All';
                            iconColor = Theme.of(context).colorScheme.primary;
                            break;
                        }
                        
                        return IconButton(
                          icon: Icon(iconData),
                          color: iconColor,
                          onPressed: () {
                            (widget.audioHandler as MyAudioHandler).toggleRepeat();
                          },
                          tooltip: tooltip,
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  void _openPlayerDrawer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (_) => _PlayerDrawer(audioHandler: widget.audioHandler),
    );
  }
}
