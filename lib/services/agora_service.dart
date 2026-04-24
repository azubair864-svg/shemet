import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:deepar_flutter_plus/deepar_flutter_plus.dart' as deepar;
import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../core/constants/api_constants.dart';

enum CameraOwner { none, deepAr, agora }

class AgoraService {
  static final AgoraService _instance = AgoraService._internal();
  factory AgoraService() => _instance;
  AgoraService._internal();

  RtcEngine? _engine;
  deepar.DeepArControllerPlus? _deepArController;
  bool _isInitialized = false;
  bool _isDeepArInitialized = false;
  bool _isMuted = false;
  bool _isInChannel = false;
  String? _currentChannelId;
  
  // Camera State Tracking
  CameraOwner _currentOwner = CameraOwner.none;
  bool _isTransitioning = false;
  bool _isInitializingSvc = false;

  // Beauty State Cache (for re-applying after sticker change)
  double _lastSmooth = 0;
  double _lastWhiten = 0;
  double _lastFaceSlim = 0;
  double _lastEyeSize = 0;

  // Injected at build time or fallback to ApiConstants
  static const String _envAppId = String.fromEnvironment('AGORA_APP_ID');
  static const String deepArAndroidKey = String.fromEnvironment('DEEPAR_ANDROID_KEY');
  static const String deepArIosKey = String.fromEnvironment('DEEPAR_IOS_KEY');

  // Effective App ID (Env > Constant)
  static String get appId {
    // debugPrint('[DEEP_DEBUG] AppID Fetching -> EnvAppId: "$_envAppId", ApiConstantAppId: "${ApiConstants.agoraAppId}"');
    if (_envAppId.isNotEmpty && _envAppId != 'YOUR_APP_ID') return _envAppId;
    if (ApiConstants.agoraAppId.isNotEmpty && ApiConstants.agoraAppId != 'YOUR_AGORA_APP_ID') {
      return ApiConstants.agoraAppId;
    }
    // debugPrint('[DEEP_DEBUG] AppID Fetching -> NO VALID APP ID FOUND');
    return '';
  }

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isDeepArInitialized => _isDeepArInitialized;
  bool get isMuted => _isMuted;
  bool get isInChannel => _isInChannel;
  String? get currentChannelId => _currentChannelId;
  CameraOwner get currentOwner => _currentOwner;
  bool get isCameraEnabled => _currentOwner == CameraOwner.agora;
  RtcEngine? get engine => _engine;
  deepar.DeepArControllerPlus? get deepArController => _deepArController;

