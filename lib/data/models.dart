/// Typed models for the conference data stored in Cloud Firestore
/// (`conference/main`, `people/{email}`, `couponIndex/{couponId}`).
///
/// Every constructor validates its input and throws [DataException] with the
/// path of the first problem, so malformed data fails loudly instead of
/// rendering half-empty screens.
library;

class DataException implements Exception {
  DataException(this.message);

  final String message;

  @override
  String toString() => 'DataException: $message';
}

typedef Json = Map<String, dynamic>;

String _str(Json json, String key, String path) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) return value;
  throw DataException('Missing or empty text field "$path.$key"');
}

String? _optStr(Json json, String key, String path) {
  final value = json[key];
  if (value == null) return null;
  if (value is String) return value.trim().isEmpty ? null : value;
  throw DataException('Field "$path.$key" must be text or null');
}

int _int(Json json, String key, String path) {
  final value = json[key];
  if (value is int) return value;
  if (value is num && value == value.roundToDouble()) return value.toInt();
  throw DataException('Missing or non-integer field "$path.$key"');
}

int? _optInt(Json json, String key, String path) =>
    json[key] == null ? null : _int(json, key, path);

bool _bool(Json json, String key, String path) {
  final value = json[key];
  if (value is bool) return value;
  throw DataException('Missing or non-boolean field "$path.$key"');
}

Json _obj(Json json, String key, String path) {
  final value = json[key];
  if (value is Map) return Map<String, dynamic>.from(value);
  throw DataException('Missing object "$path.$key"');
}

Json? _optObj(Json json, String key, String path) =>
    json[key] == null ? null : _obj(json, key, path);

List<T> _list<T>(
  Json json,
  String key,
  String path,
  T Function(dynamic item, String itemPath) parse,
) {
  final value = json[key];
  if (value == null) return const [];
  if (value is! List) throw DataException('Field "$path.$key" must be a list');
  return [
    for (var i = 0; i < value.length; i++) parse(value[i], '$path.$key[$i]'),
  ];
}

Json _asObj(dynamic item, String path) {
  if (item is Map) return Map<String, dynamic>.from(item);
  throw DataException('"$path" must be an object');
}

String _asStr(dynamic item, String path) {
  if (item is String) return item;
  throw DataException('"$path" must be text');
}

/// Workbook "Yes"/"No" cells, matched case-insensitively. Null if absent.
bool? _optYesNo(Json json, String key, String path) {
  final raw = _optStr(json, key, path);
  if (raw == null) return null;
  final value = raw.trim().toLowerCase();
  if (value == 'yes') return true;
  if (value == 'no') return false;
  throw DataException('Field "$path.$key" must be "Yes" or "No"');
}

/// What someone does at the congress.
enum Role {
  presenter,
  attendee,
  speaker,
  vip,
  organiser,
  volunteer;

  static Role parse(String value, String path) => Role.values.firstWhere(
    (r) => r.name == value,
    orElse: () => throw DataException('Unknown role "$value" at $path'),
  );

  /// Volunteers and organisers run the meal desk.
  bool get isStaff => this == volunteer || this == organiser;
}

class Conference {
  Conference({
    required this.name,
    required this.shortName,
    required this.notInWorkbook,
    required this.categories,
    required this.presentationTypes,
    required this.totals,
    required this.disciplines,
    required this.schedule,
  });

  factory Conference.fromJson(Json json, [String path = 'conference']) {
    final types = _obj(json, 'presentationTypes', path);
    return Conference(
      name: _str(json, 'name', path),
      shortName: _str(json, 'shortName', path),
      notInWorkbook: _list(json, 'notInWorkbook', path, _asStr),
      categories: _list(json, 'categories', path, _asStr),
      presentationTypes: {
        for (final e in types.entries)
          e.key: _asStr(e.value, '$path.presentationTypes.${e.key}'),
      },
      totals: ConferenceTotals.fromJson(
        _obj(json, 'totals', path),
        '$path.totals',
      ),
      disciplines: _list(
        json,
        'disciplines',
        path,
        (item, p) => DisciplineSummary.fromJson(_asObj(item, p), p),
      ),
      schedule: _list(
        json,
        'schedule',
        path,
        (item, p) => ScheduleItem.fromJson(_asObj(item, p), p),
      ),
    );
  }

  final String name;
  final String shortName;

  /// Conference facts not yet published (shown as "to be announced").
  final List<String> notInWorkbook;
  final List<String> categories;
  final Map<String, String> presentationTypes;
  final ConferenceTotals totals;
  final List<DisciplineSummary> disciplines;

  /// Sessions for everyone.
  final List<ScheduleItem> schedule;
}

class ConferenceTotals {
  ConferenceTotals({
    required this.oral,
    required this.poster,
    required this.abstracts,
  });

  factory ConferenceTotals.fromJson(Json json, String path) => ConferenceTotals(
    oral: _int(json, 'oral', path),
    poster: _int(json, 'poster', path),
    abstracts: _int(json, 'abstracts', path),
  );

