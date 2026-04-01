import 'package:get/get.dart';

class ModuleVersionStore {
  final RxInt _version = 0.obs;

  int get version => _version.value;
  set version(int value) => _version.value = value;
}
