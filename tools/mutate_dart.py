# -*- coding: utf-8 -*-
# 규칙을 하나씩 깨뜨려 Dart 시험이 실패하는지 본다. tools/model_check.py --mutate의 실제 코드판이다
# 안 실패하면 그 규칙을 지키는 시험이 없는 것이다. 파일은 끝나면 원래대로 돌린다
import os,subprocess,sys
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CORE='packages/noriori_core/lib/src/'
STORE='packages/noriori_store/lib/src/'
M=[
 ('updated_at 단조 증가',CORE+'records/change.dart',"  if (previous == null || now > previous) return now;\n  return previous + 1;","  return now;"),
 ('되돌린 새 행은 삭제 표시',CORE+'records/change.dart',"byId[row.id] ?? row.withDeletedAt(now)","byId[row.id] ?? row"),
 ('같은 시각이면 로컬',CORE+'records/merge.dart',"incoming > local","incoming >= local"),
 ('읽지 못한 파일은 지우지 않음',CORE+'backup/rotation.dart',"if (file.readable && file.mergeChangesNothing) {","if (!file.readable || file.mergeChangesNothing) {"),
 ('병합이 무변경일 때만 지움',CORE+'backup/rotation.dart',"if (file.readable && file.mergeChangesNothing) {","if (file.readable) {"),
 ('읽을 수 있는 파일만 셈',CORE+'backup/rotation.dart',"var readable = files.where((f) => f.readable).length;","var readable = files.length;"),
 ('격리 파일이 있으면 멈춤',CORE+'startup/user_db_decision.dart',"  if (quarantinePresent) return UserDbAction.holdRestoreOnly;\n",""),
 ('다른 오류는 손상이 아님',CORE+'startup/user_db_decision.dart',"UserDbUnavailable() => UserDbAction.retryLater,","UserDbUnavailable() => UserDbAction.quarantine,"),
 ('지원 스키마만 고름',CORE+'pack/pack_choice.dart',"    if (pack.schemaVersion != supportedSchema) continue;\n",""),
 ('한 기록의 실패 격리',CORE+'records/derived.dart',"  } on Object {\n    return const RideDerived.error();\n  }","  } on Never {\n    return const RideDerived.error();\n  }"),
 ('검사는 읽기 전용',STORE+'startup/user_db_file.dart',"s3.OpenMode.readOnly","s3.OpenMode.readWrite"),
 ('-wal까지 격리',STORE+'startup/user_db_file.dart',"sidecars = ['-wal', '-shm', '']","sidecars = ['']"),
 ('사본 임시 파일 먼저 삭제',STORE+'startup/user_db_file.dart',"    if (temp.existsSync()) temp.deleteSync();\n",""),
 ('사본을 남김',STORE+'startup/cold_start.dart',"      file.copyBeforeMigration(fromVersion);\n",""),
 ('버전을 같은 트랜잭션에',STORE+'db/user_db.dart',"          await _dropCaches(m);\n          await _writeVersion(to);\n","          await _dropCaches(m);\n"),
 ('마이그레이션 때 캐시를 비움',STORE+'db/user_db.dart',"          await _dropCaches(m);\n",""),
 ('병합은 시각을 지킴',STORE+'records/record_store.dart',"            await _write(row);\n            taken++;","            await _write(row.stamped(now()));\n            taken++;"),
 ('삭제한 기록의 캐시 제거',STORE+'records/record_store.dart',"    if (ride.isDeleted) return _caches.clearRide(ride.id);\n",""),
 ('옛 구간 제거',STORE+'records/record_store.dart',"    await (_db.delete(_db.rideLegTable)..where((t) => t.rideId.equals(ride.id))).go();\n",""),
 ('백업을 다시 읽어 확인',STORE+'backup/auto_backup.dart',"      if (await folder.read(name) == text) return true;\n      await folder.delete(name);\n      return false;\n","      return true;\n"),
 ('쓰지 못하면 지우지 않음',STORE+'backup/auto_backup.dart',"    if (!written) {\n","    if (false) {\n"),
 ('새 스키마 파일은 읽지 못함',STORE+'backup/auto_backup.dart',"      if (restorePath(header: header, appVersion: appUserVersion) == RestorePath.refuse) {\n        return null;\n      }\n",""),
 ('깨진 판은 버림',STORE+'pack/pack_folder.dart',"      if (_isIntact(pack)) return pack;\n      pack.directory.deleteSync(recursive: true);\n","      return pack;\n"),
 ('자산 해시 확인',STORE+'pack/pack_folder.dart',"      if (sha256.convert(bytes).toString() != expected.sha256) {","      if (false) {"),
 ('분모는 normal 단위만',CORE+'score/scorer.dart',"  if (!unit.normal) return false;\n",""),
 ('연도 기준은 그해 말까지 끝난 기록',CORE+'score/scorer.dart',"effectiveHi != null && effectiveHi.compareTo('$year-12-31') <= 0","true"),
 ('완주율 표시는 내림',CORE+'score/scorer.dart',"numMeters * 1000 ~/ denMeters","(numMeters * 1000 / denMeters).round()"),
 ('하루로 정한 날짜가 as_of를 이김',CORE+'network/route_resolver.dart',"date != null && date.isDay ? date : (asOf ?? date)","asOf ?? date"),
 ('그날 경로가 없으면 날짜 모름',CORE+'network/route_resolver.dart',"      demoted = true;\n",""),
 ('그날 노선으로 맞춤',CORE+'network/route_resolver.dart',"(byLine[_lineOn(edge, line, date)] ??= []).add(edge);","(byLine[line] ??= []).add(edge);"),
 ('영업 중단은 탈 수 없음',CORE+'network/network.dart',"LifeState.suspended => Usable.suspended,","LifeState.suspended => Usable.ok,"),
 ('이관 전 역은 앞 노선으로',CORE+'network/selector.dart',"if (savedAs != null) (state, selectable) = (StopState.open, true);",""),
 ('유효 범위는 승하차역까지',CORE+'network/ride_interpreter.dart',"if (stop.isStop && got.contains(stop.node)) cap(stop.period.toHi);",""),
 ('검색 가나 정규화',CORE+'name/name_lookup.dart',"if (code >= 0x30A1 && code <= 0x30F6) code -= 0x60;\n",""),
 ('바뀐 것이 없으면 쓰지 않음',STORE+'backup/auto_backup.dart',"      if (file.contents.sameAs(contents)) heldAt = file.header.exportedAt;\n",""),
 ('빈 DB는 쓰지 않음',STORE+'backup/auto_backup.dart',"if (heldAt != null || contents.rowCount == 0) {","if (heldAt != null) {"),
 ('앱보다 새 파일은 복원 거부',STORE+'backup/backup_restore.dart',"    if (inspected.state != CandidateState.ready) return RestoreRefused(inspected.state);\n",""),
 ('닫아도 격리 파일을 지우지 않음',STORE+'startup/user_db_file.dart',"entry.renameSync(p.join(_closed.path, p.basename(entry.path)));","entry.deleteSync(recursive: true);"),
 ('격리 이름이 겹쳐도 덮어쓰지 않음',STORE+'startup/user_db_file.dart',"for (var i = 1; dir.existsSync(); i++) {","for (var i = 1; false; i++) {"),
 ('복원 세션만 격리를 넘어감',STORE+'startup/cold_start.dart',"quarantinePresent: !restoring && file.hasQuarantine","quarantinePresent: file.hasQuarantine"),
 ('사본은 하나만',STORE+'startup/cold_start.dart',"      file.pruneCopies(keep: fromVersion);\n",""),
 ('공간 부족을 구분',STORE+'startup/cold_start.dart',"static const _noSpaceCodes = {28, 69, 122};","static const _noSpaceCodes = {29, 69, 122};"),
 ('폐선은 마지막 소유자에게',CORE+'score/browse_tree.dart',"if (held == null || _end(attr).compareTo(_end(held)) > 0) last[unit] = attr;","last[unit] = attr;"),
 ('현행 구간은 폐선이 아님',CORE+'score/browse_tree.dart',"    if (unitCounts(unit, const BasisCurrent(), today: today)) continue;\n",""),
 ('현행은 오늘의 소속으로',CORE+'score/browse_tree.dart',"    if (stateOfPeriod(day, attr.period) != PeriodState.yes) continue;\n",""),
 ('탄 구간이 있으면 0%가 아님',CORE+'score/score_format.dart',"  if (hundredths > 0) return '0.0$hundredths%';\n  return '<0.01%';","  return '0%';"),
 ('표시는 내림',CORE+'score/score_format.dart',"final tenths = numerator * 1000 ~/ denominator;","final tenths = (numerator * 1000 / denominator).round();"),
 ('100%는 다 탔을 때만',CORE+'score/score_format.dart',"  if (numerator >= denominator) return '100%';\n",""),
 ('이어진 구간은 합침',CORE+'score/line_strip.dart',"if (segments.isNotEmpty && segments.last.to == at) {","if (segments.isEmpty) {"),
 ('띠는 그 줄의 구간만',CORE+'score/line_strip.dart',"if (!line.edgeIds.contains(edge) || !seen.add(edge)) continue;","if (!seen.add(edge)) continue;"),
 ('숨은 역 사이도 다 타야',CORE+'network/selector.dart',"inside.isNotEmpty && inside.every((value) => value)","inside.any((value) => value)"),
 ('이미 탄 구간은 새 구간이 아님',CORE+'score/ride_preview.dart',"if (unit != null && unit.normal && !hits.containsKey(unit.n)) fresh[unit.n] = unit;","if (unit != null) fresh[unit.n] = unit;"),
 ('현 경계는 나눠 셈',CORE+'score/pref_scores.dart',"den[pref] = (den[pref] ?? 0) + meters;","den[pref] = (den[pref] ?? 0) + unit.meters;"),
 ('곧 완주에 다 탄 노선 없음',CORE+'score/browse_tree.dart',"if (line.score.started && !line.score.complete) line,","if (line.score.started) line,"),
 ('순환 방향은 파일 거리로',CORE+'importing/csv_import.dart',"if (network.routes[routeId]!.closed && row.meters != null) {","if (network.routes[routeId]!.closed && row.meters == null) {"),
 ('가져온 끝은 통과',CORE+'importing/csv_import.dart',"    fromAlighted: false,\n    toAlighted: false,\n    importSource","    importSource"),
 ('지운 기록은 저절로 안 살아남',CORE+'importing/csv_import.dart',"true => ImportState.deleted,","true => ImportState.fresh,"),
 ('같은 행은 따로 센다',CORE+'importing/csv_import.dart',"final occurrence = seen[key] = (seen[key] ?? 0) + 1;","final occurrence = seen[key] = 1;"),
 ('거리 차이는 0.1km 단위',CORE+'importing/csv_import.dart',"return (matched.meters + 50) ~/ 100 != (file + 50) ~/ 100;","return false;"),
 ('날짜 모름 표시를 읽음',CORE+'importing/noritsubushi_csv.dart',"fields[5].trim() == _noDate ? null : parseDateInput(fields[5])","parseDateInput(fields[5])"),
 ('깨진 행을 버리지 않음',CORE+'importing/noritsubushi_csv.dart',"      broken.add(record.raw);\n",""),
 ('CP932 뒤 바이트 표',CORE+'importing/cp932.dart',"if (byte >= 0x80 && byte <= 0xFC) return byte - 0x80 + 63;","if (byte >= 0x80 && byte <= 0xFC) return byte - 0x80 + 64;"),
 ('내용 ID는 판 5',STORE+'records/content_id.dart',"bytes[6] = 0x50 | (bytes[6] & 0x0f);","bytes[6] = 0x40 | (bytes[6] & 0x0f);"),
 ('맡은 회사를 모두 표시',CORE+'network/network.dart',"if (running.isNotEmpty) return running.toList();","if (running.isNotEmpty) return [running.first];"),
 ('끝난 노선은 마지막 회사',CORE+'network/network.dart',"      last = attr.operatorId;\n","      last ??= attr.operatorId;\n"),
 ('두 회사 노선은 하나로 셈',CORE+'score/browse_tree.dart',"int get lineCount => _byLine.length;","int get lineCount => lines.length;"),
 ('캐시 키 비교',STORE+'records/cache_rebuild.dart',"    if (state != null && state.edition == edition && state.appBuild == appBuild) {\n      return false;\n    }\n","    if (state != null) return false;\n"),
 ('-wal을 본체보다 먼저 옮김',STORE+'startup/user_db_file.dart',"sidecars = ['-wal', '-shm', '']","sidecars = ['', '-wal', '-shm']"),
 ('데이터 페이지 손상을 찾음',STORE+'startup/user_db_file.dart',"      if (verdict != 'ok') return const UserDbCorrupt();\n",""),
 ('세션 중 손상은 격리',STORE+'startup/cold_start.dart',"      if (_isCorrupt(e)) {","      if (false) {"),
 ('드리프트가 싼 오류를 푼다',STORE+'startup/cold_start.dart',"error is DriftRemoteException ? error.remoteCause : error","error"),
 ('앞선 형식은 거부',CORE+'backup/backup_envelope.dart',"  if (header.format > BackupHeader.currentFormat) return RestorePath.refuse;\n",""),
 ('앞선 형식은 해석 안 함',CORE+'backup/backup_codec.dart',"    if (header.format > BackupHeader.currentFormat) {","    if (false) {"),
 ('다른 앱 파일은 없는 파일',STORE+'backup/auto_backup.dart',"      if (!isOurBackup(other, text)) continue;\n",""),
 ('복원 목록에도 다른 앱 파일 없음',STORE+'backup/backup_restore.dart',"if (isOurBackup(name, text)) found.add(_inspect(name, text));","found.add(_inspect(name, text));"),
 ('분모 밖은 저장 전 값에 없음',CORE+'score/ride_preview.dart',"unit != null && unit.normal && !hits","unit != null && !hits"),
 ('범위 날짜는 입력 노선 유지',CORE+'network/route_resolver.dart',"return mine ? line : attr.lineId;","return attr.lineId;"),
 ('범위 날짜는 연결과 겹침으로 판단',CORE+'network/selector.dart',"(from == null || from.compareTo(day.hi) <= 0)","(from == null || from.compareTo(day.lo) <= 0)"),
 ('유효 범위가 비면 날짜 모름',CORE+'network/ride_interpreter.dart',"if (dated != null && hi.compareTo(dated.lo) < 0) {","if (false) {"),
 ('leg 경계는 통과',CORE+'network/ride_interpreter.dart',"final alighted = (first && ride.fromAlighted) ||","final alighted = at == path.length - 1 || (first && ride.fromAlighted) ||"),
 ('한 바퀴는 고른 역에서',CORE+'network/route_resolver.dart',"final at = nodes.indexOf(start);","final at = 0;"),
 ('한 바퀴는 방향을 따름',CORE+'network/route_resolver.dart',"if (direction != seqDown) return turned;","return turned;"),
 ('이번 달에서 날짜 모름 제외',CORE+'score/pref_scores.dart',"if (!hits.containsKey(unit.n) || undated.contains(unit.n)) continue;","if (!hits.containsKey(unit.n)) continue;"),
 ('없는 달은 형식 오류',CORE+'date/date_span.dart',"      if (int.parse(mm) case < 1 || > 12) throw FormatException('달이 아니다', raw);\n",""),
 ('환승 번호는 둘 이상일 때',CORE+'network/display_rules.dart',"number: kinds.length > 1 ? index + 1 : null,","number: index + 1,"),
 ('같은 회사 먼저',CORE+'network/display_rules.dart',"return (same.isEmpty ? 2 : 0) + (item.gone ? 1 : 0);","return item.gone ? 1 : 0;"),
 ('이어받은 노선은 이름만',CORE+'network/display_rules.dart',"      taken.addAll(earlier);\n",""),
 ('열람 전용은 체크박스를 따름',CORE+'network/display_rules.dart',"final archive = options.showClosed && options.showArchive;","const archive = true;"),
 ('폐역을 끄면 숨김',CORE+'network/display_rules.dart',"if (options.showClosed) return rows;","return rows;"),
 ('현행 분기 폐역은 남김',CORE+'network/display_rules.dart',"if (!_isGoneStop(row) || row.links.any((link) => link.kind == 'branch')) row,","if (!_isGoneStop(row)) row,"),
 ('역 사이 분기는 어깨가 없음',CORE+'network/display_rules.dart',"final downs = inner.where((item) => item.link.side != 'up' && !item.link.midway).toList();","final downs = inner.where((item) => item.link.side != 'up').toList();"),
]
def tests():
    for pkg in ('packages/noriori_core','packages/noriori_store'):
        r=subprocess.run(['dart','test','-r','silent','-x','crash'],cwd=os.path.join(ROOT,pkg),capture_output=True,text=True)
        if r.returncode!=0:return False
    return True
only=sys.argv[1:] 
lost=[]
for name,path,old,new in M:
    if only and not any(o in name for o in only):continue
    full=os.path.join(ROOT,path);src=open(full,encoding='utf-8').read()
    if src.count(old)<1:print('  찾지 못함',name);lost.append(name);continue
    open(full,'w',encoding='utf-8').write(src.replace(old,new,1))
    try:
        ok=tests()
    finally:
        open(full,'w',encoding='utf-8').write(src)
    print('  못 잡음' if ok else '  잡음',name,flush=True)
    if ok:lost.append(name)
print('규칙',len(M),'못 잡음',len(lost),lost)
sys.exit(1 if lost else 0)
