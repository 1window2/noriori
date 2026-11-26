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
class TranslationsEn with BaseTranslations<AppLocale, Translations> implements Translations {
	/// You can call this constructor and build your own translation instance of this locale.
	/// Constructing via the enum [AppLocale.build] is preferred.
	TranslationsEn({Map<String, Node>? overrides, PluralResolver? cardinalResolver, PluralResolver? ordinalResolver, TranslationMetadata<AppLocale, Translations>? meta})
		: assert(overrides == null, 'Set "translation_overrides: true" in order to enable this feature.'),
		  _meta = meta ?? TranslationMetadata(
		    locale: AppLocale.en,
		    overrides: overrides ?? {},
		    cardinalResolver: cardinalResolver,
		    ordinalResolver: ordinalResolver,
		  ) {
		_meta.setFlatMapFunction(_flatMapFunction);
	}

	/// Metadata for the translations of <en>.
	final TranslationMetadata<AppLocale, Translations> _meta;
	@override TranslationMetadata<AppLocale, Translations> get $meta => _meta;

	/// Access flat map
	@override dynamic operator[](String key) => _meta.getTranslation(key);

	late final TranslationsEn _root = this; // ignore: unused_field

	@override 
	TranslationsEn $copyWith({TranslationMetadata<AppLocale, Translations>? meta}) => TranslationsEn(meta: meta ?? this.$meta);

	// Translations
	@override late final _Translations$app$en app = _Translations$app$en._(_root);
	@override late final _Translations$tabs$en tabs = _Translations$tabs$en._(_root);
	@override late final _Translations$start$en start = _Translations$start$en._(_root);
	@override late final _Translations$map$en map = _Translations$map$en._(_root);
	@override late final _Translations$record$en record = _Translations$record$en._(_root);
	@override late final _Translations$stats$en stats = _Translations$stats$en._(_root);
	@override late final _Translations$settings$en settings = _Translations$settings$en._(_root);
	@override late final _Translations$search$en search = _Translations$search$en._(_root);
	@override late final _Translations$session$en session = _Translations$session$en._(_root);
	@override late final _Translations$data$en data = _Translations$data$en._(_root);
	@override late final _Translations$importing$en importing = _Translations$importing$en._(_root);
	@override late final _Translations$ticket$en ticket = _Translations$ticket$en._(_root);
	@override late final _Translations$sources$en sources = _Translations$sources$en._(_root);
	@override late final _Translations$editRide$en editRide = _Translations$editRide$en._(_root);
	@override late final _Translations$lineDetail$en lineDetail = _Translations$lineDetail$en._(_root);
	@override late final _Translations$service$en service = _Translations$service$en._(_root);
	@override late final _Translations$deleted$en deleted = _Translations$deleted$en._(_root);
	@override late final _Translations$complete$en complete = _Translations$complete$en._(_root);
	@override late final _Translations$collection$en collection = _Translations$collection$en._(_root);
	@override late final _Translations$visits$en visits = _Translations$visits$en._(_root);
	@override late final _Translations$remaining$en remaining = _Translations$remaining$en._(_root);
	@override late final _Translations$news$en news = _Translations$news$en._(_root);
	@override late final _Translations$journey$en journey = _Translations$journey$en._(_root);
	@override late final _Translations$years$en years = _Translations$years$en._(_root);
	@override late final _Translations$trip$en trip = _Translations$trip$en._(_root);
	@override late final _Translations$mapSheet$en mapSheet = _Translations$mapSheet$en._(_root);
	@override List<String> get prefNames => [
		'Hokkaido',
		'Aomori',
		'Iwate',
		'Miyagi',
		'Akita',
		'Yamagata',
		'Fukushima',
		'Ibaraki',
		'Tochigi',
		'Gunma',
		'Saitama',
		'Chiba',
		'Tokyo',
		'Kanagawa',
		'Niigata',
		'Toyama',
		'Ishikawa',
		'Fukui',
		'Yamanashi',
		'Nagano',
		'Gifu',
		'Shizuoka',
		'Aichi',
		'Mie',
		'Shiga',
		'Kyoto',
		'Osaka',
		'Hyogo',
		'Nara',
		'Wakayama',
		'Tottori',
		'Shimane',
		'Okayama',
		'Hiroshima',
		'Yamaguchi',
		'Tokushima',
		'Kagawa',
		'Ehime',
		'Kochi',
		'Fukuoka',
		'Saga',
		'Nagasaki',
		'Kumamoto',
		'Oita',
		'Miyazaki',
		'Kagoshima',
		'Okinawa',
	];
	@override late final _Translations$date$en date = _Translations$date$en._(_root);
}

