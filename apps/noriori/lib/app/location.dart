import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// 지금 위치. 기기 밖으로 나가지 않는다 (DESIGN §7). 시험에서 바꿔 끼운다.
abstract interface class LocationSource {
  /// 처음 부를 때 권한을 묻는다. 거절하면 null이다.
  Future<(double, double)?> current();
}

final class DeviceLocation implements LocationSource {
  const DeviceLocation();

  @override
  Future<(double, double)?> current() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      return null;
    }
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    // 반경 50km를 보는 데 정밀한 위치는 필요 없다
    final at = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 15)),
    );
    return (at.latitude, at.longitude);
  }
}

final locationProvider = Provider<LocationSource>((ref) => const DeviceLocation());
