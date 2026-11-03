import 'dart:convert';

import 'package:noriori_core/noriori_core.dart';
import 'package:test/test.dart';

const header = BackupHeader(userVersion: 1, edition: '2026-11-02', appBuild: 3, exportedAt: 9);

const fullRide = Ride(
  rideId: RideId('r'),
  datasetVersion: '2026-11-02',
  createdAt: 1,
  updatedAt: 2,
  deletedAt: 3,
  deviceId: 'd',
  tripId: TripId('t'),
  dateInput: '1985-XX-XX',
  times: '10:00',
  trainName: 'はやぶさ3号',
  carNo: '12',
  note: '메모',
  serviceId: ServiceId('s'),
  transferNodes: [NodeId('n_b')],
  fromAlighted: false,
  toAlighted: false,
  importSource: 'csv',
  importRaw: '원문',
  legs: [
    RideLeg(
      seq: 0,
      lineId: LineId('l'),
      routeId: RouteId('r'),
      fromNode: NodeId('n_a'),
      toNode: NodeId('n_a'),
      direction: 'seq_up',
      resolveAsOf: '1985-01-01',
      resolveUnknown: true,
      lineLabel: '線',
      fromLabel: 'A',
      toLabel: 'A',
    ),
  ],
);

void main() {
  test('기록의 모든 열이 왕복한다', () {
    const file = BackupFile(
      header: header,
      contents: BackupContents(
        trips: [
          Trip(tripId: TripId('t'), title: '여정', note: 'n', createdAt: 1, updatedAt: 2, deviceId: 'd'),
        ],
        rides: [fullRide],
        visits: [
          Visit(
            visitId: VisitId('v'),
            nodeId: NodeId('n_a'),
            nodeLabel: 'A',
            nodeExplicit: false,
            createdAt: 1,
            updatedAt: 2,
            deviceId: 'd',
            dateInput: '2020-01-01',
            note: 'v',
          ),
        ],
      ),
    );
    final back = BackupFile.decode(file.encode());
    expect(back.encode(), file.encode());
    expect(back.contents.rowCount, 3);
    expect(back.contents.stamps, {'t': 2, 'r': 2, 'v': 2});
    final ride = back.contents.rides.single;
    expect(ride.deletedAt, 3);
    expect(ride.legs.single.direction, 'seq_up');
    expect(ride.legs.single.resolveUnknown, isTrue);
    expect(ride.transferNodes, [const NodeId('n_b')]);
  });

  test('잘린 파일은 거부한다', () {
    final text = const BackupFile(
      header: header,
      contents: BackupContents(trips: [], rides: [fullRide], visits: []),
    ).encode();
    expect(() => BackupFile.decode(text.substring(0, text.length - 20)), throwsFormatException);
  });

  test('다른 JSON은 거부한다', () {
    expect(() => BackupFile.decode('[]'), throwsFormatException);
    expect(() => BackupFile.decode('{"kind":"other"}'), throwsFormatException);
  });

  test('행이 어긋난 파일은 거부한다', () {
    final text = '{"kind":"${BackupHeader.formatName}","format":1,"user_version":1,'
        '"edition":"e","app_build":1,"exported_at":1,'
        '"tables":{"trip":[{"id":1}],"ride":[],"visit":[]}}';
    expect(() => BackupFile.decode(text), throwsFormatException);
  });

  test('행 순서가 달라도 같은 내용이고 값이 다르면 다른 내용이다', () {
    const a = Trip(tripId: TripId('a'), title: 'x', createdAt: 1, updatedAt: 2, deviceId: 'd');
    const b = Trip(tripId: TripId('b'), title: 'y', createdAt: 1, updatedAt: 2, deviceId: 'd');
    const c = Trip(tripId: TripId('b'), title: 'z', createdAt: 1, updatedAt: 2, deviceId: 'd');
    BackupContents of(List<Trip> trips) =>
        BackupContents(trips: trips, rides: const [], visits: const []);
    expect(of(const [a, b]).sameAs(of(const [b, a])), isTrue);
    expect(of(const [a, b]).sameAs(of(const [a, c])), isFalse);
  });

  test('앱보다 새 파일은 머리말만 읽을 수 있다', () {
    const text = '{"kind":"${BackupHeader.formatName}","format":9,"user_version":9,'
        '"edition":"e","app_build":1,"exported_at":1,"tables":{"new":[]}}';
    expect(BackupFile.decodeHeader(text).userVersion, 9);
  });

  group('다른 앱의 파일', () {
    test('우리 이름은 깨졌어도 우리 파일이다', () {
      expect(isOurBackup('noriori-1.json', null), isTrue);
      expect(isOurBackup('noriori-1.json', '{잘림'), isTrue);
    });

    test('이름을 바꾼 사본은 머리말로 알아본다', () {
      final text = const BackupFile(
        header: header,
        contents: BackupContents(trips: [], rides: [], visits: []),
      ).encode();
      expect(isOurBackup('내 백업.json', text), isTrue);
    });

    test('다른 이름의 다른 파일은 우리 파일이 아니다', () {
      expect(isOurBackup('settings.json', '{"theme":"dark"}'), isFalse);
      expect(isOurBackup('report.json', '[1,2]'), isFalse);
      expect(isOurBackup('broken.json', '{'), isFalse);
      expect(isOurBackup('cloud.json', null), isFalse);
    });
  });

  test('앱보다 새 형식은 표를 해석하지 않는다', () {
    final text = const BackupFile(
      header: BackupHeader(
        userVersion: 1,
        edition: 'e',
        appBuild: 1,
        exportedAt: 1,
        format: BackupHeader.currentFormat + 1,
      ),
      contents: BackupContents(trips: [], rides: [], visits: []),
    ).encode();
    expect(() => BackupFile.decode(text), throwsFormatException);
  });

  test('설정은 왕복하고 옛 파일에 없어도 읽힌다', () {
    const contents = BackupContents(
      trips: [],
      rides: [],
      visits: [],
      settings: {'theme': 'dark', 'show_closed': '0'},
    );
    const header = BackupHeader(userVersion: 1, edition: 'e', appBuild: 1, exportedAt: 1);
    final text = const BackupFile(header: header, contents: contents).encode();
    final back = BackupFile.decode(text).contents;
    expect(back.settings, {'theme': 'dark', 'show_closed': '0'});
    expect(back.sameAs(contents), isTrue);
    expect(back.sameAs(const BackupContents(trips: [], rides: [], visits: [])), isFalse);
    final old = (jsonDecode(text) as Map<String, Object?>);
    (old['tables']! as Map<String, Object?>).remove('setting');
    expect(BackupFile.decode(jsonEncode(old)).contents.settings, isEmpty);
  });

  group('입구 검사', () {
    String file(String date, {bool legs = true}) => jsonEncode({
          ...const BackupHeader(userVersion: 1, edition: 'e', appBuild: 1, exportedAt: 1).toJson(),
          'tables': {
            'trip': const <Object>[],
            'visit': const <Object>[],
            'setting': const <Object>[],
            'photo': const <Object>[],
            'change_report': [
              {
                'id': 'change-e-1',
                'created_at': 1,
                'updated_at': 1,
                'deleted_at': null,
                'device_id': '',
                'edition': 'e',
                'body': '[]',
              },
            ],
            'ride': [
              {
                'id': 'r',
                'created_at': 1,
                'updated_at': 1,
                'deleted_at': null,
                'device_id': 'd',
                'trip_id': null,
                'date_input': date,
                'times': null,
                'train_name': null,
                'car_no': null,
                'note': null,
                'service_id': null,
                'transfer_nodes': const <Object>[],
                'from_alighted': true,
                'to_alighted': true,
                'dataset_version': 'e',
                'import_source': null,
                'import_raw': null,
                'legs': legs
                    ? [
                        {
                          'seq': 0,
                          'line_id': 'l',
                          'route_id': 'r',
                          'from_node': 'a',
                          'to_node': 'b',
                          'direction': null,
                          'resolve_as_of': null,
                          'resolve_unknown': false,
                          'line_label': '',
                          'from_label': '',
                          'to_label': '',
                        },
                      ]
                    : const <Object>[],
              },
            ],
          },
        });

    test('변경 내역이 돌아온다', () {
      final contents = BackupFile.decode(file('2015-03-14')).contents;
      expect(contents.changeNotes.single.edition, 'e');
      expect(contents.stamps, containsPair('change-e-1', 1));
    });

    test('읽을 수 없는 날짜는 파일을 거부한다', () {
      expect(() => BackupFile.decode(file('어제')), throwsFormatException);
    });

    test('구간 없는 기록은 파일을 거부한다', () {
      expect(() => BackupFile.decode(file('2015-03-14', legs: false)), throwsFormatException);
    });
  });
}
