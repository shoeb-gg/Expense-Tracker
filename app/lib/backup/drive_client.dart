/// The few Google Drive calls the backup needs, over plain HTTPS: find or
/// make the backup folder, upload, list, download and delete files. With the
/// drive.file permission the app only ever sees files it made itself.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// A file in the backup folder.
@immutable
class DriveFile {
  const DriveFile({
    required this.id,
    required this.name,
    required this.createdTime,
    required this.size,
    required this.properties,
  });

  factory DriveFile.fromJson(Map<String, Object?> json) {
    final props = json['appProperties'];
    return DriveFile(
      id: json['id']! as String,
      name: (json['name'] as String?) ?? '',
      createdTime: DateTime.tryParse((json['createdTime'] as String?) ?? '')?.toLocal(),
      size: int.tryParse((json['size'] as String?) ?? ''),
      properties: props is Map<String, Object?>
          ? {for (final e in props.entries) e.key: '${e.value}'}
          : const <String, String>{},
    );
  }

  final String id;
  final String name;
  final DateTime? createdTime;

  /// Bytes, when Drive reports it.
  final int? size;

  /// The app's own notes on the file (`appProperties`).
  final Map<String, String> properties;

  @override
  bool operator ==(Object other) =>
      other is DriveFile &&
      other.id == id &&
      other.name == name &&
      other.createdTime == createdTime &&
      other.size == size &&
      mapEquals(other.properties, properties);

  @override
  int get hashCode => Object.hash(id, name, createdTime, size);
}

/// A Drive call that failed.
class DriveException implements Exception {
  const DriveException(this.statusCode, this.message);

  /// The HTTP status, or 0 when Drive could not be reached.
  final int statusCode;
  final String message;

  /// The sign-in has expired or was taken back.
  bool get unauthorized => statusCode == 401;

  /// No internet (or Drive could not be reached).
  bool get offline => statusCode == 0;

  @override
  String toString() => 'DriveException($statusCode): $message';
}

/// Gives the access token for the drive.file permission. [refresh] asks for
/// a new one after Drive turned the last one down.
typedef TokenSource = Future<String> Function({bool refresh});

class DriveClient {
  DriveClient(this._http, this._token);

  final http.Client _http;
  final TokenSource _token;

  /// The folder the backups go into, in the user's Drive.
  static const String folderName = 'Spill the Bills backups';

  static const String _api = 'https://www.googleapis.com/drive/v3/files';
  static const String _upload = 'https://www.googleapis.com/upload/drive/v3/files';
  static const String _folderType = 'application/vnd.google-apps.folder';
  static const String _fields = 'id,name,createdTime,size,appProperties';

  /// Sends a request built by [build] with the token; once more with a fresh
  /// token when Drive says it expired. Turns errors into [DriveException].
  Future<http.Response> _send(Future<http.BaseRequest> Function(String token) build) async {
    for (var attempt = 0; ; attempt++) {
      final token = await _token(refresh: attempt > 0);
      final http.Response response;
      try {
        response = await http.Response.fromStream(await _http.send(await build(token)));
      } on SocketException catch (e) {
        throw DriveException(0, e.message);
      } on http.ClientException catch (e) {
        throw DriveException(0, e.message);
      }
      if (response.statusCode == 401 && attempt == 0) continue;
      if (response.statusCode >= 400) {
        throw DriveException(response.statusCode, response.body);
      }
      return response;
    }
  }

  Map<String, String> _auth(String token) => {'Authorization': 'Bearer $token'};

  Future<http.Request> _get(Uri uri, String token) async =>
      http.Request('GET', uri)..headers.addAll(_auth(token));

  /// The backup folder's id; makes the folder the first time.
  Future<String> ensureFolder() async {
    final query = "name = '$folderName' and mimeType = '$_folderType' and trashed = false";
    final found = await _send(
      (t) => _get(Uri.parse(_api).replace(queryParameters: {'q': query, 'spaces': 'drive', 'fields': 'files(id)'}), t),
    );
    final files = (jsonDecode(found.body) as Map<String, Object?>)['files'];
    if (files is List && files.isNotEmpty) {
      return (files.first as Map<String, Object?>)['id']! as String;
    }
    final made = await _send(
      (t) async => http.Request('POST', Uri.parse(_api).replace(queryParameters: {'fields': 'id'}))
        ..headers.addAll({..._auth(t), 'Content-Type': 'application/json; charset=UTF-8'})
        ..body = jsonEncode({'name': folderName, 'mimeType': _folderType}),
    );
    return (jsonDecode(made.body) as Map<String, Object?>)['id']! as String;
  }

  /// Uploads [file] into [folderId] as [name], with [properties] as its
  /// notes. Uses a resumable upload, which suits files of any size.
  Future<DriveFile> upload(
    File file, {
    required String folderId,
    required String name,
    Map<String, String> properties = const {},
  }) async {
    final length = await file.length();
    final start = await _send(
      (t) async => http.Request(
        'POST',
        Uri.parse(_upload).replace(queryParameters: {'uploadType': 'resumable', 'fields': _fields}),
      )
        ..headers.addAll({
          ..._auth(t),
          'Content-Type': 'application/json; charset=UTF-8',
          'X-Upload-Content-Type': 'application/zip',
          'X-Upload-Content-Length': '$length',
        })
        ..body = jsonEncode({
          'name': name,
          'parents': [folderId],
          'mimeType': 'application/zip',
          'appProperties': properties,
        }),
    );
    final session = start.headers['location'];
    if (session == null) throw const DriveException(500, 'Drive did not start the upload.');
    final done = await _send((t) async {
      final put = http.StreamedRequest('PUT', Uri.parse(session))
        ..headers.addAll({..._auth(t), 'Content-Type': 'application/zip'})
        ..contentLength = length;
      file.openRead().listen(put.sink.add, onDone: put.sink.close, onError: put.sink.addError);
      return put;
    });
    return DriveFile.fromJson(jsonDecode(done.body) as Map<String, Object?>);
  }

  /// The files in [folderId], newest first.
  Future<List<DriveFile>> list(String folderId) async {
    final response = await _send(
      (t) => _get(
        Uri.parse(_api).replace(
          queryParameters: {
            'q': "'$folderId' in parents and trashed = false",
            'orderBy': 'createdTime desc',
            'pageSize': '100',
            'spaces': 'drive',
            'fields': 'files($_fields)',
          },
        ),
        t,
      ),
    );
    final files = (jsonDecode(response.body) as Map<String, Object?>)['files'];
    return [
      if (files is List)
        for (final f in files) DriveFile.fromJson(f as Map<String, Object?>),
    ];
  }

  /// Saves the file [id] to [target].
  Future<void> download(String id, File target) async {
    final response = await _send((t) => _get(Uri.parse('$_api/$id').replace(queryParameters: {'alt': 'media'}), t));
    await target.writeAsBytes(response.bodyBytes, flush: true);
  }

  /// Deletes the file [id] for good.
  Future<void> delete(String id) async {
    await _send((t) async => http.Request('DELETE', Uri.parse('$_api/$id'))..headers.addAll(_auth(t)));
  }
}
