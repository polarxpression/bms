import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:version/version.dart';

class UpdateInfo {
  final String version;
  final String releaseNotes;
  final String downloadUrl;
  final String tagName;

  UpdateInfo({
    required this.version,
    required this.releaseNotes,
    required this.downloadUrl,
    required this.tagName,
  });
}

class UpdateService {
  final String _repoOwner = 'polarxpression';
  final String _repoName = 'bms';

  Future<UpdateInfo?> checkForUpdate() async {
    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final Version currentVersion = Version.parse(packageInfo.version);

      final response = await http.get(
        Uri.parse('https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest'),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final String tagName = data['tag_name'];
        // Remove 'v' prefix if present
        final String remoteVersionStr = tagName.startsWith('v') ? tagName.substring(1) : tagName;
        
        try {
           final Version remoteVersion = Version.parse(remoteVersionStr);

           if (remoteVersion > currentVersion) {
             String? downloadUrl;
             
             // Find the correct asset
             final List<dynamic> assets = data['assets'];
             if (Platform.isWindows) {
               // Look for .exe
               final asset = assets.firstWhere(
                 (a) => a['name'].toString().endsWith('.exe'),
                 orElse: () => null,
               );
               downloadUrl = asset?['browser_download_url'];
             } else if (Platform.isAndroid) {
               // Look for .apk
               final asset = assets.firstWhere(
                 (a) => a['name'].toString().endsWith('.apk'),
                 orElse: () => null,
               );
               downloadUrl = asset?['browser_download_url'];
             }

             // If no specific asset found, fallback to html_url (release page)
             downloadUrl ??= data['html_url'];

             return UpdateInfo(
               version: tagName,
               releaseNotes: data['body'] ?? '',
               downloadUrl: downloadUrl!,
               tagName: tagName,
             );
           }
        } catch (e) {
          debugPrint('Error parsing remote version: $e');
        }
      }
    } catch (e) {
      debugPrint('Error checking for updates: $e');
    }
    return null;
  }

  Future<void> downloadAndInstall(String url) async {
    if (url.startsWith('http')) {
       // If it is a direct file download (checked by extension)
       if (url.endsWith('.exe') || url.endsWith('.apk')) {
         try {
           final directory = await getTemporaryDirectory();
           final String fileName = url.split('/').last;
           final String savePath = '${directory.path}/$fileName';

           // Download
           final response = await http.get(Uri.parse(url));
           final File file = File(savePath);
           await file.writeAsBytes(response.bodyBytes);

           // Install/Open
           final result = await OpenFilex.open(savePath);
           if (result.type != ResultType.done) {
             debugPrint('Error opening file: ${result.message}');
             // Fallback to launcher if open fails
             if (!await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) {
                throw 'Could not launch $url';
             }
           }
         } catch (e) {
           debugPrint('Error downloading/installing: $e');
           // Fallback
           if (!await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) {
              throw 'Could not launch $url';
           }
         }
       } else {
         // Open release page
         if (!await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) {
           throw 'Could not launch $url';
         }
       }
    }
  }
}
