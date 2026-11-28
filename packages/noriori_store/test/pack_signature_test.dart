import 'dart:convert';
import 'dart:io';

import 'package:noriori_store/noriori_store.dart';
import 'package:test/test.dart';

// 시험용 키 한 쌍으로 만든 고정 값(tools/sign_manifest.py와 같은 방식: 매니페스트 바이트에 ed25519, 서명은 base64 한 줄).
// 개인 키는 저장소에 두지 않는다. 실제 공개 키는 manifestPublicKeys에 있다
const _testKey = 'l6VX+imswn+nIzhtlAdyX8OUZOd83rwMV5PFHEoH5xY=';
const _manifest = '{"edition":"test","schema_version":3,"files":{}}\n';
const _signature = 'B8IMkrWRWrS6IKPt8Is2oAp/EzaxJCXdO2U1/ivwejZ85b9WlYyGig3Qod+FXwEYMg+dNpfzY8/aojdxKYLeAg==';

void main() {
  group('매니페스트 서명', () {
    test('맞는 서명은 공개 키 가운데 하나로 통과한다', () async {
      expect(await manifestSignatureValid(utf8.encode(_manifest), _signature, keys: const ['AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=', _testKey]), isTrue);
    });

    test('매니페스트가 한 글자라도 바뀌면 거부한다', () async {
      expect(await manifestSignatureValid(utf8.encode(_manifest.replaceFirst('test', 'tesT')), _signature, keys: const [_testKey]), isFalse);
    });

    test('다른 키, 깨진 서명, 길이가 틀린 서명은 거부한다', () async {
      expect(await manifestSignatureValid(utf8.encode(_manifest), _signature, keys: const ['AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=']), isFalse);
      expect(await manifestSignatureValid(utf8.encode(_manifest), 'not base64!', keys: const [_testKey]), isFalse);
      expect(await manifestSignatureValid(utf8.encode(_manifest), base64.encode(List.filled(32, 1)), keys: const [_testKey]), isFalse);
    });
  });

  test('앱의 공개 키는 저장소 data/keys의 공개 키와 같다', () {
    // PEM 본문은 ed25519 SubjectPublicKeyInfo(DER 44바이트)이고 끝 32바이트가 원시 공개 키다
    final files = Directory('../../data/keys').listSync().whereType<File>().where((f) => f.path.endsWith('.pub.pem')).toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    final raw = [
      for (final f in files)
        base64.encode(base64.decode(f.readAsLinesSync().where((l) => !l.startsWith('-----')).join()).sublist(12)),
    ];
    expect(raw, manifestPublicKeys);
    expect(manifestPublicKeys, hasLength(2));
  });
}
