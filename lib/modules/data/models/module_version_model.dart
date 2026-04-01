class ModuleVersionModel {
  final int id;
  final int version;

  const ModuleVersionModel({
    required this.id,
    required this.version,
  });

  ModuleVersionModel copyWith({
    int? id,
    int? version,
  }) {
    return ModuleVersionModel(
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

  factory ModuleVersionModel.fromMap(Map<String, dynamic> map) {
    return ModuleVersionModel(
      id: map['id'] as int,
      version: map['version'] as int,
    );
  }
}
