import 'package:sale_module/config/di/datasources.dart';
import 'package:sale_module/config/di/repositories.dart';
import 'package:sale_module/config/di/store.dart';
import 'package:sale_module/config/di/usecases.dart';

void initSaleInstances() {
  initDataSourceInstances();
  initRepositoryInstances();
  initUseCasesInstances();
  initStoreInstances();
}
