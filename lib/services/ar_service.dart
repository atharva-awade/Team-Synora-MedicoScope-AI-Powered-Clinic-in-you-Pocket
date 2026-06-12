import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class ARService {
  /// Launch AR viewer for the given 3D model
  /// On iOS: Uses AR Quick Look with GLB files
  /// On Android: Uses Scene Viewer with GLB files via FileProvider
  static Future<bool> launchARViewer(String modelPath) async {
    try {
      if (Platform.isIOS) {
        return await _launchIOSARQuickLook(modelPath);
      } else if (Platform.isAndroid) {
        return await _launchAndroidSceneViewer(modelPath);
      } else {
        print('AR viewing is not supported on this platform');
        return false;
      }
    } catch (e) {
      print('Error launching AR viewer: $e');
      return false;
    }
  }

  /// Launch AR Quick Look on iOS
  static Future<bool> _launchIOSARQuickLook(String modelPath) async {
    try {
      // Load the GLB file from assets
      final ByteData data = await rootBundle.load(modelPath);
      final List<int> bytes = data.buffer.asUint8List();

      // Get temporary directory
      final Directory tempDir = await getTemporaryDirectory();
      final String fileName = modelPath.split('/').last;
      final File tempFile = File('${tempDir.path}/$fileName');

      // Write the file to temporary directory
      await tempFile.writeAsBytes(bytes);

      // Create the AR Quick Look URL
      final Uri arUrl = Uri.parse('file://${tempFile.path}');

      // Launch AR Quick Look
      if (await canLaunchUrl(arUrl)) {
        return await launchUrl(
          arUrl,
          mode: LaunchMode.externalApplication,
        );
      } else {
        print('Cannot launch AR Quick Look');
        return false;
      }
    } catch (e) {
      print('Error launching iOS AR Quick Look: $e');
      return false;
    }
  }

  /// Launch Scene Viewer on Android using FileProvider
  static Future<bool> _launchAndroidSceneViewer(String modelPath) async {
    try {
      // Load the GLB file from assets
      final ByteData data = await rootBundle.load(modelPath);
      final List<int> bytes = data.buffer.asUint8List();

      // Get cache directory for AR models
      final Directory cacheDir = await getTemporaryDirectory();
      final Directory arModelsDir = Directory('${cacheDir.path}/ar_models');
      
      // Create directory if it doesn't exist
      if (!await arModelsDir.exists()) {
        await arModelsDir.create(recursive: true);
      }

      final String fileName = modelPath.split('/').last;
      final File modelFile = File('${arModelsDir.path}/$fileName');

      // Write the file
      await modelFile.writeAsBytes(bytes);
      
      print('Model file saved to: ${modelFile.path}');

      // Use method channel to get content URI from FileProvider
      const platform = MethodChannel('com.example.medicoscope/ar');
      
      try {
        final String? contentUri = await platform.invokeMethod(
          'getContentUri',
          {'filePath': modelFile.path},
        );

        if (contentUri == null) {
          print('Failed to get content URI from FileProvider');
          return false;
        }

        print('Content URI: $contentUri');

        // Create Scene Viewer intent URL with content URI
        final Uri sceneViewerUrl = Uri.parse(
          'intent://arvr.google.com/scene-viewer/1.0?file=$contentUri&mode=ar_preferred#Intent;scheme=https;package=com.google.android.googlequicksearchbox;action=android.intent.action.VIEW;S.browser_fallback_url=https://developers.google.com/ar;end;',
        );

        print('Launching Scene Viewer with URL: $sceneViewerUrl');

        // Launch Scene Viewer
        if (await canLaunchUrl(sceneViewerUrl)) {
          return await launchUrl(
            sceneViewerUrl,
            mode: LaunchMode.externalApplication,
          );
        } else {
          print('Cannot launch Scene Viewer');
          return false;
        }
      } on PlatformException catch (e) {
        print('Platform exception: ${e.message}');
        return false;
      }
    } catch (e) {
      print('Error launching Android Scene Viewer: $e');
      return false;
    }
  }

  /// Check if AR is supported on the current device
  static bool isARSupported() {
    return Platform.isIOS || Platform.isAndroid;
  }

  /// Get a user-friendly message about AR support
  static String getARSupportMessage() {
    if (Platform.isIOS) {
      return 'AR viewing requires iOS 12 or later';
    } else if (Platform.isAndroid) {
      return 'AR viewing requires ARCore support';
    } else {
      return 'AR viewing is not supported on this platform';
    }
  }
}
