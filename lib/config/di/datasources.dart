import 'package:componentes_lr/componentes_lr.dart';
import 'package:sale_module/config/database/sale_database_config.dart';
import 'package:sale_module/modules/data/datasource/local/module_version_local_datasource.dart';
import 'package:sale_module/modules/data/datasource/local/sale_local_history_store.dart';
import 'package:sale_module/modules/data/datasource/remote/module_version_remote_datasource.dart';
import 'package:sale_module/modules/data/datasource/remote/sale_remote_datasource.dart';
import 'package:stock_module/modules/data/stock_api_settings.dart';

void initDataSourceInstances() {
  instanceManager.registerLazySingleton<SaleDatabaseConfig>(
    () => const SaleDatabaseConfig(),
  );

  instanceManager.registerLazySingleton<IModuleVersionRemoteDataSource>(
    () => ModuleVersionRemoteDataSource(),
  );

  instanceManager.registerLazySingleton<IModuleVersionLocalDataSource>(
    () => ModuleVersionLocalDataSource(
      database: instanceManager.get<SaleDatabaseConfig>(),
    ),
  );

  instanceManager.registerLazySingleton<SaleRemoteDataSource>(
    () => SaleRemoteDataSource(
      settings: instanceManager.get<StockApiSettings>(),
    ),
  );

  instanceManager.registerLazySingleton<SaleLocalHistoryStore>(
    () => SaleLocalHistoryStore(),
  );
}
