import 'package:better_player/better_player.dart';
import 'package:flutter/material.dart';
import 'package:stack_appodeal_flutter/stack_appodeal_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'dart:async';

class AdvancedVideoPlayer extends StatefulWidget {
  final String url;
  final String title;
  final bool isLive;
  final Map<String, String>? qualities;

  const AdvancedVideoPlayer({
    super.key,
    required this.url,
    required this.title,
    this.isLive = false,
    this.qualities,
  });

  @override
  State<AdvancedVideoPlayer> createState() => _AdvancedVideoPlayerState();
}

class _AdvancedVideoPlayerState extends State<AdvancedVideoPlayer> {
  late BetterPlayerController _betterPlayerController;
  final GlobalKey _betterPlayerKey = GlobalKey();
  late SharedPreferences _prefs;
  Duration _lastPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initAndSetup();
  }

  Future<void> _initAndSetup() async {
    _prefs = await SharedPreferences.getInstance();
    if (!widget.isLive) {
      int savedPos = _prefs.getInt('pos_${widget.url}') ?? 0;
      _lastPosition = Duration(seconds: savedPos);
    }
    _setupPlayer();
  }

  void _setupPlayer() {
    BetterPlayerConfiguration betterPlayerConfiguration =
        BetterPlayerConfiguration(
          aspectRatio: 16 / 9,
          fit: BoxFit.contain,
          autoPlay: true,
          looping: false,
          allowedScreenSleep: false,
          fullScreenByDefault: false,
          startAt: _lastPosition,
          deviceOrientationsAfterFullScreen: [
            DeviceOrientation.portraitUp,
            DeviceOrientation.portraitDown,
          ],
          translations: [
            BetterPlayerTranslations(
              languageCode: "ar",
              generalDefaultError: "حدث خطأ أثناء تشغيل الفيديو",
              generalNone: "لا يوجد",
              generalDefault: "افتراضي",
              playlistEmptyPage: "قائمة التشغيل فارغة",
              playlistItems: "عناصر",
              qualityAuto: "تلقائي",
              controlsNextShort: "التالي",
              controlsPreviousShort: "السابق",
              controlsPlaybackSpeed: "سرعة التشغيل",
              controlsSubtitles: "الترجمة",
              controlsQuality: "الجودة",
            ),
          ],
          controlsConfiguration: BetterPlayerControlsConfiguration(
            enableProgressText: true,
            enablePlaybackSpeed: true,
            enableSubtitles: false,
            enableQualities: true,
            enableFullscreen: true,
            enableAudioTracks: true,
            loadingColor: Colors.red,
            progressBarSelectedColor: Colors.red,
            progressBarHandleColor: Colors.red,
            enableSkips: true,
            controlBarColor: Colors.black.withOpacity(0.5),
            overflowMenuIconsColor: Colors.white,
          ),
        );

    BetterPlayerDataSource dataSource = BetterPlayerDataSource(
      widget.isLive
          ? BetterPlayerDataSourceType.network
          : BetterPlayerDataSourceType.network,
      widget.url,
      liveStream: widget.isLive,
      notificationConfiguration: BetterPlayerNotificationConfiguration(
        showNotification: true,
        title: widget.title,
        author: "Codro IPTV",
      ),
      // Ad configuration for Pre-roll and Post-roll
      // Note: BetterPlayer supports IMA ads, but for Appodeal we usually handle Interstitials manually
      // or use the Pre-roll/Post-roll logic if we have VAST tags.
      // Since user mentioned Appodeal integration and pre-roll, I'll add a placeholder for ads logic.
      adConfiguration: BetterPlayerAdConfiguration(
        adTagUrls: [
          // If we had VAST/VMAP urls we would put them here
          // "https://pubads.g.doubleclick.net/gampad/ads?..."
        ],
      ),
    );

    _betterPlayerController = BetterPlayerController(betterPlayerConfiguration);
    _betterPlayerController.setupDataSource(dataSource);

    _betterPlayerController.addEventsListener((BetterPlayerEvent event) {
      if (event.betterPlayerEventType == BetterPlayerEventType.progress) {
        _savePosition();
      }
    });

    // Show interstitial ad before starting playback
    _showInterstitialAd();
  }

  void _savePosition() {
    if (widget.isLive) return;
    final pos = _betterPlayerController.videoPlayerController?.value.position;
    if (pos != null) {
      _prefs.setInt('pos_${widget.url}', pos.inSeconds);
    }
  }

  Future<void> _showInterstitialAd() async {
    bool isLoaded = await Appodeal.isLoaded(AppodealAdType.Interstitial);
    if (isLoaded) {
      Appodeal.show(AppodealAdType.Interstitial);
    }
  }

  @override
  void dispose() {
    _savePosition();
    _betterPlayerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: BetterPlayer(
            key: _betterPlayerKey,
            controller: _betterPlayerController,
          ),
        ),
        // Banner Ad below player
        AppodealBanner(adSize: AppodealBannerSize.Banner, placement: "default"),
      ],
    );
  }
}
