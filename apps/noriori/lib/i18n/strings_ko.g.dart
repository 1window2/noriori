///
/// Generated file. Do not edit.
///
// coverage:ignore-file
// ignore_for_file: type=lint, unused_import
// dart format off

part of 'strings.g.dart';

// Path: <root>
typedef TranslationsKo = Translations; // ignore: unused_element
class Translations with BaseTranslations<AppLocale, Translations> {
	/// Returns the current translations of the given [context].
	///
	/// Usage:
	/// final t = Translations.of(context);
	static Translations of(BuildContext context) => InheritedLocaleData.of<AppLocale, Translations>(context).translations;

	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	Translations({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  _meta = meta ?? TranslationMetadata(
		    locale: AppLocale.ko,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ) {
		_meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <ko>.
	final TranslationMetadata<AppLocale, Translations> _meta;
	@override TranslationMetadata<AppLocale, Translations> get $meta => _meta;

	/// Access flat map
	dynamic operator[](String key) => _meta.getTranslation(key);

	late final Translations _root = this; // ignore: unused_field

	Translations $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => Translations(meta: meta ?? this.$meta);

	// Translations
	late final Translations$app$ko app = Translations$app$ko._(_root);
	late final Translations$tabs$ko tabs = Translations$tabs$ko._(_root);
	late final Translations$start$ko start = Translations$start$ko._(_root);
	late final Translations$map$ko map = Translations$map$ko._(_root);
	late final Translations$record$ko record = Translations$record$ko._(_root);
	late final Translations$stats$ko stats = Translations$stats$ko._(_root);
	late final Translations$settings$ko settings = Translations$settings$ko._(_root);
	late final Translations$search$ko search = Translations$search$ko._(_root);
	late final Translations$session$ko session = Translations$session$ko._(_root);
	late final Translations$data$ko data = Translations$data$ko._(_root);
	late final Translations$importing$ko importing = Translations$importing$ko._(_root);
	late final Translations$ticket$ko ticket = Translations$ticket$ko._(_root);
	late final Translations$sources$ko sources = Translations$sources$ko._(_root);
	late final Translations$editRide$ko editRide = Translations$editRide$ko._(_root);
	late final Translations$lineDetail$ko lineDetail = Translations$lineDetail$ko._(_root);
	late final Translations$service$ko service = Translations$service$ko._(_root);
	late final Translations$deleted$ko deleted = Translations$deleted$ko._(_root);
	late final Translations$complete$ko complete = Translations$complete$ko._(_root);
	late final Translations$collection$ko collection = Translations$collection$ko._(_root);
	late final Translations$visits$ko visits = Translations$visits$ko._(_root);
	late final Translations$remaining$ko remaining = Translations$remaining$ko._(_root);
	late final Translations$news$ko news = Translations$news$ko._(_root);
	late final Translations$journey$ko journey = Translations$journey$ko._(_root);
	late final Translations$years$ko years = Translations$years$ko._(_root);
	late final Translations$trip$ko trip = Translations$trip$ko._(_root);
	late final Translations$mapSheet$ko mapSheet = Translations$mapSheet$ko._(_root);
	List<String> get prefNames => [
		'홋카이도',
		'아오모리',
		'이와테',
		'미야기',
		'아키타',
		'야마가타',
		'후쿠시마',
		'이바라키',
		'도치기',
		'군마',
		'사이타마',
		'치바',
		'도쿄',
		'가나가와',
		'니가타',
		'도야마',
		'이시카와',
		'후쿠이',
		'야마나시',
		'나가노',
		'기후',
		'시즈오카',
		'아이치',
		'미에',
		'시가',
		'교토',
		'오사카',
		'효고',
		'나라',
		'와카야마',
		'돗토리',
		'시마네',
		'오카야마',
		'히로시마',
		'야마구치',
		'도쿠시마',
		'카가와',
		'에히메',
		'고치',
		'후쿠오카',
		'사가',
		'나가사키',
		'구마모토',
		'오이타',
		'미야자키',
		'가고시마',
		'오키나와',
	];
	late final Translations$date$ko date = Translations$date$ko._(_root);
}

// Path: app
class Translations$app$ko {
	Translations$app$ko._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// ko: 'noriori'
	String get name => 'noriori';

	/// ko: '불러오지 못했습니다. 앱을 다시 열어 주세요'
	String get loadFailed => '불러오지 못했습니다. 앱을 다시 열어 주세요';
}

// Path: tabs
class Translations$tabs$ko {
	Translations$tabs$ko._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// ko: '지도'
	String get map => '지도';

	/// ko: '기록'
	String get record => '기록';

	/// ko: '통계'
	String get stats => '통계';

	/// ko: '설정'
	String get settings => '설정';
}

// Path: start
class Translations$start$ko {
	Translations$start$ko._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// ko: '준비하는 중'
	String get loading => '준비하는 중';

	/// ko: '앱을 업데이트해 주세요'
	String get updateTitle => '앱을 업데이트해 주세요';

	/// ko: '기록이 이 앱보다 새로운 버전에서 저장되었습니다. 기록은 그대로 있습니다.'
	String get updateBody => '기록이 이 앱보다 새로운 버전에서 저장되었습니다. 기록은 그대로 있습니다.';

	/// ko: '기록을 열지 못했습니다'
	String get retryTitle => '기록을 열지 못했습니다';

	/// ko: '기록은 그대로 있습니다. 잠시 뒤 다시 시도해 주세요.'
	String get retryBody => '기록은 그대로 있습니다. 잠시 뒤 다시 시도해 주세요.';

	/// ko: '기록 파일이 손상되었습니다'
	String get restoreTitle => '기록 파일이 손상되었습니다';

	/// ko: '손상된 파일은 보관해 두었습니다. 백업 파일에서 복원할 수 있습니다.'
	String get restoreBody => '손상된 파일은 보관해 두었습니다. 백업 파일에서 복원할 수 있습니다.';

	/// ko: '다시 시도'
	String get retry => '다시 시도';

	/// ko: '저장 공간이 부족합니다'
	String get noSpaceTitle => '저장 공간이 부족합니다';

	/// ko: '기록은 그대로 있습니다. 공간을 확보한 뒤 다시 시도해 주세요.'
	String get noSpaceBody => '기록은 그대로 있습니다. 공간을 확보한 뒤 다시 시도해 주세요.';

	/// ko: '복원하기'
	String get restoreAction => '복원하기';
}

// Path: map
class Translations$map$ko {
	Translations$map$ko._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// ko: '모든 노선 보기'
	String get soloOff => '모든 노선 보기';

	/// ko: '기록'
	String get add => '기록';

	/// ko: '노선이나 역 찾기'
	String get search => '노선이나 역 찾기';

	/// ko: '폐선'
	String get closed => '폐선';

	/// ko: '역 이름'
	String get names => '역 이름';

	/// ko: '전국 보기'
	String get wholeJapan => '전국 보기';

	/// ko: '첫 탑승을 기록해 보세요'
	String get firstRide => '첫 탑승을 기록해 보세요';

	/// ko: '노선을 고르고 두 역만 누르면 됩니다'
	String get firstRideHint => '노선을 고르고 두 역만 누르면 됩니다';

	/// ko: '$km km 남음'
	String left({required Object km}) => '${km} km 남음';

	/// ko: '이어서 타기'
	String get continueTitle => '이어서 타기';

	/// ko: '승차만'
	String get onlyRidden => '승차만';

	/// ko: '이어서 타기 목록 펼치기'
	String get sheetHandle => '이어서 타기 목록 펼치기';

	/// ko: '연도'
	String get year => '연도';

	/// ko: '그해까지 탄 구간만 파랗게 보입니다'
	String get yearHint => '그해까지 탄 구간만 파랗게 보입니다';

	/// ko: '도도부현'
	String get heat => '도도부현';
}

// Path: record
class Translations$record$ko {
	Translations$record$ko._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// ko: '$name 탑승'
	String viaService({required Object name}) => '${name} 탑승';

	/// ko: '아직 기록이 없습니다'
	String get empty => '아직 기록이 없습니다';

	/// ko: '노선별 목록이나 검색에서 첫 탑승을 기록해 보세요'
	String get emptyHint => '노선별 목록이나 검색에서 첫 탑승을 기록해 보세요';

	/// ko: '기록 추가'
	String get add => '기록 추가';

	/// ko: '날짜 모름'
	String get dateUnknown => '날짜 모름';

	late final Translations$record$status$ko status = Translations$record$status$ko._(_root);

	/// ko: '기록을 삭제했습니다'
	String get deleted => '기록을 삭제했습니다';

	/// ko: '되돌리기'
	String get undo => '되돌리기';

	/// ko: '삭제'
	String get delete => '삭제';

	/// ko: '$km km'
	String km({required Object km}) => '${km} km';

	late final Translations$record$view$ko view = Translations$record$view$ko._(_root);
	late final Translations$record$era$ko era = Translations$record$era$ko._(_root);
	late final Translations$record$category$ko category = Translations$record$category$ko._(_root);

	/// ko: '기록'
	String get title => '기록';

	/// ko: '현재 노선 전체'
	String get currentLabel => '현재 노선 전체';

	/// ko: '폐지된 구간'
	String get closedLabel => '폐지된 구간';

	/// ko: '$km km 중'
	String of({required Object km}) => '${km} km 중';

	/// ko: '노선 $num / $den'
	String lineCount({required Object num, required Object den}) => '노선 ${num} / ${den}';

	/// ko: '완주 $num'
	String completeCount({required Object num}) => '완주 ${num}';

	late final Translations$record$filter$ko filter = Translations$record$filter$ko._(_root);

	/// ko: '$era · $num / $den km · $percent'
	String lineSub({required Object era, required Object num, required Object den, required Object percent}) => '${era} · ${num} / ${den} km · ${percent}';

	/// ko: '해당하는 노선이 없습니다'
	String get filterEmpty => '해당하는 노선이 없습니다';

	/// ko: '$count건 선택'
	String picked({required Object count}) => '${count}건 선택';

	/// ko: '모두 선택'
	String get pickAll => '모두 선택';
}

// Path: stats
class Translations$stats$ko {
	Translations$stats$ko._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// ko: '누적 탑승 거리 $km km'
	String totalRidden({required Object km}) => '누적 탑승 거리 ${km} km';

	/// ko: '기록을 추가하면 완주율이 보입니다'
	String get empty => '기록을 추가하면 완주율이 보입니다';

	/// ko: '현재 노선'
	String get current => '현재 노선';

	/// ko: '폐선 포함'
	String get allTime => '폐선 포함';

	/// ko: '$num / $den km'
	String ridden({required Object num, required Object den}) => '${num} / ${den} km';

	/// ko: '회사'
	String get operators => '회사';

	/// ko: '노선'
	String get lines => '노선';

	/// ko: '통계'
	String get title => '통계';

	/// ko: '연도'
	String get year => '연도';

	/// ko: '연도 고르기'
	String get yearPick => '연도 고르기';

	/// ko: '$year년'
	String yearLabel({required Object year}) => '${year}년';

	/// ko: '$num / $den km'
	String rodeOf({required Object num, required Object den}) => '${num} / ${den} km';

	/// ko: '이번 달 +$km km'
	String month({required Object km}) => '이번 달 +${km} km';

	late final Translations$stats$kpi$ko kpi = Translations$stats$kpi$ko._(_root);

	/// ko: '곧 완주'
	String get nearly => '곧 완주';

	/// ko: '$km km 남음'
	String left({required Object km}) => '${km} km 남음';

	/// ko: '도도부현'
	String get prefs => '도도부현';

	/// ko: '탄 비율'
	String get prefHint => '탄 비율';

	/// ko: '$name $percent'
	String prefLabel({required Object name, required Object percent}) => '${name} ${percent}';

	/// ko: '(other) {타고 내렸거나 들른 역 $n곳}'
	String visited({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(n,
		other: '타고 내렸거나 들른 역 ${n}곳',
	);

	/// ko: '$year년대'
	String decade({required Object year}) => '${year}년대';

	/// ko: '(other) {판정 불가 $n구간}'
	String undecided({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(n,
		other: '판정 불가 ${n}구간',
	);

	/// ko: '(other) {확인 필요 $n건 · $km km}'
	String review({required num n, required Object km}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(n,
		other: '확인 필요 ${n}건 · ${km} km',
	);

	/// ko: '(other) {배지 $n개}'
	String badges({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(n,
		other: '배지 ${n}개',
	);

	/// ko: '폐역 $n곳'
	String visitedClosed({required Object n}) => '폐역 ${n}곳';
}

// Path: settings
class Translations$settings$ko {
	Translations$settings$ko._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// ko: '앱 버전'
	String get version => '앱 버전';

	/// ko: '데이터 버전'
	String get dataEdition => '데이터 버전';

	/// ko: '역 $stations곳 · 노선 $lines개'
	String packSummary({required Object stations, required Object lines}) => '역 ${stations}곳 · 노선 ${lines}개';

	/// ko: '백업과 복원'
	String get data => '백업과 복원';

	/// ko: '오픈소스 라이선스'
	String get licenses => '오픈소스 라이선스';

	/// ko: '데이터 출처'
	String get sources => '데이터 출처';

	/// ko: '폐역·폐선 표시'
	String get showClosed => '폐역·폐선 표시';

	/// ko: '기록할 수 없는 옛 역·노선도 표시'
	String get showArchive => '기록할 수 없는 옛 역·노선도 표시';

	/// ko: '분기선 표시'
	String get showBranches => '분기선 표시';

	/// ko: '테마'
	String get theme => '테마';

	/// ko: '라이트'
	String get themeLight => '라이트';

	/// ko: '다크'
	String get themeDark => '다크';

	/// ko: '시스템 설정'
	String get themeSystem => '시스템 설정';

	/// ko: '언어'
	String get language => '언어';

	/// ko: '사업자 전환 시 기록 승계'
	String get carryover => '사업자 전환 시 기록 승계';

	/// ko: '끄면 JR에서 넘어간 구간은 새 노선으로 따로 셉니다'
	String get carryoverHint => '끄면 JR에서 넘어간 구간은 새 노선으로 따로 셉니다';
}

// Path: search
class Translations$search$ko {
	Translations$search$ko._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// ko: '지도에서 보기'
	String get showOnMap => '지도에서 보기';

	/// ko: '노선이나 역 이름'
	String get hint => '노선이나 역 이름';

	/// ko: '노선이나 역을 찾아 시작하세요'
	String get prompt => '노선이나 역을 찾아 시작하세요';

	/// ko: '검색 결과가 없습니다'
	String get none => '검색 결과가 없습니다';

	/// ko: '열람 전용'
	String get archive => '열람 전용';
}

// Path: session
class Translations$session$ko {
	Translations$session$ko._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// ko: '(other) {$n바퀴}'
	String laps({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(n,
		other: '${n}바퀴',
	);

	/// ko: '한 바퀴 줄이기'
	String get lapLess => '한 바퀴 줄이기';

	/// ko: '한 바퀴 늘리기'
	String get lapMore => '한 바퀴 늘리기';

	/// ko: '(other) {$n역}'
	String foldStops({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(n,
		other: '${n}역',
	);

	/// ko: '(other) {+$n역}'
	String away({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(n,
		other: '+${n}역',
	);

	/// ko: '탑승일'
	String get dateTitle => '탑승일';

	/// ko: '2015, 2015-03, 2015-03-14, 198X'
	String get dateHint => '2015, 2015-03, 2015-03-14, 198X';

	/// ko: '날짜 모름'
	String get dateUnknown => '날짜 모름';

	/// ko: '날짜 모름: 역은 모든 시기, 직통·환승은 마지막 상태로 보여요'
	String get dateUnknownHint => '날짜 모름: 역은 모든 시기, 직통·환승은 마지막 상태로 보여요';

	/// ko: '달력에서 고르기'
	String get datePick => '달력에서 고르기';

	/// ko: '오늘'
	String get dateToday => '오늘';

	/// ko: '날짜 형식을 확인해 주세요'
	String get dateBad => '날짜 형식을 확인해 주세요';

	/// ko: '적용'
	String get apply => '적용';

	/// ko: '취소'
	String get cancel => '취소';

	/// ko: '본선'
	String get main => '본선';

	/// ko: '출발역을 고르세요'
	String get pickFrom => '출발역을 고르세요';

	/// ko: '임시'
	String get tempTag => '임시';

	/// ko: '정기 여객 열차 미운행 구간(임시 열차 운행일만 기록 가능)'
	String get tempNotice => '정기 여객 열차 미운행 구간(임시 열차 운행일만 기록 가능)';

	/// ko: '임시 열차 운행일을 고르세요'
	String get tempPickDay => '임시 열차 운행일을 고르세요';

	/// ko: '이 날짜에는 임시 열차가 다니지 않았습니다. 위의 운행일을 눌러 보세요'
	String get tempNoRun => '이 날짜에는 임시 열차가 다니지 않았습니다. 위의 운행일을 눌러 보세요';

	/// ko: '도착역을 고르세요'
	String get pickTo => '도착역을 고르세요';

	/// ko: '기록하기'
	String get save => '기록하기';

	/// ko: '$from → $to · $km km'
	String summary({required Object from, required Object to, required Object km}) => '${from} → ${to} · ${km} km';

	/// ko: '이 두 역 사이의 경로를 찾지 못했습니다'
	String get noPath => '이 두 역 사이의 경로를 찾지 못했습니다';

	late final Translations$session$state$ko state = Translations$session$state$ko._(_root);

	/// ko: '탑승일 기준 $line 구간'
	String savedAs({required Object line}) => '탑승일 기준 ${line} 구간';

	/// ko: '${year}년 ${name} 이전'
	String movedTo({required Object year, required Object name}) => '${year}년 ${name} 이전';

	/// ko: '$date부터 $line'
	String handSince({required Object date, required Object line}) => '${date}부터 ${line}';

	/// ko: '노선 보기 ›'
	String get handOpen => '노선 보기 ›';

	/// ko: '이 구간은 그 노선으로 기록돼요'
	String get handNote => '이 구간은 그 노선으로 기록돼요';

	/// ko: '그 전 날짜로만 기록할 수 있어요'
	String get noticeClosedSub => '그 전 날짜로만 기록할 수 있어요';

	/// ko: '운휴 전 날짜로만 기록할 수 있어요'
	String get noticeSuspendedSub => '운휴 전 날짜로만 기록할 수 있어요';

	/// ko: '보통 $from월~$to월에만 다녀요. 이 날은 운행하지 않아요'
	String noticeSeasonSub({required Object from, required Object to}) => '보통 ${from}월~${to}월에만 다녀요. 이 날은 운행하지 않아요';

	/// ko: '보통 $from월~$to월에만 다녀요'
	String noticeSeasonAnySub({required Object from, required Object to}) => '보통 ${from}월~${to}월에만 다녀요';

	/// ko: '개업한 뒤 날짜로 기록할 수 있어요'
	String get noticeBeforeSub => '개업한 뒤 날짜로 기록할 수 있어요';

	/// ko: '어느 쪽으로 탔나요?'
	String get chooseDirection => '어느 쪽으로 탔나요?';

	/// ko: '$km km'
	String directionKm({required Object km}) => '${km} km';

	/// ko: '어느 시기의 선로였나요?'
	String get chooseRelocation => '어느 시기의 선로였나요?';

	/// ko: '$date 기준 · $km km'
	String relocationOption({required Object date, required Object km}) => '${date} 기준 · ${km} km';

	/// ko: '모르겠음'
	String get dontKnow => '모르겠음';

	/// ko: '오늘'
	String get today => '오늘';

	/// ko: '역 찾기'
	String get findStop => '역 찾기';

	/// ko: '$operator · $km'
	String meta({required Object operator, required Object km}) => '${operator} · ${km}';

	/// ko: '새로 타는 구간 $km km'
	String fresh({required Object km}) => '새로 타는 구간 ${km} km';

	/// ko: '이미 탄 구간입니다'
	String get noFresh => '이미 탄 구간입니다';

	/// ko: '$before → $after'
	String change({required Object before, required Object after}) => '${before} → ${after}';

	/// ko: '이 날짜에 고를 수 있는 역이 없습니다. 탑승일을 바꿔 보세요'
	String get nonePickable => '이 날짜에 고를 수 있는 역이 없습니다. 탑승일을 바꿔 보세요';

	/// ko: '이 날짜에 운행했는지 확인되지 않았습니다'
	String get maybeHint => '이 날짜에 운행했는지 확인되지 않았습니다';

	/// ko: '저장하지 못했습니다. 기록은 바뀌지 않았습니다'
	String get saveFailed => '저장하지 못했습니다. 기록은 바뀌지 않았습니다';

	/// ko: '$km킬로미터'
	String spokenKm({required Object km}) => '${km}킬로미터';

	/// ko: '(other) {환승 $n개}'
	String spokenTransfer({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(n,
		other: '환승 ${n}개',
	);

	/// ko: '출발역으로 선택됨'
	String get spokenFrom => '출발역으로 선택됨';

	/// ko: '도착역으로 선택됨'
	String get spokenTo => '도착역으로 선택됨';

	/// ko: '폐역·폐선 표시'
	String get showClosed => '폐역·폐선 표시';

	/// ko: '기록할 수 없는 옛 역·노선도 표시'
	String get showArchive => '기록할 수 없는 옛 역·노선도 표시';

	/// ko: '선택 해제'
	String get clear => '선택 해제';

	/// ko: '한 바퀴'
	String get lap => '한 바퀴';

	/// ko: '(other) {$n개 역}'
	String stops({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(n,
		other: '${n}개 역',
	);

	/// ko: '~$year 폐지'
	String closedSection({required Object year}) => '~${year} 폐지';

	/// ko: '$year년 개업'
	String openedSection({required Object year}) => '${year}년 개업';

	/// ko: '$name: 폐역($year). 기록할 수 없는 옛 역입니다'
	String archiveStop({required Object name, required Object year}) => '${name}: 폐역(${year}). 기록할 수 없는 옛 역입니다';

	/// ko: '$name: 폐역($year). 기록할 수 없는 옛 역입니다. 지금의 $now역 자리'
	String archiveStopNow({required Object name, required Object year, required Object now}) => '${name}: 폐역(${year}). 기록할 수 없는 옛 역입니다. 지금의 ${now}역 자리';

	/// ko: '$name: 폐역. 기록할 수 없는 옛 역입니다'
	String archiveStopNoYear({required Object name}) => '${name}: 폐역. 기록할 수 없는 옛 역입니다';

	/// ko: '$name: 폐역. 기록할 수 없는 옛 역입니다. 지금의 $now역 자리'
	String archiveStopNowNoYear({required Object name, required Object now}) => '${name}: 폐역. 기록할 수 없는 옛 역입니다. 지금의 ${now}역 자리';

	/// ko: '$name: 기록할 수 없는 옛 노선입니다'
	String archiveLine({required Object name}) => '${name}: 기록할 수 없는 옛 노선입니다';

	/// ko: '출발'
	String get from => '출발';

	/// ko: '도착'
	String get to => '도착';

	/// ko: '그 날짜에는 운영하지 않던 역입니다'
	String get whyClosed => '그 날짜에는 운영하지 않던 역입니다';

	/// ko: '신호장·분기점이라 여기서 기록을 시작하거나 끝낼 수 없어요'
	String get whyViewSignal => '신호장·분기점이라 여기서 기록을 시작하거나 끝낼 수 없어요';

	/// ko: '이 노선은 이 역에 서지 않아 여기서 기록을 시작하거나 끝낼 수 없어요'
	String get whyViewNoBoarding => '이 노선은 이 역에 서지 않아 여기서 기록을 시작하거나 끝낼 수 없어요';

	/// ko: '승객을 받지 않는 역이라 여기서 기록을 시작하거나 끝낼 수 없어요'
	String get whyViewStaff => '승객을 받지 않는 역이라 여기서 기록을 시작하거나 끝낼 수 없어요';

	/// ko: '하행만'
	String get onlyDown => '하행만';

	/// ko: '상행만'
	String get onlyUp => '상행만';

	/// ko: '한 방향만'
	String get onlyOneWay => '한 방향만';

	/// ko: '하행 열차만 정차'
	String get spokenOnlyDown => '하행 열차만 정차';

	/// ko: '상행 열차만 정차'
	String get spokenOnlyUp => '상행 열차만 정차';

	/// ko: '한 방향 열차만 정차'
	String get spokenOnlyOneWay => '한 방향 열차만 정차';

	/// ko: '$name에는 하행 열차만 서요'
	String stopDownTitle({required Object name}) => '${name}에는 하행 열차만 서요';

	/// ko: '$name에는 상행 열차만 서요'
	String stopUpTitle({required Object name}) => '${name}에는 상행 열차만 서요';

	/// ko: '$name에는 한 방향 열차만 서요'
	String stopOneWayTitle({required Object name}) => '${name}에는 한 방향 열차만 서요';

	/// ko: '$name 방면으로만 탈 수 있어요'
	String towardOnly({required Object name}) => '${name} 방면으로만 탈 수 있어요';

	/// ko: '한 방향으로만 다니는 구간이에요'
	String get sectionTitle => '한 방향으로만 다니는 구간이에요';

	/// ko: '이 방향으로는 열차가 다니지 않아요'
	String get sectionDetail => '이 방향으로는 열차가 다니지 않아요';

	/// ko: '한 방향으로만 도는 구간이에요'
	String get aroundTitle => '한 방향으로만 도는 구간이에요';

	/// ko: '돌아가는 길 $km km로 셉니다'
	String aroundDetail({required Object km}) => '돌아가는 길 ${km} km로 셉니다';

	/// ko: '방향 바꾸기'
	String get reverse => '방향 바꾸기';

	/// ko: '하차전용'
	String get onlyAlight => '하차전용';

	/// ko: '하차전용 역이에요'
	String get alightTitle => '하차전용 역이에요';

	/// ko: '도착역으로만 고를 수 있어요'
	String get alightDetail => '도착역으로만 고를 수 있어요';

	/// ko: '그 날짜에는 운행이 중단된 구간입니다'
	String get whySuspended => '그 날짜에는 운행이 중단된 구간입니다';

	/// ko: '$names 방면'
	String bound({required Object names}) => '${names} 방면';

	/// ko: '$year년 폐지'
	String spokenClosed({required Object year}) => '${year}년 폐지';

	/// ko: '$year년부터 운휴'
	String spokenSuspendedSince({required Object year}) => '${year}년부터 운휴';

	/// ko: '가'
	String get pastKari => '가';

	/// ko: '임'
	String get pastRinji => '임';

	/// ko: '예전 가승강장'
	String get spokenPastKari => '예전 가승강장';

	/// ko: '예전 임시역'
	String get spokenPastRinji => '예전 임시역';

	/// ko: '$line, $next 분기'
	String spokenBranch({required Object line, required Object next}) => '${line}, ${next} 분기';

	/// ko: '이 역에서 진행 방향을 바꿔 $line 직통합니다'
	String reverseNow({required Object line}) => '이 역에서 진행 방향을 바꿔 ${line} 직통합니다';

	/// ko: '이 역에서 진행 방향을 바꿔 $line 직통하는 열차가 있었습니다'
	String reverseUsed({required Object line}) => '이 역에서 진행 방향을 바꿔 ${line} 직통하는 열차가 있었습니다';

	/// ko: '방향 바꿈'
	String get spokenReverse => '방향 바꿈';

	/// ko: '$name에서 출발'
	String leaving({required Object name}) => '${name}에서 출발';

	/// ko: '$num / $den km ($percent)'
	String progress({required Object num, required Object den, required Object percent}) => '${num} / ${den} km (${percent})';

	/// ko: '고른 역이 사라집니다'
	String get leaveTitle => '고른 역이 사라집니다';

	/// ko: '다른 노선으로 넘어가면 지금 고른 역은 지워집니다.'
	String get leaveBody => '다른 노선으로 넘어가면 지금 고른 역은 지워집니다.';

	/// ko: '넘어가기'
	String get leave => '넘어가기';

	/// ko: '그 날짜에는 탈 수 없는 구간입니다'
	String get unridableTitle => '그 날짜에는 탈 수 없는 구간입니다';

	/// ko: '폐지 뒤나 개업 전, 운휴 중이었거나 고른 역에 열차가 서지 않던 날입니다. 기록하지 않았습니다.'
	String get unridableSave => '폐지 뒤나 개업 전, 운휴 중이었거나 고른 역에 열차가 서지 않던 날입니다. 기록하지 않았습니다.';

	/// ko: '폐지 뒤나 개업 전, 운휴 중이었거나 고른 역에 열차가 서지 않던 날입니다. 탑승일은 그대로 둡니다.'
	String get unridableDate => '폐지 뒤나 개업 전, 운휴 중이었거나 고른 역에 열차가 서지 않던 날입니다. 탑승일은 그대로 둡니다.';

	/// ko: '확인'
	String get unridableOk => '확인';

	/// ko: '다른 역을 누르면 처음부터 다시 고릅니다'
	String get repick => '다른 역을 누르면 처음부터 다시 고릅니다';

	/// ko: '폐지 구간'
	String get closedUnknown => '폐지 구간';

	/// ko: '운휴 중'
	String get suspendedSection => '운휴 중';

	/// ko: '계절 운행'
	String get seasonSection => '계절 운행';

	/// ko: '옛 선로 · $km km'
	String relocationOld({required Object km}) => '옛 선로 · ${km} km';

	/// ko: '새 선로 · $km km'
	String relocationNew({required Object km}) => '새 선로 · ${km} km';

	/// ko: '영업 중'
	String get spokenOpen => '영업 중';

	/// ko: '승하차 불가'
	String get spokenPassing => '승하차 불가';

	/// ko: '탄 역'
	String get spokenRidden => '탄 역';
}

// Path: data
class Translations$data$ko {
	Translations$data$ko._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// ko: '기록 파일이 20MB를 넘어 Android 클라우드 백업에 들어가지 않을 수 있어요. 백업 폴더를 골라 두세요'
	String get osBackupLarge => '기록 파일이 20MB를 넘어 Android 클라우드 백업에 들어가지 않을 수 있어요. 백업 폴더를 골라 두세요';

	/// ko: '백업과 복원'
	String get title => '백업과 복원';

	/// ko: '백업 폴더'
	String get folder => '백업 폴더';

	/// ko: '앱을 지워도 남는 곳을 고르세요'
	String get folderHint => '앱을 지워도 남는 곳을 고르세요';

	/// ko: '고르지 않음'
	String get folderNone => '고르지 않음';

	/// ko: '앱을 지우면 함께 사라지는 위치입니다. 다른 폴더를 골라 주세요'
	String get insideApp => '앱을 지우면 함께 사라지는 위치입니다. 다른 폴더를 골라 주세요';

	/// ko: '마지막 백업'
	String get lastBackup => '마지막 백업';

	/// ko: '없음'
	String get never => '없음';

	/// ko: '마지막 백업에 실패했습니다'
	String get lastFailed => '마지막 백업에 실패했습니다';

	/// ko: '지금 백업'
	String get backupNow => '지금 백업';

	/// ko: '복원'
	String get restore => '복원';

	/// ko: '백업 파일을 지금 기록에 합칩니다. 같은 기록은 더 늦게 고친 쪽이 남으므로 새 기록이 사라지지 않습니다.'
	String get restoreHint => '백업 파일을 지금 기록에 합칩니다. 같은 기록은 더 늦게 고친 쪽이 남으므로 새 기록이 사라지지 않습니다.';

	/// ko: '이 폴더에 백업 파일이 없습니다'
	String get noFiles => '이 폴더에 백업 파일이 없습니다';

	/// ko: '(other) {기록 $n건}'
	String fileRows({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(n,
		other: '기록 ${n}건',
	);

	/// ko: '앱을 업데이트해야 읽을 수 있습니다'
	String get fileTooNew => '앱을 업데이트해야 읽을 수 있습니다';

	/// ko: '읽을 수 없는 파일입니다'
	String get fileUnreadable => '읽을 수 없는 파일입니다';

	/// ko: '(other) {$n건을 복원했습니다}'
	String merged({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(n,
		other: '${n}건을 복원했습니다',
	);

	/// ko: '이 파일은 복원할 수 없습니다'
	String get refused => '이 파일은 복원할 수 없습니다';

	/// ko: '손상된 파일 내보내기'
	String get exportQuarantined => '손상된 파일 내보내기';

	/// ko: '백업 폴더에 사본을 저장합니다'
	String get exportHint => '백업 폴더에 사본을 저장합니다';

	/// ko: '(other) {파일 $n개를 내보냈습니다}'
	String exported({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(n,
		other: '파일 ${n}개를 내보냈습니다',
	);

	/// ko: '복원을 마치고 시작'
	String get finish => '복원을 마치고 시작';

	late final Translations$data$notice$ko notice = Translations$data$notice$ko._(_root);

	/// ko: 'CSV 내보내기 (노리츠부시 호환)'
	String get exportCompat => 'CSV 내보내기 (노리츠부시 호환)';

	/// ko: '노리츠부시와 같은 형식으로 보냅니다'
	String get exportCompatHint => '노리츠부시와 같은 형식으로 보냅니다';

	/// ko: 'CSV 내보내기 (전체)'
	String get exportFull => 'CSV 내보내기 (전체)';

	/// ko: '경로와 날짜까지 담아 보냅니다'
	String get exportFullHint => '경로와 날짜까지 담아 보냅니다';

	/// ko: '일본어 CSV 형식에 없는 글자가 있어 UTF-8로 저장했습니다: $name'
	String exportedUtf8({required Object name}) => '일본어 CSV 형식에 없는 글자가 있어 UTF-8로 저장했습니다: ${name}';

	/// ko: '내보내지 못했습니다'
	String get exportFailed => '내보내지 못했습니다';

	/// ko: '백업 파일 내보내기'
	String get exportBackup => '백업 파일 내보내기';

	/// ko: '지금 기록을 파일 하나로 만들어 보냅니다'
	String get exportBackupHint => '지금 기록을 파일 하나로 만들어 보냅니다';

	/// ko: '파일에서 복원'
	String get restoreFile => '파일에서 복원';

	/// ko: '내보낸 백업 파일을 직접 고릅니다'
	String get restoreFileHint => '내보낸 백업 파일을 직접 고릅니다';
}

// Path: importing
class Translations$importing$ko {
	Translations$importing$ko._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// ko: '노리츠부시 기록 가져오기'
	String get title => '노리츠부시 기록 가져오기';

	/// ko: '내려받은 CSV를 지금 기록에 더합니다'
	String get entryHint => '내려받은 CSV를 지금 기록에 더합니다';

	/// ko: '노리츠부시의 기록 편집 화면 아래에서 내려받은 CSV 파일을 고르세요. 일반판과 코멘트판 모두 됩니다.'
	String get hint => '노리츠부시의 기록 편집 화면 아래에서 내려받은 CSV 파일을 고르세요. 일반판과 코멘트판 모두 됩니다.';

	/// ko: '파일 고르기'
	String get choose => '파일 고르기';

	/// ko: '노리츠부시 CSV가 아닙니다: $name. 다른 파일을 골라 주세요.'
	String refused({required Object name}) => '노리츠부시 CSV가 아닙니다: ${name}. 다른 파일을 골라 주세요.';

	/// ko: '가져오지 못했습니다. 기록은 바뀌지 않았습니다.'
	String get failed => '가져오지 못했습니다. 기록은 바뀌지 않았습니다.';

	/// ko: '되돌렸습니다. 지운 기록은 다시 가져올 때 고를 수 있습니다.'
	String get undone => '되돌렸습니다. 지운 기록은 다시 가져올 때 고를 수 있습니다.';

	/// ko: '파일'
	String get file => '파일';

	/// ko: '새 기록'
	String get fresh => '새 기록';

	/// ko: '$count건'
	String rows({required Object count}) => '${count}건';

	/// ko: '기록 거리 합계'
	String get distance => '기록 거리 합계';

	/// ko: '이미 있는 기록'
	String get existing => '이미 있는 기록';

	/// ko: '삭제했던 기록도 다시 넣기'
	String get deleted => '삭제했던 기록도 다시 넣기';

	/// ko: '(other) {노선을 찾지 못한 행 $count건}'
	String missed({required num n, required Object count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(n,
		other: '노선을 찾지 못한 행 ${count}건',
	);

	/// ko: '기록으로 남기지만 완주율에는 들지 않습니다'
	String get missedHint => '기록으로 남기지만 완주율에는 들지 않습니다';

	/// ko: '(other) {읽지 못한 행 $count건}'
	String broken({required num n, required Object count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(n,
		other: '읽지 못한 행 ${count}건',
	);

	/// ko: '형식이 맞지 않아 가져오지 않습니다'
	String get brokenHint => '형식이 맞지 않아 가져오지 않습니다';

	/// ko: '(other) {거리가 다른 행 $count건}'
	String kmDiffers({required num n, required Object count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(n,
		other: '거리가 다른 행 ${count}건',
	);

	/// ko: '파일의 거리와 앱의 거리가 다릅니다'
	String get kmDiffersHint => '파일의 거리와 앱의 거리가 다릅니다';

	/// ko: '$raw → 앱 $km km'
	String kmDiffersRow({required Object raw, required Object km}) => '${raw} → 앱 ${km} km';

	/// ko: '새로 가져올 기록이 없습니다'
	String get nothing => '새로 가져올 기록이 없습니다';

	/// ko: '(other) {$count건 가져오기}'
	String confirm({required num n, required Object count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(n,
		other: '${count}건 가져오기',
	);

	/// ko: '(other) {$count건을 가져왔습니다}'
	String done({required num n, required Object count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(n,
		other: '${count}건을 가져왔습니다',
	);

	/// ko: '(other) {날짜 모름으로 넣은 행 $count건}'
	String undated({required num n, required Object count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(n,
		other: '날짜 모름으로 넣은 행 ${count}건',
	);

	/// ko: '닫기'
	String get close => '닫기';

	/// ko: '되돌리기'
	String get undo => '되돌리기';

	/// ko: 'noriori 전체 내보내기 파일입니다. 기록 $count건 중 없는 것만 더합니다.'
	String fullHint({required Object count}) => 'noriori 전체 내보내기 파일입니다. 기록 ${count}건 중 없는 것만 더합니다.';

	/// ko: '(other) {$n건을 더했습니다}'
	String merged({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(n,
		other: '${n}건을 더했습니다',
	);
}

// Path: ticket
class Translations$ticket$ko {
	Translations$ticket$ko._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// ko: '完乗'
	String get completeStamp => '完乗';

	/// ko: '乗車'
	String get rideStamp => '乗車';

	/// ko: '되돌리기'
	String get undo => '되돌리기';

	/// ko: '날짜 모름'
	String get noDate => '날짜 모름';
}

// Path: sources
class Translations$sources$ko {
	Translations$sources$ko._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// ko: '데이터 출처'
	String get title => '데이터 출처';

	/// ko: '이름, 거리, 날짜 같은 사실 정보를 여러 출처에서 모아 만들었습니다. noriori 데이터는 CC BY-SA 4.0으로 배포합니다. 선로 모양은 아래 원 자료의 조건을 따르고, OSM 선로 파일만 ODbL 1.0입니다.'
	String get intro => '이름, 거리, 날짜 같은 사실 정보를 여러 출처에서 모아 만들었습니다. noriori 데이터는 CC BY-SA 4.0으로 배포합니다. 선로 모양은 아래 원 자료의 조건을 따르고, OSM 선로 파일만 ODbL 1.0입니다.';

	late final Translations$sources$n02$ko n02 = Translations$sources$n02$ko._(_root);
	late final Translations$sources$n05$ko n05 = Translations$sources$n05$ko._(_root);
	late final Translations$sources$n03$ko n03 = Translations$sources$n03$ko._(_root);
	late final Translations$sources$gsi$ko gsi = Translations$sources$gsi$ko._(_root);
	late final Translations$sources$stationDatabase$ko stationDatabase = Translations$sources$stationDatabase$ko._(_root);
	late final Translations$sources$wikipedia$ko wikipedia = Translations$sources$wikipedia$ko._(_root);
	late final Translations$sources$wikidata$ko wikidata = Translations$sources$wikidata$ko._(_root);
	late final Translations$sources$namuwiki$ko namuwiki = Translations$sources$namuwiki$ko._(_root);
	late final Translations$sources$noritsubushi$ko noritsubushi = Translations$sources$noritsubushi$ko._(_root);
	late final Translations$sources$others$ko others = Translations$sources$others$ko._(_root);
	late final Translations$sources$openFreeMap$ko openFreeMap = Translations$sources$openFreeMap$ko._(_root);
	late final Translations$sources$openStreetMap$ko openStreetMap = Translations$sources$openStreetMap$ko._(_root);
	late final Translations$sources$noto$ko noto = Translations$sources$noto$ko._(_root);
}

// Path: editRide
class Translations$editRide$ko {
	Translations$editRide$ko._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// ko: '고쳤습니다'
	String get saved => '고쳤습니다';

	/// ko: '갈아탄 역'
	String get transfers => '갈아탄 역';

	/// ko: '지나간 역 중 내려서 갈아탄 역을 고릅니다'
	String get transfersHint => '지나간 역 중 내려서 갈아탄 역을 고릅니다';

	/// ko: '기록 수정'
	String get title => '기록 수정';

	/// ko: '기록을 찾지 못했습니다'
	String get missing => '기록을 찾지 못했습니다';

	/// ko: '탑승일'
	String get date => '탑승일';

	/// ko: '시각'
	String get times => '시각';

	/// ko: '열차명'
	String get train => '열차명';

	/// ko: '차량 편성'
	String get car => '차량 편성';

	/// ko: '메모'
	String get note => '메모';

	/// ko: '출발역에서 실제로 탔음'
	String get fromAlighted => '출발역에서 실제로 탔음';

	/// ko: '도착역에서 실제로 내렸음'
	String get toAlighted => '도착역에서 실제로 내렸음';

	/// ko: '저장'
	String get save => '저장';

	/// ko: '삭제'
	String get delete => '삭제';

	/// ko: '폐지 뒤나 개업 전, 운휴 중이었거나 기록한 역에 열차가 서지 않던 날입니다. 기록은 바뀌지 않았습니다.'
	String get unridable => '폐지 뒤나 개업 전, 운휴 중이었거나 기록한 역에 열차가 서지 않던 날입니다. 기록은 바뀌지 않았습니다.';

	/// ko: '저장하지 못했습니다. 기록은 바뀌지 않았습니다'
	String get failed => '저장하지 못했습니다. 기록은 바뀌지 않았습니다';
}

// Path: lineDetail
class Translations$lineDetail$ko {
	Translations$lineDetail$ko._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// ko: '지도에서 이 노선만 보기'
	String get soloMap => '지도에서 이 노선만 보기';

	/// ko: '현재 구간'
	String get current => '현재 구간';

	/// ko: '폐지 구간 포함'
	String get allTime => '폐지 구간 포함';

	/// ko: '$num / $den km'
	String km({required Object num, required Object den}) => '${num} / ${den} km';

	/// ko: '현재 구간 완주'
	String get completeCurrent => '현재 구간 완주';

	/// ko: '전체 통계에 들어가지 않는 노선입니다. 이 노선의 거리만으로 진행률을 셉니다'
	String get selfScore => '전체 통계에 들어가지 않는 노선입니다. 이 노선의 거리만으로 진행률을 셉니다';

	/// ko: '노선 상세'
	String get open => '노선 상세';

	/// ko: '이 노선 기록하기'
	String get record => '이 노선 기록하기';

	/// ko: '이 노선 탑승 기록 모두 지우기'
	String get clear => '이 노선 탑승 기록 모두 지우기';

	/// ko: '구간을 누르면 탑승 표시가 바뀝니다. 길게 누른 뒤 끌면 여러 구간을 한 번에 바꿉니다. 역을 나타내는 점을 누르면 방문 표시가 바뀝니다'
	String get hint => '구간을 누르면 탑승 표시가 바뀝니다. 길게 누른 뒤 끌면 여러 구간을 한 번에 바꿉니다. 역을 나타내는 점을 누르면 방문 표시가 바뀝니다';

	/// ko: '$from에서 $to까지, 탄 구간. 누르면 탑승 표시를 지웁니다'
	String sectionRidden({required Object from, required Object to}) => '${from}에서 ${to}까지, 탄 구간. 누르면 탑승 표시를 지웁니다';

	/// ko: '$from에서 $to까지, 안 탄 구간. 누르면 탑승으로 표시합니다'
	String sectionOpen({required Object from, required Object to}) => '${from}에서 ${to}까지, 안 탄 구간. 누르면 탑승으로 표시합니다';

	/// ko: '$name 방문 표시 바꾸기'
	String stopNode({required Object name}) => '${name} 방문 표시 바꾸기';

	/// ko: '(other) {기록 $n건을 고쳤습니다}'
	String turnedOff({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(n,
		other: '기록 ${n}건을 고쳤습니다',
	);

	/// ko: '탑승으로 표시했습니다'
	String get turnedOn => '탑승으로 표시했습니다';

	/// ko: '지운 기록을 되살렸습니다'
	String get restored => '지운 기록을 되살렸습니다';

	/// ko: '역이 아닌 지점에서 기록을 나눠야 해서 여기서는 지울 수 없습니다. 기록을 직접 고쳐 주세요'
	String get blockedHidden => '역이 아닌 지점에서 기록을 나눠야 해서 여기서는 지울 수 없습니다. 기록을 직접 고쳐 주세요';

	/// ko: '이 구간을 빼면 남은 기록의 경로나 날짜가 달라져서 지울 수 없습니다. 기록을 직접 고쳐 주세요'
	String get blockedPath => '이 구간을 빼면 남은 기록의 경로나 날짜가 달라져서 지울 수 없습니다. 기록을 직접 고쳐 주세요';

	/// ko: '이 방향 열차가 서지 않는 역에서 기록을 나눠야 해서 여기서는 지울 수 없습니다. 기록을 직접 고쳐 주세요'
	String get blockedNoStop => '이 방향 열차가 서지 않는 역에서 기록을 나눠야 해서 여기서는 지울 수 없습니다. 기록을 직접 고쳐 주세요';

	/// ko: '이 구간은 여기서 탑승으로 표시할 수 없습니다. 출발역과 도착역을 골라 기록해 주세요'
	String get blockedOn => '이 구간은 여기서 탑승으로 표시할 수 없습니다. 출발역과 도착역을 골라 기록해 주세요';

	/// ko: '방문으로 표시했습니다'
	String get visitAdded => '방문으로 표시했습니다';

	/// ko: '방문을 지웠습니다'
	String get visitRemoved => '방문을 지웠습니다';

	/// ko: '타고 내린 기록으로 표시된 역입니다. 표시를 지우려면 기록을 고쳐 주세요'
	String get visitByRide => '타고 내린 기록으로 표시된 역입니다. 표시를 지우려면 기록을 고쳐 주세요';

	/// ko: '되돌리기'
	String get undo => '되돌리기';

	/// ko: '$name →'
	String joinsTo({required Object name}) => '${name} →';

	/// ko: '방문일을 바꿨습니다'
	String get visitDated => '방문일을 바꿨습니다';
}

// Path: service
class Translations$service$ko {
	Translations$service$ko._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// ko: '운행 계통'
	String get kind => '운행 계통';

	/// ko: '그 날짜에 운행하지 않던 운행 계통입니다'
	String get none => '그 날짜에 운행하지 않던 운행 계통입니다';

	/// ko: '기록하기'
	String get save => '기록하기';

	/// ko: '이 구간은 기록할 수 없습니다. 날짜를 확인해 주세요'
	String get failed => '이 구간은 기록할 수 없습니다. 날짜를 확인해 주세요';
}

// Path: deleted
class Translations$deleted$ko {
	Translations$deleted$ko._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// ko: '예전에 가져온 기록'
	String get fileOldest => '예전에 가져온 기록';

	/// ko: '삭제한 기록'
	String get title => '삭제한 기록';

	/// ko: '삭제한 기록이 없습니다'
	String get empty => '삭제한 기록이 없습니다';

	/// ko: '되살리기'
	String get restore => '되살리기';

	/// ko: '기록을 되살렸습니다'
	String get restored => '기록을 되살렸습니다';

	/// ko: '(other) {기록 $n건}'
	String fileRides({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(n,
		other: '기록 ${n}건',
	);

	/// ko: '이 파일 기록 모두 지우기'
	String get fileDelete => '이 파일 기록 모두 지우기';

	/// ko: '(other) {기록 $n건을 지울까요?}'
	String fileDeleteTitle({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(n,
		other: '기록 ${n}건을 지울까요?',
	);

	/// ko: '$file에서 가져온 기록을 모두 지웁니다. 설정의 삭제한 기록에서 되살릴 수 있습니다.'
	String fileDeleteBody({required Object file}) => '${file}에서 가져온 기록을 모두 지웁니다. 설정의 삭제한 기록에서 되살릴 수 있습니다.';

	/// ko: '삭제'
	String get fileDeleteConfirm => '삭제';

	/// ko: '취소'
	String get fileDeleteCancel => '취소';

	/// ko: '(other) {기록 $n건을 지웠습니다}'
	String fileDeleted({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(n,
		other: '기록 ${n}건을 지웠습니다',
	);
}

// Path: complete
class Translations$complete$ko {
	Translations$complete$ko._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// ko: 'noriori로 기록했습니다'
	String get credit => 'noriori로 기록했습니다';

	/// ko: '공유하기'
	String get share => '공유하기';

	/// ko: '닫기'
	String get close => '닫기';
}

// Path: collection
class Translations$collection$ko {
	Translations$collection$ko._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// ko: '수집'
	String get title => '수집';

	/// ko: '노선'
	String get lines => '노선';

	/// ko: '회사'
	String get operators => '회사';

	/// ko: '도도부현'
	String get prefs => '도도부현';

	/// ko: '역'
	String get stations => '역';

	/// ko: '역 $n곳'
	String stationGoal({required Object n}) => '역 ${n}곳';

	/// ko: '아직 없습니다'
	String get empty => '아직 없습니다';

	/// ko: '폐선'
	String get closed => '폐선';

	/// ko: '탄 구간 중 폐지된 곳이 없습니다'
	String get closedEmpty => '탄 구간 중 폐지된 곳이 없습니다';

	/// ko: '$year년 폐지'
	String closedYear({required Object year}) => '${year}년 폐지';

	/// ko: '(other) {탄 지 $n년 뒤}'
	String closedAfter({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(n,
		other: '탄 지 ${n}년 뒤',
	);

	/// ko: '(other) {이제는 탈 수 없는 구간 $n곳 · $km km}'
	String closedTotal({required num n, required Object km}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(n,
		other: '이제는 탈 수 없는 구간 ${n}곳 · ${km} km',
	);
}

// Path: visits
class Translations$visits$ko {
	Translations$visits$ko._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// ko: '방문 역'
	String get title => '방문 역';

	/// ko: '(other) {$n곳}'
	String count({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(n,
		other: '${n}곳',
	);

	/// ko: '현행 $open곳 · 폐역 $closed곳'
	String split({required Object open, required Object closed}) => '현행 ${open}곳 · 폐역 ${closed}곳';

	/// ko: '도도부현 $n / 47'
	String prefs({required Object n}) => '도도부현 ${n} / 47';

	/// ko: '(other) {도도부현을 모르는 역 $n곳}'
	String unknown({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(n,
		other: '도도부현을 모르는 역 ${n}곳',
	);

	/// ko: '아직 방문한 역이 없습니다'
	String get empty => '아직 방문한 역이 없습니다';
}

// Path: remaining
class Translations$remaining$ko {
	Translations$remaining$ko._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// ko: '남은 구간'
	String get title => '남은 구간';

	/// ko: '추천 보기'
	String get entry => '추천 보기';

	/// ko: '곧 완주'
	String get shortest => '곧 완주';

	/// ko: '가까운 곳'
	String get near => '가까운 곳';

	/// ko: '회사별'
	String get operators => '회사별';

	/// ko: '남은 구간이 없습니다'
	String get empty => '남은 구간이 없습니다';

	/// ko: '위치를 쓸 수 없습니다. 설정에서 위치 권한을 켜 주세요'
	String get nearDenied => '위치를 쓸 수 없습니다. 설정에서 위치 권한을 켜 주세요';

	/// ko: '$km km 안에 남은 구간이 없습니다'
	String nearNone({required Object km}) => '${km} km 안에 남은 구간이 없습니다';

	/// ko: '$km km'
	String nearAway({required Object km}) => '${km} km';
}

// Path: news
class Translations$news$ko {
	Translations$news$ko._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// ko: '철도망이 바뀌었습니다'
	String get title => '철도망이 바뀌었습니다';

	/// ko: '철도망 변경 내역'
	String get history => '철도망 변경 내역';

	/// ko: '확인'
	String get ok => '확인';

	/// ko: '$line $km km 개업'
	String lineOpened({required Object line, required Object km}) => '${line} ${km} km 개업';

	/// ko: '$line $km km 폐지'
	String lineClosed({required Object line, required Object km}) => '${line} ${km} km 폐지';

	/// ko: '$station역 개업 ($line)'
	String stationOpened({required Object station, required Object line}) => '${station}역 개업 (${line})';

	/// ko: '$station역 폐역 ($line)'
	String stationClosed({required Object station, required Object line}) => '${station}역 폐역 (${line})';

	/// ko: '(other) {그 밖에 $n건}'
	String more({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(n,
		other: '그 밖에 ${n}건',
	);

	/// ko: '$line $km km 개업. 완주가 풀렸습니다'
	String lineReopened({required Object line, required Object km}) => '${line} ${km} km 개업. 완주가 풀렸습니다';

	/// ko: '$line 기록 거리가 $before km에서 $after km로 바뀌었습니다'
	String rideDistance({required Object line, required Object before, required Object after}) => '${line} 기록 거리가 ${before} km에서 ${after} km로 바뀌었습니다';

	/// ko: '$line 기록을 확인해 주세요'
	String rideReview({required Object line}) => '${line} 기록을 확인해 주세요';
}

// Path: journey
class Translations$journey$ko {
	Translations$journey$ko._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// ko: '여러 노선 한 번에 기록'
	String get title => '여러 노선 한 번에 기록';

	/// ko: '출발역과 도착역을 고르면 경로를 찾아 노선마다 기록하고 여정으로 묶습니다'
	String get hint => '출발역과 도착역을 고르면 경로를 찾아 노선마다 기록하고 여정으로 묶습니다';

	/// ko: '출발'
	String get from => '출발';

	/// ko: '도착'
	String get to => '도착';

	/// ko: '고르기'
	String get choose => '고르기';

	/// ko: '기록하기'
	String get save => '기록하기';

	/// ko: '이어지는 경로를 찾지 못했습니다'
	String get none => '이어지는 경로를 찾지 못했습니다';

	/// ko: '역 이름'
	String get stationHint => '역 이름';

	/// ko: '(other) {기록 $n건을 저장했습니다}'
	String saved({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(n,
		other: '기록 ${n}건을 저장했습니다',
	);
}

// Path: years
class Translations$years$ko {
	Translations$years$ko._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// ko: '연도별'
	String get title => '연도별';

	/// ko: '활동'
	String get activity => '활동';

	/// ko: '거리'
	String get distance => '거리';

	/// ko: '기록 수'
	String get count => '기록 수';

	/// ko: '새 구간'
	String get fresh => '새 구간';

	/// ko: '가장 많이 탄 해'
	String get busiest => '가장 많이 탄 해';

	/// ko: '날짜 모름'
	String get undated => '날짜 모름';

	/// ko: '그래프와 캘린더에는 들지 않습니다'
	String get undatedHint => '그래프와 캘린더에는 들지 않습니다';

	/// ko: '날짜가 있는 기록이 없습니다'
	String get empty => '날짜가 있는 기록이 없습니다';

	/// ko: '색이 진할수록 많이 탄 날입니다'
	String get activityHint => '색이 진할수록 많이 탄 날입니다';

	/// ko: '기록 없음'
	String get noRides => '기록 없음';

	/// ko: '(other) {$n건}'
	String rides({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(n,
		other: '${n}건',
	);
}

// Path: trip
class Translations$trip$ko {
	Translations$trip$ko._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// ko: '여정으로 묶기'
	String get make => '여정으로 묶기';

	/// ko: '여정 이름'
	String get nameTitle => '여정 이름';

	/// ko: '간사이 여행'
	String get nameHint => '간사이 여행';

	/// ko: '저장'
	String get save => '저장';

	/// ko: '이름 바꾸기'
	String get rename => '이름 바꾸기';

	/// ko: '여정 풀기'
	String get dissolve => '여정 풀기';

	/// ko: '묶음만 없앱니다. 기록은 남습니다'
	String get dissolveHint => '묶음만 없앱니다. 기록은 남습니다';

	/// ko: '여정을 풀었습니다'
	String get dissolved => '여정을 풀었습니다';

	/// ko: '여정으로 묶었습니다'
	String get made => '여정으로 묶었습니다';

	/// ko: '여정이 없습니다'
	String get empty => '여정이 없습니다';

	/// ko: '탑승 기록을 길게 눌러 고른 뒤 여정으로 묶을 수 있습니다'
	String get emptyHint => '탑승 기록을 길게 눌러 고른 뒤 여정으로 묶을 수 있습니다';

	/// ko: '(other) {기록 $n건}'
	String rides({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(n,
		other: '기록 ${n}건',
	);

	/// ko: '여정과 기록 삭제'
	String get delete => '여정과 기록 삭제';

	/// ko: '여정에 묶인 기록까지 지웁니다. 5초 안에 되돌릴 수 있습니다'
	String get deleteHint => '여정에 묶인 기록까지 지웁니다. 5초 안에 되돌릴 수 있습니다';

	/// ko: '여정과 기록을 지웠습니다'
	String get deleted => '여정과 기록을 지웠습니다';
}

// Path: mapSheet
class Translations$mapSheet$ko {
	Translations$mapSheet$ko._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// ko: '이 역 너머 폐지 구간'
	String get beyond => '이 역 너머 폐지 구간';

	/// ko: '정확한 위치 모름'
	String get unlocated => '정확한 위치 모름';

	/// ko: '내 탑승 기록 $count건'
	String rideCount({required Object count}) => '내 탑승 기록 ${count}건';

	/// ko: '구간 보기'
	String get viewSection => '구간 보기';

	/// ko: '지도에 없음'
	String get unmapped => '지도에 없음';

	/// ko: '이 역에 가 봤음'
	String get visited => '이 역에 가 봤음';

	/// ko: '완주율에는 들지 않고 지도의 점만 칠합니다'
	String get visitedHint => '완주율에는 들지 않고 지도의 점만 칠합니다';

	/// ko: '역 방문 기록이 없습니다. 지도에서 역을 눌러 남길 수 있습니다'
	String get noVisits => '역 방문 기록이 없습니다. 지도에서 역을 눌러 남길 수 있습니다';

	/// ko: '이 자리를 지나는 노선'
	String get pickerLabel => '이 자리를 지나는 노선';

	/// ko: '이 구간 폐지'
	String get partlyClosed => '이 구간 폐지';

	/// ko: '폐선'
	String get closed => '폐선';
}

// Path: date
class Translations$date$ko {
	Translations$date$ko._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations
	List<String> get months => [
		'1',
		'2',
		'3',
		'4',
		'5',
		'6',
		'7',
		'8',
		'9',
		'10',
		'11',
		'12',
	];

	/// ko: '$year.$month.$day'
	String day({required Object year, required Object month, required Object day}) => '${year}.${month}.${day}';

	/// ko: '$year.$month'
	String month({required Object year, required Object month}) => '${year}.${month}';
}

// Path: record.status
class Translations$record$status$ko {
	Translations$record$status$ko._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// ko: '일부 구간만 반영'
	String get partial => '일부 구간만 반영';

	/// ko: '확인 필요'
	String get needsInput => '확인 필요';

	/// ko: '확인 필요'
	String get unknownRef => '확인 필요';

	/// ko: '확인 필요'
	String get invalid => '확인 필요';

	/// ko: '계산 실패'
	String get error => '계산 실패';
}

// Path: record.view
class Translations$record$view$ko {
	Translations$record$view$ko._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// ko: '노선'
	String get lines => '노선';

	/// ko: '탑승 기록'
	String get rides => '탑승 기록';

	/// ko: '역 방문'
	String get visits => '역 방문';

	/// ko: '여정'
	String get trips => '여정';
}

// Path: record.era
class Translations$record$era$ko {
	Translations$record$era$ko._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// ko: '현재'
	String get current => '현재';

	/// ko: '폐선'
	String get closed => '폐선';
}

// Path: record.category
class Translations$record$category$ko {
	Translations$record$category$ko._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// ko: 'JR'
	String get jr => 'JR';

	/// ko: '대형 사철'
	String get majorPrivate => '대형 사철';

	/// ko: '준대형 사철'
	String get semiMajorPrivate => '준대형 사철';

	/// ko: '공영'
	String get public => '공영';

	/// ko: '일반 사철'
	String get generalPrivate => '일반 사철';

	/// ko: '모노레일'
	String get monorail => '모노레일';

	/// ko: '경전철(AGT)'
	String get agt => '경전철(AGT)';

	/// ko: '케이블카'
	String get cable => '케이블카';
}

// Path: record.filter
class Translations$record$filter$ko {
	Translations$record$filter$ko._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// ko: '전체'
	String get all => '전체';

	/// ko: '일부 탄 노선'
	String get riding => '일부 탄 노선';

	/// ko: '안 탄 노선'
	String get unridden => '안 탄 노선';

	/// ko: '완주'
	String get complete => '완주';
}

// Path: stats.kpi
class Translations$stats$kpi$ko {
	Translations$stats$kpi$ko._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// ko: '탄 노선'
	String get lines => '탄 노선';

	/// ko: '완주'
	String get complete => '완주';

	/// ko: '지나간 역'
	String get stations => '지나간 역';

	/// ko: '탄 회사'
	String get operators => '탄 회사';
}

// Path: session.state
class Translations$session$state$ko {
	Translations$session$state$ko._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// ko: '?'
	String get maybe => '?';

	/// ko: '운휴'
	String get suspended => '운휴';

	/// ko: '휴무'
	String get offSeason => '휴무';

	/// ko: '운휴 $year~'
	String suspendedSince({required Object year}) => '운휴 ${year}~';

	/// ko: '~$year'
	String until({required Object year}) => '~${year}';

	/// ko: '$year~'
	String since({required Object year}) => '${year}~';

	/// ko: '$from~$to'
	String span({required Object from, required Object to}) => '${from}~${to}';
}

// Path: data.notice
class Translations$data$notice$ko {
	Translations$data$notice$ko._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// ko: '백업 폴더에 이 기기보다 새로운 기록이 있습니다. 복원해 주세요'
	String get needsMerge => '백업 폴더에 이 기기보다 새로운 기록이 있습니다. 복원해 주세요';

	/// ko: '자동 백업에 실패했습니다'
	String get failed => '자동 백업에 실패했습니다';

	/// ko: '백업 폴더를 다시 골라 주세요'
	String get folderLost => '백업 폴더를 다시 골라 주세요';

	/// ko: '백업 폴더에 읽지 못한 파일이 있습니다'
	String get unreadable => '백업 폴더에 읽지 못한 파일이 있습니다';

	/// ko: '바뀐 기록이 일주일 넘게 백업되지 않았습니다'
	String get stale => '바뀐 기록이 일주일 넘게 백업되지 않았습니다';

	/// ko: '백업 폴더를 골라 기록을 지켜 주세요'
	String get noFolder => '백업 폴더를 골라 기록을 지켜 주세요';
}

// Path: sources.n02
class Translations$sources$n02$ko {
	Translations$sources$n02$ko._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// ko: '国土数値情報 鉄道データ (N02)'
	String get name => '国土数値情報 鉄道データ (N02)';

	/// ko: '선로 모양, 역 좌표 교정'
	String get use => '선로 모양, 역 좌표 교정';

	/// ko: '국토교통성. 2020년 이후 판 CC BY 4.0, 그 전 판은 国土数値情報 이용 조건. 「国土数値情報（鉄道データ）」（国土交通省）を加工して作成。このデータは国土交通省が作成したものではありません。'
	String get terms => '국토교통성. 2020년 이후 판 CC BY 4.0, 그 전 판은 国土数値情報 이용 조건. 「国土数値情報（鉄道データ）」（国土交通省）を加工して作成。このデータは国土交通省が作成したものではありません。';
}

// Path: sources.n05
class Translations$sources$n05$ko {
	Translations$sources$n05$ko._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// ko: '国土数値情報 鉄道時系列データ (N05)'
	String get name => '国土数値情報 鉄道時系列データ (N05)';

	/// ko: 'N02와 OpenStreetMap에 없는 폐선 구간의 선로 모양'
	String get use => 'N02와 OpenStreetMap에 없는 폐선 구간의 선로 모양';

	/// ko: '국토교통성. 国土数値情報 이용 조건 (비상업). 「国土数値情報（鉄道時系列データ）」（国土交通省）を加工して作成。このデータは国土交通省が作成したものではありません。'
	String get terms => '국토교통성. 国土数値情報 이용 조건 (비상업). 「国土数値情報（鉄道時系列データ）」（国土交通省）を加工して作成。このデータは国土交通省が作成したものではありません。';
}

// Path: sources.n03
class Translations$sources$n03$ko {
	Translations$sources$n03$ko._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// ko: '국토수치정보 행정구역 (N03)'
	String get name => '국토수치정보 행정구역 (N03)';

	/// ko: '일본 윤곽과 도도부현 경계, 경계를 넘는 구간의 도도부현별 거리'
	String get use => '일본 윤곽과 도도부현 경계, 경계를 넘는 구간의 도도부현별 거리';

	/// ko: '「国土数値情報（行政区域データ）」（国土交通省）を加工して作成。このデータは国土交通省が作成したものではありません。'
	String get terms => '「国土数値情報（行政区域データ）」（国土交通省）を加工して作成。このデータは国土交通省が作成したものではありません。';
}

// Path: sources.gsi
class Translations$sources$gsi$ko {
	Translations$sources$gsi$ko._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// ko: '国土地理院 ベクトルタイル'
	String get name => '国土地理院 ベクトルタイル';

	/// ko: '田端信号場 일대 선로 모양 일부'
	String get use => '田端信号場 일대 선로 모양 일부';

	/// ko: '国土地理院コンテンツ利用規約 (CC BY 4.0 호환). 出典：国土地理院ベクトルタイル（鉄道中心線）を加工して作成'
	String get terms => '国土地理院コンテンツ利用規約 (CC BY 4.0 호환). 出典：国土地理院ベクトルタイル（鉄道中心線）を加工して作成';
}

// Path: sources.stationDatabase
class Translations$sources$stationDatabase$ko {
	Translations$sources$stationDatabase$ko._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// ko: 'station_database'
	String get name => 'station_database';

	/// ko: '역 목록과 좌표'
	String get use => '역 목록과 좌표';

	/// ko: 'Seo-4d696b75. CC BY-SA 4.0'
	String get terms => 'Seo-4d696b75. CC BY-SA 4.0';
}

// Path: sources.wikipedia
class Translations$sources$wikipedia$ko {
	Translations$sources$wikipedia$ko._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// ko: '일본어 위키백과'
	String get name => '일본어 위키백과';

	/// ko: '노선도, 연결, 폐선 이력, 일본어 읽는 법'
	String get use => '노선도, 연결, 폐선 이력, 일본어 읽는 법';

	/// ko: 'CC BY-SA 4.0'
	String get terms => 'CC BY-SA 4.0';
}

// Path: sources.wikidata
class Translations$sources$wikidata$ko {
	Translations$sources$wikidata$ko._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// ko: 'Wikidata'
	String get name => 'Wikidata';

	/// ko: '영어 이름, 일부 역 좌표'
	String get use => '영어 이름, 일부 역 좌표';

	/// ko: 'CC0 1.0'
	String get terms => 'CC0 1.0';
}

// Path: sources.namuwiki
class Translations$sources$namuwiki$ko {
	Translations$sources$namuwiki$ko._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// ko: '나무위키'
	String get name => '나무위키';

	/// ko: '한국어 표제어 표기. 본문은 쓰지 않음'
	String get use => '한국어 표제어 표기. 본문은 쓰지 않음';

	/// ko: '사이트 라이선스 CC BY-NC-SA 2.0 KR'
	String get terms => '사이트 라이선스 CC BY-NC-SA 2.0 KR';
}

// Path: sources.noritsubushi
class Translations$sources$noritsubushi$ko {
	Translations$sources$noritsubushi$ko._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// ko: '노리츠부시'
	String get name => '노리츠부시';

	/// ko: '영업거리, 역 순서, 기본 날짜, 일본어 표기'
	String get use => '영업거리, 역 순서, 기본 날짜, 일본어 표기';

	/// ko: '사실 정보로 사용'
	String get terms => '사실 정보로 사용';
}

// Path: sources.others
class Translations$sources$others$ko {
	Translations$sources$others$ko._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// ko: '그 밖의 사실 근거'
	String get name => '그 밖의 사실 근거';

	/// ko: '사업자 공식 자료(영어 역 이름 등), 公共交通オープンデータセンター, 국립국회도서관·국립공문서관 공개 자료, 日本郵便 우편번호 자료, 역명판 사진'
	String get use => '사업자 공식 자료(영어 역 이름 등), 公共交通オープンデータセンター, 국립국회도서관·국립공문서관 공개 자료, 日本郵便 우편번호 자료, 역명판 사진';

	/// ko: '사실 정보로 사용. 출처는 데이터 행마다 있고 전체 목록은 저장소의 data/NOTICE.md에 있습니다'
	String get terms => '사실 정보로 사용. 출처는 데이터 행마다 있고 전체 목록은 저장소의 data/NOTICE.md에 있습니다';
}

// Path: sources.openFreeMap
class Translations$sources$openFreeMap$ko {
	Translations$sources$openFreeMap$ko._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// ko: 'OpenFreeMap'
	String get name => 'OpenFreeMap';

	/// ko: '배경 지도'
	String get use => '배경 지도';

	/// ko: 'OpenFreeMap © OpenMapTiles. Data from OpenStreetMap'
	String get terms => 'OpenFreeMap © OpenMapTiles. Data from OpenStreetMap';
}

// Path: sources.openStreetMap
class Translations$sources$openStreetMap$ko {
	Translations$sources$openStreetMap$ko._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// ko: 'OpenStreetMap'
	String get name => 'OpenStreetMap';

	/// ko: 'N02에 없는 선로 모양'
	String get use => 'N02에 없는 선로 모양';

	/// ko: '© OpenStreetMap contributors. ODbL 1.0. rail-osm.pmtiles 파일에만 적용'
	String get terms => '© OpenStreetMap contributors. ODbL 1.0. rail-osm.pmtiles 파일에만 적용';
}

// Path: sources.noto
class Translations$sources$noto$ko {
	Translations$sources$noto$ko._(this._root);

	final Translations _root; // ignore: unused_field

	// Translations

	/// ko: 'Noto Sans, Noto Sans CJK'
	String get name => 'Noto Sans, Noto Sans CJK';

	/// ko: '지도의 역 이름 글자'
	String get use => '지도의 역 이름 글자';

	/// ko: 'SIL OFL 1.1. 전문은 오픈소스 라이선스 화면에 있습니다'
	String get terms => 'SIL OFL 1.1. 전문은 오픈소스 라이선스 화면에 있습니다';
}

/// The flat map containing all translations for locale <ko>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on Translations {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'app.name' => 'noriori',
			'app.loadFailed' => '불러오지 못했습니다. 앱을 다시 열어 주세요',
			'tabs.map' => '지도',
			'tabs.record' => '기록',
			'tabs.stats' => '통계',
			'tabs.settings' => '설정',
			'start.loading' => '준비하는 중',
			'start.updateTitle' => '앱을 업데이트해 주세요',
			'start.updateBody' => '기록이 이 앱보다 새로운 버전에서 저장되었습니다. 기록은 그대로 있습니다.',
			'start.retryTitle' => '기록을 열지 못했습니다',
			'start.retryBody' => '기록은 그대로 있습니다. 잠시 뒤 다시 시도해 주세요.',
			'start.restoreTitle' => '기록 파일이 손상되었습니다',
			'start.restoreBody' => '손상된 파일은 보관해 두었습니다. 백업 파일에서 복원할 수 있습니다.',
			'start.retry' => '다시 시도',
			'start.noSpaceTitle' => '저장 공간이 부족합니다',
			'start.noSpaceBody' => '기록은 그대로 있습니다. 공간을 확보한 뒤 다시 시도해 주세요.',
			'start.restoreAction' => '복원하기',
			'map.soloOff' => '모든 노선 보기',
			'map.add' => '기록',
			'map.search' => '노선이나 역 찾기',
			'map.closed' => '폐선',
			'map.names' => '역 이름',
			'map.wholeJapan' => '전국 보기',
			'map.firstRide' => '첫 탑승을 기록해 보세요',
			'map.firstRideHint' => '노선을 고르고 두 역만 누르면 됩니다',
			'map.left' => ({required Object km}) => '${km} km 남음',
			'map.continueTitle' => '이어서 타기',
			'map.onlyRidden' => '승차만',
			'map.sheetHandle' => '이어서 타기 목록 펼치기',
			'map.year' => '연도',
			'map.yearHint' => '그해까지 탄 구간만 파랗게 보입니다',
			'map.heat' => '도도부현',
			'record.viaService' => ({required Object name}) => '${name} 탑승',
			'record.empty' => '아직 기록이 없습니다',
			'record.emptyHint' => '노선별 목록이나 검색에서 첫 탑승을 기록해 보세요',
			'record.add' => '기록 추가',
			'record.dateUnknown' => '날짜 모름',
			'record.status.partial' => '일부 구간만 반영',
			'record.status.needsInput' => '확인 필요',
			'record.status.unknownRef' => '확인 필요',
			'record.status.invalid' => '확인 필요',
			'record.status.error' => '계산 실패',
			'record.deleted' => '기록을 삭제했습니다',
			'record.undo' => '되돌리기',
			'record.delete' => '삭제',
			'record.km' => ({required Object km}) => '${km} km',
			'record.view.lines' => '노선',
			'record.view.rides' => '탑승 기록',
			'record.view.visits' => '역 방문',
			'record.view.trips' => '여정',
			'record.era.current' => '현재',
			'record.era.closed' => '폐선',
			'record.category.jr' => 'JR',
			'record.category.majorPrivate' => '대형 사철',
			'record.category.semiMajorPrivate' => '준대형 사철',
			'record.category.public' => '공영',
			'record.category.generalPrivate' => '일반 사철',
			'record.category.monorail' => '모노레일',
			'record.category.agt' => '경전철(AGT)',
			'record.category.cable' => '케이블카',
			'record.title' => '기록',
			'record.currentLabel' => '현재 노선 전체',
			'record.closedLabel' => '폐지된 구간',
			'record.of' => ({required Object km}) => '${km} km 중',
			'record.lineCount' => ({required Object num, required Object den}) => '노선 ${num} / ${den}',
			'record.completeCount' => ({required Object num}) => '완주 ${num}',
			'record.filter.all' => '전체',
			'record.filter.riding' => '일부 탄 노선',
			'record.filter.unridden' => '안 탄 노선',
			'record.filter.complete' => '완주',
			'record.lineSub' => ({required Object era, required Object num, required Object den, required Object percent}) => '${era} · ${num} / ${den} km · ${percent}',
			'record.filterEmpty' => '해당하는 노선이 없습니다',
			'record.picked' => ({required Object count}) => '${count}건 선택',
			'record.pickAll' => '모두 선택',
			'stats.totalRidden' => ({required Object km}) => '누적 탑승 거리 ${km} km',
			'stats.empty' => '기록을 추가하면 완주율이 보입니다',
			'stats.current' => '현재 노선',
			'stats.allTime' => '폐선 포함',
			'stats.ridden' => ({required Object num, required Object den}) => '${num} / ${den} km',
			'stats.operators' => '회사',
			'stats.lines' => '노선',
			'stats.title' => '통계',
			'stats.year' => '연도',
			'stats.yearPick' => '연도 고르기',
			'stats.yearLabel' => ({required Object year}) => '${year}년',
			'stats.rodeOf' => ({required Object num, required Object den}) => '${num} / ${den} km',
			'stats.month' => ({required Object km}) => '이번 달 +${km} km',
			'stats.kpi.lines' => '탄 노선',
			'stats.kpi.complete' => '완주',
			'stats.kpi.stations' => '지나간 역',
			'stats.kpi.operators' => '탄 회사',
			'stats.nearly' => '곧 완주',
			'stats.left' => ({required Object km}) => '${km} km 남음',
			'stats.prefs' => '도도부현',
			'stats.prefHint' => '탄 비율',
			'stats.prefLabel' => ({required Object name, required Object percent}) => '${name} ${percent}',
			'stats.visited' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(n, other: '타고 내렸거나 들른 역 ${n}곳', ), 
			'stats.decade' => ({required Object year}) => '${year}년대',
			'stats.undecided' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(n, other: '판정 불가 ${n}구간', ), 
			'stats.review' => ({required num n, required Object km}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(n, other: '확인 필요 ${n}건 · ${km} km', ), 
			'stats.badges' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(n, other: '배지 ${n}개', ), 
			'stats.visitedClosed' => ({required Object n}) => '폐역 ${n}곳',
			'settings.version' => '앱 버전',
			'settings.dataEdition' => '데이터 버전',
			'settings.packSummary' => ({required Object stations, required Object lines}) => '역 ${stations}곳 · 노선 ${lines}개',
			'settings.data' => '백업과 복원',
			'settings.licenses' => '오픈소스 라이선스',
			'settings.sources' => '데이터 출처',
			'settings.showClosed' => '폐역·폐선 표시',
			'settings.showArchive' => '기록할 수 없는 옛 역·노선도 표시',
			'settings.showBranches' => '분기선 표시',
			'settings.theme' => '테마',
			'settings.themeLight' => '라이트',
			'settings.themeDark' => '다크',
			'settings.themeSystem' => '시스템 설정',
			'settings.language' => '언어',
			'settings.carryover' => '사업자 전환 시 기록 승계',
			'settings.carryoverHint' => '끄면 JR에서 넘어간 구간은 새 노선으로 따로 셉니다',
			'search.showOnMap' => '지도에서 보기',
			'search.hint' => '노선이나 역 이름',
			'search.prompt' => '노선이나 역을 찾아 시작하세요',
			'search.none' => '검색 결과가 없습니다',
			'search.archive' => '열람 전용',
			'session.laps' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(n, other: '${n}바퀴', ), 
			'session.lapLess' => '한 바퀴 줄이기',
			'session.lapMore' => '한 바퀴 늘리기',
			'session.foldStops' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(n, other: '${n}역', ), 
			'session.away' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(n, other: '+${n}역', ), 
			'session.dateTitle' => '탑승일',
			'session.dateHint' => '2015, 2015-03, 2015-03-14, 198X',
			'session.dateUnknown' => '날짜 모름',
			'session.dateUnknownHint' => '날짜 모름: 역은 모든 시기, 직통·환승은 마지막 상태로 보여요',
			'session.datePick' => '달력에서 고르기',
			'session.dateToday' => '오늘',
			'session.dateBad' => '날짜 형식을 확인해 주세요',
			'session.apply' => '적용',
			'session.cancel' => '취소',
			'session.main' => '본선',
			'session.pickFrom' => '출발역을 고르세요',
			'session.tempTag' => '임시',
			'session.tempNotice' => '정기 여객 열차 미운행 구간(임시 열차 운행일만 기록 가능)',
			'session.tempPickDay' => '임시 열차 운행일을 고르세요',
			'session.tempNoRun' => '이 날짜에는 임시 열차가 다니지 않았습니다. 위의 운행일을 눌러 보세요',
			'session.pickTo' => '도착역을 고르세요',
			'session.save' => '기록하기',
			'session.summary' => ({required Object from, required Object to, required Object km}) => '${from} → ${to} · ${km} km',
			'session.noPath' => '이 두 역 사이의 경로를 찾지 못했습니다',
			'session.state.maybe' => '?',
			'session.state.suspended' => '운휴',
			'session.state.offSeason' => '휴무',
			'session.state.suspendedSince' => ({required Object year}) => '운휴 ${year}~',
			'session.state.until' => ({required Object year}) => '~${year}',
			'session.state.since' => ({required Object year}) => '${year}~',
			'session.state.span' => ({required Object from, required Object to}) => '${from}~${to}',
			'session.savedAs' => ({required Object line}) => '탑승일 기준 ${line} 구간',
			'session.movedTo' => ({required Object year, required Object name}) => '${year}년 ${name} 이전',
			'session.handSince' => ({required Object date, required Object line}) => '${date}부터 ${line}',
			'session.handOpen' => '노선 보기 ›',
			'session.handNote' => '이 구간은 그 노선으로 기록돼요',
			'session.noticeClosedSub' => '그 전 날짜로만 기록할 수 있어요',
			'session.noticeSuspendedSub' => '운휴 전 날짜로만 기록할 수 있어요',
			'session.noticeSeasonSub' => ({required Object from, required Object to}) => '보통 ${from}월~${to}월에만 다녀요. 이 날은 운행하지 않아요',
			'session.noticeSeasonAnySub' => ({required Object from, required Object to}) => '보통 ${from}월~${to}월에만 다녀요',
			'session.noticeBeforeSub' => '개업한 뒤 날짜로 기록할 수 있어요',
			'session.chooseDirection' => '어느 쪽으로 탔나요?',
			'session.directionKm' => ({required Object km}) => '${km} km',
			'session.chooseRelocation' => '어느 시기의 선로였나요?',
			'session.relocationOption' => ({required Object date, required Object km}) => '${date} 기준 · ${km} km',
			'session.dontKnow' => '모르겠음',
			'session.today' => '오늘',
			'session.findStop' => '역 찾기',
			'session.meta' => ({required Object operator, required Object km}) => '${operator} · ${km}',
			'session.fresh' => ({required Object km}) => '새로 타는 구간 ${km} km',
			'session.noFresh' => '이미 탄 구간입니다',
			'session.change' => ({required Object before, required Object after}) => '${before} → ${after}',
			'session.nonePickable' => '이 날짜에 고를 수 있는 역이 없습니다. 탑승일을 바꿔 보세요',
			'session.maybeHint' => '이 날짜에 운행했는지 확인되지 않았습니다',
			'session.saveFailed' => '저장하지 못했습니다. 기록은 바뀌지 않았습니다',
			'session.spokenKm' => ({required Object km}) => '${km}킬로미터',
			'session.spokenTransfer' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(n, other: '환승 ${n}개', ), 
			'session.spokenFrom' => '출발역으로 선택됨',
			'session.spokenTo' => '도착역으로 선택됨',
			'session.showClosed' => '폐역·폐선 표시',
			'session.showArchive' => '기록할 수 없는 옛 역·노선도 표시',
			'session.clear' => '선택 해제',
			'session.lap' => '한 바퀴',
			'session.stops' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(n, other: '${n}개 역', ), 
			'session.closedSection' => ({required Object year}) => '~${year} 폐지',
			'session.openedSection' => ({required Object year}) => '${year}년 개업',
			'session.archiveStop' => ({required Object name, required Object year}) => '${name}: 폐역(${year}). 기록할 수 없는 옛 역입니다',
			'session.archiveStopNow' => ({required Object name, required Object year, required Object now}) => '${name}: 폐역(${year}). 기록할 수 없는 옛 역입니다. 지금의 ${now}역 자리',
			'session.archiveStopNoYear' => ({required Object name}) => '${name}: 폐역. 기록할 수 없는 옛 역입니다',
			'session.archiveStopNowNoYear' => ({required Object name, required Object now}) => '${name}: 폐역. 기록할 수 없는 옛 역입니다. 지금의 ${now}역 자리',
			'session.archiveLine' => ({required Object name}) => '${name}: 기록할 수 없는 옛 노선입니다',
			'session.from' => '출발',
			'session.to' => '도착',
			'session.whyClosed' => '그 날짜에는 운영하지 않던 역입니다',
			'session.whyViewSignal' => '신호장·분기점이라 여기서 기록을 시작하거나 끝낼 수 없어요',
			'session.whyViewNoBoarding' => '이 노선은 이 역에 서지 않아 여기서 기록을 시작하거나 끝낼 수 없어요',
			'session.whyViewStaff' => '승객을 받지 않는 역이라 여기서 기록을 시작하거나 끝낼 수 없어요',
			'session.onlyDown' => '하행만',
			'session.onlyUp' => '상행만',
			'session.onlyOneWay' => '한 방향만',
			'session.spokenOnlyDown' => '하행 열차만 정차',
			'session.spokenOnlyUp' => '상행 열차만 정차',
			'session.spokenOnlyOneWay' => '한 방향 열차만 정차',
			'session.stopDownTitle' => ({required Object name}) => '${name}에는 하행 열차만 서요',
			'session.stopUpTitle' => ({required Object name}) => '${name}에는 상행 열차만 서요',
			'session.stopOneWayTitle' => ({required Object name}) => '${name}에는 한 방향 열차만 서요',
			'session.towardOnly' => ({required Object name}) => '${name} 방면으로만 탈 수 있어요',
			'session.sectionTitle' => '한 방향으로만 다니는 구간이에요',
			'session.sectionDetail' => '이 방향으로는 열차가 다니지 않아요',
			'session.aroundTitle' => '한 방향으로만 도는 구간이에요',
			'session.aroundDetail' => ({required Object km}) => '돌아가는 길 ${km} km로 셉니다',
			'session.reverse' => '방향 바꾸기',
			'session.onlyAlight' => '하차전용',
			'session.alightTitle' => '하차전용 역이에요',
			'session.alightDetail' => '도착역으로만 고를 수 있어요',
			'session.whySuspended' => '그 날짜에는 운행이 중단된 구간입니다',
			'session.bound' => ({required Object names}) => '${names} 방면',
			'session.spokenClosed' => ({required Object year}) => '${year}년 폐지',
			'session.spokenSuspendedSince' => ({required Object year}) => '${year}년부터 운휴',
			'session.pastKari' => '가',
			'session.pastRinji' => '임',
			'session.spokenPastKari' => '예전 가승강장',
			'session.spokenPastRinji' => '예전 임시역',
			'session.spokenBranch' => ({required Object line, required Object next}) => '${line}, ${next} 분기',
			'session.reverseNow' => ({required Object line}) => '이 역에서 진행 방향을 바꿔 ${line} 직통합니다',
			'session.reverseUsed' => ({required Object line}) => '이 역에서 진행 방향을 바꿔 ${line} 직통하는 열차가 있었습니다',
			'session.spokenReverse' => '방향 바꿈',
			'session.leaving' => ({required Object name}) => '${name}에서 출발',
			'session.progress' => ({required Object num, required Object den, required Object percent}) => '${num} / ${den} km (${percent})',
			'session.leaveTitle' => '고른 역이 사라집니다',
			'session.leaveBody' => '다른 노선으로 넘어가면 지금 고른 역은 지워집니다.',
			'session.leave' => '넘어가기',
			'session.unridableTitle' => '그 날짜에는 탈 수 없는 구간입니다',
			'session.unridableSave' => '폐지 뒤나 개업 전, 운휴 중이었거나 고른 역에 열차가 서지 않던 날입니다. 기록하지 않았습니다.',
			'session.unridableDate' => '폐지 뒤나 개업 전, 운휴 중이었거나 고른 역에 열차가 서지 않던 날입니다. 탑승일은 그대로 둡니다.',
			'session.unridableOk' => '확인',
			'session.repick' => '다른 역을 누르면 처음부터 다시 고릅니다',
			'session.closedUnknown' => '폐지 구간',
			'session.suspendedSection' => '운휴 중',
			'session.seasonSection' => '계절 운행',
			'session.relocationOld' => ({required Object km}) => '옛 선로 · ${km} km',
			'session.relocationNew' => ({required Object km}) => '새 선로 · ${km} km',
			'session.spokenOpen' => '영업 중',
			'session.spokenPassing' => '승하차 불가',
			'session.spokenRidden' => '탄 역',
			'data.osBackupLarge' => '기록 파일이 20MB를 넘어 Android 클라우드 백업에 들어가지 않을 수 있어요. 백업 폴더를 골라 두세요',
			'data.title' => '백업과 복원',
			'data.folder' => '백업 폴더',
			'data.folderHint' => '앱을 지워도 남는 곳을 고르세요',
			'data.folderNone' => '고르지 않음',
			'data.insideApp' => '앱을 지우면 함께 사라지는 위치입니다. 다른 폴더를 골라 주세요',
			'data.lastBackup' => '마지막 백업',
			'data.never' => '없음',
			'data.lastFailed' => '마지막 백업에 실패했습니다',
			'data.backupNow' => '지금 백업',
			'data.restore' => '복원',
			'data.restoreHint' => '백업 파일을 지금 기록에 합칩니다. 같은 기록은 더 늦게 고친 쪽이 남으므로 새 기록이 사라지지 않습니다.',
			'data.noFiles' => '이 폴더에 백업 파일이 없습니다',
			'data.fileRows' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(n, other: '기록 ${n}건', ), 
			'data.fileTooNew' => '앱을 업데이트해야 읽을 수 있습니다',
			'data.fileUnreadable' => '읽을 수 없는 파일입니다',
			'data.merged' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(n, other: '${n}건을 복원했습니다', ), 
			'data.refused' => '이 파일은 복원할 수 없습니다',
			'data.exportQuarantined' => '손상된 파일 내보내기',
			'data.exportHint' => '백업 폴더에 사본을 저장합니다',
			'data.exported' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(n, other: '파일 ${n}개를 내보냈습니다', ), 
			'data.finish' => '복원을 마치고 시작',
			'data.notice.needsMerge' => '백업 폴더에 이 기기보다 새로운 기록이 있습니다. 복원해 주세요',
			'data.notice.failed' => '자동 백업에 실패했습니다',
			'data.notice.folderLost' => '백업 폴더를 다시 골라 주세요',
			'data.notice.unreadable' => '백업 폴더에 읽지 못한 파일이 있습니다',
			'data.notice.stale' => '바뀐 기록이 일주일 넘게 백업되지 않았습니다',
			'data.notice.noFolder' => '백업 폴더를 골라 기록을 지켜 주세요',
			'data.exportCompat' => 'CSV 내보내기 (노리츠부시 호환)',
			'data.exportCompatHint' => '노리츠부시와 같은 형식으로 보냅니다',
			'data.exportFull' => 'CSV 내보내기 (전체)',
			'data.exportFullHint' => '경로와 날짜까지 담아 보냅니다',
			'data.exportedUtf8' => ({required Object name}) => '일본어 CSV 형식에 없는 글자가 있어 UTF-8로 저장했습니다: ${name}',
			'data.exportFailed' => '내보내지 못했습니다',
			'data.exportBackup' => '백업 파일 내보내기',
			'data.exportBackupHint' => '지금 기록을 파일 하나로 만들어 보냅니다',
			'data.restoreFile' => '파일에서 복원',
			'data.restoreFileHint' => '내보낸 백업 파일을 직접 고릅니다',
			'importing.title' => '노리츠부시 기록 가져오기',
			'importing.entryHint' => '내려받은 CSV를 지금 기록에 더합니다',
			'importing.hint' => '노리츠부시의 기록 편집 화면 아래에서 내려받은 CSV 파일을 고르세요. 일반판과 코멘트판 모두 됩니다.',
			'importing.choose' => '파일 고르기',
			'importing.refused' => ({required Object name}) => '노리츠부시 CSV가 아닙니다: ${name}. 다른 파일을 골라 주세요.',
			'importing.failed' => '가져오지 못했습니다. 기록은 바뀌지 않았습니다.',
			'importing.undone' => '되돌렸습니다. 지운 기록은 다시 가져올 때 고를 수 있습니다.',
			'importing.file' => '파일',
			'importing.fresh' => '새 기록',
			'importing.rows' => ({required Object count}) => '${count}건',
			'importing.distance' => '기록 거리 합계',
			'importing.existing' => '이미 있는 기록',
			'importing.deleted' => '삭제했던 기록도 다시 넣기',
			'importing.missed' => ({required num n, required Object count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(n, other: '노선을 찾지 못한 행 ${count}건', ), 
			'importing.missedHint' => '기록으로 남기지만 완주율에는 들지 않습니다',
			'importing.broken' => ({required num n, required Object count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(n, other: '읽지 못한 행 ${count}건', ), 
			'importing.brokenHint' => '형식이 맞지 않아 가져오지 않습니다',
			'importing.kmDiffers' => ({required num n, required Object count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(n, other: '거리가 다른 행 ${count}건', ), 
			'importing.kmDiffersHint' => '파일의 거리와 앱의 거리가 다릅니다',
			'importing.kmDiffersRow' => ({required Object raw, required Object km}) => '${raw} → 앱 ${km} km',
			'importing.nothing' => '새로 가져올 기록이 없습니다',
			'importing.confirm' => ({required num n, required Object count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(n, other: '${count}건 가져오기', ), 
			'importing.done' => ({required num n, required Object count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(n, other: '${count}건을 가져왔습니다', ), 
			'importing.undated' => ({required num n, required Object count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(n, other: '날짜 모름으로 넣은 행 ${count}건', ), 
			'importing.close' => '닫기',
			'importing.undo' => '되돌리기',
			'importing.fullHint' => ({required Object count}) => 'noriori 전체 내보내기 파일입니다. 기록 ${count}건 중 없는 것만 더합니다.',
			'importing.merged' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(n, other: '${n}건을 더했습니다', ), 
			'ticket.completeStamp' => '完乗',
			'ticket.rideStamp' => '乗車',
			'ticket.undo' => '되돌리기',
			'ticket.noDate' => '날짜 모름',
			'sources.title' => '데이터 출처',
			'sources.intro' => '이름, 거리, 날짜 같은 사실 정보를 여러 출처에서 모아 만들었습니다. noriori 데이터는 CC BY-SA 4.0으로 배포합니다. 선로 모양은 아래 원 자료의 조건을 따르고, OSM 선로 파일만 ODbL 1.0입니다.',
			'sources.n02.name' => '国土数値情報 鉄道データ (N02)',
			'sources.n02.use' => '선로 모양, 역 좌표 교정',
			'sources.n02.terms' => '국토교통성. 2020년 이후 판 CC BY 4.0, 그 전 판은 国土数値情報 이용 조건. 「国土数値情報（鉄道データ）」（国土交通省）を加工して作成。このデータは国土交通省が作成したものではありません。',
			'sources.n05.name' => '国土数値情報 鉄道時系列データ (N05)',
			'sources.n05.use' => 'N02와 OpenStreetMap에 없는 폐선 구간의 선로 모양',
			'sources.n05.terms' => '국토교통성. 国土数値情報 이용 조건 (비상업). 「国土数値情報（鉄道時系列データ）」（国土交通省）を加工して作成。このデータは国土交通省が作成したものではありません。',
			'sources.n03.name' => '국토수치정보 행정구역 (N03)',
			'sources.n03.use' => '일본 윤곽과 도도부현 경계, 경계를 넘는 구간의 도도부현별 거리',
			'sources.n03.terms' => '「国土数値情報（行政区域データ）」（国土交通省）を加工して作成。このデータは国土交通省が作成したものではありません。',
			'sources.gsi.name' => '国土地理院 ベクトルタイル',
			'sources.gsi.use' => '田端信号場 일대 선로 모양 일부',
			'sources.gsi.terms' => '国土地理院コンテンツ利用規約 (CC BY 4.0 호환). 出典：国土地理院ベクトルタイル（鉄道中心線）を加工して作成',
			'sources.stationDatabase.name' => 'station_database',
			'sources.stationDatabase.use' => '역 목록과 좌표',
			'sources.stationDatabase.terms' => 'Seo-4d696b75. CC BY-SA 4.0',
			'sources.wikipedia.name' => '일본어 위키백과',
			'sources.wikipedia.use' => '노선도, 연결, 폐선 이력, 일본어 읽는 법',
			'sources.wikipedia.terms' => 'CC BY-SA 4.0',
			'sources.wikidata.name' => 'Wikidata',
			'sources.wikidata.use' => '영어 이름, 일부 역 좌표',
			'sources.wikidata.terms' => 'CC0 1.0',
			'sources.namuwiki.name' => '나무위키',
			'sources.namuwiki.use' => '한국어 표제어 표기. 본문은 쓰지 않음',
			'sources.namuwiki.terms' => '사이트 라이선스 CC BY-NC-SA 2.0 KR',
			'sources.noritsubushi.name' => '노리츠부시',
			'sources.noritsubushi.use' => '영업거리, 역 순서, 기본 날짜, 일본어 표기',
			'sources.noritsubushi.terms' => '사실 정보로 사용',
			'sources.others.name' => '그 밖의 사실 근거',
			'sources.others.use' => '사업자 공식 자료(영어 역 이름 등), 公共交通オープンデータセンター, 국립국회도서관·국립공문서관 공개 자료, 日本郵便 우편번호 자료, 역명판 사진',
			'sources.others.terms' => '사실 정보로 사용. 출처는 데이터 행마다 있고 전체 목록은 저장소의 data/NOTICE.md에 있습니다',
			'sources.openFreeMap.name' => 'OpenFreeMap',
			'sources.openFreeMap.use' => '배경 지도',
			'sources.openFreeMap.terms' => 'OpenFreeMap © OpenMapTiles. Data from OpenStreetMap',
			'sources.openStreetMap.name' => 'OpenStreetMap',
			'sources.openStreetMap.use' => 'N02에 없는 선로 모양',
			'sources.openStreetMap.terms' => '© OpenStreetMap contributors. ODbL 1.0. rail-osm.pmtiles 파일에만 적용',
			'sources.noto.name' => 'Noto Sans, Noto Sans CJK',
			'sources.noto.use' => '지도의 역 이름 글자',
			'sources.noto.terms' => 'SIL OFL 1.1. 전문은 오픈소스 라이선스 화면에 있습니다',
			'editRide.saved' => '고쳤습니다',
			'editRide.transfers' => '갈아탄 역',
			'editRide.transfersHint' => '지나간 역 중 내려서 갈아탄 역을 고릅니다',
			'editRide.title' => '기록 수정',
			'editRide.missing' => '기록을 찾지 못했습니다',
			'editRide.date' => '탑승일',
			'editRide.times' => '시각',
			'editRide.train' => '열차명',
			'editRide.car' => '차량 편성',
			'editRide.note' => '메모',
			'editRide.fromAlighted' => '출발역에서 실제로 탔음',
			'editRide.toAlighted' => '도착역에서 실제로 내렸음',
			'editRide.save' => '저장',
			'editRide.delete' => '삭제',
			'editRide.unridable' => '폐지 뒤나 개업 전, 운휴 중이었거나 기록한 역에 열차가 서지 않던 날입니다. 기록은 바뀌지 않았습니다.',
			'editRide.failed' => '저장하지 못했습니다. 기록은 바뀌지 않았습니다',
			'lineDetail.soloMap' => '지도에서 이 노선만 보기',
			'lineDetail.current' => '현재 구간',
			'lineDetail.allTime' => '폐지 구간 포함',
			'lineDetail.km' => ({required Object num, required Object den}) => '${num} / ${den} km',
			'lineDetail.completeCurrent' => '현재 구간 완주',
			'lineDetail.selfScore' => '전체 통계에 들어가지 않는 노선입니다. 이 노선의 거리만으로 진행률을 셉니다',
			'lineDetail.open' => '노선 상세',
			'lineDetail.record' => '이 노선 기록하기',
			'lineDetail.clear' => '이 노선 탑승 기록 모두 지우기',
			'lineDetail.hint' => '구간을 누르면 탑승 표시가 바뀝니다. 길게 누른 뒤 끌면 여러 구간을 한 번에 바꿉니다. 역을 나타내는 점을 누르면 방문 표시가 바뀝니다',
			'lineDetail.sectionRidden' => ({required Object from, required Object to}) => '${from}에서 ${to}까지, 탄 구간. 누르면 탑승 표시를 지웁니다',
			'lineDetail.sectionOpen' => ({required Object from, required Object to}) => '${from}에서 ${to}까지, 안 탄 구간. 누르면 탑승으로 표시합니다',
			'lineDetail.stopNode' => ({required Object name}) => '${name} 방문 표시 바꾸기',
			'lineDetail.turnedOff' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(n, other: '기록 ${n}건을 고쳤습니다', ), 
			'lineDetail.turnedOn' => '탑승으로 표시했습니다',
			'lineDetail.restored' => '지운 기록을 되살렸습니다',
			'lineDetail.blockedHidden' => '역이 아닌 지점에서 기록을 나눠야 해서 여기서는 지울 수 없습니다. 기록을 직접 고쳐 주세요',
			'lineDetail.blockedPath' => '이 구간을 빼면 남은 기록의 경로나 날짜가 달라져서 지울 수 없습니다. 기록을 직접 고쳐 주세요',
			'lineDetail.blockedNoStop' => '이 방향 열차가 서지 않는 역에서 기록을 나눠야 해서 여기서는 지울 수 없습니다. 기록을 직접 고쳐 주세요',
			'lineDetail.blockedOn' => '이 구간은 여기서 탑승으로 표시할 수 없습니다. 출발역과 도착역을 골라 기록해 주세요',
			'lineDetail.visitAdded' => '방문으로 표시했습니다',
			'lineDetail.visitRemoved' => '방문을 지웠습니다',
			'lineDetail.visitByRide' => '타고 내린 기록으로 표시된 역입니다. 표시를 지우려면 기록을 고쳐 주세요',
			'lineDetail.undo' => '되돌리기',
			'lineDetail.joinsTo' => ({required Object name}) => '${name} →',
			'lineDetail.visitDated' => '방문일을 바꿨습니다',
			'service.kind' => '운행 계통',
			'service.none' => '그 날짜에 운행하지 않던 운행 계통입니다',
			'service.save' => '기록하기',
			'service.failed' => '이 구간은 기록할 수 없습니다. 날짜를 확인해 주세요',
			'deleted.fileOldest' => '예전에 가져온 기록',
			'deleted.title' => '삭제한 기록',
			'deleted.empty' => '삭제한 기록이 없습니다',
			'deleted.restore' => '되살리기',
			'deleted.restored' => '기록을 되살렸습니다',
			'deleted.fileRides' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(n, other: '기록 ${n}건', ), 
			'deleted.fileDelete' => '이 파일 기록 모두 지우기',
			'deleted.fileDeleteTitle' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(n, other: '기록 ${n}건을 지울까요?', ), 
			'deleted.fileDeleteBody' => ({required Object file}) => '${file}에서 가져온 기록을 모두 지웁니다. 설정의 삭제한 기록에서 되살릴 수 있습니다.',
			'deleted.fileDeleteConfirm' => '삭제',
			'deleted.fileDeleteCancel' => '취소',
			'deleted.fileDeleted' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(n, other: '기록 ${n}건을 지웠습니다', ), 
			'complete.credit' => 'noriori로 기록했습니다',
			'complete.share' => '공유하기',
			'complete.close' => '닫기',
			'collection.title' => '수집',
			'collection.lines' => '노선',
			'collection.operators' => '회사',
			'collection.prefs' => '도도부현',
			'collection.stations' => '역',
			'collection.stationGoal' => ({required Object n}) => '역 ${n}곳',
			'collection.empty' => '아직 없습니다',
			'collection.closed' => '폐선',
			'collection.closedEmpty' => '탄 구간 중 폐지된 곳이 없습니다',
			'collection.closedYear' => ({required Object year}) => '${year}년 폐지',
			'collection.closedAfter' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(n, other: '탄 지 ${n}년 뒤', ), 
			'collection.closedTotal' => ({required num n, required Object km}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(n, other: '이제는 탈 수 없는 구간 ${n}곳 · ${km} km', ), 
			'visits.title' => '방문 역',
			'visits.count' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(n, other: '${n}곳', ), 
			'visits.split' => ({required Object open, required Object closed}) => '현행 ${open}곳 · 폐역 ${closed}곳',
			'visits.prefs' => ({required Object n}) => '도도부현 ${n} / 47',
			'visits.unknown' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(n, other: '도도부현을 모르는 역 ${n}곳', ), 
			'visits.empty' => '아직 방문한 역이 없습니다',
			'remaining.title' => '남은 구간',
			'remaining.entry' => '추천 보기',
			'remaining.shortest' => '곧 완주',
			'remaining.near' => '가까운 곳',
			'remaining.operators' => '회사별',
			'remaining.empty' => '남은 구간이 없습니다',
			'remaining.nearDenied' => '위치를 쓸 수 없습니다. 설정에서 위치 권한을 켜 주세요',
			'remaining.nearNone' => ({required Object km}) => '${km} km 안에 남은 구간이 없습니다',
			'remaining.nearAway' => ({required Object km}) => '${km} km',
			'news.title' => '철도망이 바뀌었습니다',
			'news.history' => '철도망 변경 내역',
			'news.ok' => '확인',
			'news.lineOpened' => ({required Object line, required Object km}) => '${line} ${km} km 개업',
			'news.lineClosed' => ({required Object line, required Object km}) => '${line} ${km} km 폐지',
			'news.stationOpened' => ({required Object station, required Object line}) => '${station}역 개업 (${line})',
			'news.stationClosed' => ({required Object station, required Object line}) => '${station}역 폐역 (${line})',
			'news.more' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(n, other: '그 밖에 ${n}건', ), 
			'news.lineReopened' => ({required Object line, required Object km}) => '${line} ${km} km 개업. 완주가 풀렸습니다',
			'news.rideDistance' => ({required Object line, required Object before, required Object after}) => '${line} 기록 거리가 ${before} km에서 ${after} km로 바뀌었습니다',
			'news.rideReview' => ({required Object line}) => '${line} 기록을 확인해 주세요',
			'journey.title' => '여러 노선 한 번에 기록',
			'journey.hint' => '출발역과 도착역을 고르면 경로를 찾아 노선마다 기록하고 여정으로 묶습니다',
			'journey.from' => '출발',
			'journey.to' => '도착',
			'journey.choose' => '고르기',
			'journey.save' => '기록하기',
			'journey.none' => '이어지는 경로를 찾지 못했습니다',
			'journey.stationHint' => '역 이름',
			'journey.saved' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(n, other: '기록 ${n}건을 저장했습니다', ), 
			'years.title' => '연도별',
			'years.activity' => '활동',
			'years.distance' => '거리',
			'years.count' => '기록 수',
			'years.fresh' => '새 구간',
			'years.busiest' => '가장 많이 탄 해',
			'years.undated' => '날짜 모름',
			'years.undatedHint' => '그래프와 캘린더에는 들지 않습니다',
			'years.empty' => '날짜가 있는 기록이 없습니다',
			'years.activityHint' => '색이 진할수록 많이 탄 날입니다',
			'years.noRides' => '기록 없음',
			'years.rides' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(n, other: '${n}건', ), 
			'trip.make' => '여정으로 묶기',
			'trip.nameTitle' => '여정 이름',
			'trip.nameHint' => '간사이 여행',
			'trip.save' => '저장',
			'trip.rename' => '이름 바꾸기',
			'trip.dissolve' => '여정 풀기',
			'trip.dissolveHint' => '묶음만 없앱니다. 기록은 남습니다',
			'trip.dissolved' => '여정을 풀었습니다',
			'trip.made' => '여정으로 묶었습니다',
			'trip.empty' => '여정이 없습니다',
			'trip.emptyHint' => '탑승 기록을 길게 눌러 고른 뒤 여정으로 묶을 수 있습니다',
			'trip.rides' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ko'))(n, other: '기록 ${n}건', ), 
			'trip.delete' => '여정과 기록 삭제',
			'trip.deleteHint' => '여정에 묶인 기록까지 지웁니다. 5초 안에 되돌릴 수 있습니다',
			'trip.deleted' => '여정과 기록을 지웠습니다',
			'mapSheet.beyond' => '이 역 너머 폐지 구간',
			'mapSheet.unlocated' => '정확한 위치 모름',
			'mapSheet.rideCount' => ({required Object count}) => '내 탑승 기록 ${count}건',
			'mapSheet.viewSection' => '구간 보기',
			'mapSheet.unmapped' => '지도에 없음',
			'mapSheet.visited' => '이 역에 가 봤음',
			'mapSheet.visitedHint' => '완주율에는 들지 않고 지도의 점만 칠합니다',
			'mapSheet.noVisits' => '역 방문 기록이 없습니다. 지도에서 역을 눌러 남길 수 있습니다',
			'mapSheet.pickerLabel' => '이 자리를 지나는 노선',
			'mapSheet.partlyClosed' => '이 구간 폐지',
			'mapSheet.closed' => '폐선',
			'prefNames.0' => '홋카이도',
			'prefNames.1' => '아오모리',
			'prefNames.2' => '이와테',
			'prefNames.3' => '미야기',
			'prefNames.4' => '아키타',
			'prefNames.5' => '야마가타',
			'prefNames.6' => '후쿠시마',
			_ => null,
		} ?? switch (path) {
			'prefNames.7' => '이바라키',
			'prefNames.8' => '도치기',
			'prefNames.9' => '군마',
			'prefNames.10' => '사이타마',
			'prefNames.11' => '치바',
			'prefNames.12' => '도쿄',
			'prefNames.13' => '가나가와',
			'prefNames.14' => '니가타',
			'prefNames.15' => '도야마',
			'prefNames.16' => '이시카와',
			'prefNames.17' => '후쿠이',
			'prefNames.18' => '야마나시',
			'prefNames.19' => '나가노',
			'prefNames.20' => '기후',
			'prefNames.21' => '시즈오카',
			'prefNames.22' => '아이치',
			'prefNames.23' => '미에',
			'prefNames.24' => '시가',
			'prefNames.25' => '교토',
			'prefNames.26' => '오사카',
			'prefNames.27' => '효고',
			'prefNames.28' => '나라',
			'prefNames.29' => '와카야마',
			'prefNames.30' => '돗토리',
			'prefNames.31' => '시마네',
			'prefNames.32' => '오카야마',
			'prefNames.33' => '히로시마',
			'prefNames.34' => '야마구치',
			'prefNames.35' => '도쿠시마',
			'prefNames.36' => '카가와',
			'prefNames.37' => '에히메',
			'prefNames.38' => '고치',
			'prefNames.39' => '후쿠오카',
			'prefNames.40' => '사가',
			'prefNames.41' => '나가사키',
			'prefNames.42' => '구마모토',
			'prefNames.43' => '오이타',
			'prefNames.44' => '미야자키',
			'prefNames.45' => '가고시마',
			'prefNames.46' => '오키나와',
			'date.months.0' => '1',
			'date.months.1' => '2',
			'date.months.2' => '3',
			'date.months.3' => '4',
			'date.months.4' => '5',
			'date.months.5' => '6',
			'date.months.6' => '7',
			'date.months.7' => '8',
			'date.months.8' => '9',
			'date.months.9' => '10',
			'date.months.10' => '11',
			'date.months.11' => '12',
			'date.day' => ({required Object year, required Object month, required Object day}) => '${year}.${month}.${day}',
			'date.month' => ({required Object year, required Object month}) => '${year}.${month}',
			_ => null,
		};
	}
}
