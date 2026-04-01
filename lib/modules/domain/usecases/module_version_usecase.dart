import 'package:sale_module/modules/domain/repositories/module_version_repository.dart';

abstract class IModuleVersionUseCase {}

class ModuleVersionUseCase implements IModuleVersionUseCase {
  // ignore: unused_field
  final IModuleVersionRepository _moduleVersionRepository;

  ModuleVersionUseCase({
    required IModuleVersionRepository moduleVersionRepository,
  }) : _moduleVersionRepository = moduleVersionRepository;
}
