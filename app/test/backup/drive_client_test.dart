import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:spill_the_bills/backup/drive_client.dart';

import '../support/fake_drive.dart';

void main() {
  late Directory temp;
  late FakeDrive drive;
  late DriveClient client;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('stb_drive_');
    drive = FakeDrive();
    client = DriveClient(drive.client, drive.token);
  });
  tearDown(() => temp.deleteSync(recursive: true));

  test('makes the backup folder once, then finds it', () async {
    final first = await client.ensureFolder();
    final again = await client.ensureFolder();
    expect(again, first);
    expect(drive.folders, {first: DriveClient.folderName});
  });

  test('uploads, lists newest first, downloads and deletes', () async {
    final folder = await client.ensureFolder();
    final a = File(p.join(temp.path, 'a.zip'))..writeAsBytesSync(List<int>.generate(3000, (i) => i % 256));
    final b = File(p.join(temp.path, 'b.zip'))..writeAsBytesSync([7, 7, 7]);
    final up1 = await client.upload(a, folderId: folder, name: 'first.zip', properties: {'expenses': '12'});
    drive.clock = drive.clock.add(const Duration(minutes: 1));
    final up2 = await client.upload(b, folderId: folder, name: 'second.zip');
    expect(up1.properties, {'expenses': '12'});
    expect(up1.size, 3000);

    final listed = await client.list(folder);
    expect(listed.map((f) => f.name), ['second.zip', 'first.zip']);
    expect(listed.last.properties['expenses'], '12');

    final out = File(p.join(temp.path, 'out.zip'));
    await client.download(up1.id, out);
    expect(out.readAsBytesSync(), a.readAsBytesSync());

    await client.delete(up2.id);
    expect((await client.list(folder)).map((f) => f.name), ['first.zip']);
  });

  test('an expired token is refreshed once and the call goes through', () async {
    drive.expireNextToken = true;
    final folder = await client.ensureFolder();
    expect(folder, isNotEmpty);
    expect(drive.refreshes, 1);
  });

  test('a token turned down twice is an unauthorized error', () async {
    drive.rejectAll = true;
    await expectLater(
      client.ensureFolder(),
      throwsA(isA<DriveException>().having((e) => e.unauthorized, 'unauthorized', isTrue)),
    );
  });

  test('no internet is an offline error', () async {
    final offline = DriveClient(
      MockClient((_) async => throw const SocketException('Failed host lookup')),
      ({bool refresh = false}) async => 't',
    );
    await expectLater(
      offline.ensureFolder(),
      throwsA(isA<DriveException>().having((e) => e.offline, 'offline', isTrue)),
    );
  });

  test('other errors carry the status', () async {
    final broken = DriveClient(
      MockClient((_) async => http.Response(jsonEncode({'error': 'quota'}), 403)),
      ({bool refresh = false}) async => 't',
    );
    await expectLater(
      broken.list('x'),
      throwsA(isA<DriveException>().having((e) => e.statusCode, 'status', 403)),
    );
  });
}
