import 'package:video_player/video_player.dart';

class VideoPreloadService {
  static final VideoPreloadService _instance = VideoPreloadService._internal();
  factory VideoPreloadService() => _instance;
  VideoPreloadService._internal();

  VideoPlayerController? _preloadedController;
  String? _preloadedPath;

  Future<void> preloadVideo(String assetPath) async {
    if (_preloadedPath == assetPath && _preloadedController != null) return;

    await _preloadedController?.dispose();
    
    _preloadedPath = assetPath;
    _preloadedController = VideoPlayerController.asset(assetPath);
    
    try {
      await _preloadedController!.initialize();
      _preloadedController!.setLooping(true);
      _preloadedController!.setVolume(0.0);
    } catch (e) {
      print("Error preloading video: $e");
    }
  }

  VideoPlayerController? getAndReleaseController(String assetPath) {
    if (_preloadedPath == assetPath) {
      final controller = _preloadedController;
      _preloadedController = null;
      _preloadedPath = null;
      return controller;
    }
    return null;
  }
  
  void dispose() {
    _preloadedController?.dispose();
    _preloadedController = null;
    _preloadedPath = null;
  }
}
