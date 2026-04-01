import 'package:sale_module/modules/data/datasource/local/module_version_local_datasource.dart';
import 'package:sale_module/modules/data/datasource/remote/module_version_remote_datasource.dart';
import 'package:sale_module/modules/data/models/module_version_model.dart';
import 'package:sale_module/modules/domain/repositories/module_version_repository.dart';

class ModuleVersionRepository implements IModuleVersionRepository {
  final IModuleVersionLocalDataSource _localDatasource;

  ModuleVersionRepository({
    required IModuleVersionLocalDataSource localDatasource,
    required IModuleVersionRemoteDataSource remoteDatasource,
  }) : _localDatasource = localDatasource;

  @override
  Future<ModuleVersionModel?> getLocal() => _localDatasource.getLocal();

  @override
  Future<ModuleVersionModel?> updateLocal({required int version}) =>
      _localDatasource.updateLocal(version: version);

  @override
  Future<int?> insertLocal({required int version}) =>
      _localDatasource.insertLocal(version: version);
}
