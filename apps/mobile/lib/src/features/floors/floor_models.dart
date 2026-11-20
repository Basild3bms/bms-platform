import 'hierarchy_models.dart';

class FloorRecord {
  const FloorRecord(
      {required this.id,
      required this.organizationId,
      required this.buildingId,
      required this.name,
      required this.code,
      required this.level,
      required this.createdAt,
      required this.updatedAt});

  final String id, organizationId, buildingId, name, code;
  final int level;
  final DateTime createdAt, updatedAt;

  factory FloorRecord.fromJson(
      Object? value, String organizationId, String buildingId,
      {String? floorId}) {
    final object = hierarchyObject(value);
    final id = hierarchyId(object, 'id');
    if (hierarchyId(object, 'organization_id') !=
            hierarchyUuid(organizationId) ||
        hierarchyId(object, 'building_id') != hierarchyUuid(buildingId) ||
        (floorId != null && hierarchyUuid(floorId) != id)) {
      throw const FormatException('Floor context mismatch.');
    }
    final level = object['level'];
    if (level is! int || level < -2147483648 || level > 2147483647) {
      throw const FormatException('Invalid floor level.');
    }
    return FloorRecord(
        id: id,
        organizationId: hierarchyUuid(organizationId),
        buildingId: hierarchyUuid(buildingId),
        name: hierarchyText(object, 'name'),
        code: hierarchyText(object, 'code'),
        level: level,
        createdAt: hierarchyDate(object, 'created_at'),
        updatedAt: hierarchyDate(object, 'updated_at'));
  }
}

typedef FloorPage = HierarchyPage<FloorRecord>;
