import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

class WidgetGitReleaseChecker extends StatefulWidget {
  final String user;
  final String repo;
  final String currentRelease;
  final bool filterOutPreRelease;
  final bool showLoading;


  const WidgetGitReleaseChecker({
    super.key,
    required this.user,
    required this.repo,
    required this.currentRelease,
    required this.filterOutPreRelease,
    required this.showLoading,
  });

  @override
  State<WidgetGitReleaseChecker> createState() =>
      _WidgetGitReleaseCheckerState();
}

class _WidgetGitReleaseCheckerState extends State<WidgetGitReleaseChecker> {
  Future<dynamic> githubReleaseCheck(
    String user,
    String repo,
    String currentRelease,
    bool filterOutPreRelease,
  ) async {
    debugPrint('\x1B[32m[GitReleaseCheckerLog]: Execution started\x1B[0m');

    final response = await http.get(
      Uri.parse('https://api.github.com/repos/$user/$repo/releases'),
    );

    debugPrint(
      '\x1B[32m[GitReleaseCheckerLog]: Status code ${response.statusCode}\x1B[0m',
    );

    if (response.statusCode != 200) return false;

    final decoded = jsonDecode(response.body);
    if (decoded is! List || decoded.isEmpty) return false;

    Map<String, dynamic>? item;

    // pick first valid release
    for (final r in decoded) {
      if (r is! Map<String, dynamic>) continue;

      final bool isPre = r['prerelease'] == true;
      if (filterOutPreRelease && isPre) continue;

      item = r;
      break;
    }

    if (item == null) return false;

    // -------- guarded fields --------
    final String name =
        (item['name'] is String && item['name'].toString().trim().isNotEmpty)
            ? item['name']
            : 'Unnamed Release';

    final String tag =
        (item['tag_name'] is String && item['tag_name'].toString().isNotEmpty)
            ? item['tag_name']
            : 'v0.0.0';

    final String publishedAt =
        (item['published_at'] is String) ? item['published_at'] : 'Unknown';

    final String description =
        (item['body'] is String) ? item['body'] : '';

    final bool preRelease = item['prerelease'] == true;

    // assets guard
    String? downloadLink;
    if (item['assets'] is List && item['assets'].isNotEmpty) {
      final asset = item['assets'][0];
      if (asset is Map && asset['browser_download_url'] is String) {
        downloadLink = asset['browser_download_url'];
      }
    }

    // -------- version parsing guard --------
    List<int> parseVersion(String v) {
      return v
          .replaceFirst('v', '')
          .split('.')
          .map((e) => int.tryParse(e) ?? 0)
          .toList();
    }

    final r1 = parseVersion(currentRelease);
    final r2 = parseVersion(tag);

    bool isNewer = false;
    final maxLen = r1.length > r2.length ? r1.length : r2.length;

    for (int i = 0; i < maxLen; i++) {
      final a = i < r1.length ? r1[i] : 0;
      final b = i < r2.length ? r2[i] : 0;

      if (b > a) {
        isNewer = true;
        break;
      } else if (b < a) {
        break;
      }
    }

    if (!isNewer) return false;

    final data = {
      'name': name,
      'version': tag,
      'published_at': publishedAt,
      'download_link': downloadLink,
      'description': description,
      'pre_release': preRelease,
      'new': true,
    };

    debugPrint('\x1B[32m[GitReleaseCheckerLog]: $data');

    return data;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<dynamic>(
      future: githubReleaseCheck(
        widget.user,
        widget.repo,
        widget.currentRelease,
        widget.filterOutPreRelease,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          if (!widget.showLoading) {
            return const SizedBox.shrink();
          }

          return const SizedBox(
            height: 50,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          debugPrint('\x1B[31m GitReleaseCheckerERROR: ${snapshot.error}');
          return const SizedBox();
        }

        if (!snapshot.hasData || snapshot.data == false) {
          return const SizedBox();
        }

        final data = snapshot.data as Map<String, dynamic>;

        return Container(
          margin: const EdgeInsets.all(5),
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.lightGreen[100],
            border: Border.all(color: Colors.green, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(data['name']),
              Text('${data['version']} ${data['new'] ? "new" : ""}'),
              Text('Date Published ${data['published_at']}'),
              if (data['pre_release']) const Text('This is a PreRelease version'),
              if (data['download_link'] != null)
                TextButton(
                  onPressed: () {
                    launchUrl(
                      Uri.parse(data['download_link']),
                      // mode: LaunchMode.externalApplication,
                    );
                  },
                  child: const Text(
                    'Download latest',
                    style: TextStyle(
                      decoration: TextDecoration.underline,
                      color: Colors.blue,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