  // Initialize Agora Engine
  Future<void> initialize() async {
    // debugPrint('[DEEP_DEBUG] AgoraService.initialize() called. Current _isInitialized: $_isInitialized, _isInitializingSvc: $_isInitializingSvc');
    if (_isInitializingSvc) {
      debugPrint('[AGORA_DEBUG] ⏳ Service initialization in progress, waiting...');
      int maxWait = 50; // max 5 seconds
      while (_isInitializingSvc && maxWait > 0) {
        await Future.delayed(const Duration(milliseconds: 100));
        maxWait--;
      }
      // If we timed out waiting for another call, we proceed if not initialized
      if (!_isInitialized) {
        debugPrint('[AGORA_DEBUG] ⚠️ Wait for initialization timed out, forcing retry...');
      } else {
        return;
      }
    }

    // If the overall service is initialized, but DeepAR was destroyed (null), 
    // we continue to initialize DeepAR.
    if (_isInitialized && _deepArController != null) {
      debugPrint('[DEEP_DEBUG] Already fully initialized. Returning.');
      return;
    }

    _isInitializingSvc = true;

    final currentAppId = appId; // Evaluate it once and trace it
    debugPrint('[DEEP_DEBUG] 📝 App ID being used for Initialization: "$currentAppId"');
    // debugPrint('[AGORA_DEBUG] 📝 App ID configured: ${currentAppId.isNotEmpty}');

    try {
      if (!_isInitialized) {
        // Request permissions
        debugPrint('[AGORA_DEBUG] 📝 Requesting permissions...');
        try {
          // Add a timeout to permission request to avoid infinite hanging if OS dialog fails
          await _requestPermissions().timeout(const Duration(seconds: 15), onTimeout: () {
            debugPrint('[AGORA_DEBUG] ⚠️ Permission request timed out');
          });
        } catch (pe) {
          debugPrint('[AGORA_DEBUG] ⚠️ Permission request error: $pe');
        }
        debugPrint('[AGORA_DEBUG] 📝 Permissions phase completed');

        // 1. Initialize Agora first (The "Base" Engine)
        debugPrint('[AGORA_DEBUG] 📝 Creating Agora RTC Engine...');
        if (currentAppId.isEmpty) {
          debugPrint('[DEEP_DEBUG] 🛑 Aborting Agora Init: App ID is empty strings.');
          _isInitialized = false;
          _isInitializingSvc = false; // Reset early
          return;
        }

        try {
          _engine = createAgoraRtcEngine();
          
          await _engine?.initialize(
            RtcEngineContext(
              appId: currentAppId,
              channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
              audioScenario: AudioScenarioType.audioScenarioGameStreaming,
            ),
          );
        } catch (engineInitErr) {
          debugPrint('[DEEP_DEBUG] ❌❌ Inner Engine Initialization Error: $engineInitErr');
          rethrow;
        }
        _isInitialized = true;
      }

      // 2. Initialize DeepAR (The "Filter" Engine)
      if (_deepArController == null) {
        debugPrint('[AGORA_DEBUG] 📝 Initializing DeepAR...');
        
        if (deepArAndroidKey.isEmpty || deepArIosKey.isEmpty || deepArAndroidKey == 'YOUR_KEY') {
          debugPrint('[AGORA_DEBUG] ⚠️ Skipping DeepAR: Missing license keys');
          _isDeepArInitialized = false;
        } else {
          _deepArController = deepar.DeepArControllerPlus();
          try {
            final deepArResult = await _deepArController!.initialize(
              androidLicenseKey: deepArAndroidKey,
              iosLicenseKey: deepArIosKey,
              resolution: deepar.Resolution.high,
            ).timeout(const Duration(seconds: 10));
            
            if (deepArResult.success) {
              _isDeepArInitialized = true;
            } else {
              _isDeepArInitialized = false;
              debugPrint('[AGORA_DEBUG] ⚠️ DeepAR initialization failed');
            }
          } catch (e) {
            debugPrint('[AGORA_DEBUG] ⚠️ DeepAR initialization error or timeout: $e');
            _isDeepArInitialized = false;
          }
        }
      }

      // 3. Set Initial Camera Owner
      // IMPORTANT: DeepAR acquires the camera immediately upon initialization.
      // We must track this so the handover logic knows to release it.
      if (_isDeepArInitialized) {
        _currentOwner = CameraOwner.deepAr;
        debugPrint('[FLOW_TRACE] 🚩 Initial state set to CameraOwner.deepAr');
      } else {
        _currentOwner = CameraOwner.none;
      }

      // Configure audio
      await _engine?.enableAudio();
      await _engine?.enableVideo(); // 🚀 ENSURE VIDEO ENGINE IS READY FOR SPECTATORS TOO
      await _engine?.setAudioProfile(
        profile: AudioProfileType.audioProfileMusicStandard,
        scenario: AudioScenarioType.audioScenarioGameStreaming,
      );

      // Configure Video Encoder for Vertical Stream (Fixes Zoom/Crop)
      await _engine?.setVideoEncoderConfiguration(
        const VideoEncoderConfiguration(
          dimensions: VideoDimensions(width: 720, height: 1280),
          frameRate: 15,
          bitrate: 0, // Standard bitrate
          orientationMode: OrientationMode.orientationModeFixedPortrait,
        ),
      );

      _isInitialized = true;
      // debugPrint('[AGORA_DEBUG] ✅ ========== INITIALIZATION SUCCESS ==========\n');
    } catch (e, stackTrace) {
      debugPrint('[AGORA_DEBUG] ❌ ========== INITIALIZATION ERROR ==========');
      debugPrint('[AGORA_DEBUG] ❌ Error: $e');
      debugPrint('[AGORA_DEBUG] 📍 Stack trace: $stackTrace');
      debugPrint('[AGORA_DEBUG] ❌ =============================================\n');
    } finally {
      _isInitializingSvc = false;
    }
  }

