import 'dart:io';

import 'package:flower_core/flower_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory project;

  setUp(() async {
    project = await Directory.systemTemp.createTemp('flower_mapper_test_');
    await File(p.join(project.path, 'pubspec.yaml')).writeAsString('''
name: sample_app
dependencies:
  flutter:
    sdk: flutter
  collection: any
flutter:
  uses-material-design: true
''');

    await _writeProjectFile(
      project,
      'lib/features/invoices/presentation/invoice_page.dart',
      '''
import 'package:flutter/widgets.dart';
import 'package:sample_app/features/invoices/application/invoice_controller.dart';

class InvoicePage {}
''',
    );
    await _writeProjectFile(
      project,
      'lib/features/invoices/application/invoice_controller.dart',
      '''
import '../presentation/invoice_page.dart';
export '../domain/invoice.dart';
part 'invoice_controller.g.dart';

class InvoiceController {}
''',
    );
    await _writeProjectFile(
      project,
      'lib/features/invoices/application/invoice_controller.g.dart',
      "part of 'invoice_controller.dart';\n",
    );
    await _writeProjectFile(
      project,
      'lib/features/invoices/domain/invoice.dart',
      'class Invoice {}\n',
    );
    await _writeProjectFile(
      project,
      'lib/features/customers/domain/customer.dart',
      "import 'package:collection/collection.dart';\nclass Customer {}\n",
    );
    await _writeProjectFile(
      project,
      'test/project_map_test.dart',
      'void main() {}\n',
    );
  });

  tearDown(() async {
    if (await project.exists()) {
      await project.delete(recursive: true);
    }
  });

  test('maps imports, exports, parts, packages, features, and cycles', () async {
    final projectMap = await const ProjectMapper().build(project.path);

    expect(projectMap.packageName, 'sample_app');
    expect(projectMap.nodes, hasLength(5));
    expect(projectMap.edges, hasLength(4));
    expect(projectMap.features, <String>{'customers', 'invoices'});

    final generatedNode = projectMap.nodes.singleWhere(
      (node) => node.path.endsWith('invoice_controller.g.dart'),
    );
    expect(generatedNode.generated, isTrue);
    expect(generatedNode.feature, 'invoices');

    final invoicePage = projectMap.nodes.singleWhere(
      (node) => node.path.endsWith('invoice_page.dart'),
    );
    expect(invoicePage.externalPackages, <String>['flutter']);

    final customer = projectMap.nodes.singleWhere(
      (node) => node.path.endsWith('customer.dart'),
    );
    expect(customer.externalPackages, <String>['collection']);

    expect(
      projectMap.edges,
      contains(
        isA<ProjectMapEdge>()
            .having(
              (edge) => edge.source,
              'source',
              'lib/features/invoices/presentation/invoice_page.dart',
            )
            .having(
              (edge) => edge.target,
              'target',
              'lib/features/invoices/application/invoice_controller.dart',
            )
            .having(
              (edge) => edge.kind,
              'kind',
              ProjectMapEdgeKind.import,
            ),
      ),
    );

    expect(projectMap.cycles, hasLength(1));
    expect(
      projectMap.cycles.single,
      <String>[
        'lib/features/invoices/application/invoice_controller.dart',
        'lib/features/invoices/presentation/invoice_page.dart',
      ],
    );
  });

  test('creates feature-scoped JSON and Mermaid output', () async {
    final projectMap = await const ProjectMapper().build(project.path);
    final invoices = projectMap.forFeature('invoices');

    expect(invoices.nodes, hasLength(4));
    expect(
      invoices.nodes.every((node) => node.feature == 'invoices'),
      isTrue,
    );
    expect(invoices.toJson()['schemaVersion'], ProjectMap.schemaVersion);

    final mermaid = invoices.toMermaid();
    expect(mermaid, startsWith('flowchart LR'));
    expect(mermaid, contains('-->'));
    expect(mermaid, contains('-.->'));
    expect(mermaid, contains('==>'));
    expect(mermaid, contains('classDef cycle'));
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
