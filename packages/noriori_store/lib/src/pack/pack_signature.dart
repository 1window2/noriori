import 'dart:convert';

import 'package:cryptography/cryptography.dart';

/// 매니페스트 서명 공개 키(ed25519 원시 32바이트, base64). 하나를 잃어도 다른 하나로 서명할 수 있게 둘을 넣는다.
/// 값은 `data/keys/manifest-ed25519-*.pub.pem`과 같아야 한다(`python3 -I tools/sign_manifest.py keys`로 대조).
/// 개인 키는 저장소와 CI에 두지 않는다 (DESIGN §2.11, ARCHITECTURE §4.5).
const manifestPublicKeys = <String>[
  'bdYtHBcZUMb/9PMy3jmo5EobpCoUX69ooOQiQu2iaSE=', // manifest-ed25519-1
  'cXyAqhBDvxZlRc9672CTK7DKkiKnnuP8w8WqmMEVfco=', // manifest-ed25519-2
];

/// [manifest] 바이트에 대한 서명 [signatureText](64바이트 base64 한 줄)가 [keys] 가운데 하나로 맞는가.
Future<bool> manifestSignatureValid(
  List<int> manifest,
  String signatureText, {
  List<String> keys = manifestPublicKeys,
}) async {
  final List<int> bytes;
  try {
    bytes = base64.decode(signatureText.trim());
  } on FormatException {
    return false;
  }
  if (bytes.length != 64) return false;
  final algorithm = Ed25519();
  for (final key in keys) {
    final publicKey = SimplePublicKey(base64.decode(key), type: KeyPairType.ed25519);
    if (await algorithm.verify(manifest, signature: Signature(bytes, publicKey: publicKey))) return true;
  }
  return false;
}