  // Public method to request camera control
  Future<void> requestCameraControl(CameraOwner owner) async {
    // debugPrint('[AGORA_TRACE] 📢 requestCameraControl(${owner.name}) requested by app');
    
    // Special case: If requesting DeepAR but it's not initialized (or was destroyed), initialize it
    if (owner == CameraOwner.deepAr && (_deepArController == null)) {
       debugPrint('[AGORA_TRACE] 🔄 DeepAR controller is null, initializing...');
       await initialize();
    }
    
    await _transitionCamera(owner);
  }

  // --- NEW: Camera Handover Logic ---
  Future<void> _transitionCamera(CameraOwner target) async {
    final String traceId = DateTime.now().millisecondsSinceEpoch.toString().substring(10);
    // debugPrint('\n[FLOW_TRACE] 🏁 [$traceId] START TRANSITION -> ${target.name}');

    // If a transition is in progress, wait for it to finish
    int waitCount = 0;
    while (_isTransitioning) {
      waitCount++;
      debugPrint('[FLOW_TRACE] ⏳ [$traceId] Waiting for previous transition... ($waitCount)');
      await Future.delayed(const Duration(milliseconds: 100));
      if (waitCount > 30) break; // Safety break
    }

    // Forcefully release DeepAR if it exists but isn't tracked as the owner
    // This catches the 'Blind Transition' cases where state wasn't updated.
    bool needsForceDeepArRelease = (_deepArController != null && target != CameraOwner.deepAr);
    
    if (_currentOwner == target && !needsForceDeepArRelease && _currentOwner != CameraOwner.none) {
      debugPrint('[FLOW_TRACE] 💡 [$traceId] Target ${target.name} already matched current state.');
      return;
    }

    _isTransitioning = true;
    try {
      // Step 1: Release Current Owner
      if (_currentOwner == CameraOwner.agora) {
        debugPrint('[FLOW_TRACE] 📤 [$traceId] AGORA_RELEASE: Stopping preview...');
        await _engine?.stopPreview();
        debugPrint('[FLOW_TRACE] ✅ [$traceId] AGORA_RELEASE: Success');
      } 
      
      // Release DeepAR if it's the owner OR if we are forcing a release
      if (_currentOwner == CameraOwner.deepAr || needsForceDeepArRelease) {
        if (needsForceDeepArRelease) {
          debugPrint('[FLOW_TRACE] 🛡️ [$traceId] FORCING DEEPAR_RELEASE: Controller exists but owner was ${_currentOwner.name}');
        }
        debugPrint('[FLOW_TRACE] 📤 [$traceId] DEEPAR_RELEASE: Calling destroy...');
        
        try {
           final dynamic dac = _deepArController;
           await dac.destroy();
           _deepArController = null;
           _isDeepArInitialized = false;
           debugPrint('[FLOW_TRACE] ✅ [$traceId] DEEPAR_RELEASE: Hardware destroyed');
        } catch (e) {
           debugPrint('[FLOW_TRACE] ❌ [$traceId] DEEPAR_RELEASE ERROR: $e');
        }
      }

      // Step 2: Critical Cooldown
      debugPrint('[FLOW_TRACE] 💤 [$traceId] COOLDOWN: Waiting 1500ms for OS to recycle camera...');
      await Future.delayed(const Duration(milliseconds: 1500));
      debugPrint('[FLOW_TRACE] ☕ [$traceId] COOLDOWN: Finished');

      // Step 3: Attach New Owner
      if (target == CameraOwner.agora) {
        debugPrint('[FLOW_TRACE] 📥 [$traceId] AGORA_ACQUIRE: Enabling video & startPreview...');
        await _configureExternalSource(false); 
        await _engine?.enableVideo();
        await _engine?.startPreview();
        debugPrint('[FLOW_TRACE] ✅ [$traceId] AGORA_ACQUIRE: Success');
      } else if (target == CameraOwner.deepAr) {
        debugPrint('[FLOW_TRACE] 📥 [$traceId] DEEPAR_ACQUIRE: Initializing fresh controller...');
        await initialize(); // This will re-init since _deepArController is null
        
        await _configureExternalSource(true); 
        debugPrint('[FLOW_TRACE] ✅ [$traceId] DEEPAR_ACQUIRE: Success');
      }

      _currentOwner = target;
      // debugPrint('[FLOW_TRACE] 🏁 [$traceId] TRANSITION COMPLETED: Now owned by ${_currentOwner.name}\n');
    } catch (e) {
      debugPrint('[FLOW_TRACE] ❌ [$traceId] CRITICAL ERROR: $e');
    } finally {
      _isTransitioning = false;
    }
  }

