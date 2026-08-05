import 'dart:convert';
import 'dart:io';

import 'package:flower_agent/flower_cli.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory project;

  setUp(() async {
    project = await Directory.systemTemp.createTemp('flower_cli_test_');
    await File(p.join(project.path, 'pubspec.yaml')).writeAsString('''
name: cli_sample
dependencies:
  flutter:
    sdk: flutter
  provider: any
flutter:
  uses-material-design: true
''');
    await Directory(
      p.join(project.path, 'lib', 'features', 'home', 'presentation'),
    ).create(recursive: true);
    await File(p.join(project.path, 'lib', 'main.dart')).writeAsString('''
import 'package:cli_sample/features/home/presentation/home_page.dart';

void main() {
  HomePage();
}
''');
    await File(
      p.join(
        project.path,
        'lib',
        'features',
        'home',
        'presentation',
        'home_page.dart',
      ),
    ).writeAsString('class HomePage {}');
  });

  tearDown(() async {
    if (await project.exists()) {
      await project.delete(recursive: true);
    }
  });

  test('inspect writes a JSON project snapshot', () async {
    final output = StringBuffer();
    final errors = StringBuffer();

    final result = await FlowerCli().run(
      <String>['inspect', '--path', project.path, '--json'],
      out: output,
      err: errors,
    );

    expect(result, 0);
    expect(errors.toString(), isEmpty);
    final decoded = jsonDecode(output.toString()) as Map<String, Object?>;
    expect(decoded['packageName'], 'cli_sample');
    expect(decoded['isFlutterProject'], isTrue);
  });

  test('init creates the Flower workspace', () async {
    final output = StringBuffer();
    final errors = StringBuffer();

    final result = await FlowerCli().run(
      <String>['init', project.path],
      out: output,
      err: errors,
    );

    expect(result, 0);
    expect(errors.toString(), isEmpty);
    expect(
      await File(p.join(project.path, '.flower', 'flower.yaml')).exists(),
      isTrue,
    );
    expect(
      await File(
        p.join(project.path, '.flower', 'context', 'project.md'),
      ).exists(),
      isTrue,
    );
    expect(await File(p.join(project.path, 'AGENTS.md')).exists(), isTrue);
  });

  test('map writes a JSON dependency graph', () async {
    final output = StringBuffer();
    final errors = StringBuffer();

    final result = await FlowerCli().run(
      <String>['map', '--path', project.path, '--json'],
      out: output,
      err: errors,
    );

    expect(result, 0);
    expect(errors.toString(), isEmpty);
    final decoded = jsonDecode(output.toString()) as Map<String, Object?>;
    expect(decoded['schemaVersion'], '1.0.0');
    expect(decoded['packageName'], 'cli_sample');
    expect(decoded['nodes'], hasLength(2));
    expect(decoded['edges'], hasLength(1));
  });

  test('map writes a feature-scoped Mermaid graph', () async {
    final output = StringBuffer();
    final errors = StringBuffer();

    final result = await FlowerCli().run(
      <String>[
        'map',
        project.path,
        '--feature',
        'home',
        '--mermaid',
      ],
      out: output,
      err: errors,
    );

    expect(result, 0);
    expect(errors.toString(), isEmpty);
    expect(output.toString(), startsWith('flowchart LR'));
    expect(output.toString(), contains('home_page.dart'));
    expect(output.toString(), isNot(contains('main.dart')));
  });

  test('map rejects multiple output formats', () async {
    final output = StringBuffer();
    final errors = StringBuffer();

    final result = await FlowerCli().run(
      <String>['map', project.path, '--json', '--mermaid'],
      out: output,
      err: errors,
    );

    expect(result, 2);
    expect(output.toString(), isEmpty);
    expect(errors.toString(), contains('Choose either --json or --mermaid'));
  });

  test('version prints the current CLI version', () async {
    final output = StringBuffer();

    final result = await FlowerCli().run(<String>['--version'], out: output);

    expect(result, 0);
    expect(output.toString(), contains(FlowerCli.version));
  });
}
