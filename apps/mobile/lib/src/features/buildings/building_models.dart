enum BuildingFailureKind {
  unauthorized,
  forbidden,
  notFound,
  invalidInput,
  rateLimited,
  timeout,
  network,
  server,
  invalidResponse,
}

class BuildingFailure implements Exception {
  const BuildingFailure(this.kind);

  final BuildingFailureKind kind;

  @override
  String toString() => 'BuildingFailure(${kind.name})';
}

Map<String, dynamic> _object(Object? value) {
  if (value is Map<String, dynamic>) return value;
  throw const FormatException('Invalid building response.');
}

String _text(Map<String, dynamic> object, String key) {
  final value = object[key];
  if (value is String && value.isNotEmpty) return value;
  throw const FormatException('Invalid building response.');
}

int _number(Map<String, dynamic> object, String key, int minimum) {
  final value = object[key];
  if (value is int && value >= minimum) return value;
  throw const FormatException('Invalid building response.');
}

class BuildingRecord {
  const BuildingRecord({
    required this.id,
    required this.organizationId,
    required this.name,
    required this.code,
    required this.address,
    required this.timezone,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String organizationId;
  final String name;
  final String code;
  final String? address;
  final String timezone;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory BuildingRecord.fromJson(Object? value, String organizationId,
      {String? buildingId}) {
    final object = _object(value);
    final id = _text(object, 'id');
    if (_text(object, 'organization_id') != organizationId ||
        (buildingId != null && id != buildingId)) {
      throw const FormatException('Building context mismatch.');
    }
    final address = object['address'];
    if (address != null && address is! String) {
      throw const FormatException('Invalid building response.');
    }
    final createdAt = DateTime.tryParse(_text(object, 'created_at'));
    final updatedAt = DateTime.tryParse(_text(object, 'updated_at'));
    if (createdAt == null || updatedAt == null) {
      throw const FormatException('Invalid building response.');
    }
    return BuildingRecord(
      id: id,
      organizationId: organizationId,
      name: _text(object, 'name'),
      code: _text(object, 'code'),
      address: address as String?,
      timezone: _text(object, 'timezone'),
      createdAt: createdAt.toUtc(),
      updatedAt: updatedAt.toUtc(),
    );
  }
}

class BuildingPage {
  const BuildingPage({
    required this.data,
    required this.currentPage,
    required this.perPage,
    required this.total,
    required this.lastPage,
  });

  final List<BuildingRecord> data;
  final int currentPage;
  final int perPage;
  final int total;
  final int lastPage;

  bool get hasMore => currentPage < lastPage;

  factory BuildingPage.fromJson(Object? value, String organizationId) {
    final object = _object(value);
    final rawData = object['data'];
    if (rawData is! List) {
      throw const FormatException('Invalid building response.');
    }
    final meta = _object(object['meta']);
    final currentPage = _number(meta, 'current_page', 1);
    final perPage = _number(meta, 'per_page', 1);
    final total = _number(meta, 'total', 0);
    final lastPage = _number(meta, 'last_page', 1);
    if (rawData.length > perPage) {
      throw const FormatException('Invalid building response.');
    }
    return BuildingPage(
      data: List.unmodifiable(
          rawData.map((item) => BuildingRecord.fromJson(item, organizationId))),
      currentPage: currentPage,
      perPage: perPage,
      total: total,
      lastPage: lastPage,
    );
  }
}
