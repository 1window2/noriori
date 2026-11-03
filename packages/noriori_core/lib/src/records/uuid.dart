/// UUIDv7. 시각과 난수를 받아 만들므로 시험에서 값을 고정할 수 있다.
///
/// [randomBytes]는 10바이트다. 기기끼리 충돌하지 않으므로 서버를 붙여도 ID가 그대로다.
String uuidV7({required int millis, required List<int> randomBytes}) {
  if (randomBytes.length != 10) {
    throw ArgumentError.value(randomBytes.length, 'randomBytes', '10바이트여야 한다');
  }
  final bytes = <int>[
    for (var shift = 40; shift >= 0; shift -= 8) (millis >> shift) & 0xff,
    0x70 | (randomBytes[0] & 0x0f),
    randomBytes[1] & 0xff,
    0x80 | (randomBytes[2] & 0x3f),
    for (final b in randomBytes.skip(3)) b & 0xff,
  ];
  return formatUuid(bytes);
}

/// 16바이트를 UUID 글자로.
String formatUuid(List<int> bytes) {
  final hex = [for (final b in bytes) b.toRadixString(16).padLeft(2, '0')].join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}'
      '-${hex.substring(16, 20)}-${hex.substring(20)}';
}