  Future<void> _configureExternalSource(bool enabled) async {
    try {
      final mediaEngine = _engine?.getMediaEngine();
      if (mediaEngine != null) {
        debugPrint('[AGORA_STATE] 📝 Setting External Video Source: $enabled');
        await mediaEngine.setExternalVideoSource(
          enabled: enabled,
          useTexture: false,
          sourceType: ExternalVideoSourceType.videoFrame,
        );
      }
    } catch (e) {
      debugPrint('[AGORA_STATE] ⚠️ External Source Config Failed: $e');
    }
  }

  // Request permissions (Mic + Camera)
  Future<void> _requestPermissions() async {
    if (!kIsWeb) {
      await [Permission.microphone, Permission.camera].request();
    }
  }

  // Join channel with role
  Future<bool> joinChannel({
    required String channelId,
    required String token,
    required int uid,
    bool isBroadcaster = true,
    bool enableVideo = true,
  }) async {
    debugPrint('\n[AGORA_DEBUG] 🚀 ========== JOIN CHANNEL START ==========');
    
    // REMOVED: Automatic requestCameraControl(agora). 
    // We let the caller decide who owns the camera before joining.
    
    if (!_isInitialized || _engine == null) {
      debugPrint('[AGORA_DEBUG] ❌ Cannot join channel: Engine not initialized');
      return false;
    }

    try {
      // 🛡️ TRANSITION GUARD: If already in a channel, leave it first!
      if (_isInChannel || _currentChannelId != null) {
        debugPrint('[AGORA_DEBUG] 🔄 Already in channel $_currentChannelId. Leaving before joining $channelId...');
        await leaveChannel();
        // Give the OS a tiny breath to recycle the port/state
        await Future.delayed(const Duration(milliseconds: 300));
      }

      /* 
      REMOVED redundant setClientRole call to avoid Error -8 (Invalid Argument) 
      in certain SDK states. Role is now properly handled via ChannelMediaOptions 
      inside the joinChannel call below.
      */
      debugPrint('[AGORA_DEBUG] 📝 Preparing to join channel: $channelId as Broadcaster: $isBroadcaster');

      debugPrint('[AGORA_DEBUG] 📝 Joining channel: $channelId as UID: $uid (Broadcaster: $isBroadcaster, Video: $enableVideo)');
      final options = ChannelMediaOptions(
          clientRoleType: isBroadcaster
              ? ClientRoleType.clientRoleBroadcaster
              : ClientRoleType.clientRoleAudience,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
          publishCameraTrack: isBroadcaster && enableVideo,
          publishMicrophoneTrack: isBroadcaster,
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
          audienceLatencyLevel: AudienceLatencyLevelType.audienceLatencyLevelUltraLowLatency,
        );
      
      debugPrint('[AGORA_DEBUG] 🛠️ ChannelMediaOptions: publishMic=${options.publishMicrophoneTrack}, publishCam=${options.publishCameraTrack}, role=${options.clientRoleType?.name}');

      await _engine?.joinChannel(
        token: token,
        channelId: channelId,
        uid: uid,
        options: options,
      );

      _isInChannel = true;
      _currentChannelId = channelId;
      // debugPrint('[AGORA_DEBUG] ✅ ========== JOIN CHANNEL SUCCESS ==========\n');
      return true;
    } catch (e, stackTrace) {
      debugPrint('[AGORA_DEBUG] ❌ ========== JOIN CHANNEL ERROR ==========');
      debugPrint('[AGORA_DEBUG] ❌ Error: $e');
      debugPrint('[AGORA_DEBUG] 📍 Stack trace: $stackTrace');
      debugPrint('[AGORA_DEBUG] ❌ =============================================\n');
      return false;
    }
  }

