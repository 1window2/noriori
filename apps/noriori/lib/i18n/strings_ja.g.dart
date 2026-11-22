///
/// Generated file. Do not edit.
///
// coverage:ignore-file
// ignore_for_file: type=lint, unused_import
// dart format off

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:slang/generated.dart';
import 'strings.g.dart';

// Path: <root>
class TranslationsJa with BaseTranslations<AppLocale, Translations> implements Translations {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsJa({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  _meta = meta ?? TranslationMetadata(
		    locale: AppLocale.ja,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ) {
		_meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <ja>.
	final TranslationMetadata<AppLocale, Translations> _meta;
	@override TranslationMetadata<AppLocale, Translations> get $meta => _meta;

	/// Access flat map
	@override dynamic operator[](String key) => _meta.getTranslation(key);

	late final TranslationsJa _root = this; // ignore: unused_field

	@override 
	TranslationsJa $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsJa(meta: meta ?? this.$meta);

	// Translations
	@override late final _Translations$app$ja app = _Translations$app$ja._(_root);
	@override late final _Translations$tabs$ja tabs = _Translations$tabs$ja._(_root);
	@override late final _Translations$start$ja start = _Translations$start$ja._(_root);
	@override late final _Translations$map$ja map = _Translations$map$ja._(_root);
	@override late final _Translations$record$ja record = _Translations$record$ja._(_root);
	@override late final _Translations$stats$ja stats = _Translations$stats$ja._(_root);
	@override late final _Translations$settings$ja settings = _Translations$settings$ja._(_root);
	@override late final _Translations$search$ja search = _Translations$search$ja._(_root);
	@override late final _Translations$session$ja session = _Translations$session$ja._(_root);
	@override late final _Translations$data$ja data = _Translations$data$ja._(_root);
	@override late final _Translations$importing$ja importing = _Translations$importing$ja._(_root);
	@override late final _Translations$ticket$ja ticket = _Translations$ticket$ja._(_root);
	@override late final _Translations$sources$ja sources = _Translations$sources$ja._(_root);
	@override late final _Translations$editRide$ja editRide = _Translations$editRide$ja._(_root);
	@override late final _Translations$lineDetail$ja lineDetail = _Translations$lineDetail$ja._(_root);
	@override late final _Translations$service$ja service = _Translations$service$ja._(_root);
	@override late final _Translations$deleted$ja deleted = _Translations$deleted$ja._(_root);
	@override late final _Translations$complete$ja complete = _Translations$complete$ja._(_root);
	@override late final _Translations$collection$ja collection = _Translations$collection$ja._(_root);
	@override late final _Translations$visits$ja visits = _Translations$visits$ja._(_root);
	@override late final _Translations$remaining$ja remaining = _Translations$remaining$ja._(_root);
	@override late final _Translations$news$ja news = _Translations$news$ja._(_root);
	@override late final _Translations$journey$ja journey = _Translations$journey$ja._(_root);
	@override late final _Translations$years$ja years = _Translations$years$ja._(_root);
	@override late final _Translations$trip$ja trip = _Translations$trip$ja._(_root);
	@override late final _Translations$mapSheet$ja mapSheet = _Translations$mapSheet$ja._(_root);
	@override List<String> get prefNames => [
		'北海道',
		'青森',
		'岩手',
		'宮城',
		'秋田',
		'山形',
		'福島',
		'茨城',
		'栃木',
		'群馬',
		'埼玉',
		'千葉',
		'東京',
		'神奈川',
		'新潟',
		'富山',
		'石川',
		'福井',
		'山梨',
		'長野',
		'岐阜',
		'静岡',
		'愛知',
		'三重',
		'滋賀',
		'京都',
		'大阪',
		'兵庫',
		'奈良',
		'和歌山',
		'鳥取',
		'島根',
		'岡山',
		'広島',
		'山口',
		'徳島',
		'香川',
		'愛媛',
		'高知',
		'福岡',
		'佐賀',
		'長崎',
		'熊本',
		'大分',
		'宮崎',
		'鹿児島',
		'沖縄',
	];
	@override late final _Translations$date$ja date = _Translations$date$ja._(_root);
}

// Path: app
class _Translations$app$ja implements Translations$app$ko {
	_Translations$app$ja._(this._root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get name => 'noriori';
	@override String get loadFailed => '読み込めませんでした。アプリを開き直してください';
}

// Path: tabs
class _Translations$tabs$ja implements Translations$tabs$ko {
	_Translations$tabs$ja._(this._root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get map => '地図';
	@override String get record => '記録';
	@override String get stats => '統計';
	@override String get settings => '設定';
}

// Path: start
class _Translations$start$ja implements Translations$start$ko {
	_Translations$start$ja._(this._root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get loading => '準備しています';
	@override String get updateTitle => 'アプリを更新してください';
	@override String get updateBody => '記録はこのアプリより新しいバージョンで保存されています。記録はそのまま残っています。';
	@override String get retryTitle => '記録を開けませんでした';
	@override String get retryBody => '記録はそのまま残っています。しばらくしてからもう一度お試しください。';
	@override String get restoreTitle => '記録ファイルが破損しています';
	@override String get restoreBody => '破損したファイルは保管しました。バックアップファイルから復元できます。';
	@override String get retry => '再試行';
	@override String get noSpaceTitle => '空き容量が足りません';
	@override String get noSpaceBody => '記録はそのまま残っています。空き容量を確保してからもう一度お試しください。';
	@override String get restoreAction => '復元する';
}

// Path: map
class _Translations$map$ja implements Translations$map$ko {
	_Translations$map$ja._(this._root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get soloOff => '全路線を表示';
	@override String get add => '記録';
	@override String get search => '路線・駅を検索';
	@override String get closed => '廃線';
	@override String get names => '駅名';
	@override String get wholeJapan => '全国を表示';
	@override String get firstRide => '最初の乗車を記録しましょう';
	@override String get firstRideHint => '路線を選んで2駅をタップするだけです';
	@override String left({required Object km}) => '残り ${km} km';
	@override String get continueTitle => '乗りつぶし中の路線';
	@override String get onlyRidden => '乗車済のみ';
	@override String get sheetHandle => '乗りつぶし中の路線一覧を開く';
	@override String get year => '年';
	@override String get yearHint => 'その年までに乗った区間だけ色が付きます';
	@override String get heat => '都道府県';
}

// Path: record
class _Translations$record$ja implements Translations$record$ko {
	_Translations$record$ja._(this._root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String viaService({required Object name}) => '${name}で乗車';
	@override String get empty => 'まだ記録がありません';
	@override String get emptyHint => '路線一覧や検索から最初の乗車を記録しましょう';
	@override String get add => '記録を追加';
	@override String get dateUnknown => '日付不明';
	@override late final _Translations$record$status$ja status = _Translations$record$status$ja._(_root);
	@override String get deleted => '記録を削除しました';
	@override String get undo => '元に戻す';
	@override String get delete => '削除';
	@override String km({required Object km}) => '${km} km';
	@override late final _Translations$record$view$ja view = _Translations$record$view$ja._(_root);
	@override late final _Translations$record$era$ja era = _Translations$record$era$ja._(_root);
	@override late final _Translations$record$category$ja category = _Translations$record$category$ja._(_root);
	@override String get title => '記録';
	@override String get currentLabel => '現行路線網';
	@override String get closedLabel => '廃止区間';
	@override String of({required Object km}) => '${km} km 中';
	@override String lineCount({required Object num, required Object den}) => '路線 ${num} / ${den}';
	@override String completeCount({required Object num}) => '完乗 ${num}';
	@override late final _Translations$record$filter$ja filter = _Translations$record$filter$ja._(_root);
	@override String lineSub({required Object era, required Object num, required Object den, required Object percent}) => '${era} · ${num} / ${den} km · ${percent}';
	@override String get filterEmpty => '該当する路線がありません';
	@override String picked({required Object count}) => '${count}件選択';
	@override String get pickAll => 'すべて';
}

// Path: stats
class _Translations$stats$ja implements Translations$stats$ko {
	_Translations$stats$ja._(this._root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String decade({required Object year}) => '${year}年代';
	@override String totalRidden({required Object km}) => '累計乗車距離 ${km} km';
	@override String get empty => '記録を追加すると完乗率が表示されます';
	@override String get current => '現行';
	@override String get allTime => '廃線含む';
	@override String ridden({required Object num, required Object den}) => '${num} / ${den} km';
	@override String get operators => '事業者';
	@override String get lines => '路線';
	@override String get title => '統計';
	@override String get year => '年';
	@override String get yearPick => '年を選択';
	@override String yearLabel({required Object year}) => '${year}年';
	@override String rodeOf({required Object num, required Object den}) => '${num} / ${den} km';
	@override String month({required Object km}) => '今月 +${km} km';
	@override late final _Translations$stats$kpi$ja kpi = _Translations$stats$kpi$ja._(_root);
	@override String get nearly => 'もうすぐ完乗';
	@override String left({required Object km}) => '残り ${km} km';
	@override String get prefs => '都道府県';
	@override String get prefHint => '乗車率';
	@override String prefLabel({required Object name, required Object percent}) => '${name} ${percent}';
	@override String visited({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(n,
		other: '乗降・訪問した駅 ${n}駅',
	);
	@override String undecided({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(n,
		other: '判定不可 ${n}区間',
	);
	@override String review({required num n, required Object km}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(n,
		other: '要確認 ${n}件 · ${km} km',
	);
	@override String badges({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(n,
		other: 'バッジ${n}個',
	);
	@override String visitedClosed({required Object n}) => '廃駅${n}駅';
}

// Path: settings
class _Translations$settings$ja implements Translations$settings$ko {
	_Translations$settings$ja._(this._root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get language => '言語';
	@override String get version => 'アプリのバージョン';
	@override String get dataEdition => 'データのバージョン';
	@override String packSummary({required Object stations, required Object lines}) => '駅 ${stations} · 路線 ${lines}';
	@override String get data => 'バックアップと復元';
	@override String get licenses => 'オープンソースライセンス';
	@override String get sources => 'データの出典';
	@override String get showClosed => '廃駅・廃線を表示';
	@override String get showArchive => '記録対象外の駅・路線も表示';
	@override String get showBranches => '分岐する路線を表示';
	@override String get theme => 'テーマ';
	@override String get themeLight => 'ライト';
	@override String get themeDark => 'ダーク';
	@override String get themeSystem => 'システム設定';
	@override String get carryover => '事業者変更時に記録を引き継ぐ';
	@override String get carryoverHint => 'オフにするとJRから移管された区間を新しい路線として数えます';
}

// Path: search
class _Translations$search$ja implements Translations$search$ko {
	_Translations$search$ja._(this._root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get showOnMap => '地図で見る';
	@override String get hint => '路線名・駅名';
	@override String get prompt => '路線や駅を検索して始めましょう';
	@override String get none => '見つかりませんでした';
	@override String get archive => '閲覧のみ';
}

// Path: session
class _Translations$session$ja implements Translations$session$ko {
	_Translations$session$ja._(this._root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String laps({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(n,
		other: '${n}周',
	);
	@override String get lapLess => '1周減らす';
	@override String get lapMore => '1周増やす';
	@override String foldStops({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(n,
		other: '${n}駅',
	);
	@override String away({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(n,
		other: '+${n}駅',
	);
	@override String get dateTitle => '乗車日';
	@override String get dateHint => '2015, 2015-03, 2015-03-14, 198X';
	@override String get dateUnknown => '日付不明';
	@override String get dateUnknownHint => '日付不明：駅は全期間、直通・乗換は最後の状態で表示します';
	@override String get datePick => 'カレンダーから選ぶ';
	@override String get dateToday => '今日';
	@override String get dateBad => '日付の形式を確認してください';
	@override String get apply => '適用';
	@override String get cancel => 'キャンセル';
	@override String get main => '本線';
	@override String get pickFrom => '乗車駅を選んでください';
	@override String get tempTag => '臨時';
	@override String get tempNotice => '定期旅客列車なし（臨時列車の運行日のみ記録可）';
	@override String get tempPickDay => '臨時列車の運行日を選んでください';
	@override String get tempNoRun => 'この日は臨時列車が走っていません。上の運行日を押してください';
	@override String get pickTo => '降車駅を選んでください';
	@override String get save => '記録する';
	@override String summary({required Object from, required Object to, required Object km}) => '${from} → ${to} · ${km} km';
	@override String get noPath => 'この2駅の間の経路が見つかりませんでした';
	@override late final _Translations$session$state$ja state = _Translations$session$state$ja._(_root);
	@override String savedAs({required Object line}) => '当時は${line}';
	@override String movedTo({required Object year, required Object name}) => '${year}年 ${name}へ移転';
	@override String handSince({required Object date, required Object line}) => '${date}から${line}';
	@override String get handOpen => '路線を見る ›';
	@override String get handNote => 'この区間はその路線で記録されます';
	@override String get noticeClosedSub => 'それより前の日付でのみ記録できます';
	@override String get noticeSuspendedSub => '運休前の日付でのみ記録できます';
	@override String get noticeBeforeSub => '開業後の日付で記録できます';
	@override String get chooseDirection => 'どちら回りで乗りましたか？';
	@override String directionKm({required Object km}) => '${km} km';
	@override String get chooseRelocation => 'どの時期の線路でしたか？';
	@override String relocationOption({required Object date, required Object km}) => '${date}時点 · ${km} km';
	@override String get dontKnow => 'わからない';
	@override String get today => '今日';
	@override String get findStop => '駅を検索';
	@override String meta({required Object operator, required Object km}) => '${operator} · ${km}';
	@override String fresh({required Object km}) => '新規乗車 ${km} km';
	@override String get noFresh => '乗車済の区間です';
	@override String change({required Object before, required Object after}) => '${before} → ${after}';
	@override String get nonePickable => 'この日付に選べる駅がありません。乗車日を変えてみてください';
	@override String get maybeHint => 'この日付に営業していたか確認できていません';
	@override String get saveFailed => '保存できませんでした。記録は変わっていません';
	@override String spokenKm({required Object km}) => '${km}キロメートル';
	@override String spokenTransfer({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(n,
		other: '乗換 ${n}路線',
	);
	@override String get spokenFrom => '乗車駅に選択';
	@override String get spokenTo => '降車駅に選択';
	@override String get showClosed => '廃駅・廃線を表示';
	@override String get showArchive => '記録対象外の駅・路線も表示';
	@override String get clear => '解除';
	@override String get lap => '1周';
	@override String stops({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(n,
		other: '${n}駅',
	);
	@override String closedSection({required Object year}) => '~${year} 廃止';
	@override String openedSection({required Object year}) => '${year}年開業';
	@override String archiveStop({required Object name, required Object year}) => '${name}（${year}年廃止）は記録対象外です';
	@override String archiveLine({required Object name}) => '${name}は記録対象外です';
	@override String get from => '乗車';
	@override String get to => '降車';
	@override String get whyClosed => 'その日付には営業していなかった駅です';
	@override String get whyViewSignal => '信号場・分岐点のため、ここで記録を始めたり終えたりできません';
	@override String get whyViewNoBoarding => 'この路線はこの駅に止まらないため、ここで記録を始めたり終えたりできません';
	@override String get onlyDown => '下りのみ';
	@override String get onlyUp => '上りのみ';
	@override String get onlyOneWay => '片方向のみ';
	@override String get spokenOnlyDown => '下り列車のみ停車';
	@override String get spokenOnlyUp => '上り列車のみ停車';
	@override String get spokenOnlyOneWay => '片方向の列車のみ停車';
	@override String stopDownTitle({required Object name}) => '${name}には下り列車のみ停車します';
	@override String stopUpTitle({required Object name}) => '${name}には上り列車のみ停車します';
	@override String stopOneWayTitle({required Object name}) => '${name}には片方向の列車のみ停車します';
	@override String towardOnly({required Object name}) => '${name}方面にのみ乗車できます';
	@override String get sectionTitle => '一方向にのみ運転する区間です';
	@override String get sectionDetail => 'この方向には列車が走っていません';
	@override String get aroundTitle => '一方向にのみ回る区間です';
	@override String aroundDetail({required Object km}) => '回り道の${km} kmとして数えます';
	@override String get reverse => '方向を反転';
	@override String get onlyAlight => '降車専用';
	@override String get alightTitle => '降車専用の駅です';
	@override String get alightDetail => '降車駅としてのみ選べます';
	@override String get whySuspended => 'その日付には運休中の区間です';
	@override String bound({required Object names}) => '${names}方面';
	@override String spokenClosed({required Object year}) => '${year}年廃止';
	@override String spokenSuspendedSince({required Object year}) => '${year}年から運休';
	@override String get pastKari => '仮';
	@override String get pastRinji => '臨';
	@override String get spokenPastKari => 'かつての仮乗降場';
	@override String get spokenPastRinji => 'かつての臨時駅';
	@override String spokenBranch({required Object line, required Object next}) => '${line}、${next}方面の分岐';
	@override String reverseNow({required Object line}) => 'この駅で進行方向を変えて${line}へ直通します';
	@override String reverseUsed({required Object line}) => 'この駅で進行方向を変えて${line}へ直通する列車がありました';
	@override String get spokenReverse => 'スイッチバック';
	@override String leaving({required Object name}) => '${name}から乗車';
	@override String progress({required Object num, required Object den, required Object percent}) => '${num} / ${den} km (${percent})';
	@override String get leaveTitle => '選択が解除されます';
	@override String get leaveBody => '別の路線に移動すると、選択中の駅は解除されます。';
	@override String get leave => '移動する';
	@override String get unridableTitle => 'その日付には乗れない区間です';
	@override String get unridableSave => 'その日は廃止後か開業前、運休中だったか、選んだ駅に列車が停まっていませんでした。記録していません。';
	@override String get unridableDate => 'その日は廃止後か開業前、運休中だったか、選んだ駅に列車が停まっていませんでした。乗車日は変更していません。';
	@override String get unridableOk => 'OK';
	@override String get repick => '別の駅をタップすると選び直せます';
	@override String get closedUnknown => '廃止区間';
	@override String get suspendedSection => '運休中';
	@override String relocationOld({required Object km}) => '旧線 · ${km} km';
	@override String relocationNew({required Object km}) => '新線 · ${km} km';
	@override String get spokenOpen => '営業中';
	@override String get spokenPassing => '旅客扱いなし';
	@override String get spokenRidden => '乗車済み';
}

// Path: data
class _Translations$data$ja implements Translations$data$ko {
	_Translations$data$ja._(this._root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get osBackupLarge => '記録ファイルが20MBを超え、Androidのクラウドバックアップに含まれない場合があります。バックアップフォルダを選んでください';
	@override String get title => 'バックアップと復元';
	@override String get folder => 'バックアップフォルダ';
	@override String get folderHint => 'アプリを削除しても残る場所を選んでください';
	@override String get folderNone => '未選択';
	@override String get insideApp => 'アプリを削除すると一緒に消える場所です。別のフォルダを選んでください';
	@override String get lastBackup => '最終バックアップ';
	@override String get never => 'なし';
	@override String get lastFailed => '前回のバックアップに失敗しました';
	@override String get backupNow => '今すぐバックアップ';
	@override String get restore => '復元';
	@override String get restoreHint => 'バックアップファイルを現在の記録に統合します。同じ記録は後から編集した方が残るので、新しい記録は消えません。';
	@override String get noFiles => 'このフォルダにバックアップファイルがありません';
	@override String fileRows({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(n,
		other: '記録 ${n}件',
	);
	@override String get fileTooNew => 'アプリを更新すると読み込めます';
	@override String get fileUnreadable => '読み込めないファイルです';
	@override String merged({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(n,
		other: '${n}件を取り込みました',
	);
	@override String get refused => 'このファイルは復元できません';
	@override String get exportQuarantined => '破損したファイルを書き出す';
	@override String get exportHint => 'バックアップフォルダにコピーを保存します';
	@override String exported({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(n,
		other: '${n}個のファイルを書き出しました',
	);
	@override String get finish => '復元を完了して始める';
	@override late final _Translations$data$notice$ja notice = _Translations$data$notice$ja._(_root);
	@override String get exportCompat => 'CSV書き出し (乗りつぶしオンライン互換)';
	@override String get exportCompatHint => '乗りつぶしオンラインと同じ形式で送ります';
	@override String get exportFull => 'CSV書き出し (完全版)';
	@override String get exportFullHint => '経路と日付まで含めて送ります';
	@override String exportedUtf8({required Object name}) => 'シフトJISにない文字があるためUTF-8で保存しました: ${name}';
	@override String get exportFailed => '書き出せませんでした';
	@override String get exportBackup => 'バックアップを書き出す';
	@override String get exportBackupHint => '今の記録を1つのファイルにして送ります';
	@override String get restoreFile => 'ファイルから復元';
	@override String get restoreFileHint => '書き出したバックアップを選びます';
}

// Path: importing
class _Translations$importing$ja implements Translations$importing$ko {
	_Translations$importing$ja._(this._root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => '乗りつぶしオンラインから取り込む';
	@override String get entryHint => 'ダウンロードしたCSVを現在の記録に追加します';
	@override String get hint => '乗りつぶしオンラインの「登録した記録を編集する」画面の下部からダウンロードしたCSVファイルを選んでください。コメント付きのCSVも使えます。';
	@override String get choose => 'ファイルを選ぶ';
	@override String refused({required Object name}) => '乗りつぶしオンラインのCSVではありません: ${name}。別のファイルを選んでください。';
	@override String get failed => '取り込めませんでした。記録は変わっていません。';
	@override String get undone => '元に戻しました。削除した記録は再度取り込むときに選べます。';
	@override String get file => 'ファイル';
	@override String get fresh => '新しい記録';
	@override String rows({required Object count}) => '${count}件';
	@override String get distance => '記録距離の合計';
	@override String get existing => 'すでにある記録';
	@override String get deleted => '削除した記録も再度取り込む';
	@override String missed({required num n, required Object count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(n,
		other: '一致しなかった行 ${count}件',
	);
	@override String get missedHint => '記録としては残りますが完乗率には含まれません';
	@override String broken({required num n, required Object count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(n,
		other: '読み込めなかった行 ${count}件',
	);
	@override String get brokenHint => '形式が崩れているため取り込みません';
	@override String kmDiffers({required num n, required Object count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(n,
		other: '距離が異なる行 ${count}件',
	);
	@override String get kmDiffersHint => 'ファイルの距離とアプリの距離が異なります';
	@override String kmDiffersRow({required Object raw, required Object km}) => '${raw} → アプリ ${km}km';
	@override String get nothing => '新しく取り込む記録はありません';
	@override String confirm({required num n, required Object count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(n,
		other: '${count}件を取り込む',
	);
	@override String done({required num n, required Object count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(n,
		other: '${count}件を取り込みました',
	);
	@override String undated({required num n, required Object count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(n,
		other: '日付不明で取り込んだ行 ${count}件',
	);
	@override String get close => '閉じる';
	@override String get undo => '元に戻す';
	@override String fullHint({required Object count}) => 'noriori完全版です。記録${count}件のうち、ないものだけを追加します。';
	@override String merged({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(n,
		other: '${n}件を追加しました',
	);
}

// Path: ticket
class _Translations$ticket$ja implements Translations$ticket$ko {
	_Translations$ticket$ja._(this._root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get completeStamp => '完乗';
	@override String get rideStamp => '乗車';
	@override String get undo => '元に戻す';
	@override String get noDate => '日付不明';
}

// Path: sources
class _Translations$sources$ja implements Translations$sources$ko {
	_Translations$sources$ja._(this._root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => 'データの出典';
	@override String get intro => '名称、距離、日付などの事実情報を複数の出典から集めて作成しました。norioriのデータはCC BY-SA 4.0で配布します。線路形状は下記の原資料の条件に従い、OSM線路ファイルのみODbL 1.0です。';
	@override late final _Translations$sources$n02$ja n02 = _Translations$sources$n02$ja._(_root);
	@override late final _Translations$sources$n05$ja n05 = _Translations$sources$n05$ja._(_root);
	@override late final _Translations$sources$n03$ja n03 = _Translations$sources$n03$ja._(_root);
	@override late final _Translations$sources$stationDatabase$ja stationDatabase = _Translations$sources$stationDatabase$ja._(_root);
	@override late final _Translations$sources$wikipedia$ja wikipedia = _Translations$sources$wikipedia$ja._(_root);
	@override late final _Translations$sources$wikidata$ja wikidata = _Translations$sources$wikidata$ja._(_root);
	@override late final _Translations$sources$namuwiki$ja namuwiki = _Translations$sources$namuwiki$ja._(_root);
	@override late final _Translations$sources$noritsubushi$ja noritsubushi = _Translations$sources$noritsubushi$ja._(_root);
	@override late final _Translations$sources$openFreeMap$ja openFreeMap = _Translations$sources$openFreeMap$ja._(_root);
	@override late final _Translations$sources$openStreetMap$ja openStreetMap = _Translations$sources$openStreetMap$ja._(_root);
	@override late final _Translations$sources$noto$ja noto = _Translations$sources$noto$ja._(_root);
}

// Path: editRide
class _Translations$editRide$ja implements Translations$editRide$ko {
	_Translations$editRide$ja._(this._root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get saved => '修正しました';
	@override String get transfers => 'ここで乗り換えた';
	@override String get transfersHint => '通過した駅のうち、降りて乗り換えた駅を選びます';
	@override String get title => '記録の編集';
	@override String get missing => '記録が見つかりませんでした';
	@override String get date => '乗車日';
	@override String get times => '時刻';
	@override String get train => '列車名';
	@override String get car => '編成';
	@override String get note => 'メモ';
	@override String get fromAlighted => '始点の駅で実際に乗車した';
	@override String get toAlighted => '終点の駅で実際に降車した';
	@override String get save => '保存';
	@override String get delete => '削除';
	@override String get unridable => 'その日は廃止後か開業前、運休中だったか、記録した駅に列車が停まっていませんでした。記録は変わっていません。';
	@override String get failed => '保存できませんでした。記録は変わっていません';
}

// Path: lineDetail
class _Translations$lineDetail$ja implements Translations$lineDetail$ko {
	_Translations$lineDetail$ja._(this._root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get soloMap => '地図でこの路線だけ表示';
	@override String get current => '現行';
	@override String get allTime => '廃止区間含む';
	@override String km({required Object num, required Object den}) => '${num} / ${den} km';
	@override String get completeCurrent => '完乗';
	@override String get selfScore => '全体の集計対象外の路線です。この路線の中だけで乗車率を計算します。';
	@override String get open => '路線詳細';
	@override String get record => 'この路線を記録する';
	@override String get clear => 'この路線の記録をすべて消す';
	@override String get hint => '区間をタップすると乗車済・未乗が切り替わります。長押ししたままなぞると複数の区間をまとめて切り替えられます。駅の丸をタップすると訪問済・未訪問が切り替わります。';
	@override String sectionRidden({required Object from, required Object to}) => '${from}から${to}、乗車済。タップすると未乗に戻します。';
	@override String sectionOpen({required Object from, required Object to}) => '${from}から${to}、未乗。タップすると乗車済にします。';
	@override String stopNode({required Object name}) => '${name}の訪問を切り替える';
	@override String turnedOff({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(n,
		other: '記録${n}件を修正しました',
	);
	@override String get turnedOn => '乗車済にしました';
	@override String get restored => '消した記録を戻しました';
	@override String get blockedHidden => '信号場や分岐点で区切る必要があるため、ここでは消せません。記録を直接編集してください';
	@override String get blockedPath => '区切ると経路が変わるため消せません。記録を直接編集してください';
	@override String get blockedOn => 'この区間はここでは乗車済にできません。駅の選択画面から記録してください。';
	@override String get visitAdded => '訪問済にしました';
	@override String get visitRemoved => '訪問を消しました';
	@override String get visitByRide => '乗降記録で塗られた駅です。記録を編集すると消せます';
	@override String get undo => '元に戻す';
	@override String joinsTo({required Object name}) => '${name} →';
	@override String get visitDated => '訪問日を変更しました';
}

// Path: service
class _Translations$service$ja implements Translations$service$ko {
	_Translations$service$ja._(this._root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get kind => '運転系統';
	@override String get none => 'その日付には運行していなかった運転系統です';
	@override String get save => '記録する';
	@override String get failed => 'この区間は記録できません。日付を確認してください';
}

// Path: deleted
class _Translations$deleted$ja implements Translations$deleted$ko {
	_Translations$deleted$ja._(this._root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get fileOldest => '以前に取り込んだ記録';
	@override String get title => '削除した記録';
	@override String get empty => '削除した記録はありません';
	@override String get restore => '元に戻す';
	@override String get restored => '記録を戻しました';
	@override String fileRides({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(n,
		other: '記録 ${n}件',
	);
	@override String get fileDelete => 'ファイルごと削除';
	@override String fileDeleteTitle({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(n,
		other: '記録${n}件を削除しますか？',
	);
	@override String fileDeleteBody({required Object file}) => '${file}から取り込んだ記録をすべて削除します。設定の「削除した記録」から元に戻せます。';
	@override String get fileDeleteConfirm => '削除';
	@override String get fileDeleteCancel => 'キャンセル';
	@override String fileDeleted({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(n,
		other: '記録${n}件を削除しました',
	);
}

// Path: complete
class _Translations$complete$ja implements Translations$complete$ko {
	_Translations$complete$ja._(this._root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get credit => 'norioriで記録しました';
	@override String get share => '共有する';
	@override String get close => '閉じる';
}

// Path: collection
class _Translations$collection$ja implements Translations$collection$ko {
	_Translations$collection$ja._(this._root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => 'コレクション';
	@override String get lines => '路線';
	@override String get operators => '事業者';
	@override String get prefs => '都道府県';
	@override String get stations => '駅';
	@override String stationGoal({required Object n}) => '${n}駅';
	@override String get empty => 'まだありません';
	@override String get closed => '廃線';
	@override String get closedEmpty => '乗った区間に廃止されたものはありません';
	@override String closedYear({required Object year}) => '${year}年廃止';
	@override String closedAfter({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(n,
		other: '乗車の${n}年後',
	);
	@override String closedTotal({required num n, required Object km}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(n,
		other: 'もう乗れない区間 ${n}箇所 · ${km} km',
	);
}

// Path: visits
class _Translations$visits$ja implements Translations$visits$ko {
	_Translations$visits$ja._(this._root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => '訪問駅';
	@override String count({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(n,
		other: '${n}駅',
	);
	@override String split({required Object open, required Object closed}) => '現行 ${open}駅 · 廃駅 ${closed}駅';
	@override String prefs({required Object n}) => '都道府県 ${n} / 47';
	@override String unknown({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(n,
		other: '都道府県不明の駅 ${n}駅',
	);
	@override String get empty => '訪問した駅はまだありません';
}

// Path: remaining
class _Translations$remaining$ja implements Translations$remaining$ko {
	_Translations$remaining$ja._(this._root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => '未乗区間';
	@override String get entry => 'おすすめを見る';
	@override String get shortest => 'もうすぐ完乗';
	@override String get near => '近く';
	@override String get operators => '事業者別';
	@override String get empty => '未乗区間はありません';
	@override String get nearDenied => '位置情報を利用できません。設定で許可してください';
	@override String nearNone({required Object km}) => '${km} km以内に未乗区間はありません';
	@override String nearAway({required Object km}) => '${km} km';
}

// Path: news
class _Translations$news$ja implements Translations$news$ko {
	_Translations$news$ja._(this._root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => '鉄道網が変わりました';
	@override String get history => '鉄道網の変更履歴';
	@override String get ok => 'OK';
	@override String lineOpened({required Object line, required Object km}) => '${line} ${km} km 開業';
	@override String lineClosed({required Object line, required Object km}) => '${line} ${km} km 廃止';
	@override String stationOpened({required Object station, required Object line}) => '${station}駅 開業（${line}）';
	@override String stationClosed({required Object station, required Object line}) => '${station}駅 廃止（${line}）';
	@override String more({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(n,
		other: 'ほか${n}件',
	);
	@override String lineReopened({required Object line, required Object km}) => '${line} ${km} km 開業。完乗が解除されました';
	@override String rideDistance({required Object line, required Object before, required Object after}) => '${line}の記録の距離が${before} kmから${after} kmに変わりました';
	@override String rideReview({required Object line}) => '${line}の記録を確認してください';
}

// Path: journey
class _Translations$journey$ja implements Translations$journey$ko {
	_Translations$journey$ja._(this._root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => '複数路線をまとめて記録';
	@override String get hint => '2つの駅を選ぶと経路を探し、路線ごとに記録して旅程にまとめます';
	@override String get from => '出発';
	@override String get to => '到着';
	@override String get choose => '選ぶ';
	@override String get save => '記録する';
	@override String get none => 'つながる経路が見つかりません';
	@override String get stationHint => '駅名';
	@override String saved({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(n,
		other: '${n}件の記録を保存しました',
	);
}

// Path: years
class _Translations$years$ja implements Translations$years$ko {
	_Translations$years$ja._(this._root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get title => '年別';
	@override String get activity => 'アクティビティ';
	@override String get distance => '距離';
	@override String get count => '記録数';
	@override String get fresh => '新規区間';
	@override String get busiest => '一番乗った年';
	@override String get undated => '日付不明';
	@override String get undatedHint => 'グラフとカレンダーには含まれません';
	@override String get empty => '日付のある記録がありません';
	@override String get activityHint => '色が濃い日ほど多く乗っています';
	@override String get noRides => '記録なし';
	@override String rides({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(n,
		other: '${n}件',
	);
}

// Path: trip
class _Translations$trip$ja implements Translations$trip$ko {
	_Translations$trip$ja._(this._root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get make => '旅程にまとめる';
	@override String get nameTitle => '旅程の名前';
	@override String get nameHint => '関西旅行';
	@override String get save => '保存';
	@override String get rename => '名前を変更';
	@override String get dissolve => '旅程を解除';
	@override String get dissolveHint => 'まとまりだけを解除します。記録は残ります';
	@override String get dissolved => '旅程を解除しました';
	@override String get made => '旅程にまとめました';
	@override String get empty => '旅程はありません';
	@override String get emptyHint => '乗車記録を長押しして選ぶと、旅程にまとめられます';
	@override String rides({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(n,
		other: '${n}件',
	);
	@override String get delete => '旅程と記録を削除';
	@override String get deleteHint => '旅程の記録も削除します。5秒以内なら元に戻せます';
	@override String get deleted => '旅程と記録を削除しました';
}

// Path: mapSheet
class _Translations$mapSheet$ja implements Translations$mapSheet$ko {
	_Translations$mapSheet$ja._(this._root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get beyond => 'この駅の先の廃止区間';
	@override String get unlocated => '正確な位置は未確認';
	@override String rideCount({required Object count}) => '自分の乗車記録 ${count}件';
	@override String get viewSection => '区間を見る';
	@override String get unmapped => '地図に表示なし';
	@override String get visited => 'この駅に行ったことがある';
	@override String get visitedHint => '完乗率には含まれず、地図の丸だけが塗られます';
	@override String get noVisits => '駅訪問の記録はありません。地図で駅をタップすると残せます。';
	@override String get pickerLabel => 'この場所を通る路線';
	@override String get partlyClosed => 'この区間は廃止';
	@override String get closed => '廃線';
}

// Path: date
class _Translations$date$ja implements Translations$date$ko {
	_Translations$date$ja._(this._root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override List<String> get months => [
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
	@override String day({required Object year, required Object month, required Object day}) => '${year}.${month}.${day}';
	@override String month({required Object year, required Object month}) => '${year}.${month}';
}

// Path: record.status
class _Translations$record$status$ja implements Translations$record$status$ko {
	_Translations$record$status$ja._(this._root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get partial => '一部のみ確定';
	@override String get needsInput => '要確認';
	@override String get unknownRef => '要確認';
	@override String get invalid => '要確認';
	@override String get error => '計算失敗';
}

// Path: record.view
class _Translations$record$view$ja implements Translations$record$view$ko {
	_Translations$record$view$ja._(this._root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get lines => '路線';
	@override String get rides => '乗車記録';
	@override String get visits => '駅訪問';
	@override String get trips => '旅程';
}

// Path: record.era
class _Translations$record$era$ja implements Translations$record$era$ko {
	_Translations$record$era$ja._(this._root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get current => '現行';
	@override String get closed => '廃線';
}

// Path: record.category
class _Translations$record$category$ja implements Translations$record$category$ko {
	_Translations$record$category$ja._(this._root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get jr => 'JR';
	@override String get majorPrivate => '大手私鉄';
	@override String get semiMajorPrivate => '準大手私鉄';
	@override String get public => '公営';
	@override String get generalPrivate => '中小私鉄・三セク';
	@override String get monorail => 'モノレール';
	@override String get agt => '新交通';
	@override String get cable => '鋼索線';
}

// Path: record.filter
class _Translations$record$filter$ja implements Translations$record$filter$ko {
	_Translations$record$filter$ja._(this._root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get all => 'すべて';
	@override String get riding => '一部乗車';
	@override String get unridden => '未乗の路線';
	@override String get complete => '完乗';
}

// Path: stats.kpi
class _Translations$stats$kpi$ja implements Translations$stats$kpi$ko {
	_Translations$stats$kpi$ja._(this._root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get lines => '乗車路線';
	@override String get complete => '完乗';
	@override String get stations => '経由駅';
	@override String get operators => '事業者';
}

// Path: session.state
class _Translations$session$state$ja implements Translations$session$state$ko {
	_Translations$session$state$ja._(this._root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get maybe => '?';
	@override String get suspended => '運休';
	@override String suspendedSince({required Object year}) => '運休 ${year}~';
	@override String until({required Object year}) => '~${year}';
	@override String since({required Object year}) => '${year}~';
	@override String span({required Object from, required Object to}) => '${from}~${to}';
}

// Path: data.notice
class _Translations$data$notice$ja implements Translations$data$notice$ko {
	_Translations$data$notice$ja._(this._root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get needsMerge => 'バックアップフォルダにこの端末より新しい記録があります。復元してください';
	@override String get failed => '自動バックアップに失敗しました';
	@override String get folderLost => 'バックアップフォルダを選び直してください';
	@override String get unreadable => 'バックアップフォルダに読み込めないファイルがあります';
	@override String get stale => '変更した記録が1週間以上バックアップされていません';
	@override String get noFolder => 'バックアップフォルダを選んで記録を守りましょう';
}

// Path: sources.n02
class _Translations$sources$n02$ja implements Translations$sources$n02$ko {
	_Translations$sources$n02$ja._(this._root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get name => '国土数値情報 鉄道データ (N02)';
	@override String get use => '線路形状、駅座標の補正';
	@override String get terms => '国土交通省。2020年以降の版はCC BY 4.0、それ以前の版は国土数値情報の利用条件。「国土数値情報（鉄道データ）」（国土交通省）を加工して作成。このデータは国土交通省が作成したものではありません。';
}

// Path: sources.n05
class _Translations$sources$n05$ja implements Translations$sources$n05$ko {
	_Translations$sources$n05$ja._(this._root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get name => '国土数値情報 鉄道時系列データ (N05)';
	@override String get use => 'N02とOpenStreetMapにない廃止区間の線路形状';
	@override String get terms => '国土交通省。国土数値情報の利用条件（非商用）。「国土数値情報（鉄道時系列データ）」（国土交通省）を加工して作成。このデータは国土交通省が作成したものではありません。';
}

// Path: sources.n03
class _Translations$sources$n03$ja implements Translations$sources$n03$ko {
	_Translations$sources$n03$ja._(this._root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get name => '国土数値情報 行政区域データ (N03)';
	@override String get use => '日本の輪郭と都道府県境、県境をまたぐ区間の都道府県別キロ';
	@override String get terms => '「国土数値情報（行政区域データ）」（国土交通省）を加工して作成。このデータは国土交通省が作成したものではありません。';
}

// Path: sources.stationDatabase
class _Translations$sources$stationDatabase$ja implements Translations$sources$stationDatabase$ko {
	_Translations$sources$stationDatabase$ja._(this._root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get name => 'station_database';
	@override String get use => '駅一覧と座標';
	@override String get terms => 'Seo-4d696b75. CC BY-SA 4.0';
}

// Path: sources.wikipedia
class _Translations$sources$wikipedia$ja implements Translations$sources$wikipedia$ko {
	_Translations$sources$wikipedia$ja._(this._root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get name => '日本語版ウィキペディア';
	@override String get use => '路線図、接続、廃線履歴、読み';
	@override String get terms => 'CC BY-SA 4.0';
}

// Path: sources.wikidata
class _Translations$sources$wikidata$ja implements Translations$sources$wikidata$ko {
	_Translations$sources$wikidata$ja._(this._root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get name => 'Wikidata';
	@override String get use => '英語名、一部の駅座標';
	@override String get terms => 'CC0 1.0';
}

// Path: sources.namuwiki
class _Translations$sources$namuwiki$ja implements Translations$sources$namuwiki$ko {
	_Translations$sources$namuwiki$ja._(this._root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get name => 'ナムウィキ';
	@override String get use => '韓国語の見出し表記。本文は使用しません';
	@override String get terms => 'サイトライセンス CC BY-NC-SA 2.0 KR';
}

// Path: sources.noritsubushi
class _Translations$sources$noritsubushi$ja implements Translations$sources$noritsubushi$ko {
	_Translations$sources$noritsubushi$ja._(this._root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get name => '乗りつぶしオンライン';
	@override String get use => '営業キロ、駅の順序、開業日・廃止日、日本語表記';
	@override String get terms => '事実情報として使用';
}

// Path: sources.openFreeMap
class _Translations$sources$openFreeMap$ja implements Translations$sources$openFreeMap$ko {
	_Translations$sources$openFreeMap$ja._(this._root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get name => 'OpenFreeMap';
	@override String get use => '背景地図';
	@override String get terms => 'OpenFreeMap © OpenMapTiles. Data from OpenStreetMap';
}

// Path: sources.openStreetMap
class _Translations$sources$openStreetMap$ja implements Translations$sources$openStreetMap$ko {
	_Translations$sources$openStreetMap$ja._(this._root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get name => 'OpenStreetMap';
	@override String get use => 'N02にない線路形状';
	@override String get terms => '© OpenStreetMap contributors. ODbL 1.0。rail-osm.pmtilesのみ';
}

// Path: sources.noto
class _Translations$sources$noto$ja implements Translations$sources$noto$ko {
	_Translations$sources$noto$ja._(this._root);

	final TranslationsJa _root; // ignore: unused_field

	// Translations
	@override String get name => 'Noto Sans, Noto Sans CJK';
	@override String get use => '地図の駅名の文字';
	@override String get terms => 'SIL OFL 1.1。全文はオープンソースライセンス画面にあります';
}

/// The flat map containing all translations for locale <ja>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsJa {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'app.name' => 'noriori',
			'app.loadFailed' => '読み込めませんでした。アプリを開き直してください',
			'tabs.map' => '地図',
			'tabs.record' => '記録',
			'tabs.stats' => '統計',
			'tabs.settings' => '設定',
			'start.loading' => '準備しています',
			'start.updateTitle' => 'アプリを更新してください',
			'start.updateBody' => '記録はこのアプリより新しいバージョンで保存されています。記録はそのまま残っています。',
			'start.retryTitle' => '記録を開けませんでした',
			'start.retryBody' => '記録はそのまま残っています。しばらくしてからもう一度お試しください。',
			'start.restoreTitle' => '記録ファイルが破損しています',
			'start.restoreBody' => '破損したファイルは保管しました。バックアップファイルから復元できます。',
			'start.retry' => '再試行',
			'start.noSpaceTitle' => '空き容量が足りません',
			'start.noSpaceBody' => '記録はそのまま残っています。空き容量を確保してからもう一度お試しください。',
			'start.restoreAction' => '復元する',
			'map.soloOff' => '全路線を表示',
			'map.add' => '記録',
			'map.search' => '路線・駅を検索',
			'map.closed' => '廃線',
			'map.names' => '駅名',
			'map.wholeJapan' => '全国を表示',
			'map.firstRide' => '最初の乗車を記録しましょう',
			'map.firstRideHint' => '路線を選んで2駅をタップするだけです',
			'map.left' => ({required Object km}) => '残り ${km} km',
			'map.continueTitle' => '乗りつぶし中の路線',
			'map.onlyRidden' => '乗車済のみ',
			'map.sheetHandle' => '乗りつぶし中の路線一覧を開く',
			'map.year' => '年',
			'map.yearHint' => 'その年までに乗った区間だけ色が付きます',
			'map.heat' => '都道府県',
			'record.viaService' => ({required Object name}) => '${name}で乗車',
			'record.empty' => 'まだ記録がありません',
			'record.emptyHint' => '路線一覧や検索から最初の乗車を記録しましょう',
			'record.add' => '記録を追加',
			'record.dateUnknown' => '日付不明',
			'record.status.partial' => '一部のみ確定',
			'record.status.needsInput' => '要確認',
			'record.status.unknownRef' => '要確認',
			'record.status.invalid' => '要確認',
			'record.status.error' => '計算失敗',
			'record.deleted' => '記録を削除しました',
			'record.undo' => '元に戻す',
			'record.delete' => '削除',
			'record.km' => ({required Object km}) => '${km} km',
			'record.view.lines' => '路線',
			'record.view.rides' => '乗車記録',
			'record.view.visits' => '駅訪問',
			'record.view.trips' => '旅程',
			'record.era.current' => '現行',
			'record.era.closed' => '廃線',
			'record.category.jr' => 'JR',
			'record.category.majorPrivate' => '大手私鉄',
			'record.category.semiMajorPrivate' => '準大手私鉄',
			'record.category.public' => '公営',
			'record.category.generalPrivate' => '中小私鉄・三セク',
			'record.category.monorail' => 'モノレール',
			'record.category.agt' => '新交通',
			'record.category.cable' => '鋼索線',
			'record.title' => '記録',
			'record.currentLabel' => '現行路線網',
			'record.closedLabel' => '廃止区間',
			'record.of' => ({required Object km}) => '${km} km 中',
			'record.lineCount' => ({required Object num, required Object den}) => '路線 ${num} / ${den}',
			'record.completeCount' => ({required Object num}) => '完乗 ${num}',
			'record.filter.all' => 'すべて',
			'record.filter.riding' => '一部乗車',
			'record.filter.unridden' => '未乗の路線',
			'record.filter.complete' => '完乗',
			'record.lineSub' => ({required Object era, required Object num, required Object den, required Object percent}) => '${era} · ${num} / ${den} km · ${percent}',
			'record.filterEmpty' => '該当する路線がありません',
			'record.picked' => ({required Object count}) => '${count}件選択',
			'record.pickAll' => 'すべて',
			'stats.decade' => ({required Object year}) => '${year}年代',
			'stats.totalRidden' => ({required Object km}) => '累計乗車距離 ${km} km',
			'stats.empty' => '記録を追加すると完乗率が表示されます',
			'stats.current' => '現行',
			'stats.allTime' => '廃線含む',
			'stats.ridden' => ({required Object num, required Object den}) => '${num} / ${den} km',
			'stats.operators' => '事業者',
			'stats.lines' => '路線',
			'stats.title' => '統計',
			'stats.year' => '年',
			'stats.yearPick' => '年を選択',
			'stats.yearLabel' => ({required Object year}) => '${year}年',
			'stats.rodeOf' => ({required Object num, required Object den}) => '${num} / ${den} km',
			'stats.month' => ({required Object km}) => '今月 +${km} km',
			'stats.kpi.lines' => '乗車路線',
			'stats.kpi.complete' => '完乗',
			'stats.kpi.stations' => '経由駅',
			'stats.kpi.operators' => '事業者',
			'stats.nearly' => 'もうすぐ完乗',
			'stats.left' => ({required Object km}) => '残り ${km} km',
			'stats.prefs' => '都道府県',
			'stats.prefHint' => '乗車率',
			'stats.prefLabel' => ({required Object name, required Object percent}) => '${name} ${percent}',
			'stats.visited' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(n, other: '乗降・訪問した駅 ${n}駅', ), 
			'stats.undecided' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(n, other: '判定不可 ${n}区間', ), 
			'stats.review' => ({required num n, required Object km}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(n, other: '要確認 ${n}件 · ${km} km', ), 
			'stats.badges' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(n, other: 'バッジ${n}個', ), 
			'stats.visitedClosed' => ({required Object n}) => '廃駅${n}駅',
			'settings.language' => '言語',
			'settings.version' => 'アプリのバージョン',
			'settings.dataEdition' => 'データのバージョン',
			'settings.packSummary' => ({required Object stations, required Object lines}) => '駅 ${stations} · 路線 ${lines}',
			'settings.data' => 'バックアップと復元',
			'settings.licenses' => 'オープンソースライセンス',
			'settings.sources' => 'データの出典',
			'settings.showClosed' => '廃駅・廃線を表示',
			'settings.showArchive' => '記録対象外の駅・路線も表示',
			'settings.showBranches' => '分岐する路線を表示',
			'settings.theme' => 'テーマ',
			'settings.themeLight' => 'ライト',
			'settings.themeDark' => 'ダーク',
			'settings.themeSystem' => 'システム設定',
			'settings.carryover' => '事業者変更時に記録を引き継ぐ',
			'settings.carryoverHint' => 'オフにするとJRから移管された区間を新しい路線として数えます',
			'search.showOnMap' => '地図で見る',
			'search.hint' => '路線名・駅名',
			'search.prompt' => '路線や駅を検索して始めましょう',
			'search.none' => '見つかりませんでした',
			'search.archive' => '閲覧のみ',
			'session.laps' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(n, other: '${n}周', ), 
			'session.lapLess' => '1周減らす',
			'session.lapMore' => '1周増やす',
			'session.foldStops' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(n, other: '${n}駅', ), 
			'session.away' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(n, other: '+${n}駅', ), 
			'session.dateTitle' => '乗車日',
			'session.dateHint' => '2015, 2015-03, 2015-03-14, 198X',
			'session.dateUnknown' => '日付不明',
			'session.dateUnknownHint' => '日付不明：駅は全期間、直通・乗換は最後の状態で表示します',
			'session.datePick' => 'カレンダーから選ぶ',
			'session.dateToday' => '今日',
			'session.dateBad' => '日付の形式を確認してください',
			'session.apply' => '適用',
			'session.cancel' => 'キャンセル',
			'session.main' => '本線',
			'session.pickFrom' => '乗車駅を選んでください',
			'session.tempTag' => '臨時',
			'session.tempNotice' => '定期旅客列車なし（臨時列車の運行日のみ記録可）',
			'session.tempPickDay' => '臨時列車の運行日を選んでください',
			'session.tempNoRun' => 'この日は臨時列車が走っていません。上の運行日を押してください',
			'session.pickTo' => '降車駅を選んでください',
			'session.save' => '記録する',
			'session.summary' => ({required Object from, required Object to, required Object km}) => '${from} → ${to} · ${km} km',
			'session.noPath' => 'この2駅の間の経路が見つかりませんでした',
			'session.state.maybe' => '?',
			'session.state.suspended' => '運休',
			'session.state.suspendedSince' => ({required Object year}) => '運休 ${year}~',
			'session.state.until' => ({required Object year}) => '~${year}',
			'session.state.since' => ({required Object year}) => '${year}~',
			'session.state.span' => ({required Object from, required Object to}) => '${from}~${to}',
			'session.savedAs' => ({required Object line}) => '当時は${line}',
			'session.movedTo' => ({required Object year, required Object name}) => '${year}年 ${name}へ移転',
			'session.handSince' => ({required Object date, required Object line}) => '${date}から${line}',
			'session.handOpen' => '路線を見る ›',
			'session.handNote' => 'この区間はその路線で記録されます',
			'session.noticeClosedSub' => 'それより前の日付でのみ記録できます',
			'session.noticeSuspendedSub' => '運休前の日付でのみ記録できます',
			'session.noticeBeforeSub' => '開業後の日付で記録できます',
			'session.chooseDirection' => 'どちら回りで乗りましたか？',
			'session.directionKm' => ({required Object km}) => '${km} km',
			'session.chooseRelocation' => 'どの時期の線路でしたか？',
			'session.relocationOption' => ({required Object date, required Object km}) => '${date}時点 · ${km} km',
			'session.dontKnow' => 'わからない',
			'session.today' => '今日',
			'session.findStop' => '駅を検索',
			'session.meta' => ({required Object operator, required Object km}) => '${operator} · ${km}',
			'session.fresh' => ({required Object km}) => '新規乗車 ${km} km',
			'session.noFresh' => '乗車済の区間です',
			'session.change' => ({required Object before, required Object after}) => '${before} → ${after}',
			'session.nonePickable' => 'この日付に選べる駅がありません。乗車日を変えてみてください',
			'session.maybeHint' => 'この日付に営業していたか確認できていません',
			'session.saveFailed' => '保存できませんでした。記録は変わっていません',
			'session.spokenKm' => ({required Object km}) => '${km}キロメートル',
			'session.spokenTransfer' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(n, other: '乗換 ${n}路線', ), 
			'session.spokenFrom' => '乗車駅に選択',
			'session.spokenTo' => '降車駅に選択',
			'session.showClosed' => '廃駅・廃線を表示',
			'session.showArchive' => '記録対象外の駅・路線も表示',
			'session.clear' => '解除',
			'session.lap' => '1周',
			'session.stops' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(n, other: '${n}駅', ), 
			'session.closedSection' => ({required Object year}) => '~${year} 廃止',
			'session.openedSection' => ({required Object year}) => '${year}年開業',
			'session.archiveStop' => ({required Object name, required Object year}) => '${name}（${year}年廃止）は記録対象外です',
			'session.archiveLine' => ({required Object name}) => '${name}は記録対象外です',
			'session.from' => '乗車',
			'session.to' => '降車',
			'session.whyClosed' => 'その日付には営業していなかった駅です',
			'session.whyViewSignal' => '信号場・分岐点のため、ここで記録を始めたり終えたりできません',
			'session.whyViewNoBoarding' => 'この路線はこの駅に止まらないため、ここで記録を始めたり終えたりできません',
			'session.onlyDown' => '下りのみ',
			'session.onlyUp' => '上りのみ',
			'session.onlyOneWay' => '片方向のみ',
			'session.spokenOnlyDown' => '下り列車のみ停車',
			'session.spokenOnlyUp' => '上り列車のみ停車',
			'session.spokenOnlyOneWay' => '片方向の列車のみ停車',
			'session.stopDownTitle' => ({required Object name}) => '${name}には下り列車のみ停車します',
			'session.stopUpTitle' => ({required Object name}) => '${name}には上り列車のみ停車します',
			'session.stopOneWayTitle' => ({required Object name}) => '${name}には片方向の列車のみ停車します',
			'session.towardOnly' => ({required Object name}) => '${name}方面にのみ乗車できます',
			'session.sectionTitle' => '一方向にのみ運転する区間です',
			'session.sectionDetail' => 'この方向には列車が走っていません',
			'session.aroundTitle' => '一方向にのみ回る区間です',
			'session.aroundDetail' => ({required Object km}) => '回り道の${km} kmとして数えます',
			'session.reverse' => '方向を反転',
			'session.onlyAlight' => '降車専用',
			'session.alightTitle' => '降車専用の駅です',
			'session.alightDetail' => '降車駅としてのみ選べます',
			'session.whySuspended' => 'その日付には運休中の区間です',
			'session.bound' => ({required Object names}) => '${names}方面',
			'session.spokenClosed' => ({required Object year}) => '${year}年廃止',
			'session.spokenSuspendedSince' => ({required Object year}) => '${year}年から運休',
			'session.pastKari' => '仮',
			'session.pastRinji' => '臨',
			'session.spokenPastKari' => 'かつての仮乗降場',
			'session.spokenPastRinji' => 'かつての臨時駅',
			'session.spokenBranch' => ({required Object line, required Object next}) => '${line}、${next}方面の分岐',
			'session.reverseNow' => ({required Object line}) => 'この駅で進行方向を変えて${line}へ直通します',
			'session.reverseUsed' => ({required Object line}) => 'この駅で進行方向を変えて${line}へ直通する列車がありました',
			'session.spokenReverse' => 'スイッチバック',
			'session.leaving' => ({required Object name}) => '${name}から乗車',
			'session.progress' => ({required Object num, required Object den, required Object percent}) => '${num} / ${den} km (${percent})',
			'session.leaveTitle' => '選択が解除されます',
			'session.leaveBody' => '別の路線に移動すると、選択中の駅は解除されます。',
			'session.leave' => '移動する',
			'session.unridableTitle' => 'その日付には乗れない区間です',
			'session.unridableSave' => 'その日は廃止後か開業前、運休中だったか、選んだ駅に列車が停まっていませんでした。記録していません。',
			'session.unridableDate' => 'その日は廃止後か開業前、運休中だったか、選んだ駅に列車が停まっていませんでした。乗車日は変更していません。',
			'session.unridableOk' => 'OK',
			'session.repick' => '別の駅をタップすると選び直せます',
			'session.closedUnknown' => '廃止区間',
			'session.suspendedSection' => '運休中',
			'session.relocationOld' => ({required Object km}) => '旧線 · ${km} km',
			'session.relocationNew' => ({required Object km}) => '新線 · ${km} km',
			'session.spokenOpen' => '営業中',
			'session.spokenPassing' => '旅客扱いなし',
			'session.spokenRidden' => '乗車済み',
			'data.osBackupLarge' => '記録ファイルが20MBを超え、Androidのクラウドバックアップに含まれない場合があります。バックアップフォルダを選んでください',
			'data.title' => 'バックアップと復元',
			'data.folder' => 'バックアップフォルダ',
			'data.folderHint' => 'アプリを削除しても残る場所を選んでください',
			'data.folderNone' => '未選択',
			'data.insideApp' => 'アプリを削除すると一緒に消える場所です。別のフォルダを選んでください',
			'data.lastBackup' => '最終バックアップ',
			'data.never' => 'なし',
			'data.lastFailed' => '前回のバックアップに失敗しました',
			'data.backupNow' => '今すぐバックアップ',
			'data.restore' => '復元',
			'data.restoreHint' => 'バックアップファイルを現在の記録に統合します。同じ記録は後から編集した方が残るので、新しい記録は消えません。',
			'data.noFiles' => 'このフォルダにバックアップファイルがありません',
			'data.fileRows' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(n, other: '記録 ${n}件', ), 
			'data.fileTooNew' => 'アプリを更新すると読み込めます',
			'data.fileUnreadable' => '読み込めないファイルです',
			'data.merged' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(n, other: '${n}件を取り込みました', ), 
			'data.refused' => 'このファイルは復元できません',
			'data.exportQuarantined' => '破損したファイルを書き出す',
			'data.exportHint' => 'バックアップフォルダにコピーを保存します',
			'data.exported' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(n, other: '${n}個のファイルを書き出しました', ), 
			'data.finish' => '復元を完了して始める',
			'data.notice.needsMerge' => 'バックアップフォルダにこの端末より新しい記録があります。復元してください',
			'data.notice.failed' => '自動バックアップに失敗しました',
			'data.notice.folderLost' => 'バックアップフォルダを選び直してください',
			'data.notice.unreadable' => 'バックアップフォルダに読み込めないファイルがあります',
			'data.notice.stale' => '変更した記録が1週間以上バックアップされていません',
			'data.notice.noFolder' => 'バックアップフォルダを選んで記録を守りましょう',
			'data.exportCompat' => 'CSV書き出し (乗りつぶしオンライン互換)',
			'data.exportCompatHint' => '乗りつぶしオンラインと同じ形式で送ります',
			'data.exportFull' => 'CSV書き出し (完全版)',
			'data.exportFullHint' => '経路と日付まで含めて送ります',
			'data.exportedUtf8' => ({required Object name}) => 'シフトJISにない文字があるためUTF-8で保存しました: ${name}',
			'data.exportFailed' => '書き出せませんでした',
			'data.exportBackup' => 'バックアップを書き出す',
			'data.exportBackupHint' => '今の記録を1つのファイルにして送ります',
			'data.restoreFile' => 'ファイルから復元',
			'data.restoreFileHint' => '書き出したバックアップを選びます',
			'importing.title' => '乗りつぶしオンラインから取り込む',
			'importing.entryHint' => 'ダウンロードしたCSVを現在の記録に追加します',
			'importing.hint' => '乗りつぶしオンラインの「登録した記録を編集する」画面の下部からダウンロードしたCSVファイルを選んでください。コメント付きのCSVも使えます。',
			'importing.choose' => 'ファイルを選ぶ',
			'importing.refused' => ({required Object name}) => '乗りつぶしオンラインのCSVではありません: ${name}。別のファイルを選んでください。',
			'importing.failed' => '取り込めませんでした。記録は変わっていません。',
			'importing.undone' => '元に戻しました。削除した記録は再度取り込むときに選べます。',
			'importing.file' => 'ファイル',
			'importing.fresh' => '新しい記録',
			'importing.rows' => ({required Object count}) => '${count}件',
			'importing.distance' => '記録距離の合計',
			'importing.existing' => 'すでにある記録',
			'importing.deleted' => '削除した記録も再度取り込む',
			'importing.missed' => ({required num n, required Object count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(n, other: '一致しなかった行 ${count}件', ), 
			'importing.missedHint' => '記録としては残りますが完乗率には含まれません',
			'importing.broken' => ({required num n, required Object count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(n, other: '読み込めなかった行 ${count}件', ), 
			'importing.brokenHint' => '形式が崩れているため取り込みません',
			'importing.kmDiffers' => ({required num n, required Object count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(n, other: '距離が異なる行 ${count}件', ), 
			'importing.kmDiffersHint' => 'ファイルの距離とアプリの距離が異なります',
			'importing.kmDiffersRow' => ({required Object raw, required Object km}) => '${raw} → アプリ ${km}km',
			'importing.nothing' => '新しく取り込む記録はありません',
			'importing.confirm' => ({required num n, required Object count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(n, other: '${count}件を取り込む', ), 
			'importing.done' => ({required num n, required Object count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(n, other: '${count}件を取り込みました', ), 
			'importing.undated' => ({required num n, required Object count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(n, other: '日付不明で取り込んだ行 ${count}件', ), 
			'importing.close' => '閉じる',
			'importing.undo' => '元に戻す',
			'importing.fullHint' => ({required Object count}) => 'noriori完全版です。記録${count}件のうち、ないものだけを追加します。',
			'importing.merged' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(n, other: '${n}件を追加しました', ), 
			'ticket.completeStamp' => '完乗',
			'ticket.rideStamp' => '乗車',
			'ticket.undo' => '元に戻す',
			'ticket.noDate' => '日付不明',
			'sources.title' => 'データの出典',
			'sources.intro' => '名称、距離、日付などの事実情報を複数の出典から集めて作成しました。norioriのデータはCC BY-SA 4.0で配布します。線路形状は下記の原資料の条件に従い、OSM線路ファイルのみODbL 1.0です。',
			'sources.n02.name' => '国土数値情報 鉄道データ (N02)',
			'sources.n02.use' => '線路形状、駅座標の補正',
			'sources.n02.terms' => '国土交通省。2020年以降の版はCC BY 4.0、それ以前の版は国土数値情報の利用条件。「国土数値情報（鉄道データ）」（国土交通省）を加工して作成。このデータは国土交通省が作成したものではありません。',
			'sources.n05.name' => '国土数値情報 鉄道時系列データ (N05)',
			'sources.n05.use' => 'N02とOpenStreetMapにない廃止区間の線路形状',
			'sources.n05.terms' => '国土交通省。国土数値情報の利用条件（非商用）。「国土数値情報（鉄道時系列データ）」（国土交通省）を加工して作成。このデータは国土交通省が作成したものではありません。',
			'sources.n03.name' => '国土数値情報 行政区域データ (N03)',
			'sources.n03.use' => '日本の輪郭と都道府県境、県境をまたぐ区間の都道府県別キロ',
			'sources.n03.terms' => '「国土数値情報（行政区域データ）」（国土交通省）を加工して作成。このデータは国土交通省が作成したものではありません。',
			'sources.stationDatabase.name' => 'station_database',
			'sources.stationDatabase.use' => '駅一覧と座標',
			'sources.stationDatabase.terms' => 'Seo-4d696b75. CC BY-SA 4.0',
			'sources.wikipedia.name' => '日本語版ウィキペディア',
			'sources.wikipedia.use' => '路線図、接続、廃線履歴、読み',
			'sources.wikipedia.terms' => 'CC BY-SA 4.0',
			'sources.wikidata.name' => 'Wikidata',
			'sources.wikidata.use' => '英語名、一部の駅座標',
			'sources.wikidata.terms' => 'CC0 1.0',
			'sources.namuwiki.name' => 'ナムウィキ',
			'sources.namuwiki.use' => '韓国語の見出し表記。本文は使用しません',
			'sources.namuwiki.terms' => 'サイトライセンス CC BY-NC-SA 2.0 KR',
			'sources.noritsubushi.name' => '乗りつぶしオンライン',
			'sources.noritsubushi.use' => '営業キロ、駅の順序、開業日・廃止日、日本語表記',
			'sources.noritsubushi.terms' => '事実情報として使用',
			'sources.openFreeMap.name' => 'OpenFreeMap',
			'sources.openFreeMap.use' => '背景地図',
			'sources.openFreeMap.terms' => 'OpenFreeMap © OpenMapTiles. Data from OpenStreetMap',
			'sources.openStreetMap.name' => 'OpenStreetMap',
			'sources.openStreetMap.use' => 'N02にない線路形状',
			'sources.openStreetMap.terms' => '© OpenStreetMap contributors. ODbL 1.0。rail-osm.pmtilesのみ',
			'sources.noto.name' => 'Noto Sans, Noto Sans CJK',
			'sources.noto.use' => '地図の駅名の文字',
			'sources.noto.terms' => 'SIL OFL 1.1。全文はオープンソースライセンス画面にあります',
			'editRide.saved' => '修正しました',
			'editRide.transfers' => 'ここで乗り換えた',
			'editRide.transfersHint' => '通過した駅のうち、降りて乗り換えた駅を選びます',
			'editRide.title' => '記録の編集',
			'editRide.missing' => '記録が見つかりませんでした',
			'editRide.date' => '乗車日',
			'editRide.times' => '時刻',
			'editRide.train' => '列車名',
			'editRide.car' => '編成',
			'editRide.note' => 'メモ',
			'editRide.fromAlighted' => '始点の駅で実際に乗車した',
			'editRide.toAlighted' => '終点の駅で実際に降車した',
			'editRide.save' => '保存',
			'editRide.delete' => '削除',
			'editRide.unridable' => 'その日は廃止後か開業前、運休中だったか、記録した駅に列車が停まっていませんでした。記録は変わっていません。',
			'editRide.failed' => '保存できませんでした。記録は変わっていません',
			'lineDetail.soloMap' => '地図でこの路線だけ表示',
			'lineDetail.current' => '現行',
			'lineDetail.allTime' => '廃止区間含む',
			'lineDetail.km' => ({required Object num, required Object den}) => '${num} / ${den} km',
			'lineDetail.completeCurrent' => '完乗',
			'lineDetail.selfScore' => '全体の集計対象外の路線です。この路線の中だけで乗車率を計算します。',
			'lineDetail.open' => '路線詳細',
			'lineDetail.record' => 'この路線を記録する',
			'lineDetail.clear' => 'この路線の記録をすべて消す',
			'lineDetail.hint' => '区間をタップすると乗車済・未乗が切り替わります。長押ししたままなぞると複数の区間をまとめて切り替えられます。駅の丸をタップすると訪問済・未訪問が切り替わります。',
			'lineDetail.sectionRidden' => ({required Object from, required Object to}) => '${from}から${to}、乗車済。タップすると未乗に戻します。',
			'lineDetail.sectionOpen' => ({required Object from, required Object to}) => '${from}から${to}、未乗。タップすると乗車済にします。',
			'lineDetail.stopNode' => ({required Object name}) => '${name}の訪問を切り替える',
			'lineDetail.turnedOff' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(n, other: '記録${n}件を修正しました', ), 
			'lineDetail.turnedOn' => '乗車済にしました',
			'lineDetail.restored' => '消した記録を戻しました',
			'lineDetail.blockedHidden' => '信号場や分岐点で区切る必要があるため、ここでは消せません。記録を直接編集してください',
			'lineDetail.blockedPath' => '区切ると経路が変わるため消せません。記録を直接編集してください',
			'lineDetail.blockedOn' => 'この区間はここでは乗車済にできません。駅の選択画面から記録してください。',
			'lineDetail.visitAdded' => '訪問済にしました',
			'lineDetail.visitRemoved' => '訪問を消しました',
			'lineDetail.visitByRide' => '乗降記録で塗られた駅です。記録を編集すると消せます',
			'lineDetail.undo' => '元に戻す',
			'lineDetail.joinsTo' => ({required Object name}) => '${name} →',
			'lineDetail.visitDated' => '訪問日を変更しました',
			'service.kind' => '運転系統',
			'service.none' => 'その日付には運行していなかった運転系統です',
			'service.save' => '記録する',
			'service.failed' => 'この区間は記録できません。日付を確認してください',
			'deleted.fileOldest' => '以前に取り込んだ記録',
			'deleted.title' => '削除した記録',
			'deleted.empty' => '削除した記録はありません',
			'deleted.restore' => '元に戻す',
			'deleted.restored' => '記録を戻しました',
			'deleted.fileRides' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(n, other: '記録 ${n}件', ), 
			'deleted.fileDelete' => 'ファイルごと削除',
			'deleted.fileDeleteTitle' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(n, other: '記録${n}件を削除しますか？', ), 
			'deleted.fileDeleteBody' => ({required Object file}) => '${file}から取り込んだ記録をすべて削除します。設定の「削除した記録」から元に戻せます。',
			'deleted.fileDeleteConfirm' => '削除',
			'deleted.fileDeleteCancel' => 'キャンセル',
			'deleted.fileDeleted' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(n, other: '記録${n}件を削除しました', ), 
			'complete.credit' => 'norioriで記録しました',
			'complete.share' => '共有する',
			'complete.close' => '閉じる',
			'collection.title' => 'コレクション',
			'collection.lines' => '路線',
			'collection.operators' => '事業者',
			'collection.prefs' => '都道府県',
			'collection.stations' => '駅',
			'collection.stationGoal' => ({required Object n}) => '${n}駅',
			'collection.empty' => 'まだありません',
			'collection.closed' => '廃線',
			'collection.closedEmpty' => '乗った区間に廃止されたものはありません',
			'collection.closedYear' => ({required Object year}) => '${year}年廃止',
			'collection.closedAfter' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(n, other: '乗車の${n}年後', ), 
			'collection.closedTotal' => ({required num n, required Object km}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(n, other: 'もう乗れない区間 ${n}箇所 · ${km} km', ), 
			'visits.title' => '訪問駅',
			'visits.count' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(n, other: '${n}駅', ), 
			'visits.split' => ({required Object open, required Object closed}) => '現行 ${open}駅 · 廃駅 ${closed}駅',
			'visits.prefs' => ({required Object n}) => '都道府県 ${n} / 47',
			'visits.unknown' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(n, other: '都道府県不明の駅 ${n}駅', ), 
			'visits.empty' => '訪問した駅はまだありません',
			'remaining.title' => '未乗区間',
			'remaining.entry' => 'おすすめを見る',
			'remaining.shortest' => 'もうすぐ完乗',
			'remaining.near' => '近く',
			'remaining.operators' => '事業者別',
			'remaining.empty' => '未乗区間はありません',
			'remaining.nearDenied' => '位置情報を利用できません。設定で許可してください',
			'remaining.nearNone' => ({required Object km}) => '${km} km以内に未乗区間はありません',
			'remaining.nearAway' => ({required Object km}) => '${km} km',
			'news.title' => '鉄道網が変わりました',
			'news.history' => '鉄道網の変更履歴',
			'news.ok' => 'OK',
			'news.lineOpened' => ({required Object line, required Object km}) => '${line} ${km} km 開業',
			'news.lineClosed' => ({required Object line, required Object km}) => '${line} ${km} km 廃止',
			'news.stationOpened' => ({required Object station, required Object line}) => '${station}駅 開業（${line}）',
			'news.stationClosed' => ({required Object station, required Object line}) => '${station}駅 廃止（${line}）',
			'news.more' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(n, other: 'ほか${n}件', ), 
			'news.lineReopened' => ({required Object line, required Object km}) => '${line} ${km} km 開業。完乗が解除されました',
			'news.rideDistance' => ({required Object line, required Object before, required Object after}) => '${line}の記録の距離が${before} kmから${after} kmに変わりました',
			'news.rideReview' => ({required Object line}) => '${line}の記録を確認してください',
			'journey.title' => '複数路線をまとめて記録',
			'journey.hint' => '2つの駅を選ぶと経路を探し、路線ごとに記録して旅程にまとめます',
			'journey.from' => '出発',
			'journey.to' => '到着',
			'journey.choose' => '選ぶ',
			'journey.save' => '記録する',
			'journey.none' => 'つながる経路が見つかりません',
			'journey.stationHint' => '駅名',
			'journey.saved' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(n, other: '${n}件の記録を保存しました', ), 
			'years.title' => '年別',
			'years.activity' => 'アクティビティ',
			'years.distance' => '距離',
			'years.count' => '記録数',
			'years.fresh' => '新規区間',
			'years.busiest' => '一番乗った年',
			'years.undated' => '日付不明',
			'years.undatedHint' => 'グラフとカレンダーには含まれません',
			'years.empty' => '日付のある記録がありません',
			'years.activityHint' => '色が濃い日ほど多く乗っています',
			'years.noRides' => '記録なし',
			'years.rides' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(n, other: '${n}件', ), 
			'trip.make' => '旅程にまとめる',
			'trip.nameTitle' => '旅程の名前',
			'trip.nameHint' => '関西旅行',
			'trip.save' => '保存',
			'trip.rename' => '名前を変更',
			'trip.dissolve' => '旅程を解除',
			'trip.dissolveHint' => 'まとまりだけを解除します。記録は残ります',
			'trip.dissolved' => '旅程を解除しました',
			'trip.made' => '旅程にまとめました',
			'trip.empty' => '旅程はありません',
			'trip.emptyHint' => '乗車記録を長押しして選ぶと、旅程にまとめられます',
			'trip.rides' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('ja'))(n, other: '${n}件', ), 
			'trip.delete' => '旅程と記録を削除',
			'trip.deleteHint' => '旅程の記録も削除します。5秒以内なら元に戻せます',
			'trip.deleted' => '旅程と記録を削除しました',
			'mapSheet.beyond' => 'この駅の先の廃止区間',
			'mapSheet.unlocated' => '正確な位置は未確認',
			'mapSheet.rideCount' => ({required Object count}) => '自分の乗車記録 ${count}件',
			'mapSheet.viewSection' => '区間を見る',
			'mapSheet.unmapped' => '地図に表示なし',
			'mapSheet.visited' => 'この駅に行ったことがある',
			'mapSheet.visitedHint' => '完乗率には含まれず、地図の丸だけが塗られます',
			'mapSheet.noVisits' => '駅訪問の記録はありません。地図で駅をタップすると残せます。',
			'mapSheet.pickerLabel' => 'この場所を通る路線',
			'mapSheet.partlyClosed' => 'この区間は廃止',
			'mapSheet.closed' => '廃線',
			'prefNames.0' => '北海道',
			'prefNames.1' => '青森',
			'prefNames.2' => '岩手',
			'prefNames.3' => '宮城',
			'prefNames.4' => '秋田',
			'prefNames.5' => '山形',
			'prefNames.6' => '福島',
			'prefNames.7' => '茨城',
			'prefNames.8' => '栃木',
			'prefNames.9' => '群馬',
			'prefNames.10' => '埼玉',
			'prefNames.11' => '千葉',
			'prefNames.12' => '東京',
			'prefNames.13' => '神奈川',
			'prefNames.14' => '新潟',
			'prefNames.15' => '富山',
			'prefNames.16' => '石川',
			'prefNames.17' => '福井',
			'prefNames.18' => '山梨',
			'prefNames.19' => '長野',
			'prefNames.20' => '岐阜',
			'prefNames.21' => '静岡',
			_ => null,
		} ?? switch (path) {
			'prefNames.22' => '愛知',
			'prefNames.23' => '三重',
			'prefNames.24' => '滋賀',
			'prefNames.25' => '京都',
			'prefNames.26' => '大阪',
			'prefNames.27' => '兵庫',
			'prefNames.28' => '奈良',
			'prefNames.29' => '和歌山',
			'prefNames.30' => '鳥取',
			'prefNames.31' => '島根',
			'prefNames.32' => '岡山',
			'prefNames.33' => '広島',
			'prefNames.34' => '山口',
			'prefNames.35' => '徳島',
			'prefNames.36' => '香川',
			'prefNames.37' => '愛媛',
			'prefNames.38' => '高知',
			'prefNames.39' => '福岡',
			'prefNames.40' => '佐賀',
			'prefNames.41' => '長崎',
			'prefNames.42' => '熊本',
			'prefNames.43' => '大分',
			'prefNames.44' => '宮崎',
			'prefNames.45' => '鹿児島',
			'prefNames.46' => '沖縄',
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
