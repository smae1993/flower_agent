import 'dart:io';

import 'package:flower_core/flower_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory project;

  setUp(() async {
    project = await Directory.systemTemp.createTemp('flower_guard_test_');
    await File(p.join(project.path, 'pubspec.yaml')).writeAsString('''
name: guard_sample
dependencies:
  flutter:
    sdk: flutter
flutter:
  uses-material-design: true
''');

    await _writeProjectFile(
      project,
      'lib/features/orders/domain/order.dart',
      '''
import 'package:flutter/material.dart';
import '../data/order_repository.dart';

class Order {}
''',
    );
    await _writeProjectFile(
      project,
      'lib/features/orders/data/order_repository.dart',
      '''
import '../presentation/order_page.dart';

class OrderRepository {}
''',
    );
    await _writeProjectFile(
      project,
      'lib/features/orders/application/order_controller.dart',
      '''
import '../presentation/order_page.dart';

class OrderController {}
''',
    );
    await _writeProjectFile(
      project,
      'lib/features/orders/presentation/order_page.dart',
      '''
import '../application/order_controller.dart';

class OrderPage {}
''',
    );
  });

  tearDown(() async {
    if (await project.exists()) {
      await project.delete(recursive: true);
    }
  });

  test(
    'reports dependency cycles, layer direction, and Flutter in domain',
    () async {
      final report = await ArchitectureGuard().inspect(project.path);

      expect(report.packageName, 'guard_sample');
      expect(report.enabledRules, <String>[
        'dependency_cycle',
        'layer_dependency',
        'domain_flutter_dependency',
      ]);
      expect(
        report.violations.map((violation) => violation.ruleId),
        containsAll(<String>[
          'dependency_cycle',
          'layer_dependency',
          'domain_flutter_dependency',
        ]),
      );
      expect(
        report.violations.where(
          (violation) => violation.ruleId == 'layer_dependency',
        ),
        hasLength(3),
      );
      expect(
        report.violations
            .singleWhere(
              (violation) => violation.ruleId == 'domain_flutter_dependency',
            )
            .path,
        endsWith('domain/order.dart'),
      );
      expect(report.hasViolationsAtOrAbove(GuardSeverity.error), isTrue);
      expect(report.toJson()['schemaVersion'], GuardReport.schemaVersion);
      expect(report.toJson()['passed'], isFalse);
    },
  );

  test('passes a correctly directed clean architecture fixture', () async {
    await project.delete(recursive: true);
    project = await Directory.systemTemp.createTemp('flower_guard_clean_test_');
    await File(p.join(project.path, 'pubspec.yaml')).writeAsString('''
name: clean_sample
dependencies: {}
''');
    await _writeProjectFile(
      project,
      'lib/features/orders/domain/order.dart',
      'class Order {}\n',
    );
    await _writeProjectFile(
      project,
      'lib/features/orders/data/order_repository.dart',
      "import '../domain/order.dart';\nclass OrderRepository {}\n",
    );
    await _writeProjectFile(
      project,
      'lib/features/orders/application/order_controller.dart',
      "import '../domain/order.dart';\nclass OrderController {}\n",
    );
    await _writeProjectFile(
      project,
      'lib/features/orders/presentation/order_page.dart',
      "import '../application/order_controller.dart';\nclass OrderPage {}\n",
    );

    final report = await ArchitectureGuard().inspect(project.path);

    expect(report.violations, isEmpty);
    expect(report.hasViolationsAtOrAbove(GuardSeverity.warning), isFalse);
    expect(report.toJson()['passed'], isTrue);
  });

  test('supports custom architecture rules', () async {
    final guard = ArchitectureGuard(
      rules: const <ArchitectureRule>[_ProjectNamingRule()],
    );

    final report = await guard.inspect(project.path);

    expect(report.enabledRules, <String>['project_naming']);
    expect(report.violations, hasLength(1));
    expect(report.violations.single.severity, GuardSeverity.warning);
    expect(report.hasViolationsAtOrAbove(GuardSeverity.error), isFalse);
    expect(report.hasViolationsAtOrAbove(GuardSeverity.warning), isTrue);
  });
}

final class _ProjectNamingRule implements ArchitectureRule {
  const _ProjectNamingRule();

  @override
  String get id => 'project_naming';

  @override
  Iterable<GuardViolation> evaluate(ProjectMap projectMap) sync* {
    yield const GuardViolation(
      ruleId: 'project_naming',
      severity: GuardSeverity.warning,
      path: 'pubspec.yaml',
      targetPath: null,
      message: 'Fixture warning.',
      suggestion: 'Rename the fixture.',
    );
  }
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
