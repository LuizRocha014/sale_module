import 'package:sale_module/config/database/sale_database_config.dart';
import 'package:sale_module/modules/data/models/module_version_model.dart';

abstract class IModuleVersionLocalDataSource {
  Future<ModuleVersionModel?> getLocal();
  Future<ModuleVersionModel?> updateLocal({required int version});
  Future<int?> insertLocal({required int version});
}

/// Implementação local será conectada ao banco (Drift/sqflite) depois.
class ModuleVersionLocalDataSource implements IModuleVersionLocalDataSource {
  ModuleVersionLocalDataSource({required SaleDatabaseConfig database});

  @override
  Future<ModuleVersionModel?> getLocal() async {
    throw UnimplementedError('Persistência local ainda não configurada.');
  }

  @override
  Future<ModuleVersionModel?> updateLocal({required int version}) async {
    throw UnimplementedError('Persistência local ainda não configurada.');
  }

  @override
  Future<int?> insertLocal({required int version}) async {
    throw UnimplementedError('Persistência local ainda não configurada.');
  }
}
