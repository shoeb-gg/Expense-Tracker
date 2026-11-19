import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// An in-memory Google Drive that answers the calls DriveClient makes.
class FakeDrive {
  FakeDrive() {
    client = MockClient(_handle);
  }

  late final http.Client client;

  /// Folder id -> name.
  final Map<String, String> folders = {};

  /// File id -> stored file.
  final Map<String, FakeDriveFile> files = {};

  /// The time new files get.
  DateTime clock = DateTime.utc(2026, 11, 19, 15);

  bool expireNextToken = false;
  bool rejectAll = false;
  int refreshes = 0;
  int _next = 1;
  int _token = 1;
  final Map<String, ({String name, String parent, Map<String, String> props})> _sessions = {};

  /// The access tokens handed out.
  Future<String> token({bool refresh = false}) async {
    if (refresh) {
      refreshes++;
      _token++;
    }
    return 'token-$_token';
  }

  bool _authorized(http.BaseRequest r) {
    if (rejectAll) return false;
    if (expireNextToken && r.headers['Authorization'] == 'Bearer token-1') {
      expireNextToken = false;
      return false;
    }
    return r.headers['Authorization']?.startsWith('Bearer token-') ?? false;
  }

  http.Response _json(Object body, [int status = 200]) =>
      http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

  Map<String, Object?> _fileJson(String id) {
    final f = files[id]!;
    return {
      'id': id,
      'name': f.name,
      'createdTime': f.created.toIso8601String(),
      'size': '${f.bytes.length}',
      'appProperties': f.props,
    };
  }

  Future<http.Response> _handle(http.Request r) async {
    if (!_authorized(r)) return http.Response('unauthorized', 401);
    final path = r.url.path;
    final q = r.url.queryParameters;
    if (r.method == 'GET' && path == '/drive/v3/files') {
      final query = q['q'] ?? '';
      if (query.contains("mimeType = 'application/vnd.google-apps.folder'")) {
        final name = RegExp("name = '([^']*)'").firstMatch(query)!.group(1);
        return _json({
          'files': [
            for (final e in folders.entries)
              if (e.value == name) {'id': e.key},
          ],
        });
      }
      final parent = RegExp(r"'([^']*)' in parents").firstMatch(query)!.group(1);
      final ids = files.keys.where((id) => files[id]!.parent == parent).toList()
        ..sort((a, b) => files[b]!.created.compareTo(files[a]!.created));
      return _json({
        'files': [for (final id in ids) _fileJson(id)],
      });
    }
    if (r.method == 'POST' && path == '/drive/v3/files') {
      final body = jsonDecode(r.body) as Map<String, Object?>;
      final id = 'folder-${_next++}';
      folders[id] = body['name']! as String;
      return _json({'id': id});
    }
    if (r.method == 'POST' && path == '/upload/drive/v3/files') {
      final body = jsonDecode(r.body) as Map<String, Object?>;
      final session = 'session-${_next++}';
      final props = (body['appProperties'] as Map<String, Object?>?) ?? const {};
      _sessions[session] = (
        name: body['name']! as String,
        parent: (body['parents']! as List<Object?>).first! as String,
        props: {for (final e in props.entries) e.key: '${e.value}'},
      );
      return http.Response('', 200, headers: {'location': 'https://upload.example/$session'});
    }
    if (r.method == 'PUT' && r.url.host == 'upload.example') {
      final s = _sessions.remove(r.url.pathSegments.last)!;
      final id = 'file-${_next++}';
      files[id] = FakeDriveFile(s.name, s.parent, r.bodyBytes, clock, s.props);
      return _json(_fileJson(id));
    }
    if (r.method == 'GET' && path.startsWith('/drive/v3/files/') && q['alt'] == 'media') {
      final f = files[path.split('/').last];
      return f == null ? http.Response('not found', 404) : http.Response.bytes(f.bytes, 200);
    }
    if (r.method == 'DELETE' && path.startsWith('/drive/v3/files/')) {
      files.remove(path.split('/').last);
      return http.Response('', 204);
    }
    return http.Response('unexpected ${r.method} ${r.url}', 500);
  }
}

class FakeDriveFile {
  FakeDriveFile(this.name, this.parent, this.bytes, this.created, this.props);

  final String name;
  final String parent;
  final List<int> bytes;
  final DateTime created;
  final Map<String, String> props;
}
