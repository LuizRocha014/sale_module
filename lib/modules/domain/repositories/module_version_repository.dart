import 'package:sale_module/modules/data/models/module_version_model.dart';

abstract class IModuleVersionRepository {
  Future<ModuleVersionModel?> getLocal();
  Future<ModuleVersionModel?> updateLocal({required int version});
  Future<int?> insertLocal({required int version});
}
