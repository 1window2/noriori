import 'package:noriori_core/noriori_core.dart';
import 'package:test/test.dart';

Ride ride(String id, {int updatedAt = 10, String? note, int? deletedAt}) => Ride(
      rideId: RideId(id),
      legs: const [],
      datasetVersion: '2026-11-02',
      createdAt: 1,
      updatedAt: updatedAt,
      deviceId: 'd',
      note: note,
      deletedAt: deletedAt,
    );

final class _Broken implements RecordInterpreter {
  @override
  RideDerived ride(Ride ride) => throw StateError('깨짐');

  @override
  VisitDerived visit(Visit visit) => const VisitDerived();
}

void main() {
  group('nextStamp', () {
    test('새 행은 현재 시각', () => expect(nextStamp(now: 5, previous: null), 5));
    test('시계가 정상이면 현재 시각', () => expect(nextStamp(now: 9, previous: 5), 9));
    test('시계가 되돌아가도 앞으로 간다', () => expect(nextStamp(now: 3, previous: 5), 6));
    test('같은 시각이어도 앞으로 간다', () => expect(nextStamp(now: 5, previous: 5), 6));
  });

  group('Change.undo', () {
    test('고친 행은 원래 값으로 돌아간다', () {
      final change = Change(before: [ride('r', note: '전')], after: [ride('r', note: '후')]);
      final undo = change.undo(now: 99);
      expect((undo.after.single as Ride).note, '전');
      expect((undo.before.single as Ride).note, '후');
    });

    test('새 행은 지우지 않고 삭제 표시로 둔다', () {
      final change = Change(before: const [], after: [ride('r')]);
      final row = change.undo(now: 99).after.single;
      expect(row.id, 'r');
      expect(row.deletedAt, 99);
    });

    test('삭제를 되돌리면 삭제 표시가 사라진다', () {
      final change = Change(before: [ride('r')], after: [ride('r', deletedAt: 50)]);
      expect(change.undo(now: 99).after.single.isDeleted, isFalse);
    });
  });

  group('병합', () {
    test('늦은 쪽, 같으면 로컬, 없으면 추가', () {
      expect(incomingWins(local: 5, incoming: 6), isTrue);
      expect(incomingWins(local: 5, incoming: 5), isFalse);
      expect(incomingWins(local: 5, incoming: 4), isFalse);
      expect(incomingWins(local: null, incoming: 1), isTrue);
    });

    test('파일의 모든 행이 로컬보다 늦지 않으면 무변경', () {
      expect(
        mergeChangesNothing(fileStamps: {'a': 1, 'b': 2}, localStamps: {'a': 1, 'b': 3, 'c': 9}),
        isTrue,
      );
    });

    test('로컬에 없는 행이 있으면 변경', () {
      expect(
        mergeChangesNothing(fileStamps: {'a': 1}, localStamps: const {}),
        isFalse,
      );
    });

    test('파일이 더 새로우면 변경', () {
      expect(
        mergeChangesNothing(fileStamps: {'a': 7}, localStamps: {'a': 5}),
        isFalse,
      );
    });
  });

  group('uuidV7', () {
    test('버전과 변형 비트, 시각 접두', () {
      final id = uuidV7(millis: 0x0123456789ab, randomBytes: List.filled(10, 0xff));
      expect(id, '01234567-89ab-7fff-bfff-ffffffffffff');
    });

    test('시각 순으로 정렬된다', () {
      final a = uuidV7(millis: 1000, randomBytes: List.filled(10, 0xff));
      final b = uuidV7(millis: 1001, randomBytes: List.filled(10, 0));
      expect(a.compareTo(b), isNegative);
    });

    test('난수 길이를 검사한다', () {
      expect(() => uuidV7(millis: 1, randomBytes: const [1]), throwsArgumentError);
    });
  });

  group('interpretRideIsolated', () {
    test('한 기록의 예외는 그 기록만 error로 만든다', () {
      final derived = interpretRideIsolated(_Broken(), ride('r'));
      expect(derived.status, ResolveStatus.error);
    });
  });

  group('기록 수정', () {
    const ride = Ride(
      rideId: RideId('r'),
      datasetVersion: 'e',
      createdAt: 1,
      updatedAt: 2,
      deviceId: 'd',
      dateInput: '2010-01-01',
      importSource: 'csv',
      legs: [
        RideLeg(
          seq: 0,
          lineId: LineId('l'),
          routeId: RouteId('r'),
          fromNode: NodeId('a'),
          toNode: NodeId('b'),
          resolveAsOf: '2000-01-01',
          resolveUnknown: true,
          lineLabel: '',
          fromLabel: '',
          toLabel: '',
        ),
      ],
    );

    Ride edit({String? date = '2010-01-01'}) => ride.edited(
          dateInput: date,
          times: '10:00',
          trainName: null,
          carNo: null,
          note: '메모',
          fromAlighted: true,
          toAlighted: false,
        );

    test('날짜를 그대로 두면 경로 답이 남는다', () {
      final leg = edit().legs.single;
      expect(leg.resolveAsOf, '2000-01-01');
      expect(leg.resolveUnknown, isTrue);
    });

    test('날짜를 바꾸면 경로 답을 지운다', () {
      final leg = edit(date: '2011-01-01').legs.single;
      expect(leg.resolveAsOf, isNull);
      expect(leg.resolveUnknown, isFalse);
    });

    test('답을 고르면 그 답이 남고 모름은 풀린다', () {
      final leg = edit().answered((_) => true, asOf: '2020-01-01').legs.single;
      expect(leg.resolveAsOf, '2020-01-01');
      expect(leg.resolveUnknown, isFalse);
    });

    test('고친 값 외에는 그대로다', () {
      final got = edit();
      expect(got.note, '메모');
      expect(got.toAlighted, isFalse);
      expect(got.importSource, 'csv');
      expect(got.createdAt, 1);
    });
  });
}
