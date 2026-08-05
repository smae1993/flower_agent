import 'dart:io';

import 'package:flower_core/flower_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory project;

  setUp(() async {
    project = await Directory.systemTemp.createTemp('flower_symbols_test_');
    await File(p.join(project.path, 'pubspec.yaml')).writeAsString('''
name: symbol_sample
dependencies:
  flutter:
    sdk: flutter
flutter:
  uses-material-design: true
''');

    await _writeProjectFile(
      project,
      'lib/features/invoices/data/invoice_repository.dart',
      '''
abstract class InvoiceRepository {}

class InvoiceRepositoryImpl implements InvoiceRepository {}

class InvoiceRemoteDataSource {}

class InvoiceDao {}
''',
    );
    await _writeProjectFile(
      project,
      'lib/features/invoices/application/invoice_controller.dart',
      '''
class StateNotifier<T> {}

class InvoiceController extends StateNotifier<int> {}

final invoiceProvider = Provider((ref) => InvoiceController());

@riverpod
Future<int> invoiceTotal(InvoiceTotalRef ref) async => 0;
''',
    );
    await _writeProjectFile(
      project,
      'lib/core/services/api_service.dart',
      'class ApiService {}\n',
    );
    await _writeProjectFile(
      project,
      'lib/app_router.dart',
      '''
final routes = <Object>[
  GoRoute(
    path: '/invoices',
    name: 'invoices',
    builder: (context, state) => InvoicePage(),
  ),
  AutoRoute(path: '/settings', page: SettingsRoute.page),
  GetPage(name: '/login', page: () => LoginPage()),
];
''',
    );
    await _writeProjectFile(
      project,
      'lib/features/invoices/application/invoice_controller.g.dart',
      '// generated provider output\n',
    );
  });

  tearDown(() async {
    if (await project.exists()) {
      await project.delete(recursive: true);
    }
  });

  test('indexes architecture roles and excludes generated files', () async {
    final index = await const ProjectSymbolIndexer().build(project.path);

    expect(index.packageName, 'symbol_sample');
    expect(index.symbols, hasLength(8));
    expect(index.counts[ProjectSymbolKind.repository], 2);
    expect(index.counts[ProjectSymbolKind.dataSource], 2);
    expect(index.counts[ProjectSymbolKind.service], 1);
    expect(index.counts[ProjectSymbolKind.controller], 1);
    expect(index.counts[ProjectSymbolKind.provider], 2);
    expect(
      index.symbols.any(
        (symbol) => symbol.path.endsWith('invoice_controller.g.dart'),
      ),
      isFalse,
    );

    final controller = index.symbols.singleWhere(
      (symbol) => symbol.name == 'InvoiceController',
    );
    expect(controller.kind, ProjectSymbolKind.controller);
    expect(controller.feature, 'invoices');
    expect(controller.metadata['supertypes'], 'StateNotifier<int>');

    final generatedProvider = index.symbols.singleWhere(
      (symbol) => symbol.name == 'invoiceTotal',
    );
    expect(generatedProvider.kind, ProjectSymbolKind.provider);
    expect(generatedProvider.metadata['annotation'], 'riverpod');
  });

  test('extracts routes from supported router constructors', () async {
    final index = await const ProjectSymbolIndexer().build(project.path);

    expect(index.routes, hasLength(3));

    final goRoute = index.routes.singleWhere(
      (route) => route.router == 'go_router',
    );
    expect(goRoute.path, '/invoices');
    expect(goRoute.name, 'invoices');
    expect(goRoute.declaration, contains('InvoicePage'));

    final autoRoute = index.routes.singleWhere(
      (route) => route.router == 'auto_route',
    );
    expect(autoRoute.path, '/settings');
    expect(autoRoute.declaration, 'SettingsRoute.page');

    final getRoute = index.routes.singleWhere((route) => route.router == 'get');
    expect(getRoute.path, '/login');
    expect(getRoute.name, isNull);
  });

  test('filters symbols and routes by kind and feature', () async {
    final index = await const ProjectSymbolIndexer().build(project.path);
    final repositories = index.filtered(
      kind: ProjectSymbolKind.repository,
      feature: 'invoices',
    );

    expect(repositories.symbols, hasLength(2));
    expect(
      repositories.symbols.every(
        (symbol) => symbol.kind == ProjectSymbolKind.repository,
      ),
      isTrue,
    );
    expect(repositories.routes, isEmpty);
    expect(repositories.toJson()['schemaVersion'], ProjectSymbolIndex.schemaVersion);
  });
}

Future<void> _writeProjectFile(
  Directory project,
  String relativePath,
  String content,
) async {
  final file = File(p.join(project.path, relativePath));
  await file.parent.create(recursive: true);
  await file.writeAsString(content);
}
