import '../floors/hierarchy_models.dart';

enum ZoneType { office, plantRoom, common, retail, storage, other }

class ZoneRecord {
  const ZoneRecord(
      {required this.id,
      required this.organizationId,
      required this.buildingId,
      required this.floorId,
      required this.name,
      required this.code,
      required this.zoneType,
      required this.createdAt,
      required this.updatedAt});

  final String id, organizationId, buildingId, floorId, name, code;
  final ZoneType zoneType;
  final DateTime createdAt, updatedAt;

  factory ZoneRecord.fromJson(
      Object? value, String organizationId, String buildingId, String floorId,
      {String? zoneId}) {
    final object = hierarchyObject(value);
    final id = hierarchyId(object, 'id');
    if (hierarchyId(object, 'organization_id') !=
            hierarchyUuid(organizationId) ||
        hierarchyId(object, 'building_id') != hierarchyUuid(buildingId) ||
        hierarchyId(object, 'floor_id') != hierarchyUuid(floorId) ||
        (zoneId != null && hierarchyUuid(zoneId) != id)) {
      throw const FormatException('Zone context mismatch.');
    }
    final type = switch (hierarchyText(object, 'zone_type')) {
      'office' => ZoneType.office,
      'plant_room' => ZoneType.plantRoom,
      'common' => ZoneType.common,
      'retail' => ZoneType.retail,
      'storage' => ZoneType.storage,
      'other' => ZoneType.other,
      _ => throw const FormatException('Invalid zone type.'),
    };
    return ZoneRecord(
        id: id,
        organizationId: hierarchyUuid(organizationId),
        buildingId: hierarchyUuid(buildingId),
        floorId: hierarchyUuid(floorId),
        name: hierarchyText(object, 'name'),
        code: hierarchyText(object, 'code'),
        zoneType: type,
        createdAt: hierarchyDate(object, 'created_at'),
        updatedAt: hierarchyDate(object, 'updated_at'));
  }
}

typedef ZonePage = HierarchyPage<ZoneRecord>;