  final int oral;
  final int poster;
  final int abstracts;
}

class DisciplineSummary {
  DisciplineSummary({
    required this.srNo,
    required this.name,
    required this.oral,
    required this.poster,
    required this.abstracts,
  });

  factory DisciplineSummary.fromJson(Json json, String path) =>
      DisciplineSummary(
        srNo: _int(json, 'srNo', path),
        name: _str(json, 'name', path),
        oral: _int(json, 'oral', path),
        poster: _int(json, 'poster', path),
        abstracts: _int(json, 'abstracts', path),
      );

  final int srNo;
  final String name;
  final int oral;
  final int poster;
  final int abstracts;
}

/// Anyone registered for the congress, in any [Role].
class Person {
  Person({
    required this.role,
    required this.registrationId,
    required this.passId,
    required this.registrationStatus,
    required this.fullName,
    required this.email,
    required this.mobile,
    required this.affiliation,
    this.designation,
    this.workingAs,
    this.district,
    this.discipline,
    this.disciplineShort,
    this.category,
    this.presentationType,
    this.registrationFee,
    this.feesReceived,
    this.softCopy,
    this.accommodation,
    this.earlierAwardee,
    this.paper,
    this.talk,
    this.host,
    this.duties = const [],
    this.personalSchedule = const [],
    this.coupons = const [],
  });

  factory Person.fromJson(Json json, [String path = 'person']) {
    final presentationType = _optStr(json, 'presentationType', path);
    if (presentationType != null &&
        presentationType != 'O' &&
        presentationType != 'P') {
      throw DataException('"$path.presentationType" must be "O" or "P"');
    }
    final paper = _optObj(json, 'paper', path);
    final talk = _optObj(json, 'talk', path);
    final host = _optObj(json, 'host', path);
    return Person(
      role: Role.parse(_str(json, 'role', path), '$path.role'),
      registrationId: _str(json, 'registrationId', path),
      passId: _str(json, 'passId', path),
      registrationStatus: _str(json, 'registrationStatus', path),
      fullName: _str(json, 'fullName', path),
      email: _str(json, 'email', path).toLowerCase(),
      mobile: _str(json, 'mobile', path),
      affiliation: _str(json, 'affiliation', path),
      designation: _optStr(json, 'designation', path),
      workingAs: _optStr(json, 'workingAs', path),
      district: _optStr(json, 'district', path),
      discipline: _optStr(json, 'discipline', path),
      disciplineShort: _optStr(json, 'disciplineShort', path),
      category: _optStr(json, 'category', path),
      presentationType: presentationType,
      registrationFee: _optInt(json, 'registrationFee', path),
      feesReceived: _optStr(json, 'feesReceived', path),
      softCopy: _optYesNo(json, 'softCopy', path),
      accommodation: _optYesNo(json, 'accommodation', path),
      earlierAwardee: _optYesNo(json, 'earlierAwardee', path),
      paper: paper == null ? null : Paper.fromJson(paper, '$path.paper'),
      talk: talk == null ? null : Talk.fromJson(talk, '$path.talk'),
      host: host == null ? null : Host.fromJson(host, '$path.host'),
      duties: _list(json, 'duties', path, _asStr),
      personalSchedule: _list(
        json,
        'personalSchedule',
        path,
        (item, p) => ScheduleItem.fromJson(_asObj(item, p), p),
      ),
      coupons: _list(
        json,
        'coupons',
        path,
        (item, p) => FoodCoupon.fromJson(_asObj(item, p), p),
      ),
    );
  }

  final Role role;
  final String registrationId;

  /// The only value encoded in the QR pass.
  final String passId;
  final String registrationStatus;
  final String fullName;
  final String email;
  final String mobile;
  final String affiliation;

  /// e.g. "Plenary speaker", "Guest of Honour", "Meal desk volunteer".
  final String? designation;
  final String? workingAs;

  /// Two-letter district code as written in the workbook (e.g. `DN`).
  final String? district;
  final String? discipline;
  final String? disciplineShort;

  /// Workbook `CT.` code (I–IV), presenters only.
  final String? category;

  /// Workbook `O/P` code, presenters only.
  final String? presentationType;
  final int? registrationFee;
  final String? feesReceived;
  final bool? softCopy;
  final bool? accommodation;
  final bool? earlierAwardee;
  final Paper? paper;
  final Talk? talk;

  /// VIP liaison.
  final Host? host;

  /// Staff responsibilities.
  final List<String> duties;

  /// Sessions specific to this person (their talk, duties, …).
  final List<ScheduleItem> personalSchedule;
  final List<FoodCoupon> coupons;

  String? get presentationLabel => switch (presentationType) {
    'O' => 'Oral',
    'P' => 'Poster',
    _ => null,
  };

  /// Mobile number with all but the last four digits hidden.
  String get maskedMobile {
    if (mobile.length <= 4) return mobile;
    return '${'•' * (mobile.length - 4)}${mobile.substring(mobile.length - 4)}';
  }

