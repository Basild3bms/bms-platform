import '../floors/hierarchy_models.dart';

String? _optionalText(Map<String, dynamic> object, String key) {
  if (!object.containsKey(key)) {
    throw const FormatException('Missing equipment field.');
  }
  final value = object[key];
  if (value == null) return null;
  if (value is String) return value;
  throw const FormatException('Invalid equipment field.');
}

String? _optionalId(Map<String, dynamic> object, String key) {
  final value = _optionalText(object, key);
  return value == null ? null : hierarchyUuid(value);
}

String? _dateOnly(Map<String, dynamic> object, String key) {
  final value = _optionalText(object, key);
  if (value == null) return null;
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    throw const FormatException('Invalid equipment date.');
  }
  final date = DateTime.tryParse(value);
  if (date == null ||
      date.year.toString().padLeft(4, '0') != value.substring(0, 4) ||
      date.month.toString().padLeft(2, '0') != value.substring(5, 7) ||
      date.day.toString().padLeft(2, '0') != value.substring(8, 10)) {
    throw const FormatException('Invalid equipment date.');
  }
  return value;
}

class EquipmentSpecifications {
  const EquipmentSpecifications(this.schemaVersion, this.values);
  final int schemaVersion;
  final Map<String, double> values;
  bool get supported => schemaVersion == 1;

  factory EquipmentSpecifications.fromJson(Object? raw, Object? version) {
    if (version is! int || version < 1 || raw is! Map<String, dynamic>) {
      throw const FormatException('Invalid equipment specifications.');
    }
    if (version != 1) return EquipmentSpecifications(version, const {});
    const allowed = {
      'design_airflow_m3_h',
      'design_flow_m3_h',
      'design_capacity_kw',
      'rated_power_kw'
    };
    final values = <String, double>{};
    for (final entry in raw.entries) {
      final value = entry.value;
      if (!allowed.contains(entry.key) ||
          value is! num ||
          !value.toDouble().isFinite ||
          value > 1000000000 ||
          (entry.key == 'rated_power_kw' ? value < 0 : value <= 0)) {
        throw const FormatException('Invalid equipment specifications.');
      }
      values[entry.key] = value.toDouble();
    }
    return EquipmentSpecifications(version, Map.unmodifiable(values));
  }
}

class EquipmentRecord {
  const EquipmentRecord(
      {required this.id,
      required this.organizationId,
      required this.buildingId,
      required this.floorId,
      required this.zoneId,
      required this.code,
      required this.name,
      required this.description,
      required this.typeCode,
      required this.manufacturer,
      required this.model,
      required this.serialNumber,
      required this.lifecycleStatus,
      required this.installedOn,
      required this.commissionedOn,
      required this.specifications,
      required this.createdAt,
      required this.updatedAt});

  final String id,
      organizationId,
      buildingId,
      code,
      name,
      typeCode,
      lifecycleStatus;
  final String? floorId, zoneId, description, manufacturer, model, serialNumber;
  final String? installedOn, commissionedOn;
  final EquipmentSpecifications? specifications;
  final DateTime createdAt, updatedAt;

  factory EquipmentRecord.fromJson(
      Object? raw, String organizationId, String buildingId,
      {String? floorId, String? zoneId, String? equipmentId}) {
    final object = hierarchyObject(raw);
    final id = hierarchyId(object, 'id');
    final actualFloor = _optionalId(object, 'floor_id');
    final actualZone = _optionalId(object, 'zone_id');
    if (hierarchyId(object, 'organization_id') !=
            hierarchyUuid(organizationId) ||
        hierarchyId(object, 'building_id') != hierarchyUuid(buildingId) ||
        (equipmentId != null && id != hierarchyUuid(equipmentId)) ||
        (floorId != null && actualFloor != hierarchyUuid(floorId)) ||
        (zoneId != null && actualZone != hierarchyUuid(zoneId)) ||
        (actualZone != null && actualFloor == null)) {
      throw const FormatException('Equipment context mismatch.');
    }
    final code = hierarchyText(object, 'code');
    final name = hierarchyText(object, 'name');
    final type = hierarchyText(object, 'type_code');
    final status = hierarchyText(object, 'lifecycle_status');
    if (!RegExp(r'^[A-Z0-9][A-Z0-9_-]*$').hasMatch(code) ||
        code.length > 64 ||
        name.length > 255 ||
        type.length > 255 ||
        status.length > 255) {
      throw const FormatException('Invalid equipment identity.');
    }
    if (!object.containsKey('specifications') ||
        !object.containsKey('spec_schema_version')) {
      throw const FormatException('Missing specifications.');
    }
    final specRaw = object['specifications'];
    final specVersion = object['spec_schema_version'];
    if ((specRaw == null) != (specVersion == null)) {
      throw const FormatException('Invalid specification version.');
    }
    return EquipmentRecord(
        id: id,
        organizationId: hierarchyUuid(organizationId),
        buildingId: hierarchyUuid(buildingId),
        floorId: actualFloor,
        zoneId: actualZone,
        code: code,
        name: name,
        description: _optionalText(object, 'description'),
        typeCode: type,
        manufacturer: _optionalText(object, 'manufacturer'),
        model: _optionalText(object, 'model'),
        serialNumber: _optionalText(object, 'serial_number'),
        lifecycleStatus: status,
        installedOn: _dateOnly(object, 'installed_on'),
        commissionedOn: _dateOnly(object, 'commissioned_on'),
        specifications: specRaw == null
            ? null
            : EquipmentSpecifications.fromJson(specRaw, specVersion),
        createdAt: hierarchyDate(object, 'created_at'),
        updatedAt: hierarchyDate(object, 'updated_at'));
  }
}

class EquipmentPageMeta {
  const EquipmentPageMeta(
      this.currentPage, this.perPage, this.total, this.lastPage);
  final int currentPage, perPage, total, lastPage;
}

class EquipmentListResponse {
  const EquipmentListResponse(this.data, this.meta);
  final List<EquipmentRecord> data;
  final EquipmentPageMeta meta;

  factory EquipmentListResponse.fromJson(
      Object? raw, String organizationId, String buildingId, int requestedPage,
      {String? floorId, String? zoneId}) {
    final page = HierarchyPage<EquipmentRecord>.fromJson(
        raw,
        (item) => EquipmentRecord.fromJson(item, organizationId, buildingId,
            floorId: floorId, zoneId: zoneId),
        idOf: (item) => item.id);
    if (page.currentPage != requestedPage || page.perPage > 100) {
      throw const FormatException('Invalid equipment page.');
    }
    return EquipmentListResponse(
        page.data,
        EquipmentPageMeta(
            page.currentPage, page.perPage, page.total, page.lastPage));
  }
}

class EquipmentDetailResponse {
  const EquipmentDetailResponse(this.data);
  final EquipmentRecord data;

  factory EquipmentDetailResponse.fromJson(Object? raw, String organizationId,
          String buildingId, String equipmentId) =>
      EquipmentDetailResponse(EquipmentRecord.fromJson(
          hierarchyObject(raw)['data'], organizationId, buildingId,
          equipmentId: equipmentId));
}
