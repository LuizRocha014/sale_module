# sale_module

Pacote Flutter de **vendas** do ecossistema InOutWareApp. Segue a estrutura inspirada em `create_package` (domain / data / presentation / DI), com **`componentes_lr`** como base para `instanceManager` e widgets compartilhados.

## Dependências

- **`componentes_lr`**: `path: ../../../Flutter_X_Components_Flutter` (irmão da pasta `InOutWareApp` no repositório).
- **`get`**: estado/navegação auxiliar nas telas do módulo.

## Estrutura

```
lib/
  config/
    database/          # SaleDatabaseConfig (placeholder até existir schema)
    di/                # initSaleInstances, datasources, repositories, usecases, store
  modules/
    domain/            # entities, repositories (interfaces), usecases
    data/              # models, repositories (impl), datasources local/remoto, store, tables
    presentation/      # pages, controllers
  sale_module.dart     # export do tables_export
  presentation_export.dart   # export público das telas (uso no app host)
  tables_export.dart
```

## Inicialização (DI)

Chamar no app host:

```dart
import 'package:sale_module/config/di/init_instances.dart';

void main() {
  // ...
  initSaleInstances();
}
```

Ordem interna: `initDataSourceInstances` → `initRepositoryInstances` → `initUseCasesInstances` → `initStoreInstances`.

## Uso no app

No `pubspec.yaml` do aplicativo:

```yaml
dependencies:
  sale_module:
    path: ../packages/sale_module
```

Rotas e telas: ver `presentation_export.dart` (ex.: `SaleHomePage`).

## Banco de dados

Persistência local ainda **não** está ligada: `ModuleVersionLocalDataSource` e `SaleDatabaseConfig` são placeholders até definição de Drift/sqflite e tabelas reais.

## Desenvolvimento

```bash
cd packages/sale_module
flutter pub get
dart analyze
flutter test
```
