import 'dart:io';

import 'package:flower_core/flower_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory project;

  setUp(() async {
    project = await Directory.systemTemp.createTemp('flower_context_test_');
    await File(p.join(project.path, 'pubspec.yaml')).writeAsString('''
name: context_sample
dependencies:
  flutter:
    sdk: flutter
flutter:
  uses-material-design: true
''');

    await _writeProjectFile(project, 'lib/main.dart', '''
import 'app_router.dart';

void main() {}
''');
    await _writeProjectFile(project, 'lib/app_router.dart', '''
import 'features/invoices/presentation/invoice_page.dart';

final invoiceRoute = GoRoute(
  path: '/invoices',
  name: 'invoices',
  builder: (context, state) => InvoicePage(),
);
''');
    await _writeProjectFile(
      project,
      'lib/features/invoices/domain/invoice.dart',
      'class Invoice {}\n',
    );
    await _writeProjectFile(
      project,
      'lib/features/invoices/data/invoice_repository.dart',
      '''
import '../domain/invoice.dart';

abstract class InvoiceRepository {}
''',
    );
    await _writeProjectFile(
      project,
      'lib/features/invoices/application/invoice_controller.dart',
      '''
import '../data/invoice_repository.dart';

class InvoiceController {}
''',
    );
    await _writeProjectFile(
      project,
      'lib/features/invoices/presentation/invoice_page.dart',
      '''
import '../application/invoice_controller.dart';

class InvoicePage {}
''',
    );
    await _writeProjectFile(
      project,
      'lib/features/customers/data/customer_repository.dart',
      'abstract class CustomerRepository {}\n',
    );
  });

  tearDown(() async {
    if (await project.exists()) {
      await project.delete(recursive: true);
    }
  });

  test(
    'ranks feature, symbol, path, and graph matches deterministically',
    () async {
      final context = await ProjectContextEngine().build(
        project.path,
        'add invoice repository discount support',
        limit: 5,
      );

      expect(context.packageName, 'context_sample');
      expect(
        context.queryTerms,
        containsAll(<String>['invoice', 'repository', 'discount', 'support']),
      );
      expect(context.matchedFeatures, <String>['invoices']);
      expect(context.files, isNotEmpty);
      expect(context.files.first.path, contains('invoice_repository.dart'));
      expect(context.files.first.symbols.single.name, 'InvoiceRepository');
      expect(context.files.first.reasons, contains(contains('repository')));
      expect(
        context.files.any((file) => file.path.endsWith('invoice.dart')),
        isTrue,
      );
      expect(
        context.files.map((file) => file.score),
        orderedEquals(
          context.files.map((file) => file.score).toList()
            ..sort((left, right) => right.compareTo(left)),
        ),
      );
    },
  );

  test('expands built-in Persian task aliases', () async {
    final context = await ProjectContextEngine().build(
      project.path,
      'تخفیف فاکتور را اضافه کن',
      limit: 4,
    );

    expect(context.queryTerms, contains('invoice'));
    expect(context.matchedFeatures, <String>['invoices']);
    expect(
      context.files.every(
        (file) =>
            file.feature == 'invoices' || file.path == 'lib/app_router.dart',
      ),
      isTrue,
    );
  });

  test(
    'selects deterministic entry points when no task term matches',
    () async {
      final context = await ProjectContextEngine().build(
        project.path,
        'quantum zebra telemetry',
        limit: 3,
      );

      expect(context.files, isNotEmpty);
      expect(context.files.map((file) => file.path), contains('lib/main.dart'));
      expect(
        context.warnings.single,
        contains('No lexical or architecture match'),
      );
    },
  );

  test('emits versioned JSON and readable Markdown', () async {
    final context = await ProjectContextEngine().build(
      project.path,
      'invoice route',
      limit: 6,
    );

    expect(context.toJson()['schemaVersion'], ProjectContext.schemaVersion);
    expect(context.routes, hasLength(1));
    final markdown = context.toMarkdown();
    expect(markdown, startsWith('# Flower Task Context'));
    expect(markdown, contains('`invoices` via `go_router`'));
    expect(markdown, contains('Relevant files'));
  });

  test('validates the task and context limit', () async {
    await expectLater(
      ProjectContextEngine().build(project.path, '  '),
      throwsA(isA<FlowerException>()),
    );
    await expectLater(
      ProjectContextEngine().build(project.path, 'invoice', limit: 0),
      throwsA(isA<FlowerException>()),
    );
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