  String get initials => fullName
      .replaceAll(RegExp(r'^(Dr|Prof|Shri|Smt|Mr|Ms|Mrs)\.?\s+'), '')
      .split(' ')
      .where((s) => s.isNotEmpty)
      .take(2)
      .map((s) => s[0].toUpperCase())
      .join();

  /// Conference sessions plus this person's own items, in time order.
  List<ScheduleItem> scheduleWith(Conference conference) {
    final items = [...conference.schedule, ...personalSchedule];
    items.sort((a, b) {
      final day = a.day.compareTo(b.day);
      return day != 0 ? day : a.start.compareTo(b.start);
    });
    return items;
  }
}

class Paper {
  Paper({
    required this.submissionId,
    required this.title,
    required this.abstractText,
    required this.authors,
  });

  factory Paper.fromJson(Json json, String path) => Paper(
    submissionId: _str(json, 'submissionId', path),
    title: _str(json, 'title', path),
    abstractText: _optStr(json, 'abstractText', path),
    authors: _list(
      json,
      'authors',
      path,
      (item, p) => Author.fromJson(_asObj(item, p), p),
    ),
  );

  final String submissionId;
  final String title;
  final String? abstractText;
  final List<Author> authors;
}

class Author {
  Author({
    required this.name,
    required this.affiliation,
    required this.role,
    required this.isParticipant,
  });

  factory Author.fromJson(Json json, String path) => Author(
    name: _str(json, 'name', path),
    affiliation: _optStr(json, 'affiliation', path),
    role: _str(json, 'role', path),
    isParticipant: _bool(json, 'isParticipant', path),
  );

  final String name;
  final String? affiliation;
  final String role;
  final bool isParticipant;
}

/// A speaker's lecture.
class Talk {
  Talk({
    required this.title,
    required this.session,
    required this.day,
    required this.start,
    required this.end,
    required this.venue,
    this.abstract,
  });

  factory Talk.fromJson(Json json, String path) => Talk(
    title: _str(json, 'title', path),
    session: _str(json, 'session', path),
    day: _str(json, 'day', path),
    start: _str(json, 'start', path),
    end: _str(json, 'end', path),
    venue: _str(json, 'venue', path),
    abstract: _optStr(json, 'abstract', path),
  );

  final String title;
  final String session;
  final String day;
  final String start;
  final String end;
  final String venue;
  final String? abstract;
}

/// The organiser looking after a VIP.
class Host {
  Host({required this.name, required this.role, this.mobile});

  factory Host.fromJson(Json json, String path) => Host(
    name: _str(json, 'name', path),
    role: _str(json, 'role', path),
    mobile: _optStr(json, 'mobile', path),
  );

  final String name;
  final String role;
  final String? mobile;
}

class ScheduleItem {
  ScheduleItem({
    required this.day,
    required this.start,
    required this.end,
    required this.title,
    required this.venue,
    required this.kind,
    required this.isOwnPresentation,
  });

  factory ScheduleItem.fromJson(Json json, String path) => ScheduleItem(
    day: _str(json, 'day', path),
    start: _str(json, 'start', path),
    end: _str(json, 'end', path),
    title: _str(json, 'title', path),
    venue: _optStr(json, 'venue', path),
    kind: _str(json, 'kind', path),
    isOwnPresentation: _bool(json, 'isOwnPresentation', path),
  );

  final String day;
  final String start;
  final String end;
  final String title;
  final String? venue;

  /// `general`, `session`, `presentation` or `personal`.
  final String kind;

  /// True for items that belong to this person (talk, duty, presentation).
  final bool isOwnPresentation;
}

class FoodCoupon {
  FoodCoupon({
    required this.couponId,
    required this.day,
    required this.meal,
    required this.window,
  });

  factory FoodCoupon.fromJson(Json json, String path) => FoodCoupon(
    couponId: _str(json, 'couponId', path),
    day: _str(json, 'day', path),
    meal: _str(json, 'meal', path),
    window: _str(json, 'window', path),
  );

  final String couponId;
  final String day;
  final String meal;
  final String window;
}

/// A scanned coupon resolved through `couponIndex/{couponId}`.
class IssuedCoupon {
  IssuedCoupon({
    required this.coupon,
    required this.ownerEmail,
    required this.ownerName,
    required this.registrationId,
    required this.role,
  });

  factory IssuedCoupon.fromJson(Json json, [String path = 'couponIndex']) =>
      IssuedCoupon(
        coupon: FoodCoupon.fromJson(json, path),
        ownerEmail: _str(json, 'email', path).toLowerCase(),
        ownerName: _str(json, 'fullName', path),
        registrationId: _str(json, 'registrationId', path),
        role: Role.parse(_str(json, 'role', path), '$path.role'),
      );

  factory IssuedCoupon.of(Person person, FoodCoupon coupon) => IssuedCoupon(
    coupon: coupon,
    ownerEmail: person.email,
    ownerName: person.fullName,
    registrationId: person.registrationId,
    role: person.role,
  );

  final FoodCoupon coupon;
  final String ownerEmail;
  final String ownerName;
  final String registrationId;
  final Role role;
}
