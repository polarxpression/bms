import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class ImageUploadService {
  static const String _baseUrl = 'https://api.imgbb.com/1/upload';

  /// Uploads an image to ImgBB and returns the URL.
  /// 
  /// [imageFile] is the file picked by ImagePicker.
  /// [apiKey] is the ImgBB API key.
  static Future<String?> uploadImage(XFile imageFile, String apiKey) async {
    if (apiKey.isEmpty) {
      throw Exception('API Key is missing');
    }

    try {
      final uri = Uri.parse(_baseUrl);
      final request = http.MultipartRequest('POST', uri)
        ..fields['key'] = apiKey
        ..files.add(await http.MultipartFile.fromPath('image', imageFile.path));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success'] == true) {
          return jsonResponse['data']['url'];
        }
      }
      return null;
    } catch (e) {
      // print('Upload error: $e');
      return null;
    }
  }
}
