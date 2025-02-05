import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class ElevenLabsService {
  final String apiKey;

  ElevenLabsService(this.apiKey);

  Future<File> getTTS(String text, String voiceId) async {
    final url = Uri.parse("https://api.elevenlabs.io/v1/text-to-speech/$voiceId");
    final headers = {
      "Content-Type": "application/json",
      "xi-api-key": apiKey,
    };
    final body = jsonEncode({
      "text": text,
      "voice_settings": {
        "stability": 0.5,
        "similarity_boost": 0.75,
      },
    });

    final response = await http.post(url, headers: headers, body: body);

    if (response.statusCode == 200) {
      final appDir = await getApplicationDocumentsDirectory();
      final filePath = "${appDir.path}/output.mp3";
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);
      return file;
    } else {
      throw Exception("Failed to fetch TTS audio: ${response.body}");
    }
  }
}
