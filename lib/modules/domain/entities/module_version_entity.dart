import 'package:sale_module/modules/data/models/module_version_model.dart';

class ModuleVersionEntity {
  final int id;
  final int version;

  const ModuleVersionEntity({
    required this.id,
    required this.version,
  });

  ModuleVersionEntity copyWith({
    int? id,
    int? version,
  }) {
    return ModuleVersionEntity(
      id: id ?? this.id,
      version: version ?? this.version,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'version': version,
    };
  }

  factory ModuleVersionEntity.fromModel(ModuleVersionModel model) {
    return ModuleVersionEntity(
      id: model.id,
      version: model.version,
    );
  }
}
