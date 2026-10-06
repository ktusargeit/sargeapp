import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ImgbbService {
  static Future<String?> uploadImage(Uint8List imageBytes, {String? fileName}) async {
    try {
      final apiKey = dotenv.env['IMGBB_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('ImgBB API key is missing.');
      }

      final uri = Uri.parse('https://api.imgbb.com/1/upload?key=$apiKey');
      
      final request = http.MultipartRequest('POST', uri);
      
      final multipartFile = http.MultipartFile.fromBytes(
        'image',
        imageBytes,
        filename: fileName ?? 'image.jpg',
      );

      request.files.add(multipartFile);

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      
      if (response.statusCode == 200) {
        final decoded = jsonDecode(responseBody);
        return decoded['data']['url']; // Return the direct URL to the image
      } else {
        debugPrint('ImgBB upload failed: ${response.statusCode} - $responseBody');
        return null;
      }
    } catch (e) {
      debugPrint('ImgBB upload error: $e');
      return null;
    }
  }
}
