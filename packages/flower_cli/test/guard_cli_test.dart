import 'dart:convert';
import 'dart:io';

import 'package:flower_agent/flower_cli.dart';
import 'package:flower_core/flower_core.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory project;

  setUp(() async {
    project = await Directory.systemTemp.createTemp('flower_guard_cli_test_');
    await File(p.join(project.path, 'pubspec.yaml')).writeAsString('''
name: guard_cli_sample
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
      'class OrderRepository {}\n',
    );
  });

  tearDown(() async {
    if (await project.exists()) {
      await project.delete(recursive: true);
    }
  });

  test('guard writes JSON and returns exit code 3 for errors', () async {
    final output = StringBuffer();
    final errors = StringBuffer();

    final result = await FlowerCli().run(
      <String>['guard', '--path', project.path, '--json'],
      out: output,
      err: errors,
    );

    expect(result, 3);
    expect(errors.toString(), isEmpty);
    final decoded = jsonDecode(output.toString()) as Map<String, Object?>;
    expect(decoded['schemaVersion'], GuardReport.schemaVersion);
    expect(decoded['packageName'], 'guard_cli_sample');
    expect(decoded['passed'], isFalse);
    expect(decoded['violations'], isNotEmpty);
  });

  test('guard writes a readable report', () async {
    final output = StringBuffer();
    final errors = StringBuffer();

    final result = await FlowerCli().run(
      <String>['guard', project.path],
      out: output,
      err: errors,
    );

    expect(result, 3);
    expect(errors.toString(), isEmpty);
    expect(output.toString(), startsWith('Flower Agent architecture guard'));
    expect(output.toString(), contains('domain_flutter_dependency'));
    expect(output.toString(), contains('Result: failed'));
  });

  test('fail-on controls the CI exit threshold', () async {
    final cli = FlowerCli(
      guard: ArchitectureGuard(rules: const <ArchitectureRule>[_WarningRule()]),
    );

    final errorThresholdOutput = StringBuffer();
    final errorThreshold = await cli.run(<String>[
      'guard',
      '--path',
      project.path,
      '--fail-on',
      'error',
    ], out: errorThresholdOutput);
    final warningThreshold = await cli.run(<String>[
      'guard',
      '--path',
      project.path,
      '--fail-on',
      'warning',
    ], out: StringBuffer());

    expect(errorThreshold, 0);
    expect(errorThresholdOutput.toString(), contains('passed with findings'));
    expect(warningThreshold, 3);
  });
}

final class _WarningRule implements ArchitectureRule {
  const _WarningRule();

  @override
  String get id => 'warning_fixture';

  @override
  Iterable<GuardViolation> evaluate(ProjectMap projectMap) sync* {
    yield const GuardViolation(
      ruleId: 'warning_fixture',
      severity: GuardSeverity.warning,
      path: 'lib/main.dart',
      targetPath: null,
      message: 'Fixture warning.',
      suggestion: 'Fixture fix.',
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
