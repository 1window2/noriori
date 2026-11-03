import 'package:noriori_core/noriori_core.dart';
import 'package:test/test.dart';

const assets = PackCandidate(edition: '2026-11-02', schemaVersion: 1, fromAssets: true);

PackCandidate folder(String edition, {int schema = 1}) =>
    PackCandidate(edition: edition, schemaVersion: schema, fromAssets: false);

BackupFileView file(String name, {bool readable = true, bool noop = true}) =>
    BackupFileView(name: name, readable: readable, mergeChangesNothing: noop);

void main() {
  group('choosePack', () {
    PackCandidate pick(List<PackCandidate> folders) =>
        choosePack(assets: assets, folders: folders, supportedSchema: 1);

    test('폴더가 비면 앱 자산', () => expect(pick(const []).fromAssets, isTrue));
    test('가장 높은 판', () {
      expect(pick([folder('2026-12-01'), folder('2027-01-01')]).edition, '2027-01-01');
    });
    test('낮은 판은 자산에 진다', () => expect(pick([folder('2026-01-01')]).fromAssets, isTrue));
    test('같은 판이면 폴더', () => expect(pick([folder('2026-11-02')]).fromAssets, isFalse));
    test('지원 안 하는 스키마는 고르지 않는다', () {
      expect(pick([folder('2099-01-01', schema: 2)]).fromAssets, isTrue);
    });
  });

  group('decideUserDb', () {
    UserDbAction decide(UserDbProbe probe, {bool quarantine = false}) => decideUserDb(
          probe: probe,
          quarantinePresent: quarantine,
          appUserVersion: 3,
        );

    test('파일이 없으면 연다', () => expect(decide(const UserDbAbsent()), UserDbAction.open));
    test('같은 버전이면 연다', () => expect(decide(const UserDbReadable(3)), UserDbAction.open));
    test('0은 만들어지지 않은 DB', () => expect(decide(const UserDbReadable(0)), UserDbAction.open));
    test('낮으면 마이그레이션', () => expect(decide(const UserDbReadable(2)), UserDbAction.migrate));
    test('높으면 앱 갱신', () {
      expect(decide(const UserDbReadable(4)), UserDbAction.askAppUpdate);
    });
    test('손상이면 격리', () => expect(decide(const UserDbCorrupt()), UserDbAction.quarantine));
    test('다른 오류는 손상이 아니다', () {
      expect(decide(const UserDbUnavailable('권한')), UserDbAction.retryLater);
    });
    test('격리 파일이 있으면 어떤 상태든 빈 DB로 넘어가지 않는다', () {
      for (final probe in const [UserDbAbsent(), UserDbReadable(3), UserDbCorrupt()]) {
        expect(decide(probe, quarantine: true), UserDbAction.holdRestoreOnly);
      }
    });
  });

  group('rotationVictims', () {
    test('세 개 이하면 지우지 않는다', () {
      expect(rotationVictims([file('a'), file('b'), file('c')]), isEmpty);
    });

    test('넘치면 오래된 무변경 파일부터', () {
      expect(rotationVictims([file('a'), file('b'), file('c'), file('d')]), ['a']);
    });

    test('방금 쓴 파일은 지우지 않는다', () {
      final files = [file('a', noop: false), file('b', noop: false), file('c', noop: false), file('d')];
      expect(rotationVictims(files), isEmpty);
    });

    test('재설치 뒤 옛 기록이 든 파일은 남는다', () {
      final files = [
        file('old1', noop: false),
        file('old2', noop: false),
        file('old3', noop: false),
        file('new1'),
        file('new2'),
      ];
      expect(rotationVictims(files), ['new1']);
    });

    test('읽지 못한 파일은 지우지 않고 세지도 않는다', () {
      final files = [
        file('cloud1', readable: false, noop: false),
        file('cloud2', readable: false, noop: false),
        file('cloud3', readable: false, noop: false),
        file('a'),
        file('b'),
        file('c'),
      ];
      expect(rotationVictims(files), isEmpty);
    });

    test('읽을 수 있는 파일 3개를 유지한다', () {
      final files = [
        file('cloud', readable: false, noop: false),
        file('a'),
        file('b'),
        file('c'),
        file('d'),
      ];
      expect(rotationVictims(files), ['a']);
    });

    test('빈 폴더', () => expect(rotationVictims(const []), isEmpty));
  });

  group('백업 머리말', () {
    test('왕복', () {
      const header = BackupHeader(
        userVersion: 1,
        edition: '2026-11-02',
        appBuild: 7,
        exportedAt: 123,
      );
      final back = BackupHeader.fromJson(header.toJson());
      expect(back.userVersion, 1);
      expect(back.edition, '2026-11-02');
      expect(back.appBuild, 7);
      expect(back.exportedAt, 123);
    });

    test('다른 파일은 거부', () {
      expect(() => BackupHeader.fromJson(const {'kind': 'x'}), throwsFormatException);
    });

    test('필드가 빠지면 거부', () {
      expect(
        () => BackupHeader.fromJson(const {'kind': BackupHeader.formatName, 'format': 1}),
        throwsFormatException,
      );
    });

    test('복원 경로', () {
      BackupHeader file(int version, {int format = BackupHeader.currentFormat}) => BackupHeader(
            userVersion: version,
            edition: 'e',
            appBuild: 1,
            exportedAt: 1,
            format: format,
          );
      expect(restorePath(header: file(3), appVersion: 2), RestorePath.refuse);
      expect(restorePath(header: file(1), appVersion: 2), RestorePath.upgradeFirst);
      expect(restorePath(header: file(2), appVersion: 2), RestorePath.direct);
      expect(
        restorePath(header: file(2, format: BackupHeader.currentFormat + 1), appVersion: 2),
        RestorePath.refuse,
      );
    });
  });

  test('고침 판은 수로 비교한다', () {
    expect(compareEditions('2026-11-03.10', '2026-11-03.9'), greaterThan(0));
    expect(compareEditions('2026-11-03.1', '2026-11-03'), greaterThan(0));
    expect(compareEditions('2026-11-04', '2026-11-03.10'), greaterThan(0));
    expect(compareEditions('2026-11-03', '2026-11-03'), 0);
  });
}