  // Leave channel
  Future<void> leaveChannel() async {
    debugPrint('\n[AGORA_DEBUG] 🚀 ========== LEAVE CHANNEL START ==========');
    try {
      if (_engine != null) {
        await _engine?.leaveChannel();
        debugPrint('[AGORA_DEBUG] ✅ Left Agora channel');
      }
      _isInChannel = false;
      _currentChannelId = null;
      debugPrint('[AGORA_DEBUG] ✅ ========== LEAVE CHANNEL SUCCESS ==========\n');
    } catch (e) {
      debugPrint('[AGORA_DEBUG] ❌ ========== LEAVE CHANNEL ERROR ==========');
      debugPrint('[AGORA_DEBUG] ❌ Error: $e');
      debugPrint('[AGORA_DEBUG] ❌ =============================================\n');
    }
  }

  // Mute/Unmute microphone
  Future<void> toggleMute() async {
    if (!_isInitialized) return;

    try {
      _isMuted = !_isMuted;
      await _engine?.muteLocalAudioStream(_isMuted);
      
    } catch (e) {
      
    }
  }

  // Mute local microphone
  Future<void> mute() async {
    if (!_isInitialized || _isMuted) return;
    await toggleMute();
  }

  // Unmute local microphone
  Future<void> unmute() async {
    if (!_isInitialized || !_isMuted) return;
    await toggleMute();
  }

  // Set volume
  Future<void> setVolume(int volume) async {
    if (!_isInitialized) return;

    try {
      await _engine?.adjustPlaybackSignalVolume(volume);
    } catch (e) {
      
    }
  }

  // Switch Camera
  Future<void> switchCamera() async {
    if (!_isInitialized) return;
    try {
      await _engine?.switchCamera();
    } catch (e) {
      
    }
  }

  // Set Beauty Effect
  Future<void> setBeautyEffectOptions({
    required bool enabled,
    required BeautyOptions options,
  }) async {
    if (!_isInitialized) return;
    try {
      await _engine?.setBeautyEffectOptions(
        enabled: enabled, 
        options: options
      );
    } catch (e) {
      
    }
  }

