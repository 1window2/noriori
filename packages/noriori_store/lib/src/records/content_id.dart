import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:noriori_core/noriori_core.dart';

/// 내용에서 만드는 ID의 이름공간. 이 값이 바뀌면 같은 내용이 다른 ID가 된다.
const _namespace = [
  0x2b, 0x8e, 0x63, 0xf9, 0x04, 0x9e, 0x58, 0xb8, //
  0x8f, 0x7b, 0x82, 0x4e, 0xd2, 0xf2, 0x9c, 0x76,
];

/// UUIDv5. 같은 내용을 다시 가져와도 같은 ID가 되어야 할 때 쓴다.
String uuidV5(String name, {List<int> namespace = _namespace}) {
  final bytes = sha1.convert([...namespace, ...utf8.encode(name)]).bytes.sublist(0, 16);
  bytes[6] = 0x50 | (bytes[6] & 0x0f);
  bytes[8] = 0x80 | (bytes[8] & 0x3f);
  return formatUuid(bytes);
}
