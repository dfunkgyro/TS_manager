import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/foundation.dart';

/// Voice Recognition Service for speech-to-text and text-to-speech
class VoiceRecognitionService extends ChangeNotifier {
  late stt.SpeechToText _speech;
  late FlutterTts _flutterTts;

  bool _isListening = false;
  bool _speechAvailable = false;
  bool _ttsAvailable = false;
  String _lastWords = '';
  double _confidence = 0.0;

  // TTS settings
  double _volume = 1.0;
  double _pitch = 1.0;
  double _rate = 0.5;

  VoiceRecognitionService() {
    _initializeSpeech();
    _initializeTts();
  }

  // Getters
  bool get isListening => _isListening;
  bool get speechAvailable => _speechAvailable;
  bool get ttsAvailable => _ttsAvailable;
  String get lastWords => _lastWords;
  double get confidence => _confidence;
  double get volume => _volume;
  double get pitch => _pitch;
  double get rate => _rate;

  /// Initialize speech recognition
  Future<void> _initializeSpeech() async {
    try {
      _speech = stt.SpeechToText();
      _speechAvailable = await _speech.initialize(
        onStatus: (status) {
          debugPrint('Speech status: $status');
          if (status == 'done' || status == 'notListening') {
            _isListening = false;
            notifyListeners();
          }
        },
        onError: (error) {
          debugPrint('Speech error: $error');
          _isListening = false;
          notifyListeners();
        },
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing speech: $e');
      _speechAvailable = false;
      notifyListeners();
    }
  }

  /// Initialize text-to-speech
  Future<void> _initializeTts() async {
    try {
      _flutterTts = FlutterTts();

      // Set default values
      await _flutterTts.setVolume(_volume);
      await _flutterTts.setPitch(_pitch);
      await _flutterTts.setSpeechRate(_rate);

      // Set completion handler
      _flutterTts.setCompletionHandler(() {
        debugPrint('TTS completed');
      });

      _flutterTts.setErrorHandler((msg) {
        debugPrint('TTS error: $msg');
      });

      _ttsAvailable = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing TTS: $e');
      _ttsAvailable = false;
      notifyListeners();
    }
  }

  /// Start listening to user speech
  Future<void> startListening({
    required Function(String) onResult,
    String? localeId,
  }) async {
    if (!_speechAvailable) {
      debugPrint('Speech recognition not available');
      return;
    }

    if (_isListening) {
      await stopListening();
    }

    try {
      _isListening = true;
      _lastWords = '';
      notifyListeners();

      await _speech.listen(
        onResult: (result) {
          _lastWords = result.recognizedWords;
          _confidence = result.confidence;

          debugPrint('Recognized: $_lastWords (confidence: $_confidence)');

          // Call callback with recognized text
          if (result.finalResult) {
            onResult(_lastWords);
            _isListening = false;
          }

          notifyListeners();
        },
        localeId: localeId ?? 'en_US',
        listenMode: stt.ListenMode.confirmation,
        cancelOnError: false,
        partialResults: true,
      );
    } catch (e) {
      debugPrint('Error starting speech recognition: $e');
      _isListening = false;
      notifyListeners();
    }
  }

  /// Stop listening
  Future<void> stopListening() async {
    if (_isListening) {
      await _speech.stop();
      _isListening = false;
      notifyListeners();
    }
  }

  /// Speak text aloud
  Future<void> speak(String text) async {
    if (!_ttsAvailable) {
      debugPrint('TTS not available');
      return;
    }

    try {
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint('Error speaking: $e');
    }
  }

  /// Stop speaking
  Future<void> stopSpeaking() async {
    if (_ttsAvailable) {
      await _flutterTts.stop();
    }
  }

  /// Set TTS volume (0.0 to 1.0)
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    if (_ttsAvailable) {
      await _flutterTts.setVolume(_volume);
    }
    notifyListeners();
  }

  /// Set TTS pitch (0.5 to 2.0)
  Future<void> setPitch(double pitch) async {
    _pitch = pitch.clamp(0.5, 2.0);
    if (_ttsAvailable) {
      await _flutterTts.setPitch(_pitch);
    }
    notifyListeners();
  }

  /// Set TTS speech rate (0.0 to 1.0)
  Future<void> setRate(double rate) async {
    _rate = rate.clamp(0.0, 1.0);
    if (_ttsAvailable) {
      await _flutterTts.setSpeechRate(_rate);
    }
    notifyListeners();
  }

  /// Get available languages for speech recognition
  Future<List<stt.LocaleName>> getAvailableLanguages() async {
    if (!_speechAvailable) return [];
    return await _speech.locales();
  }

  /// Get available voices for TTS
  Future<List<dynamic>> getAvailableVoices() async {
    if (!_ttsAvailable) return [];
    try {
      final voices = await _flutterTts.getVoices;
      return voices ?? [];
    } catch (e) {
      debugPrint('Error getting voices: $e');
      return [];
    }
  }

  /// Set TTS voice
  Future<void> setVoice(Map<String, String> voice) async {
    if (_ttsAvailable) {
      await _flutterTts.setVoice(voice);
    }
  }

  @override
  void dispose() {
    stopListening();
    stopSpeaking();
    super.dispose();
  }
}
