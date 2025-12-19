// lib\widgets\widget_github_release_checker.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:url_launcher/url_launcher.dart';

class WidgetGitReleaseChecker extends StatefulWidget {
  final String user;
  final String repo;
  final String currentRelease;
  final bool filterOutPreRelease;

  const WidgetGitReleaseChecker({
    super.key,
    required this.user,
    required this.repo,
    required this.currentRelease,
    required this.filterOutPreRelease,
  });

  @override
  State<WidgetGitReleaseChecker> createState() =>
      _WidgetGitReleaseCheckerState();
}

class _WidgetGitReleaseCheckerState extends State<WidgetGitReleaseChecker> {
  dynamic githubReleaseCheck(
    String user,
    String repo,
    String currentRelease,
    bool filterOutPreRelease,
  ) async {
    // fetching
    final response = await http.get(
      Uri.parse('https://api.github.com/repos/$user/$repo/releases'),
    );

    if (response.statusCode != 200) {
      // if there is no internet, then nothing can be done
      return false;
    }

    // we got a response, cleaning the data
    dynamic data = jsonDecode(response.body);
    dynamic item;
    for (var i in data) {
      if (filterOutPreRelease) {
        if (i['prerelease'] == false) {
          item = i;
        }
      } else {
        item = i;
      }
    }

    if (item == null) return false;

    data = {
      'name': item['name'],
      'version': item['tag_name'],
      'published_at': item['published_at'],
      'download_link': item['assets'][0]['browser_download_url'],
      'description': item['body'],
      'pre_release': !filterOutPreRelease,
    };

    // converting current release
    dynamic r1 = currentRelease.replaceFirst('v', '').split('.');
    dynamic r2 = item['tag_name'].replaceFirst('v', '').split('.');
    // check change in release
    bool isNewer = false;
    for (int i = 0; i < r1.length; i++) {
      var i1 = int.parse(r1[i]);
      var i2 = int.parse(r2[i]);

      if (i2 > i1) {
        isNewer = true;
        break;
      } else if (i2 == i1) {
        continue;
      } else {
        break;
      }
    }

    if (isNewer == false) {
      return false;
    }

    data['new'] = isNewer;

    return data;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: githubReleaseCheck(
        widget.user,
        widget.repo,
        widget.currentRelease,
        widget.filterOutPreRelease,
      ),
      builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
        if (snapshot.hasData) {
          if (snapshot.data != false) {
            return Column(
              children: [
                Container(
                  width: double.infinity,
                  constraints: BoxConstraints(minHeight: 0),
                  decoration: BoxDecoration(
                    color: Colors.lightGreen[100],
                    border: Border.all(color: Colors.green, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(snapshot.data['name']),
                        Text(
                          '${snapshot.data['version']} ${snapshot.data['new'] ? "new" : ""}',
                        ),
                        Text("Date Published ${snapshot.data['published_at']}"),
                        if (snapshot.data['pre_release'])
                          Text('This is a PreRelease version'),
                        TextButton(
                          onPressed: () {
                            launchUrl(
                              Uri.parse(snapshot.data['download_link']),
                            );
                          },
                          style: ButtonStyle(
                            padding: WidgetStateProperty.all<EdgeInsets>(
                              EdgeInsets.zero,
                            ),
                            minimumSize: WidgetStateProperty.all(Size(0, 0)),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            alignment: Alignment.centerLeft,
                          ),
                          child: Text(
                            'Download latest',
                            style: TextStyle(
                              decoration: TextDecoration.underline,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }
        }
        return Container();
      },
    );
  }
}