  // UPDATE: Advanced Beauty Pipeline Mapping
  Future<void> updateAdvancedBeautyEffects({
    // Beauty
    double smooth = 80,
    double whiten = 0,
    double sharpen = 0,
    double clarity = 0,
    // Color
    double temp = 50,
    double tone = 50,
    double saturation = 50,
    double brightness = 50,
    double contrast = 50,
    // Facial - Face
    double faceSlim = 0,
    double faceSmall = 0,
    double faceNarrow = 0,
    double vFace = 0,
    double headSmall = 0,
    double cheekbones = 0,
    double lowerJaw = 0,
    double chin = 0,
    double nasolabial = 0,
    double hairline = 0,
    // Facial - Eyes
    double eyeSize = 0,
    double eyePupil = 0,
    double eyeSpacing = 0,
    double eyeLightening = 0,
    double darkCircles = 0,
    // Facial - Nose
    double noseSize = 0,
    double noseBridge = 0,
    double noseRoot = 0,
    double noseWings = 0,
    // Facial - Mouth
    double lipSize = 0,
    double mouthWidth = 0,
    double teethWhiten = 0,
    // Filters
    String filterName = 'normal',
    double filterIntensity = 30,
  }) async {
    if (!_isInitialized) return;

    // Cache values for re-application during sticker changes
    _cacheBeautyParams(smooth, whiten, faceSlim, eyeSize);

    try {
      
      
      
      

      // 1. Basic Agora Beauty (Mapping 0-100 to 0.0-1.0)
      await _engine?.setBeautyEffectOptions(
        enabled: true,
        options: BeautyOptions(
          lighteningContrastLevel: LighteningContrastLevel.lighteningContrastNormal,
          lighteningLevel: whiten / 100.0,
          smoothnessLevel: smooth / 100.0,
          rednessLevel: 0.1, // Slight natural pinkish tint
          sharpnessLevel: sharpen / 100.0,
        ),
      );

      // 2. High-End Filters & Facial Reshaping (DeepAR)
      if (_isDeepArInitialized && _deepArController != null) {
        
        // --- A. Apply Filter Effect ---
        String effectToLoad = 'null';
        
        if (filterName == 'normal') {
          // If "Normal", we load "MakeupLook" to provide beauty capabilities
          // because without ANY effect, DeepAR cannot do smoothing/whitening.
          effectToLoad = 'MakeupLook';
        } else {
             // Map filter name to asset
             final Map<String, String> effectMap = {
            'sunny': 'MakeupLook',          // Explicitly mapped to MakeupLook
            'gray': 'Neon_Devil_Horns',     
            'warm': 'burning_effect',       
            'blue': 'Stallone',             
            'bright': 'Hope',               
            'cool': 'viking_helmet',        
            'sweet': 'flower_face',         
            'pure': '8bitHearts',           
            'tender': 'Split_View_Look',    
            
            // New Additions 
            'galaxy': 'galaxy_background',
            'mask': 'Vendetta_Mask',
            'emotion': 'Emotion_Meter',
            'humanoid': 'Humanoid',
            'snail': 'Snail',
            'pingpong': 'Ping_Pong',
            'fire': 'Fire_Effect',
            'elephant': 'Elephant_Trunk',
            'exaggerator': 'Emotions_Exaggerator',
          };
          effectToLoad = effectMap[filterName] ?? filterName;
        }

        try {
           // Basic switch without slots (not supported in this package version)
           // Only switch if effect changed to avoid reloading same effect repeatedly?
           // The controller handles optimization usually, but let's just call it.
           if (effectToLoad != 'null') {
             await _deepArController!.switchEffect('assets/effects/$effectToLoad.deepar');
           } else {
             // If we really want NO effect (raw camera), we can switch to null
             // But usually we want beauty, so we defaulted normal -> MakeupLook above.
           }
        } catch (e) {
           
        }

        // --- B. Apply Beauty Parameters (to whatever effect is loaded) ---
        // 🚀 CRITICAL GUARD: Ensure controller and engine are ready
        if (_deepArController == null || !_isDeepArInitialized) return;

        try {
          // 1. Smooth & Whiten (Standard Face Node)
          if (smooth > 0) {
            _deepArController?.changeParameter(
              gameObject: 'Face',
              component: 'MeshRenderer',
              parameter: 'smoothAmount',
              newParameter: smooth / 100.0,
            );
          }
          if (whiten > 0) {
            _deepArController?.changeParameter(
              gameObject: 'Face',
              component: 'MeshRenderer',
              parameter: 'whitenAmount',
              newParameter: whiten / 100.0,
            );
          }

          // 2. Facial Reshaping
          if (faceSlim > 0) {
            _deepArController?.changeParameter(
              gameObject: 'Face',
              component: 'MeshRenderer',
              parameter: 'slimAmount',
              newParameter: faceSlim / 100.0,
            );
          }
          if (eyeSize > 0) {
            _deepArController?.changeParameter(
              gameObject: 'Face',
              component: 'MeshRenderer',
              parameter: 'eyeSize',
              newParameter: eyeSize / 100.0,
            );
          }
        } catch (e) {
          debugPrint('[DEEPAR_DEBUG] ⚠️ ChangeParameter failed: $e');
        }
      }

    } catch (e) {
      
    }
  }

