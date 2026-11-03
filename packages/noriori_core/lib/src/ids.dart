// 영구 ID. 문자열이지만 서로 섞이지 않게 타입을 나눈다 (DESIGN §2.10).
// edge, 묶음, lineage는 판 안에서만 유효하므로 기록에 저장하는 ID가 아니다.

extension type const NodeId(String value) implements String {}

extension type const LineId(String value) implements String {}

extension type const RouteId(String value) implements String {}

extension type const ServiceId(String value) implements String {}

extension type const TripId(String value) implements String {}

extension type const RideId(String value) implements String {}

extension type const VisitId(String value) implements String {}
