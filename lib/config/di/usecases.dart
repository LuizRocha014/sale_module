import 'package:componentes_lr/componentes_lr.dart';
import 'package:sale_module/modules/domain/repositories/module_version_repository.dart';
import 'package:sale_module/modules/domain/repositories/sale_repository.dart';
import 'package:sale_module/modules/domain/usecases/module_version_usecase.dart';
import 'package:sale_module/modules/domain/usecases/register_sale_usecase.dart';
import 'package:sale_module/modules/domain/usecases/sale_history_usecases.dart';

void initUseCasesInstances() {
  instanceManager.registerLazySingleton<IModuleVersionUseCase>(
    () => ModuleVersionUseCase(
      moduleVersionRepository: instanceManager.get<IModuleVersionRepository>(),
    ),
  );

  instanceManager.registerLazySingleton<RegisterSaleUseCase>(
    () => RegisterSaleUseCase(
      instanceManager.get<ISaleRepository>(),
    ),
  );

  instanceManager.registerLazySingleton<LoadSaleHistoryUseCase>(
    () => LoadSaleHistoryUseCase(
      instanceManager.get<ISaleRepository>(),
    ),
  );

  instanceManager.registerLazySingleton<GetSaleDetailUseCase>(
    () => GetSaleDetailUseCase(
      instanceManager.get<ISaleRepository>(),
    ),
  );

  instanceManager.registerLazySingleton<AppendLocalSaleRecordUseCase>(
    () => AppendLocalSaleRecordUseCase(
      instanceManager.get<ISaleRepository>(),
    ),
  );
}