  void _cacheBeautyParams(double s, double w, double f, double e) {
    _lastSmooth = s;
    _lastWhiten = w;
    _lastFaceSlim = f;
    _lastEyeSize = e;
  }

  // Set Sticker (Effect)
  Future<void> setSticker(String? assetName) async {
    if (!_isDeepArInitialized || _deepArController == null) return;

    try {
      if (assetName != null && assetName.isNotEmpty) {
        // Handle "None" or null asset
        if (assetName == 'null') {
             
             await _deepArController!.switchEffect('assets/effects/MakeupLook.deepar');
        } else {
             
             await _deepArController!.switchEffect('assets/effects/$assetName.deepar');
        }
      } else {
        
        await _deepArController!.switchEffect('assets/effects/MakeupLook.deepar');
      }

      // Re-apply beauty parameters to the new effect
      // (This assumes the new effect has the 'Face' node)
      await Future.delayed(const Duration(milliseconds: 300)); // Increased delay for safety
      _reapplyBeautyParams();

    } catch (e) {
      
    }
  }

  void _reapplyBeautyParams() {
    if (_deepArController == null || !_isDeepArInitialized) return;

    try {
      if (_lastSmooth > 0) {
        _deepArController?.changeParameter(
            gameObject: 'Face', component: 'MeshRenderer', parameter: 'smoothAmount', newParameter: _lastSmooth / 100.0);
      }
      if (_lastWhiten > 0) {
        _deepArController?.changeParameter(
            gameObject: 'Face', component: 'MeshRenderer', parameter: 'whitenAmount', newParameter: _lastWhiten / 100.0);
      }
      if (_lastFaceSlim > 0) {
        _deepArController?.changeParameter(
            gameObject: 'Face', component: 'MeshRenderer', parameter: 'slimAmount', newParameter: _lastFaceSlim / 100.0);
      }
      if (_lastEyeSize > 0) {
        _deepArController?.changeParameter(
            gameObject: 'Face', component: 'MeshRenderer', parameter: 'eyeSize', newParameter: _lastEyeSize / 100.0);
      }
    } catch (e) {
      debugPrint('[DEEPAR_DEBUG] ⚠️ ReapplyBeautyParams failed: $e');
    }
  }

  // Enable/Disable speaker
  Future<void> setSpeakerphone(bool enabled) async {
    if (!_isInitialized) return;

    try {
      await _engine?.setEnableSpeakerphone(enabled);
    } catch (e) {
      
    }
  }

