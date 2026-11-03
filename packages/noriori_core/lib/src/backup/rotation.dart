/// 회전 판단에 필요한 백업 파일의 상태. 앱이 아는 것은 지금 읽혔는지뿐이다.
final class BackupFileView {
  const BackupFileView({
    required this.name,
    required this.readable,
    required this.mergeChangesNothing,
  });

  final String name;

  /// 읽고 해석까지 됐는가. 구름 자리표시자, 더 새로운 스키마, 깨진 파일은 거짓이다.
  final bool readable;

  /// 병합해도 아무것도 안 바뀌는가. 읽지 못했으면 거짓이다.
  final bool mergeChangesNothing;
}

/// 읽을 수 있는 파일 수.
const keptBackups = 3;

/// 지워도 되는 파일. 오래된 것부터 온 [files]의 마지막은 방금 쓴 파일이다.
///
/// 읽지 못한 파일은 판단할 수 없으므로 지우지 않고 세지도 않는다. 재설치나 OS 복원 뒤에는
/// 옛 파일이 더 새로운 값을 들고 있으므로 지워지지 않는다 (ARCHITECTURE §3.7).
List<String> rotationVictims(List<BackupFileView> files) {
  if (files.isEmpty) return const [];
  final older = files.sublist(0, files.length - 1);
  var readable = files.where((f) => f.readable).length;
  final victims = <String>[];
  for (final file in older) {
    if (readable <= keptBackups) break;
    if (file.readable && file.mergeChangesNothing) {
      victims.add(file.name);
      readable--;
    }
  }
  return victims;
}
