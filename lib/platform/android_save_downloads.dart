import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Guardado en Descargas (Android) con MIME explícito vía [MainActivity].
class AndroidSaveDownloads {
  static const MethodChannel _channel =
      MethodChannel('com.kevin.dolarsabio/downloads');

  static Future<String?> save({
    required String filename,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>(
        'saveToDownloads',
        <String, Object?>{
          'filename': filename,
          'mimeType': mimeType,
          'bytes': bytes,
        },
      );
    } on PlatformException {
      return null;
    }
  }
}