// Path: app
class _Translations$app$en implements Translations$app$ko {
	_Translations$app$en._(this._root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get name => 'noriori';
	@override String get loadFailed => 'Couldn\'t load this. Please reopen the app';
}

// Path: tabs
class _Translations$tabs$en implements Translations$tabs$ko {
	_Translations$tabs$en._(this._root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get map => 'Map';
	@override String get record => 'Log';
	@override String get stats => 'Stats';
	@override String get settings => 'Settings';
}

// Path: start
class _Translations$start$en implements Translations$start$ko {
	_Translations$start$en._(this._root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get loading => 'Getting ready';
	@override String get updateTitle => 'Please update the app';
	@override String get updateBody => 'Your rides were saved with a newer version of noriori. They\'re safe.';
	@override String get retryTitle => 'Couldn\'t open your rides';
	@override String get retryBody => 'Your rides are safe. Please try again in a moment.';
	@override String get restoreTitle => 'Your ride data is corrupted';
	@override String get restoreBody => 'We kept the corrupted file. You can restore your rides from a backup.';
	@override String get retry => 'Try again';
	@override String get noSpaceTitle => 'Not enough storage';
	@override String get noSpaceBody => 'Your rides are safe. Free up some space and try again.';
	@override String get restoreAction => 'Restore';
}

// Path: map
class _Translations$map$en implements Translations$map$ko {
	_Translations$map$en._(this._root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get soloOff => 'Show all lines';
	@override String get add => 'Add ride';
	@override String get search => 'Search lines and stations';
	@override String get closed => 'Closed lines';
	@override String get names => 'Station names';
	@override String get wholeJapan => 'Show all of Japan';
	@override String get firstRide => 'Log your first ride';
	@override String get firstRideHint => 'Pick a line and tap two stations';
	@override String left({required Object km}) => '${km} km to go';
	@override String get continueTitle => 'Continue riding';
	@override String get onlyRidden => 'Ridden only';
	@override String get sheetHandle => 'Show all lines in progress';
	@override String get year => 'Year';
	@override String get yearHint => 'Shows only what you had ridden by that year';
	@override String get heat => 'Prefectures';
}

// Path: record
class _Translations$record$en implements Translations$record$ko {
	_Translations$record$en._(this._root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String viaService({required Object name}) => 'Via ${name}';
	@override String get empty => 'No rides yet';
	@override String get emptyHint => 'Log your first ride from the line list or search';
	@override String get add => 'Add ride';
	@override String get dateUnknown => 'Date unknown';
	@override late final _Translations$record$status$en status = _Translations$record$status$en._(_root);
	@override String get deleted => 'Ride deleted';
	@override String get undo => 'Undo';
	@override String get delete => 'Delete';
	@override String km({required Object km}) => '${km} km';
	@override late final _Translations$record$view$en view = _Translations$record$view$en._(_root);
	@override late final _Translations$record$era$en era = _Translations$record$era$en._(_root);
	@override late final _Translations$record$category$en category = _Translations$record$category$en._(_root);
	@override String get title => 'Log';
	@override String get currentLabel => 'Current network';
	@override String get closedLabel => 'Closed sections';
	@override String of({required Object km}) => 'of ${km} km';
	@override String lineCount({required Object num, required Object den}) => '${num} / ${den} lines';
	@override String completeCount({required Object num}) => '${num} completed';
	@override late final _Translations$record$filter$en filter = _Translations$record$filter$en._(_root);
	@override String lineSub({required Object era, required Object num, required Object den, required Object percent}) => '${era} · ${num} / ${den} km · ${percent}';
	@override String get filterEmpty => 'No matching lines';
	@override String picked({required Object count}) => '${count} selected';
	@override String get pickAll => 'Select all';
}

// Path: stats
class _Translations$stats$en implements Translations$stats$ko {
	_Translations$stats$en._(this._root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String totalRidden({required Object km}) => 'Total distance ridden: ${km} km';
	@override String get empty => 'Add a ride to see your completion rate';
	@override String get current => 'Current';
	@override String get allTime => 'All time';
	@override String ridden({required Object num, required Object den}) => '${num} / ${den} km';
	@override String get operators => 'Operators';
	@override String get lines => 'Lines';
	@override String get title => 'Stats';
	@override String get year => 'Year';
	@override String get yearPick => 'Choose a year';
	@override String yearLabel({required Object year}) => '${year}';
	@override String rodeOf({required Object num, required Object den}) => '${num} / ${den} km';
	@override String month({required Object km}) => '+${km} km this month';
	@override late final _Translations$stats$kpi$en kpi = _Translations$stats$kpi$en._(_root);
	@override String get nearly => 'Almost complete';
	@override String left({required Object km}) => '${km} km to go';
	@override String get prefs => 'Prefectures';
	@override String get prefHint => '% ridden';
	@override String prefLabel({required Object name, required Object percent}) => '${name} ${percent}';
	@override String visited({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: '${n} station visited',
		other: '${n} stations visited',
	);
	@override String decade({required Object year}) => '${year}s';
	@override String undecided({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: '${n} section undetermined',
		other: '${n} sections undetermined',
	);
	@override String review({required num n, required Object km}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: '${n} ride needs review · ${km} km',
		other: '${n} rides need review · ${km} km',
	);
	@override String badges({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: '${n} badge',
		other: '${n} badges',
	);
	@override String visitedClosed({required Object n}) => '${n} closed';
}

// Path: settings
class _Translations$settings$en implements Translations$settings$ko {
	_Translations$settings$en._(this._root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get version => 'App version';
	@override String get dataEdition => 'Data version';
	@override String packSummary({required Object stations, required Object lines}) => '${stations} stations · ${lines} lines';
	@override String get data => 'Backup and restore';
	@override String get licenses => 'Open source licenses';
	@override String get sources => 'Data sources';
	@override String get showClosed => 'Show closed stations and lines';
	@override String get showArchive => 'Include historic stations and lines';
	@override String get showBranches => 'Show lines at junctions';
	@override String get theme => 'Theme';
	@override String get themeLight => 'Light';
	@override String get themeDark => 'Dark';
	@override String get themeSystem => 'System';
	@override String get language => 'Language';
	@override String get carryover => 'Carry rides over when operators change';
	@override String get carryoverHint => 'When off, sections transferred from JR count as new lines';
}

// Path: search
class _Translations$search$en implements Translations$search$ko {
	_Translations$search$en._(this._root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get showOnMap => 'Show on map';
	@override String get hint => 'Line or station name';
	@override String get prompt => 'Find a line or station to start';
	@override String get none => 'No results';
	@override String get archive => 'View only';
}

// Path: session
class _Translations$session$en implements Translations$session$ko {
	_Translations$session$en._(this._root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String laps({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: '${n} lap',
		other: '${n} laps',
	);
	@override String get lapLess => 'Remove a lap';
	@override String get lapMore => 'Add a lap';
	@override String foldStops({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: '${n} stop',
		other: '${n} stops',
	);
	@override String away({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: '+${n} stop',
		other: '+${n} stops',
	);
	@override String get dateTitle => 'Ride date';
	@override String get dateHint => '2015, 2015-03, 2015-03-14, 198X';
	@override String get dateUnknown => 'No date';
	@override String get dateUnknownHint => 'Date unknown: stations from all eras, connections as they last were';
	@override String get datePick => 'Pick from calendar';
	@override String get dateToday => 'Today';
	@override String get dateBad => 'Please check the date format';
	@override String get apply => 'Apply';
	@override String get cancel => 'Cancel';
	@override String get main => 'Main line';
	@override String get pickFrom => 'Pick the departure station';
	@override String get tempTag => 'Special';
	@override String get tempNotice => 'No regular passenger trains (special-train days only)';
	@override String get tempPickDay => 'Pick a special-train day';
	@override String get tempNoRun => 'No special train ran on this date. Tap a running day above';
	@override String get pickTo => 'Pick the arrival station';
	@override String get save => 'Save ride';
	@override String summary({required Object from, required Object to, required Object km}) => '${from} → ${to} · ${km} km';
	@override String get noPath => 'No route found between these two stations';
	@override late final _Translations$session$state$en state = _Translations$session$state$en._(_root);
	@override String savedAs({required Object line}) => 'Part of ${line} on that date';
	@override String movedTo({required Object name, required Object year}) => 'Moved to ${name} in ${year}';
	@override String handSince({required Object line, required Object date}) => '${line} from ${date}';
	@override String get handOpen => 'Open line ›';
	@override String get handNote => 'Rides here are saved to that line';
	@override String get noticeClosedSub => 'Only rides before then can be saved';
	@override String get noticeSuspendedSub => 'Only rides before the suspension can be saved';
	@override String noticeSeasonSub({required Object from, required Object to}) => 'Runs only ${from}–${to} each year. No service on this date';
	@override String noticeSeasonAnySub({required Object from, required Object to}) => 'Runs only ${from}–${to} each year';
	@override String get noticeBeforeSub => 'Rides from the opening day on can be saved';
	@override String get chooseDirection => 'Which way did you ride?';
	@override String directionKm({required Object km}) => '${km} km';
	@override String get chooseRelocation => 'Which alignment did you ride?';
	@override String relocationOption({required Object date, required Object km}) => 'As of ${date} · ${km} km';
	@override String get dontKnow => 'Not sure';
	@override String get today => 'Today';
	@override String get findStop => 'Find a station';
	@override String meta({required Object operator, required Object km}) => '${operator} · ${km}';
	@override String fresh({required Object km}) => 'New: ${km} km';
	@override String get noFresh => 'Already ridden';
	@override String change({required Object before, required Object after}) => '${before} → ${after}';
	@override String get nonePickable => 'No stations are available on this date. Try another date';
	@override String get maybeHint => 'We couldn\'t confirm it was open on this date';
	@override String get saveFailed => 'Couldn\'t save. Your rides haven\'t changed';
	@override String spokenKm({required Object km}) => '${km} kilometers';
	@override String spokenTransfer({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: '${n} transfer',
		other: '${n} transfers',
	);
	@override String get spokenFrom => 'Selected as departure';
	@override String get spokenTo => 'Selected as arrival';
	@override String get showClosed => 'Closed stations';
	@override String get showArchive => 'Historic stations';
	@override String get clear => 'Clear';
	@override String get lap => 'One full loop';
	@override String stops({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: '${n} station',
		other: '${n} stations',
	);
	@override String closedSection({required Object year}) => '~${year} closed';
	@override String openedSection({required Object year}) => 'Opens in ${year}';
	@override String archiveStop({required Object name, required Object year}) => '${name} closed in ${year} and can\'t be logged';
	@override String archiveStopNow({required Object name, required Object year, required Object now}) => '${name} closed in ${year} and can\'t be logged. Now ${now} station';
	@override String archiveStopNoYear({required Object name}) => '${name} is closed and can\'t be logged';
	@override String archiveStopNowNoYear({required Object name, required Object now}) => '${name} is closed and can\'t be logged. Now ${now} station';
	@override String archiveLine({required Object name}) => '${name} is a historic line and can\'t be logged';
	@override String get from => 'From';
	@override String get to => 'To';
	@override String get whyClosed => 'This station wasn\'t open on that date';
	@override String get whyViewSignal => 'This is a signal or junction, so a ride can\'t start or end here';
	@override String get whyViewNoBoarding => 'This line doesn\'t stop here, so a ride can\'t start or end here';
	@override String get whyViewStaff => 'This station doesn\'t serve passengers, so a ride can\'t start or end here';
	@override String get onlyDown => 'Down only';
	@override String get onlyUp => 'Up only';
	@override String get onlyOneWay => 'One way';
	@override String get spokenOnlyDown => 'Down trains only';
	@override String get spokenOnlyUp => 'Up trains only';
	@override String get spokenOnlyOneWay => 'Trains in one direction only';
	@override String stopDownTitle({required Object name}) => 'Only down trains stop at ${name}';
	@override String stopUpTitle({required Object name}) => 'Only up trains stop at ${name}';
	@override String stopOneWayTitle({required Object name}) => 'Trains stop at ${name} in one direction only';
	@override String towardOnly({required Object name}) => 'You can only ride toward ${name}';
	@override String get sectionTitle => 'Trains run one way on this section';
	@override String get sectionDetail => 'No trains run in this direction';
	@override String get aroundTitle => 'This loop runs one way';
	@override String aroundDetail({required Object km}) => 'Counted the long way round: ${km} km';
	@override String get reverse => 'Reverse direction';
	@override String get onlyAlight => 'Exit only';
	@override String get alightTitle => 'Alighting-only stop';
	@override String get alightDetail => 'You can only choose it as your arrival';
	@override String get whySuspended => 'This section was suspended on that date';
	@override String bound({required Object names}) => 'For ${names}';
	@override String spokenClosed({required Object year}) => 'Closed in ${year}';
	@override String spokenSuspendedSince({required Object year}) => 'Suspended since ${year}';
	@override String get pastKari => 'temp.';
	@override String get pastRinji => 'seasonal';
	@override String get spokenPastKari => 'formerly a temporary stop';
	@override String get spokenPastRinji => 'formerly a seasonal station';
	@override String spokenBranch({required Object line, required Object next}) => '${line}, branch to ${next}';
	@override String reverseNow({required Object line}) => 'Trains reverse here and run through to the ${line}';
	@override String reverseUsed({required Object line}) => 'Trains used to reverse here and run through to the ${line}';
	@override String get spokenReverse => 'reverses direction';
	@override String leaving({required Object name}) => 'From ${name}';
	@override String progress({required Object num, required Object den, required Object percent}) => '${num} / ${den} km (${percent})';
	@override String get leaveTitle => 'Your selection will be cleared';
	@override String get leaveBody => 'If you switch lines, the stations you picked will be cleared.';
	@override String get leave => 'Switch';
	@override String get unridableTitle => 'This section couldn\'t be ridden on that date';
	@override String get unridableSave => 'On that date the line was closed, not yet open or suspended, or trains didn\'t stop at the chosen station. The ride wasn\'t saved.';
	@override String get unridableDate => 'On that date the line was closed, not yet open or suspended, or trains didn\'t stop at the chosen station. The date wasn\'t changed.';
	@override String get unridableOk => 'OK';
	@override String get repick => 'Tap another station to start over';
	@override String get closedUnknown => 'Closed section';
	@override String get suspendedSection => 'Suspended';
	@override String get seasonSection => 'Seasonal line';
	@override String relocationOld({required Object km}) => 'Old alignment · ${km} km';
	@override String relocationNew({required Object km}) => 'New alignment · ${km} km';
	@override String get spokenOpen => 'open';
	@override String get spokenPassing => 'No boarding';
	@override String get spokenRidden => 'ridden';
}

// Path: data
class _Translations$data$en implements Translations$data$ko {
	_Translations$data$en._(this._root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get osBackupLarge => 'Your records are over 20 MB and may not fit in Android cloud backup. Choose a backup folder';
	@override String get title => 'Backup and restore';
	@override String get folder => 'Backup folder';
	@override String get folderHint => 'Choose a location that stays after you uninstall the app';
	@override String get folderNone => 'Not set';
	@override String get insideApp => 'This folder is deleted when you uninstall the app. Choose another folder';
	@override String get lastBackup => 'Last backup';
	@override String get never => 'Never';
	@override String get lastFailed => 'The last attempt failed';
	@override String get backupNow => 'Back up now';
	@override String get restore => 'Restore';
	@override String get restoreHint => 'Merges a backup file into your rides. If a ride is in both, the most recent edit is kept, so new rides are never lost.';
	@override String get noFiles => 'No backup files in this folder';
	@override String fileRows({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: '${n} ride',
		other: '${n} rides',
	);
	@override String get fileTooNew => 'Update the app to read this file';
	@override String get fileUnreadable => 'This file can\'t be read';
	@override String merged({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: 'Restored ${n} ride',
		other: 'Restored ${n} rides',
	);
	@override String get refused => 'This file can\'t be restored';
	@override String get exportQuarantined => 'Export the corrupted file';
	@override String get exportHint => 'Saves a copy to the backup folder';
	@override String exported({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: 'Exported ${n} file',
		other: 'Exported ${n} files',
	);
	@override String get finish => 'Finish and open app';
	@override late final _Translations$data$notice$en notice = _Translations$data$notice$en._(_root);
	@override String get exportCompat => 'Export CSV (Noritsubushi format)';
	@override String get exportCompatHint => 'Sends the same format as Noritsubushi';
	@override String get exportFull => 'Export CSV (full)';
	@override String get exportFullHint => 'Sends everything, including routes and dates';
	@override String exportedUtf8({required Object name}) => 'Saved as UTF-8 because some characters aren\'t supported in Shift-JIS: ${name}';
	@override String get exportFailed => 'Couldn\'t export';
	@override String get exportBackup => 'Export backup file';
	@override String get exportBackupHint => 'Sends all your rides as a single file';
	@override String get restoreFile => 'Restore from a file';
	@override String get restoreFileHint => 'Choose a backup file you exported';
}

// Path: importing
class _Translations$importing$en implements Translations$importing$ko {
	_Translations$importing$en._(this._root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get title => 'Import from Noritsubushi';
	@override String get entryHint => 'Adds a downloaded CSV to your rides';
	@override String get hint => 'Choose the CSV you downloaded from the bottom of Noritsubushi\'s record editing page. Both the plain and comment versions work.';
	@override String get choose => 'Choose file';
	@override String refused({required Object name}) => 'Not a Noritsubushi CSV: ${name}. Please choose another file.';
	@override String get failed => 'Couldn\'t import. Your rides haven\'t changed.';
	@override String get undone => 'Undone. You can pick the removed rides when you import again.';
	@override String get file => 'File';
	@override String get fresh => 'New rides';
	@override String rows({required Object count}) => '${count}';
	@override String get distance => 'Total distance';
	@override String get existing => 'Already in your rides';
	@override String get deleted => 'Also restore deleted rides';
	@override String missed({required num n, required Object count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: '${count} row with no matching line',
		other: '${count} rows with no matching line',
	);
	@override String get missedHint => 'Kept as rides, but they don\'t count toward completion';
	@override String broken({required num n, required Object count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: '${count} row unreadable',
		other: '${count} rows unreadable',
	);
	@override String get brokenHint => 'Malformed rows aren\'t imported';
	@override String kmDiffers({required num n, required Object count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: '${count} row differs in distance',
		other: '${count} rows differ in distance',
	);
	@override String get kmDiffersHint => 'The file\'s distance differs from the app\'s';
	@override String kmDiffersRow({required Object raw, required Object km}) => '${raw} → app ${km} km';
	@override String get nothing => 'No new rides to import';
	@override String confirm({required num n, required Object count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: 'Import ${count} ride',
		other: 'Import ${count} rides',
	);
	@override String done({required num n, required Object count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: 'Imported ${count} ride',
		other: 'Imported ${count} rides',
	);
	@override String undated({required num n, required Object count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: '${count} row added without a date',
		other: '${count} rows added without a date',
	);
	@override String get close => 'Close';
	@override String get undo => 'Undo';
	@override String fullHint({required Object count}) => 'A full noriori export. Only rides you don\'t already have are added (${count} in the file).';
	@override String merged({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: 'Added ${n} ride',
		other: 'Added ${n} rides',
	);
}

// Path: ticket
class _Translations$ticket$en implements Translations$ticket$ko {
	_Translations$ticket$en._(this._root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get completeStamp => '完乗';
	@override String get rideStamp => '乗車';
	@override String get undo => 'Undo';
	@override String get noDate => 'Date unknown';
}

// Path: sources
class _Translations$sources$en implements Translations$sources$ko {
	_Translations$sources$en._(this._root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get title => 'Data sources';
	@override String get intro => 'Built from facts such as names, distances and dates gathered from several sources. noriori data is released under CC BY-SA 4.0. Track shapes follow the terms of each original source, and only the OSM track file is ODbL 1.0.';
	@override late final _Translations$sources$n02$en n02 = _Translations$sources$n02$en._(_root);
	@override late final _Translations$sources$n05$en n05 = _Translations$sources$n05$en._(_root);
	@override late final _Translations$sources$n03$en n03 = _Translations$sources$n03$en._(_root);
	@override late final _Translations$sources$gsi$en gsi = _Translations$sources$gsi$en._(_root);
	@override late final _Translations$sources$stationDatabase$en stationDatabase = _Translations$sources$stationDatabase$en._(_root);
	@override late final _Translations$sources$wikipedia$en wikipedia = _Translations$sources$wikipedia$en._(_root);
	@override late final _Translations$sources$wikidata$en wikidata = _Translations$sources$wikidata$en._(_root);
	@override late final _Translations$sources$namuwiki$en namuwiki = _Translations$sources$namuwiki$en._(_root);
	@override late final _Translations$sources$noritsubushi$en noritsubushi = _Translations$sources$noritsubushi$en._(_root);
	@override late final _Translations$sources$others$en others = _Translations$sources$others$en._(_root);
	@override late final _Translations$sources$openFreeMap$en openFreeMap = _Translations$sources$openFreeMap$en._(_root);
	@override late final _Translations$sources$openStreetMap$en openStreetMap = _Translations$sources$openStreetMap$en._(_root);
	@override late final _Translations$sources$noto$en noto = _Translations$sources$noto$en._(_root);
}

// Path: editRide
class _Translations$editRide$en implements Translations$editRide$ko {
	_Translations$editRide$en._(this._root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get saved => 'Saved';
	@override String get transfers => 'Changed trains here';
	@override String get transfersHint => 'Pick the stations on this ride where you got off and changed';
	@override String get title => 'Edit ride';
	@override String get missing => 'Ride not found';
	@override String get date => 'Ride date';
	@override String get times => 'Departure and arrival times';
	@override String get train => 'Train name';
	@override String get car => 'Trainset';
	@override String get note => 'Note';
	@override String get fromAlighted => 'Boarded at the departure station';
	@override String get toAlighted => 'Got off at the arrival station';
	@override String get save => 'Save';
	@override String get delete => 'Delete';
	@override String get unridable => 'On that date the line was closed, not yet open or suspended, or trains didn\'t stop at the recorded station. Your ride hasn\'t changed.';
	@override String get failed => 'Couldn\'t save. Your rides haven\'t changed';
}

// Path: lineDetail
class _Translations$lineDetail$en implements Translations$lineDetail$ko {
	_Translations$lineDetail$en._(this._root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get soloMap => 'Show only this line on the map';
	@override String get current => 'Current';
	@override String get allTime => 'All time';
	@override String km({required Object num, required Object den}) => '${num} / ${den} km';
	@override String get completeCurrent => 'Completed (current)';
	@override String get selfScore => 'Not counted in your totals. Progress is based on this line alone';
	@override String get open => 'Line details';
	@override String get record => 'Log a ride on this line';
	@override String get clear => 'Clear all rides on this line';
	@override String get hint => 'Tap a section to mark it as ridden or not. Long-press and drag to change several at once. Tap a station dot to mark it as visited';
	@override String sectionRidden({required Object from, required Object to}) => '${from} to ${to}, ridden. Tap to clear';
	@override String sectionOpen({required Object from, required Object to}) => '${from} to ${to}, not ridden. Tap to mark as ridden';
	@override String stopNode({required Object name}) => 'Mark visit at ${name}';
	@override String turnedOff({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: 'Updated ${n} ride',
		other: 'Updated ${n} rides',
	);
	@override String get turnedOn => 'Marked as ridden';
	@override String get restored => 'Ride restored';
	@override String get blockedHidden => 'This ride would have to be split at a signal station or junction, so this section can\'t be cleared here. Edit the ride instead';
	@override String get blockedPath => 'Removing this section would change the ride\'s route or date, so it can\'t be cleared here. Edit the ride instead';
	@override String get blockedNoStop => 'This ride would have to be split at a station where trains in this direction don\'t stop, so this section can\'t be cleared here. Edit the ride instead';
	@override String get blockedOn => 'This section can\'t be marked as ridden here. Log it from the station picker instead';
	@override String get visitAdded => 'Marked as visited';
	@override String get visitRemoved => 'Visit removed';
	@override String get visitByRide => 'Marked because you boarded or got off here. Edit that ride to change it';
	@override String get undo => 'Undo';
	@override String joinsTo({required Object name}) => '${name} →';
	@override String get visitDated => 'Visit date changed';
}

// Path: service
class _Translations$service$en implements Translations$service$ko {
	_Translations$service$en._(this._root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get kind => 'Service';
	@override String get none => 'This service didn\'t run on that date';
	@override String get save => 'Save ride';
	@override String get failed => 'This section can\'t be logged. Please check the date';
}

// Path: deleted
class _Translations$deleted$en implements Translations$deleted$ko {
	_Translations$deleted$en._(this._root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get fileOldest => 'Earlier imports';
	@override String get title => 'Deleted rides';
	@override String get empty => 'No deleted rides';
	@override String get restore => 'Restore';
	@override String get restored => 'Ride restored';
	@override String fileRides({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: '${n} ride',
		other: '${n} rides',
	);
	@override String get fileDelete => 'Delete all';
	@override String fileDeleteTitle({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: 'Delete ${n} ride?',
		other: 'Delete ${n} rides?',
	);
	@override String fileDeleteBody({required Object file}) => 'This deletes every ride imported from ${file}. You can bring them back from Deleted rides in Settings.';
	@override String get fileDeleteConfirm => 'Delete';
	@override String get fileDeleteCancel => 'Cancel';
	@override String fileDeleted({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: 'Deleted ${n} ride',
		other: 'Deleted ${n} rides',
	);
}

// Path: complete
class _Translations$complete$en implements Translations$complete$ko {
	_Translations$complete$en._(this._root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get credit => 'Logged with noriori';
	@override String get share => 'Share';
	@override String get close => 'Close';
}

// Path: collection
class _Translations$collection$en implements Translations$collection$ko {
	_Translations$collection$en._(this._root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get title => 'Collection';
	@override String get lines => 'Lines';
	@override String get operators => 'Operators';
	@override String get prefs => 'Prefectures';
	@override String get stations => 'Stations';
	@override String stationGoal({required Object n}) => '${n} stations';
	@override String get empty => 'Nothing yet';
	@override String get closed => 'Closed';
	@override String get closedEmpty => 'None of the sections you rode have closed';
	@override String closedYear({required Object year}) => 'closed in ${year}';
	@override String closedAfter({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: '${n} year after your ride',
		other: '${n} years after your ride',
	);
	@override String closedTotal({required num n, required Object km}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: '${n} section you can no longer ride · ${km} km',
		other: '${n} sections you can no longer ride · ${km} km',
	);
}

// Path: visits
class _Translations$visits$en implements Translations$visits$ko {
	_Translations$visits$en._(this._root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get title => 'Visited stations';
	@override String count({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: '${n} station',
		other: '${n} stations',
	);
	@override String split({required Object open, required Object closed}) => '${open} open · ${closed} closed';
	@override String prefs({required Object n}) => '${n} of 47 prefectures';
	@override String unknown({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: '${n} station with no prefecture',
		other: '${n} stations with no prefecture',
	);
	@override String get empty => 'No stations visited yet';
}

// Path: remaining
class _Translations$remaining$en implements Translations$remaining$ko {
	_Translations$remaining$en._(this._root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get title => 'Unridden sections';
	@override String get entry => 'See suggestions';
	@override String get shortest => 'Almost complete';
	@override String get near => 'Nearby';
	@override String get operators => 'By operator';
	@override String get empty => 'No sections left';
	@override String get nearDenied => 'Location isn\'t available. Turn it on in Settings';
	@override String nearNone({required Object km}) => 'No unridden sections within ${km} km';
	@override String nearAway({required Object km}) => '${km} km away';
}

// Path: news
class _Translations$news$en implements Translations$news$ko {
	_Translations$news$en._(this._root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get title => 'The rail network has changed';
	@override String get history => 'Network changes';
	@override String get ok => 'OK';
	@override String lineOpened({required Object line, required Object km}) => '${line}: ${km} km opened';
	@override String lineClosed({required Object line, required Object km}) => '${line}: ${km} km closed';
	@override String stationOpened({required Object station, required Object line}) => '${station} station opened (${line})';
	@override String stationClosed({required Object station, required Object line}) => '${station} station closed (${line})';
	@override String more({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: 'and ${n} more',
		other: 'and ${n} more',
	);
	@override String lineReopened({required Object line, required Object km}) => '${line}: ${km} km opened, so the line is no longer complete';
	@override String rideDistance({required Object line, required Object before, required Object after}) => '${line} ride changed from ${before} km to ${after} km';
	@override String rideReview({required Object line}) => 'Check your ${line} ride';
}

// Path: journey
class _Translations$journey$en implements Translations$journey$ko {
	_Translations$journey$en._(this._root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get title => 'Log several lines at once';
	@override String get hint => 'Pick two stations. noriori finds a route, logs each line and groups them into a trip';
	@override String get from => 'From';
	@override String get to => 'To';
	@override String get choose => 'Choose';
	@override String get save => 'Log';
	@override String get none => 'No connecting route found';
	@override String get stationHint => 'Station name';
	@override String saved({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: 'Saved ${n} ride',
		other: 'Saved ${n} rides',
	);
}

// Path: years
class _Translations$years$en implements Translations$years$ko {
	_Translations$years$en._(this._root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get title => 'By year';
	@override String get activity => 'Activity';
	@override String get distance => 'Distance';
	@override String get count => 'Rides';
	@override String get fresh => 'New sections';
	@override String get busiest => 'Busiest year';
	@override String get undated => 'No date';
	@override String get undatedHint => 'Not included in the chart or calendar';
	@override String get empty => 'No dated rides yet';
	@override String get activityHint => 'Darker days had more rides';
	@override String get noRides => 'No rides';
	@override String rides({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: '${n} ride',
		other: '${n} rides',
	);
}

// Path: trip
class _Translations$trip$en implements Translations$trip$ko {
	_Translations$trip$en._(this._root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get make => 'Group into a trip';
	@override String get nameTitle => 'Trip name';
	@override String get nameHint => 'Kansai trip';
	@override String get save => 'Save';
	@override String get rename => 'Rename';
	@override String get dissolve => 'Ungroup trip';
	@override String get dissolveHint => 'Removes the group. Your rides stay';
	@override String get dissolved => 'Trip ungrouped';
	@override String get made => 'Grouped into a trip';
	@override String get empty => 'No trips yet';
	@override String get emptyHint => 'Long-press rides in your log to group them into a trip';
	@override String rides({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n,
		one: '${n} ride',
		other: '${n} rides',
	);
	@override String get delete => 'Delete trip and rides';
	@override String get deleteHint => 'Also deletes the rides in this trip. You can undo for 5 seconds';
	@override String get deleted => 'Trip and rides deleted';
}

// Path: mapSheet
class _Translations$mapSheet$en implements Translations$mapSheet$ko {
	_Translations$mapSheet$en._(this._root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get beyond => 'Closed section beyond this station';
	@override String get unlocated => 'Exact location unknown';
	@override String rideCount({required Object count}) => 'Your rides: ${count}';
	@override String get viewSection => 'View section';
	@override String get unmapped => 'Not on map';
	@override String get visited => 'I\'ve been to this station';
	@override String get visitedHint => 'Doesn\'t count toward completion. It only fills in the dot on the map';
	@override String get noVisits => 'No station visits yet. Tap a station on the map to add one';
	@override String get pickerLabel => 'Lines through this spot';
	@override String get partlyClosed => 'Closed here';
	@override String get closed => 'Closed line';
}

// Path: date
class _Translations$date$en implements Translations$date$ko {
	_Translations$date$en._(this._root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override List<String> get months => [
		'Jan',
		'Feb',
		'Mar',
		'Apr',
		'May',
		'Jun',
		'Jul',
		'Aug',
		'Sep',
		'Oct',
		'Nov',
		'Dec',
	];
	@override String day({required Object month, required Object day, required Object year}) => '${month} ${day}, ${year}';
	@override String month({required Object month, required Object year}) => '${month} ${year}';
}

// Path: record.status
class _Translations$record$status$en implements Translations$record$status$ko {
	_Translations$record$status$en._(this._root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get partial => 'Partially confirmed';
	@override String get needsInput => 'Needs review';
	@override String get unknownRef => 'Needs review';
	@override String get invalid => 'Needs review';
	@override String get error => 'Couldn\'t calculate';
}

// Path: record.view
class _Translations$record$view$en implements Translations$record$view$ko {
	_Translations$record$view$en._(this._root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get lines => 'Lines';
	@override String get rides => 'Rides';
	@override String get visits => 'Station visits';
	@override String get trips => 'Trips';
}

// Path: record.era
class _Translations$record$era$en implements Translations$record$era$ko {
	_Translations$record$era$en._(this._root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get current => 'Current';
	@override String get closed => 'Closed';
}

// Path: record.category
class _Translations$record$category$en implements Translations$record$category$ko {
	_Translations$record$category$en._(this._root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get jr => 'JR';
	@override String get majorPrivate => 'Major private railways';
	@override String get semiMajorPrivate => 'Semi-major private railways';
	@override String get public => 'Public operators';
	@override String get generalPrivate => 'Other private railways';
	@override String get monorail => 'Monorails';
	@override String get agt => 'New transit (AGT)';
	@override String get cable => 'Cable cars';
}

// Path: record.filter
class _Translations$record$filter$en implements Translations$record$filter$ko {
	_Translations$record$filter$en._(this._root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get all => 'All';
	@override String get riding => 'In progress';
	@override String get unridden => 'Unridden';
	@override String get complete => 'Completed';
}

// Path: stats.kpi
class _Translations$stats$kpi$en implements Translations$stats$kpi$ko {
	_Translations$stats$kpi$en._(this._root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get lines => 'Lines';
	@override String get complete => 'Completed';
	@override String get stations => 'Stations';
	@override String get operators => 'Operators';
}

// Path: session.state
class _Translations$session$state$en implements Translations$session$state$ko {
	_Translations$session$state$en._(this._root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get maybe => '?';
	@override String get suspended => 'Suspended';
	@override String get offSeason => 'Off season';
	@override String suspendedSince({required Object year}) => 'Suspended ${year}~';
	@override String until({required Object year}) => '~${year}';
	@override String since({required Object year}) => '${year}~';
	@override String span({required Object from, required Object to}) => '${from}~${to}';
}

// Path: data.notice
class _Translations$data$notice$en implements Translations$data$notice$ko {
	_Translations$data$notice$en._(this._root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get needsMerge => 'The backup folder has newer rides than this device. Please restore';
	@override String get failed => 'Automatic backup failed';
	@override String get folderLost => 'Please choose the backup folder again';
	@override String get unreadable => 'The backup folder has files that couldn\'t be read';
	@override String get stale => 'Recent changes haven\'t been backed up in over a week';
	@override String get noFolder => 'Choose a backup folder to protect your rides';
}

// Path: sources.n02
class _Translations$sources$n02$en implements Translations$sources$n02$ko {
	_Translations$sources$n02$en._(this._root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get name => '国土数値情報 鉄道データ (N02)';
	@override String get use => 'Track geometry, station coordinate corrections';
	@override String get terms => 'MLIT. CC BY 4.0 for editions from 2020; earlier editions under the 国土数値情報 terms of use. 「国土数値情報（鉄道データ）」（国土交通省）を加工して作成。このデータは国土交通省が作成したものではありません。';
}

// Path: sources.n05
class _Translations$sources$n05$en implements Translations$sources$n05$ko {
	_Translations$sources$n05$en._(this._root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get name => '国土数値情報 鉄道時系列データ (N05)';
	@override String get use => 'Track geometry of closed sections missing from N02 and OpenStreetMap';
	@override String get terms => 'MLIT. 国土数値情報 terms of use (non-commercial). 「国土数値情報（鉄道時系列データ）」（国土交通省）を加工して作成。このデータは国土交通省が作成したものではありません。';
}

// Path: sources.n03
class _Translations$sources$n03$en implements Translations$sources$n03$ko {
	_Translations$sources$n03$en._(this._root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get name => 'National Land Numerical Information: Administrative Zones (N03)';
	@override String get use => 'Outline of Japan, prefecture borders, and per-prefecture distance of sections crossing them';
	@override String get terms => '「国土数値情報（行政区域データ）」（国土交通省）を加工して作成。このデータは国土交通省が作成したものではありません。';
}

// Path: sources.gsi
class _Translations$sources$gsi$en implements Translations$sources$gsi$ko {
	_Translations$sources$gsi$en._(this._root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get name => 'GSI Vector Tiles (Geospatial Information Authority of Japan)';
	@override String get use => 'Part of the track shapes around Tabata';
	@override String get terms => 'GSI Content Terms of Use (compatible with CC BY 4.0). 出典：国土地理院ベクトルタイル（鉄道中心線）を加工して作成';
}

// Path: sources.stationDatabase
class _Translations$sources$stationDatabase$en implements Translations$sources$stationDatabase$ko {
	_Translations$sources$stationDatabase$en._(this._root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get name => 'station_database';
	@override String get use => 'Station list and coordinates';
	@override String get terms => 'Seo-4d696b75. CC BY-SA 4.0';
}

// Path: sources.wikipedia
class _Translations$sources$wikipedia$en implements Translations$sources$wikipedia$ko {
	_Translations$sources$wikipedia$en._(this._root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get name => 'Japanese Wikipedia';
	@override String get use => 'Line diagrams, connections, closure history, Japanese readings';
	@override String get terms => 'CC BY-SA 4.0';
}

// Path: sources.wikidata
class _Translations$sources$wikidata$en implements Translations$sources$wikidata$ko {
	_Translations$sources$wikidata$en._(this._root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get name => 'Wikidata';
	@override String get use => 'English names, some station coordinates';
	@override String get terms => 'CC0 1.0';
}

// Path: sources.namuwiki
class _Translations$sources$namuwiki$en implements Translations$sources$namuwiki$ko {
	_Translations$sources$namuwiki$en._(this._root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get name => 'Namuwiki';
	@override String get use => 'Korean title spellings. Article text is not used';
	@override String get terms => 'Site license CC BY-NC-SA 2.0 KR';
}

// Path: sources.noritsubushi
class _Translations$sources$noritsubushi$en implements Translations$sources$noritsubushi$ko {
	_Translations$sources$noritsubushi$en._(this._root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get name => 'Noritsubushi';
	@override String get use => 'Operating kilometers, station order, key dates, Japanese names';
	@override String get terms => 'Factual data only';
}

// Path: sources.others
class _Translations$sources$others$en implements Translations$sources$others$ko {
	_Translations$sources$others$en._(this._root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get name => 'Other factual sources';
	@override String get use => 'Operator publications (official English names and more), Public Transportation Open Data Center, public materials of the National Diet Library and the National Archives of Japan, Japan Post postal code data, station sign photos';
	@override String get terms => 'Used as factual data. Each data row records its source, and the full list is in data/NOTICE.md in the repository';
}

// Path: sources.openFreeMap
class _Translations$sources$openFreeMap$en implements Translations$sources$openFreeMap$ko {
	_Translations$sources$openFreeMap$en._(this._root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get name => 'OpenFreeMap';
	@override String get use => 'Base map';
	@override String get terms => 'OpenFreeMap © OpenMapTiles. Data from OpenStreetMap';
}

// Path: sources.openStreetMap
class _Translations$sources$openStreetMap$en implements Translations$sources$openStreetMap$ko {
	_Translations$sources$openStreetMap$en._(this._root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get name => 'OpenStreetMap';
	@override String get use => 'Track geometry missing from N02';
	@override String get terms => '© OpenStreetMap contributors. ODbL 1.0. rail-osm.pmtiles only';
}

// Path: sources.noto
class _Translations$sources$noto$en implements Translations$sources$noto$ko {
	_Translations$sources$noto$en._(this._root);

	final TranslationsEn _root; // ignore: unused_field

	// Translations
	@override String get name => 'Noto Sans, Noto Sans CJK';
	@override String get use => 'Station name lettering on the map';
	@override String get terms => 'SIL OFL 1.1. Full text in Open source licenses';
}

/// The flat map containing all translations for locale <en>.
/// Only for edge cases! For simple maps, use the map function of this library.
///
/// The Dart AOT compiler has issues with very large switch statements,
/// so the map is split into smaller functions (512 entries each).
extension on TranslationsEn {
	dynamic _flatMapFunction(String path) {
		return switch (path) {
			'app.name' => 'noriori',
			'app.loadFailed' => 'Couldn\'t load this. Please reopen the app',
			'tabs.map' => 'Map',
			'tabs.record' => 'Log',
			'tabs.stats' => 'Stats',
			'tabs.settings' => 'Settings',
			'start.loading' => 'Getting ready',
			'start.updateTitle' => 'Please update the app',
			'start.updateBody' => 'Your rides were saved with a newer version of noriori. They\'re safe.',
			'start.retryTitle' => 'Couldn\'t open your rides',
			'start.retryBody' => 'Your rides are safe. Please try again in a moment.',
			'start.restoreTitle' => 'Your ride data is corrupted',
			'start.restoreBody' => 'We kept the corrupted file. You can restore your rides from a backup.',
			'start.retry' => 'Try again',
			'start.noSpaceTitle' => 'Not enough storage',
			'start.noSpaceBody' => 'Your rides are safe. Free up some space and try again.',
			'start.restoreAction' => 'Restore',
			'map.soloOff' => 'Show all lines',
			'map.add' => 'Add ride',
			'map.search' => 'Search lines and stations',
			'map.closed' => 'Closed lines',
			'map.names' => 'Station names',
			'map.wholeJapan' => 'Show all of Japan',
			'map.firstRide' => 'Log your first ride',
			'map.firstRideHint' => 'Pick a line and tap two stations',
			'map.left' => ({required Object km}) => '${km} km to go',
			'map.continueTitle' => 'Continue riding',
			'map.onlyRidden' => 'Ridden only',
			'map.sheetHandle' => 'Show all lines in progress',
			'map.year' => 'Year',
			'map.yearHint' => 'Shows only what you had ridden by that year',
			'map.heat' => 'Prefectures',
			'record.viaService' => ({required Object name}) => 'Via ${name}',
			'record.empty' => 'No rides yet',
			'record.emptyHint' => 'Log your first ride from the line list or search',
			'record.add' => 'Add ride',
			'record.dateUnknown' => 'Date unknown',
			'record.status.partial' => 'Partially confirmed',
			'record.status.needsInput' => 'Needs review',
			'record.status.unknownRef' => 'Needs review',
			'record.status.invalid' => 'Needs review',
			'record.status.error' => 'Couldn\'t calculate',
			'record.deleted' => 'Ride deleted',
			'record.undo' => 'Undo',
			'record.delete' => 'Delete',
			'record.km' => ({required Object km}) => '${km} km',
			'record.view.lines' => 'Lines',
			'record.view.rides' => 'Rides',
			'record.view.visits' => 'Station visits',
			'record.view.trips' => 'Trips',
			'record.era.current' => 'Current',
			'record.era.closed' => 'Closed',
			'record.category.jr' => 'JR',
			'record.category.majorPrivate' => 'Major private railways',
			'record.category.semiMajorPrivate' => 'Semi-major private railways',
			'record.category.public' => 'Public operators',
			'record.category.generalPrivate' => 'Other private railways',
			'record.category.monorail' => 'Monorails',
			'record.category.agt' => 'New transit (AGT)',
			'record.category.cable' => 'Cable cars',
			'record.title' => 'Log',
			'record.currentLabel' => 'Current network',
			'record.closedLabel' => 'Closed sections',
			'record.of' => ({required Object km}) => 'of ${km} km',
			'record.lineCount' => ({required Object num, required Object den}) => '${num} / ${den} lines',
			'record.completeCount' => ({required Object num}) => '${num} completed',
			'record.filter.all' => 'All',
			'record.filter.riding' => 'In progress',
			'record.filter.unridden' => 'Unridden',
			'record.filter.complete' => 'Completed',
			'record.lineSub' => ({required Object era, required Object num, required Object den, required Object percent}) => '${era} · ${num} / ${den} km · ${percent}',
			'record.filterEmpty' => 'No matching lines',
			'record.picked' => ({required Object count}) => '${count} selected',
			'record.pickAll' => 'Select all',
			'stats.totalRidden' => ({required Object km}) => 'Total distance ridden: ${km} km',
			'stats.empty' => 'Add a ride to see your completion rate',
			'stats.current' => 'Current',
			'stats.allTime' => 'All time',
			'stats.ridden' => ({required Object num, required Object den}) => '${num} / ${den} km',
			'stats.operators' => 'Operators',
			'stats.lines' => 'Lines',
			'stats.title' => 'Stats',
			'stats.year' => 'Year',
			'stats.yearPick' => 'Choose a year',
			'stats.yearLabel' => ({required Object year}) => '${year}',
			'stats.rodeOf' => ({required Object num, required Object den}) => '${num} / ${den} km',
			'stats.month' => ({required Object km}) => '+${km} km this month',
			'stats.kpi.lines' => 'Lines',
			'stats.kpi.complete' => 'Completed',
			'stats.kpi.stations' => 'Stations',
			'stats.kpi.operators' => 'Operators',
			'stats.nearly' => 'Almost complete',
			'stats.left' => ({required Object km}) => '${km} km to go',
			'stats.prefs' => 'Prefectures',
			'stats.prefHint' => '% ridden',
			'stats.prefLabel' => ({required Object name, required Object percent}) => '${name} ${percent}',
			'stats.visited' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: '${n} station visited', other: '${n} stations visited', ), 
			'stats.decade' => ({required Object year}) => '${year}s',
			'stats.undecided' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: '${n} section undetermined', other: '${n} sections undetermined', ), 
			'stats.review' => ({required num n, required Object km}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: '${n} ride needs review · ${km} km', other: '${n} rides need review · ${km} km', ), 
			'stats.badges' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: '${n} badge', other: '${n} badges', ), 
			'stats.visitedClosed' => ({required Object n}) => '${n} closed',
			'settings.version' => 'App version',
			'settings.dataEdition' => 'Data version',
			'settings.packSummary' => ({required Object stations, required Object lines}) => '${stations} stations · ${lines} lines',
			'settings.data' => 'Backup and restore',
			'settings.licenses' => 'Open source licenses',
			'settings.sources' => 'Data sources',
			'settings.showClosed' => 'Show closed stations and lines',
			'settings.showArchive' => 'Include historic stations and lines',
			'settings.showBranches' => 'Show lines at junctions',
			'settings.theme' => 'Theme',
			'settings.themeLight' => 'Light',
			'settings.themeDark' => 'Dark',
			'settings.themeSystem' => 'System',
			'settings.language' => 'Language',
			'settings.carryover' => 'Carry rides over when operators change',
			'settings.carryoverHint' => 'When off, sections transferred from JR count as new lines',
			'search.showOnMap' => 'Show on map',
			'search.hint' => 'Line or station name',
			'search.prompt' => 'Find a line or station to start',
			'search.none' => 'No results',
			'search.archive' => 'View only',
			'session.laps' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: '${n} lap', other: '${n} laps', ), 
			'session.lapLess' => 'Remove a lap',
			'session.lapMore' => 'Add a lap',
			'session.foldStops' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: '${n} stop', other: '${n} stops', ), 
			'session.away' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: '+${n} stop', other: '+${n} stops', ), 
			'session.dateTitle' => 'Ride date',
			'session.dateHint' => '2015, 2015-03, 2015-03-14, 198X',
			'session.dateUnknown' => 'No date',
			'session.dateUnknownHint' => 'Date unknown: stations from all eras, connections as they last were',
			'session.datePick' => 'Pick from calendar',
			'session.dateToday' => 'Today',
			'session.dateBad' => 'Please check the date format',
			'session.apply' => 'Apply',
			'session.cancel' => 'Cancel',
			'session.main' => 'Main line',
			'session.pickFrom' => 'Pick the departure station',
			'session.tempTag' => 'Special',
			'session.tempNotice' => 'No regular passenger trains (special-train days only)',
			'session.tempPickDay' => 'Pick a special-train day',
			'session.tempNoRun' => 'No special train ran on this date. Tap a running day above',
			'session.pickTo' => 'Pick the arrival station',
			'session.save' => 'Save ride',
			'session.summary' => ({required Object from, required Object to, required Object km}) => '${from} → ${to} · ${km} km',
			'session.noPath' => 'No route found between these two stations',
			'session.state.maybe' => '?',
			'session.state.suspended' => 'Suspended',
			'session.state.offSeason' => 'Off season',
			'session.state.suspendedSince' => ({required Object year}) => 'Suspended ${year}~',
			'session.state.until' => ({required Object year}) => '~${year}',
			'session.state.since' => ({required Object year}) => '${year}~',
			'session.state.span' => ({required Object from, required Object to}) => '${from}~${to}',
			'session.savedAs' => ({required Object line}) => 'Part of ${line} on that date',
			'session.movedTo' => ({required Object name, required Object year}) => 'Moved to ${name} in ${year}',
			'session.handSince' => ({required Object line, required Object date}) => '${line} from ${date}',
			'session.handOpen' => 'Open line ›',
			'session.handNote' => 'Rides here are saved to that line',
			'session.noticeClosedSub' => 'Only rides before then can be saved',
			'session.noticeSuspendedSub' => 'Only rides before the suspension can be saved',
			'session.noticeSeasonSub' => ({required Object from, required Object to}) => 'Runs only ${from}–${to} each year. No service on this date',
			'session.noticeSeasonAnySub' => ({required Object from, required Object to}) => 'Runs only ${from}–${to} each year',
			'session.noticeBeforeSub' => 'Rides from the opening day on can be saved',
			'session.chooseDirection' => 'Which way did you ride?',
			'session.directionKm' => ({required Object km}) => '${km} km',
			'session.chooseRelocation' => 'Which alignment did you ride?',
			'session.relocationOption' => ({required Object date, required Object km}) => 'As of ${date} · ${km} km',
			'session.dontKnow' => 'Not sure',
			'session.today' => 'Today',
			'session.findStop' => 'Find a station',
			'session.meta' => ({required Object operator, required Object km}) => '${operator} · ${km}',
			'session.fresh' => ({required Object km}) => 'New: ${km} km',
			'session.noFresh' => 'Already ridden',
			'session.change' => ({required Object before, required Object after}) => '${before} → ${after}',
			'session.nonePickable' => 'No stations are available on this date. Try another date',
			'session.maybeHint' => 'We couldn\'t confirm it was open on this date',
			'session.saveFailed' => 'Couldn\'t save. Your rides haven\'t changed',
			'session.spokenKm' => ({required Object km}) => '${km} kilometers',
			'session.spokenTransfer' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: '${n} transfer', other: '${n} transfers', ), 
			'session.spokenFrom' => 'Selected as departure',
			'session.spokenTo' => 'Selected as arrival',
			'session.showClosed' => 'Closed stations',
			'session.showArchive' => 'Historic stations',
			'session.clear' => 'Clear',
			'session.lap' => 'One full loop',
			'session.stops' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: '${n} station', other: '${n} stations', ), 
			'session.closedSection' => ({required Object year}) => '~${year} closed',
			'session.openedSection' => ({required Object year}) => 'Opens in ${year}',
			'session.archiveStop' => ({required Object name, required Object year}) => '${name} closed in ${year} and can\'t be logged',
			'session.archiveStopNow' => ({required Object name, required Object year, required Object now}) => '${name} closed in ${year} and can\'t be logged. Now ${now} station',
			'session.archiveStopNoYear' => ({required Object name}) => '${name} is closed and can\'t be logged',
			'session.archiveStopNowNoYear' => ({required Object name, required Object now}) => '${name} is closed and can\'t be logged. Now ${now} station',
			'session.archiveLine' => ({required Object name}) => '${name} is a historic line and can\'t be logged',
			'session.from' => 'From',
			'session.to' => 'To',
			'session.whyClosed' => 'This station wasn\'t open on that date',
			'session.whyViewSignal' => 'This is a signal or junction, so a ride can\'t start or end here',
			'session.whyViewNoBoarding' => 'This line doesn\'t stop here, so a ride can\'t start or end here',
			'session.whyViewStaff' => 'This station doesn\'t serve passengers, so a ride can\'t start or end here',
			'session.onlyDown' => 'Down only',
			'session.onlyUp' => 'Up only',
			'session.onlyOneWay' => 'One way',
			'session.spokenOnlyDown' => 'Down trains only',
			'session.spokenOnlyUp' => 'Up trains only',
			'session.spokenOnlyOneWay' => 'Trains in one direction only',
			'session.stopDownTitle' => ({required Object name}) => 'Only down trains stop at ${name}',
			'session.stopUpTitle' => ({required Object name}) => 'Only up trains stop at ${name}',
			'session.stopOneWayTitle' => ({required Object name}) => 'Trains stop at ${name} in one direction only',
			'session.towardOnly' => ({required Object name}) => 'You can only ride toward ${name}',
			'session.sectionTitle' => 'Trains run one way on this section',
			'session.sectionDetail' => 'No trains run in this direction',
			'session.aroundTitle' => 'This loop runs one way',
			'session.aroundDetail' => ({required Object km}) => 'Counted the long way round: ${km} km',
			'session.reverse' => 'Reverse direction',
			'session.onlyAlight' => 'Exit only',
			'session.alightTitle' => 'Alighting-only stop',
			'session.alightDetail' => 'You can only choose it as your arrival',
			'session.whySuspended' => 'This section was suspended on that date',
			'session.bound' => ({required Object names}) => 'For ${names}',
			'session.spokenClosed' => ({required Object year}) => 'Closed in ${year}',
			'session.spokenSuspendedSince' => ({required Object year}) => 'Suspended since ${year}',
			'session.pastKari' => 'temp.',
			'session.pastRinji' => 'seasonal',
			'session.spokenPastKari' => 'formerly a temporary stop',
			'session.spokenPastRinji' => 'formerly a seasonal station',
			'session.spokenBranch' => ({required Object line, required Object next}) => '${line}, branch to ${next}',
			'session.reverseNow' => ({required Object line}) => 'Trains reverse here and run through to the ${line}',
			'session.reverseUsed' => ({required Object line}) => 'Trains used to reverse here and run through to the ${line}',
			'session.spokenReverse' => 'reverses direction',
			'session.leaving' => ({required Object name}) => 'From ${name}',
			'session.progress' => ({required Object num, required Object den, required Object percent}) => '${num} / ${den} km (${percent})',
			'session.leaveTitle' => 'Your selection will be cleared',
			'session.leaveBody' => 'If you switch lines, the stations you picked will be cleared.',
			'session.leave' => 'Switch',
			'session.unridableTitle' => 'This section couldn\'t be ridden on that date',
			'session.unridableSave' => 'On that date the line was closed, not yet open or suspended, or trains didn\'t stop at the chosen station. The ride wasn\'t saved.',
			'session.unridableDate' => 'On that date the line was closed, not yet open or suspended, or trains didn\'t stop at the chosen station. The date wasn\'t changed.',
			'session.unridableOk' => 'OK',
			'session.repick' => 'Tap another station to start over',
			'session.closedUnknown' => 'Closed section',
			'session.suspendedSection' => 'Suspended',
			'session.seasonSection' => 'Seasonal line',
			'session.relocationOld' => ({required Object km}) => 'Old alignment · ${km} km',
			'session.relocationNew' => ({required Object km}) => 'New alignment · ${km} km',
			'session.spokenOpen' => 'open',
			'session.spokenPassing' => 'No boarding',
			'session.spokenRidden' => 'ridden',
			'data.osBackupLarge' => 'Your records are over 20 MB and may not fit in Android cloud backup. Choose a backup folder',
			'data.title' => 'Backup and restore',
			'data.folder' => 'Backup folder',
			'data.folderHint' => 'Choose a location that stays after you uninstall the app',
			'data.folderNone' => 'Not set',
			'data.insideApp' => 'This folder is deleted when you uninstall the app. Choose another folder',
			'data.lastBackup' => 'Last backup',
			'data.never' => 'Never',
			'data.lastFailed' => 'The last attempt failed',
			'data.backupNow' => 'Back up now',
			'data.restore' => 'Restore',
			'data.restoreHint' => 'Merges a backup file into your rides. If a ride is in both, the most recent edit is kept, so new rides are never lost.',
			'data.noFiles' => 'No backup files in this folder',
			'data.fileRows' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: '${n} ride', other: '${n} rides', ), 
			'data.fileTooNew' => 'Update the app to read this file',
			'data.fileUnreadable' => 'This file can\'t be read',
			'data.merged' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: 'Restored ${n} ride', other: 'Restored ${n} rides', ), 
			'data.refused' => 'This file can\'t be restored',
			'data.exportQuarantined' => 'Export the corrupted file',
			'data.exportHint' => 'Saves a copy to the backup folder',
			'data.exported' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: 'Exported ${n} file', other: 'Exported ${n} files', ), 
			'data.finish' => 'Finish and open app',
			'data.notice.needsMerge' => 'The backup folder has newer rides than this device. Please restore',
			'data.notice.failed' => 'Automatic backup failed',
			'data.notice.folderLost' => 'Please choose the backup folder again',
			'data.notice.unreadable' => 'The backup folder has files that couldn\'t be read',
			'data.notice.stale' => 'Recent changes haven\'t been backed up in over a week',
			'data.notice.noFolder' => 'Choose a backup folder to protect your rides',
			'data.exportCompat' => 'Export CSV (Noritsubushi format)',
			'data.exportCompatHint' => 'Sends the same format as Noritsubushi',
			'data.exportFull' => 'Export CSV (full)',
			'data.exportFullHint' => 'Sends everything, including routes and dates',
			'data.exportedUtf8' => ({required Object name}) => 'Saved as UTF-8 because some characters aren\'t supported in Shift-JIS: ${name}',
			'data.exportFailed' => 'Couldn\'t export',
			'data.exportBackup' => 'Export backup file',
			'data.exportBackupHint' => 'Sends all your rides as a single file',
			'data.restoreFile' => 'Restore from a file',
			'data.restoreFileHint' => 'Choose a backup file you exported',
			'importing.title' => 'Import from Noritsubushi',
			'importing.entryHint' => 'Adds a downloaded CSV to your rides',
			'importing.hint' => 'Choose the CSV you downloaded from the bottom of Noritsubushi\'s record editing page. Both the plain and comment versions work.',
			'importing.choose' => 'Choose file',
			'importing.refused' => ({required Object name}) => 'Not a Noritsubushi CSV: ${name}. Please choose another file.',
			'importing.failed' => 'Couldn\'t import. Your rides haven\'t changed.',
			'importing.undone' => 'Undone. You can pick the removed rides when you import again.',
			'importing.file' => 'File',
			'importing.fresh' => 'New rides',
			'importing.rows' => ({required Object count}) => '${count}',
			'importing.distance' => 'Total distance',
			'importing.existing' => 'Already in your rides',
			'importing.deleted' => 'Also restore deleted rides',
			'importing.missed' => ({required num n, required Object count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: '${count} row with no matching line', other: '${count} rows with no matching line', ), 
			'importing.missedHint' => 'Kept as rides, but they don\'t count toward completion',
			'importing.broken' => ({required num n, required Object count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: '${count} row unreadable', other: '${count} rows unreadable', ), 
			'importing.brokenHint' => 'Malformed rows aren\'t imported',
			'importing.kmDiffers' => ({required num n, required Object count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: '${count} row differs in distance', other: '${count} rows differ in distance', ), 
			'importing.kmDiffersHint' => 'The file\'s distance differs from the app\'s',
			'importing.kmDiffersRow' => ({required Object raw, required Object km}) => '${raw} → app ${km} km',
			'importing.nothing' => 'No new rides to import',
			'importing.confirm' => ({required num n, required Object count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: 'Import ${count} ride', other: 'Import ${count} rides', ), 
			'importing.done' => ({required num n, required Object count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: 'Imported ${count} ride', other: 'Imported ${count} rides', ), 
			'importing.undated' => ({required num n, required Object count}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: '${count} row added without a date', other: '${count} rows added without a date', ), 
			'importing.close' => 'Close',
			'importing.undo' => 'Undo',
			'importing.fullHint' => ({required Object count}) => 'A full noriori export. Only rides you don\'t already have are added (${count} in the file).',
			'importing.merged' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: 'Added ${n} ride', other: 'Added ${n} rides', ), 
			'ticket.completeStamp' => '完乗',
			'ticket.rideStamp' => '乗車',
			'ticket.undo' => 'Undo',
			'ticket.noDate' => 'Date unknown',
			'sources.title' => 'Data sources',
			'sources.intro' => 'Built from facts such as names, distances and dates gathered from several sources. noriori data is released under CC BY-SA 4.0. Track shapes follow the terms of each original source, and only the OSM track file is ODbL 1.0.',
			'sources.n02.name' => '国土数値情報 鉄道データ (N02)',
			'sources.n02.use' => 'Track geometry, station coordinate corrections',
			'sources.n02.terms' => 'MLIT. CC BY 4.0 for editions from 2020; earlier editions under the 国土数値情報 terms of use. 「国土数値情報（鉄道データ）」（国土交通省）を加工して作成。このデータは国土交通省が作成したものではありません。',
			'sources.n05.name' => '国土数値情報 鉄道時系列データ (N05)',
			'sources.n05.use' => 'Track geometry of closed sections missing from N02 and OpenStreetMap',
			'sources.n05.terms' => 'MLIT. 国土数値情報 terms of use (non-commercial). 「国土数値情報（鉄道時系列データ）」（国土交通省）を加工して作成。このデータは国土交通省が作成したものではありません。',
			'sources.n03.name' => 'National Land Numerical Information: Administrative Zones (N03)',
			'sources.n03.use' => 'Outline of Japan, prefecture borders, and per-prefecture distance of sections crossing them',
			'sources.n03.terms' => '「国土数値情報（行政区域データ）」（国土交通省）を加工して作成。このデータは国土交通省が作成したものではありません。',
			'sources.gsi.name' => 'GSI Vector Tiles (Geospatial Information Authority of Japan)',
			'sources.gsi.use' => 'Part of the track shapes around Tabata',
			'sources.gsi.terms' => 'GSI Content Terms of Use (compatible with CC BY 4.0). 出典：国土地理院ベクトルタイル（鉄道中心線）を加工して作成',
			'sources.stationDatabase.name' => 'station_database',
			'sources.stationDatabase.use' => 'Station list and coordinates',
			'sources.stationDatabase.terms' => 'Seo-4d696b75. CC BY-SA 4.0',
			'sources.wikipedia.name' => 'Japanese Wikipedia',
			'sources.wikipedia.use' => 'Line diagrams, connections, closure history, Japanese readings',
			'sources.wikipedia.terms' => 'CC BY-SA 4.0',
			'sources.wikidata.name' => 'Wikidata',
			'sources.wikidata.use' => 'English names, some station coordinates',
			'sources.wikidata.terms' => 'CC0 1.0',
			'sources.namuwiki.name' => 'Namuwiki',
			'sources.namuwiki.use' => 'Korean title spellings. Article text is not used',
			'sources.namuwiki.terms' => 'Site license CC BY-NC-SA 2.0 KR',
			'sources.noritsubushi.name' => 'Noritsubushi',
			'sources.noritsubushi.use' => 'Operating kilometers, station order, key dates, Japanese names',
			'sources.noritsubushi.terms' => 'Factual data only',
			'sources.others.name' => 'Other factual sources',
			'sources.others.use' => 'Operator publications (official English names and more), Public Transportation Open Data Center, public materials of the National Diet Library and the National Archives of Japan, Japan Post postal code data, station sign photos',
			'sources.others.terms' => 'Used as factual data. Each data row records its source, and the full list is in data/NOTICE.md in the repository',
			'sources.openFreeMap.name' => 'OpenFreeMap',
			'sources.openFreeMap.use' => 'Base map',
			'sources.openFreeMap.terms' => 'OpenFreeMap © OpenMapTiles. Data from OpenStreetMap',
			'sources.openStreetMap.name' => 'OpenStreetMap',
			'sources.openStreetMap.use' => 'Track geometry missing from N02',
			'sources.openStreetMap.terms' => '© OpenStreetMap contributors. ODbL 1.0. rail-osm.pmtiles only',
			'sources.noto.name' => 'Noto Sans, Noto Sans CJK',
			'sources.noto.use' => 'Station name lettering on the map',
			'sources.noto.terms' => 'SIL OFL 1.1. Full text in Open source licenses',
			'editRide.saved' => 'Saved',
			'editRide.transfers' => 'Changed trains here',
			'editRide.transfersHint' => 'Pick the stations on this ride where you got off and changed',
			'editRide.title' => 'Edit ride',
			'editRide.missing' => 'Ride not found',
			'editRide.date' => 'Ride date',
			'editRide.times' => 'Departure and arrival times',
			'editRide.train' => 'Train name',
			'editRide.car' => 'Trainset',
			'editRide.note' => 'Note',
			'editRide.fromAlighted' => 'Boarded at the departure station',
			'editRide.toAlighted' => 'Got off at the arrival station',
			'editRide.save' => 'Save',
			'editRide.delete' => 'Delete',
			'editRide.unridable' => 'On that date the line was closed, not yet open or suspended, or trains didn\'t stop at the recorded station. Your ride hasn\'t changed.',
			'editRide.failed' => 'Couldn\'t save. Your rides haven\'t changed',
			'lineDetail.soloMap' => 'Show only this line on the map',
			'lineDetail.current' => 'Current',
			'lineDetail.allTime' => 'All time',
			'lineDetail.km' => ({required Object num, required Object den}) => '${num} / ${den} km',
			'lineDetail.completeCurrent' => 'Completed (current)',
			'lineDetail.selfScore' => 'Not counted in your totals. Progress is based on this line alone',
			'lineDetail.open' => 'Line details',
			'lineDetail.record' => 'Log a ride on this line',
			'lineDetail.clear' => 'Clear all rides on this line',
			'lineDetail.hint' => 'Tap a section to mark it as ridden or not. Long-press and drag to change several at once. Tap a station dot to mark it as visited',
			'lineDetail.sectionRidden' => ({required Object from, required Object to}) => '${from} to ${to}, ridden. Tap to clear',
			'lineDetail.sectionOpen' => ({required Object from, required Object to}) => '${from} to ${to}, not ridden. Tap to mark as ridden',
			'lineDetail.stopNode' => ({required Object name}) => 'Mark visit at ${name}',
			'lineDetail.turnedOff' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: 'Updated ${n} ride', other: 'Updated ${n} rides', ), 
			'lineDetail.turnedOn' => 'Marked as ridden',
			'lineDetail.restored' => 'Ride restored',
			'lineDetail.blockedHidden' => 'This ride would have to be split at a signal station or junction, so this section can\'t be cleared here. Edit the ride instead',
			'lineDetail.blockedPath' => 'Removing this section would change the ride\'s route or date, so it can\'t be cleared here. Edit the ride instead',
			'lineDetail.blockedNoStop' => 'This ride would have to be split at a station where trains in this direction don\'t stop, so this section can\'t be cleared here. Edit the ride instead',
			'lineDetail.blockedOn' => 'This section can\'t be marked as ridden here. Log it from the station picker instead',
			'lineDetail.visitAdded' => 'Marked as visited',
			'lineDetail.visitRemoved' => 'Visit removed',
			'lineDetail.visitByRide' => 'Marked because you boarded or got off here. Edit that ride to change it',
			'lineDetail.undo' => 'Undo',
			'lineDetail.joinsTo' => ({required Object name}) => '${name} →',
			'lineDetail.visitDated' => 'Visit date changed',
			'service.kind' => 'Service',
			'service.none' => 'This service didn\'t run on that date',
			'service.save' => 'Save ride',
			'service.failed' => 'This section can\'t be logged. Please check the date',
			'deleted.fileOldest' => 'Earlier imports',
			'deleted.title' => 'Deleted rides',
			'deleted.empty' => 'No deleted rides',
			'deleted.restore' => 'Restore',
			'deleted.restored' => 'Ride restored',
			'deleted.fileRides' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: '${n} ride', other: '${n} rides', ), 
			'deleted.fileDelete' => 'Delete all',
			'deleted.fileDeleteTitle' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: 'Delete ${n} ride?', other: 'Delete ${n} rides?', ), 
			'deleted.fileDeleteBody' => ({required Object file}) => 'This deletes every ride imported from ${file}. You can bring them back from Deleted rides in Settings.',
			'deleted.fileDeleteConfirm' => 'Delete',
			'deleted.fileDeleteCancel' => 'Cancel',
			'deleted.fileDeleted' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: 'Deleted ${n} ride', other: 'Deleted ${n} rides', ), 
			'complete.credit' => 'Logged with noriori',
			'complete.share' => 'Share',
			'complete.close' => 'Close',
			'collection.title' => 'Collection',
			'collection.lines' => 'Lines',
			'collection.operators' => 'Operators',
			'collection.prefs' => 'Prefectures',
			'collection.stations' => 'Stations',
			'collection.stationGoal' => ({required Object n}) => '${n} stations',
			'collection.empty' => 'Nothing yet',
			'collection.closed' => 'Closed',
			'collection.closedEmpty' => 'None of the sections you rode have closed',
			'collection.closedYear' => ({required Object year}) => 'closed in ${year}',
			'collection.closedAfter' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: '${n} year after your ride', other: '${n} years after your ride', ), 
			'collection.closedTotal' => ({required num n, required Object km}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: '${n} section you can no longer ride · ${km} km', other: '${n} sections you can no longer ride · ${km} km', ), 
			'visits.title' => 'Visited stations',
			'visits.count' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: '${n} station', other: '${n} stations', ), 
			'visits.split' => ({required Object open, required Object closed}) => '${open} open · ${closed} closed',
			'visits.prefs' => ({required Object n}) => '${n} of 47 prefectures',
			'visits.unknown' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: '${n} station with no prefecture', other: '${n} stations with no prefecture', ), 
			'visits.empty' => 'No stations visited yet',
			'remaining.title' => 'Unridden sections',
			'remaining.entry' => 'See suggestions',
			'remaining.shortest' => 'Almost complete',
			'remaining.near' => 'Nearby',
			'remaining.operators' => 'By operator',
			'remaining.empty' => 'No sections left',
			'remaining.nearDenied' => 'Location isn\'t available. Turn it on in Settings',
			'remaining.nearNone' => ({required Object km}) => 'No unridden sections within ${km} km',
			'remaining.nearAway' => ({required Object km}) => '${km} km away',
			'news.title' => 'The rail network has changed',
			'news.history' => 'Network changes',
			'news.ok' => 'OK',
			'news.lineOpened' => ({required Object line, required Object km}) => '${line}: ${km} km opened',
			'news.lineClosed' => ({required Object line, required Object km}) => '${line}: ${km} km closed',
			'news.stationOpened' => ({required Object station, required Object line}) => '${station} station opened (${line})',
			'news.stationClosed' => ({required Object station, required Object line}) => '${station} station closed (${line})',
			'news.more' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: 'and ${n} more', other: 'and ${n} more', ), 
			'news.lineReopened' => ({required Object line, required Object km}) => '${line}: ${km} km opened, so the line is no longer complete',
			'news.rideDistance' => ({required Object line, required Object before, required Object after}) => '${line} ride changed from ${before} km to ${after} km',
			'news.rideReview' => ({required Object line}) => 'Check your ${line} ride',
			'journey.title' => 'Log several lines at once',
			'journey.hint' => 'Pick two stations. noriori finds a route, logs each line and groups them into a trip',
			'journey.from' => 'From',
			'journey.to' => 'To',
			'journey.choose' => 'Choose',
			'journey.save' => 'Log',
			'journey.none' => 'No connecting route found',
			'journey.stationHint' => 'Station name',
			'journey.saved' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: 'Saved ${n} ride', other: 'Saved ${n} rides', ), 
			'years.title' => 'By year',
			'years.activity' => 'Activity',
			'years.distance' => 'Distance',
			'years.count' => 'Rides',
			'years.fresh' => 'New sections',
			'years.busiest' => 'Busiest year',
			'years.undated' => 'No date',
			'years.undatedHint' => 'Not included in the chart or calendar',
			'years.empty' => 'No dated rides yet',
			'years.activityHint' => 'Darker days had more rides',
			'years.noRides' => 'No rides',
			'years.rides' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: '${n} ride', other: '${n} rides', ), 
			'trip.make' => 'Group into a trip',
			'trip.nameTitle' => 'Trip name',
			'trip.nameHint' => 'Kansai trip',
			'trip.save' => 'Save',
			'trip.rename' => 'Rename',
			'trip.dissolve' => 'Ungroup trip',
			'trip.dissolveHint' => 'Removes the group. Your rides stay',
			'trip.dissolved' => 'Trip ungrouped',
			'trip.made' => 'Grouped into a trip',
			'trip.empty' => 'No trips yet',
			'trip.emptyHint' => 'Long-press rides in your log to group them into a trip',
			'trip.rides' => ({required num n}) => (_root.$meta.cardinalResolver ?? PluralResolvers.cardinal('en'))(n, one: '${n} ride', other: '${n} rides', ), 
			'trip.delete' => 'Delete trip and rides',
			'trip.deleteHint' => 'Also deletes the rides in this trip. You can undo for 5 seconds',
			'trip.deleted' => 'Trip and rides deleted',
			'mapSheet.beyond' => 'Closed section beyond this station',
			'mapSheet.unlocated' => 'Exact location unknown',
			'mapSheet.rideCount' => ({required Object count}) => 'Your rides: ${count}',
			'mapSheet.viewSection' => 'View section',
			'mapSheet.unmapped' => 'Not on map',
			'mapSheet.visited' => 'I\'ve been to this station',
			'mapSheet.visitedHint' => 'Doesn\'t count toward completion. It only fills in the dot on the map',
			'mapSheet.noVisits' => 'No station visits yet. Tap a station on the map to add one',
			'mapSheet.pickerLabel' => 'Lines through this spot',
			'mapSheet.partlyClosed' => 'Closed here',
			'mapSheet.closed' => 'Closed line',
			'prefNames.0' => 'Hokkaido',
			'prefNames.1' => 'Aomori',
			'prefNames.2' => 'Iwate',
			'prefNames.3' => 'Miyagi',
			'prefNames.4' => 'Akita',
			'prefNames.5' => 'Yamagata',
			'prefNames.6' => 'Fukushima',
			_ => null,
		} ?? switch (path) {
			'prefNames.7' => 'Ibaraki',
			'prefNames.8' => 'Tochigi',
			'prefNames.9' => 'Gunma',
			'prefNames.10' => 'Saitama',
			'prefNames.11' => 'Chiba',
			'prefNames.12' => 'Tokyo',
			'prefNames.13' => 'Kanagawa',
			'prefNames.14' => 'Niigata',
			'prefNames.15' => 'Toyama',
			'prefNames.16' => 'Ishikawa',
			'prefNames.17' => 'Fukui',
			'prefNames.18' => 'Yamanashi',
			'prefNames.19' => 'Nagano',
			'prefNames.20' => 'Gifu',
			'prefNames.21' => 'Shizuoka',
			'prefNames.22' => 'Aichi',
			'prefNames.23' => 'Mie',
			'prefNames.24' => 'Shiga',
			'prefNames.25' => 'Kyoto',
			'prefNames.26' => 'Osaka',
			'prefNames.27' => 'Hyogo',
			'prefNames.28' => 'Nara',
			'prefNames.29' => 'Wakayama',
			'prefNames.30' => 'Tottori',
			'prefNames.31' => 'Shimane',
			'prefNames.32' => 'Okayama',
			'prefNames.33' => 'Hiroshima',
			'prefNames.34' => 'Yamaguchi',
			'prefNames.35' => 'Tokushima',
			'prefNames.36' => 'Kagawa',
			'prefNames.37' => 'Ehime',
			'prefNames.38' => 'Kochi',
			'prefNames.39' => 'Fukuoka',
			'prefNames.40' => 'Saga',
			'prefNames.41' => 'Nagasaki',
			'prefNames.42' => 'Kumamoto',
			'prefNames.43' => 'Oita',
			'prefNames.44' => 'Miyazaki',
			'prefNames.45' => 'Kagoshima',
			'prefNames.46' => 'Okinawa',
			'date.months.0' => 'Jan',
			'date.months.1' => 'Feb',
			'date.months.2' => 'Mar',
			'date.months.3' => 'Apr',
			'date.months.4' => 'May',
			'date.months.5' => 'Jun',
			'date.months.6' => 'Jul',
			'date.months.7' => 'Aug',
			'date.months.8' => 'Sep',
			'date.months.9' => 'Oct',
			'date.months.10' => 'Nov',
			'date.months.11' => 'Dec',
			'date.day' => ({required Object month, required Object day, required Object year}) => '${month} ${day}, ${year}',
			'date.month' => ({required Object month, required Object year}) => '${month} ${year}',
			_ => null,
		};
	}
}
