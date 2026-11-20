import 'package:dio/dio.dart';

import '../buildings/building_models.dart';

Map<String, dynamic> hierarchyObject(Object? value) {
  if (value is Map<String, dynamic>) return value;
  throw const FormatException('Invalid hierarchy response.');
}

String hierarchyText(Map<String, dynamic> value, String key) {
  final field = value[key];
  if (field is String && field.isNotEmpty) return field;
  throw const FormatException('Invalid hierarchy response.');
}

final RegExp _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false);

String hierarchyUuid(String value) {
  if (!_uuid.hasMatch(value)) {
    throw const FormatException('Invalid hierarchy identifier.');
  }
  return value.toLowerCase();
}

String hierarchyId(Map<String, dynamic> value, String key) =>
    hierarchyUuid(hierarchyText(value, key));

DateTime hierarchyDate(Map<String, dynamic> value, String key) {
  final parsed = DateTime.tryParse(hierarchyText(value, key));
  if (parsed == null) throw const FormatException('Invalid hierarchy date.');
  return parsed.toUtc();
}

int hierarchyNumber(Map<String, dynamic> value, String key, int minimum) {
  final field = value[key];
  if (field is int && field >= minimum) return field;
  throw const FormatException('Invalid hierarchy pagination.');
}

class HierarchyPage<T> {
  const HierarchyPage(
      {required this.data,
      required this.currentPage,
      required this.perPage,
      required this.total,
      required this.lastPage});

  final List<T> data;
  final int currentPage;
  final int perPage;
  final int total;
  final int lastPage;
  bool get hasMore => currentPage < lastPage;

  factory HierarchyPage.fromJson(Object? value, T Function(Object?) parse,
      {String Function(T)? idOf}) {
    final body = hierarchyObject(value);
    final raw = body['data'];
    if (raw is! List) throw const FormatException('Invalid hierarchy list.');
    final meta = hierarchyObject(body['meta']);
    final current = hierarchyNumber(meta, 'current_page', 1);
    final perPage = hierarchyNumber(meta, 'per_page', 1);
    final total = hierarchyNumber(meta, 'total', 0);
    final last = hierarchyNumber(meta, 'last_page', 1);
    final expectedLast = total == 0 ? 1 : (total + perPage - 1) ~/ perPage;
    if (raw.length > perPage ||
        raw.length > total ||
        current > last ||
        last != expectedLast ||
        (current < last && raw.length != perPage)) {
      throw const FormatException('Invalid hierarchy pagination.');
    }
    final parsed = List<T>.unmodifiable(raw.map(parse));
    if (idOf != null) {
      final ids = parsed.map(idOf).toSet();
      if (ids.length != parsed.length) {
        throw const FormatException('Duplicate hierarchy resource.');
      }
    }
    return HierarchyPage(
        data: parsed,
        currentPage: current,
        perPage: perPage,
        total: total,
        lastPage: last);
  }
}

Future<T> safeHierarchyRead<T>(Future<T> Function() request) async {
  try {
    return await request();
  } on FormatException {
    throw const BuildingFailure(BuildingFailureKind.invalidResponse);
  } on DioException catch (error) {
    if (error.type == DioExceptionType.cancel) rethrow;
    final status = error.response?.statusCode;
    final kind = switch (status) {
      401 => BuildingFailureKind.unauthorized,
      403 => BuildingFailureKind.forbidden,
      404 => BuildingFailureKind.notFound,
      422 => BuildingFailureKind.invalidInput,
      429 => BuildingFailureKind.rateLimited,
      int() => BuildingFailureKind.server,
      _
          when error.type == DioExceptionType.connectionTimeout ||
              error.type == DioExceptionType.sendTimeout ||
              error.type == DioExceptionType.receiveTimeout =>
        BuildingFailureKind.timeout,
      _ => BuildingFailureKind.network,
    };
    throw BuildingFailure(kind);
  }
}
