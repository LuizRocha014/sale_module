import 'package:componentes_lr/componentes_lr.dart';
import 'package:sale_module/modules/data/datasource/local/module_version_local_datasource.dart';
import 'package:sale_module/modules/data/datasource/remote/module_version_remote_datasource.dart';
import 'package:sale_module/modules/data/datasource/local/sale_local_history_store.dart';
import 'package:sale_module/modules/data/datasource/remote/sale_remote_datasource.dart';
import 'package:sale_module/modules/data/repositories/module_version_repository.dart';
import 'package:sale_module/modules/data/repositories/sale_repository_impl.dart';
import 'package:sale_module/modules/domain/repositories/module_version_repository.dart';
import 'package:sale_module/modules/domain/repositories/sale_repository.dart';

void initRepositoryInstances() {
  instanceManager.registerLazySingleton<IModuleVersionRepository>(
    () => ModuleVersionRepository(
      localDatasource: instanceManager.get<IModuleVersionLocalDataSource>(),
      remoteDatasource: instanceManager.get<IModuleVersionRemoteDataSource>(),
    ),
  );

  instanceManager.registerLazySingleton<ISaleRepository>(
    () => SaleRepositoryImpl(
      instanceManager.get<SaleRemoteDataSource>(),
      instanceManager.get<SaleLocalHistoryStore>(),
    ),
  );
}
