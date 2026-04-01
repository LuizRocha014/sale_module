import 'package:componentes_lr/componentes_lr.dart';
import 'package:sale_module/modules/domain/repositories/module_version_repository.dart';
import 'package:sale_module/modules/domain/usecases/module_version_usecase.dart';

void initUseCasesInstances() {
  instanceManager.registerLazySingleton<IModuleVersionUseCase>(
    () => ModuleVersionUseCase(
      moduleVersionRepository: instanceManager.get<IModuleVersionRepository>(),
    ),
  );
}