  // Register event handlers
  void registerEventHandlers({
    Function(RtcConnection connection, int elapsed)? onJoinChannelSuccess,
    Function(RtcConnection connection, int remoteUid, int elapsed)?
    onUserJoined,
    Function(
      RtcConnection connection,
      int remoteUid,
      RemoteVideoState state,
      RemoteVideoStateReason reason,
      int elapsed,
    )?
    onRemoteVideoStateChanged,
    Function(
      RtcConnection connection,
      int remoteUid,
      UserOfflineReasonType reason,
    )?
    onUserOffline,
    Function(RtcConnection connection, RtcStats stats)? onLeaveChannel,
    Function(ErrorCodeType err, String msg)? onError,
    Function(
      RtcConnection connection,
      List<AudioVolumeInfo> speakers,
      int speakerNumber,
      int totalVolume,
    )?
    onAudioVolumeIndication,
    Function(
      RtcConnection connection,
      int remoteUid,
      QualityType txQuality,
      QualityType rxQuality,
    )?
    onNetworkQuality,
  }) {
    _engine?.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint('[AGORA_STATE] ✅ JOIN_SUCCESS: Channel=${connection.channelId}, LocalUID=${connection.localUid}, Elapsed=$elapsed');
          onJoinChannelSuccess?.call(connection, elapsed);
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          debugPrint('[AGORA_STATE] 👥 REMOTE_USER_JOINED: $remoteUid in channel ${connection.channelId}');
          onUserJoined?.call(connection, remoteUid, elapsed);
        },
        onRemoteVideoStateChanged: (connection, remoteUid, state, reason, elapsed) {
          debugPrint('[AGORA_STATE] 📹 REMOTE_VIDEO_STATE: $remoteUid -> ${state.name}');
          onRemoteVideoStateChanged?.call(connection, remoteUid, state, reason, elapsed);
        },
        onUserOffline: onUserOffline,
        onLeaveChannel: onLeaveChannel,
        onError: (ErrorCodeType err, String msg) {
           debugPrint('[AGORA_ERROR] ❌ CRITICAL_ERROR: Code=${err.name} (${err.index}), Msg=$msg');
           onError?.call(err, msg);
        },
        onConnectionStateChanged: (connection, state, reason) {
           debugPrint('[AGORA_STATE] 🌐 CONNECTION_STATE: ${state.name} (Reason: ${reason.name})');
        },
        onTokenPrivilegeWillExpire: (connection, token) {
           debugPrint('[AGORA_STATE] ⚠️ TOKEN_EXPIRING: Token length=${token.length}');
        },
        onRequestToken: (connection) {
           debugPrint('[AGORA_STATE] 🔄 TOKEN_REQUIRED: Agora is requesting a new token');
        },
        onAudioVolumeIndication: (RtcConnection connection, List<AudioVolumeInfo> speakers, int speakerNumber, int totalVolume) {
           for (var speaker in speakers) {
             if (speaker.uid == 0 && (speaker.volume ?? 0) > 0) {
                debugPrint('[AUDIO_TRACE] 🎤 Local User (UID 0) Volume: ${speaker.volume}, VAD: ${speaker.vad}');
             }
           }
           onAudioVolumeIndication?.call(connection, speakers, speakerNumber, totalVolume);
        },
        onNetworkQuality: onNetworkQuality,
        onRemoteAudioStateChanged: (connection, remoteUid, state, reason, elapsed) {
           debugPrint('[AUDIO_STATUS] 🔊 Remote User $remoteUid Audio State: ${state.name} (Reason: ${reason.name})');
        },
        onLocalAudioStateChanged: (connection, state, reason) {
           debugPrint('[AUDIO_STATUS] 🎙️ Local Audio State: ${state.name} (Reason: ${reason.name})');
        }
      ),
    );
  }

  // Enable audio volume indication
  Future<void> enableAudioVolumeIndication({
    int interval = 300,
    int smooth = 3,
    bool reportVad = true,
  }) async {
    if (!_isInitialized) return;

    try {
      await _engine?.enableAudioVolumeIndication(
        interval: interval,
        smooth: smooth,
        reportVad: reportVad,
      );
    } catch (e) {
      
    }
  }

  // Dispose
  Future<void> dispose() async {
    try {
      await leaveChannel();
      await _engine?.release();
      _isInitialized = false;
      _engine = null;
      
    } catch (e) {
      
    }
  }

  // Switch role during call
  Future<void> setClientRole(bool isBroadcaster) async {
    if (!_isInitialized) return;
    await _engine?.setClientRole(
      role: isBroadcaster
          ? ClientRoleType.clientRoleBroadcaster
          : ClientRoleType.clientRoleAudience,
    );
  }

  // ==================== AGORA TOKEN ====================

  Future<String> generateAgoraToken({
    required String channelName,
    required int uid,
  }) async {
    try {
      debugPrint('[AGORA_DEBUG] 📝 Requesting token for channel: $channelName, uid: $uid');

      // Call Cloud Function to generate token
      final callable = FirebaseFunctions.instance.httpsCallable('generateAgoraToken');
      final result = await callable.call({
        'channelName': channelName,
        'uid': uid,
      });

      final token = result.data['token'] as String;
      debugPrint('[AGORA_DEBUG] ✅ Token received successfully');

      return token;
    } catch (e) {
      debugPrint('[AGORA_DEBUG] ❌ Token Generation Failed: $e');
      return ''; // Fallback to test mode
    }
  }
}
