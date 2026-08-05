import 'dart:io';

import 'package:flower_core/flower_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory project;

  setUp(() async {
    project = await Directory.systemTemp.createTemp('flower_core_test_');
    await File(p.join(project.path, 'pubspec.yaml')).writeAsString('''
name: sample_app
description: A sample Flutter project.
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: any
  go_router: any
  dio: any
  drift: any
dev_dependencies:
  build_runner: any
  mocktail: any
flutter:
  uses-material-design: true
''');
    await Directory(
      p.join(project.path, 'lib', 'features', 'invoices'),
    ).create(recursive: true);
    await Directory(
      p.join(project.path, 'lib', 'features', 'customers'),
    ).create(recursive: true);
    await File(
      p.join(project.path, 'lib', 'features', 'invoices', 'invoice_page.dart'),
    ).writeAsString('''
class InvoiceController {}

final invoiceRoute = GoRoute(
  path: '/invoices',
  name: 'invoices',
  builder: (context, state) => InvoicePage(),
);

class InvoicePage {}
''');
    await File(
      p.join(project.path, 'lib', 'features', 'invoices', 'invoice.g.dart'),
    ).writeAsString('// generated');
    await Directory(p.join(project.path, 'test')).create();
    await File(
      p.join(project.path, 'test', 'invoice_test.dart'),
    ).writeAsString('void main() {}');
  });

  tearDown(() async {
    if (await project.exists()) {
      await project.delete(recursive: true);
    }
  });

  test('inspects project metadata and common Flutter technologies', () async {
    final snapshot = await const ProjectInspector().inspect(project.path);

    expect(snapshot.packageName, 'sample_app');
    expect(snapshot.isFlutterProject, isTrue);
    expect(snapshot.sourceFileCount, 1);
    expect(snapshot.generatedFileCount, 1);
    expect(snapshot.testFileCount, 1);
    expect(snapshot.integrationTestFileCount, 0);
    expect(snapshot.featureNames, <String>['customers', 'invoices']);
    expect(
      snapshot.technologies['state_management'],
      contains('flutter_riverpod'),
    );
    expect(snapshot.technologies['routing'], contains('go_router'));
    expect(snapshot.technologies['networking'], contains('dio'));
    expect(snapshot.technologies['database'], contains('drift'));
    expect(snapshot.symbolCounts['controller'], 1);
    expect(snapshot.routes, hasLength(1));
    expect(snapshot.routes.single.path, '/invoices');
    expect(snapshot.toJson()['schemaVersion'], 2);
    expect(snapshot.warnings, isEmpty);
  });

  test('initialization creates Flower files and preserves AGENTS.md', () async {
    final agentsFile = File(p.join(project.path, 'AGENTS.md'));
    await agentsFile.writeAsString('Existing project instructions.');

    final result = await const ProjectInitializer().initialize(project.path);

    expect(
      result.createdFiles,
      containsAll(<String>[
        p.join('.flower', 'flower.yaml'),
        p.join('.flower', 'context', 'project.md'),
      ]),
    );
    expect(result.skippedFiles, contains('AGENTS.md'));
    expect(await agentsFile.readAsString(), 'Existing project instructions.');
    expect(
      await File(p.join(project.path, '.flower', 'flower.yaml')).readAsString(),
      allOf(
        contains('name: "sample_app"'),
        contains('controller: 1'),
        contains('routes: 1'),
      ),
    );
    expect(
      await File(
        p.join(project.path, '.flower', 'context', 'project.md'),
      ).readAsString(),
      contains('`invoices` via `go_router`'),
    );
  });

  test('reports a missing pubspec as a FlowerException', () async {
    final emptyDirectory = await Directory.systemTemp.createTemp(
      'flower_empty_test_',
    );
    addTearDown(() async {
      if (await emptyDirectory.exists()) {
        await emptyDirectory.delete(recursive: true);
      }
    });

    await expectLater(
      const ProjectInspector().inspect(emptyDirectory.path),
      throwsA(isA<FlowerException>()),
    );
  });
}
