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
    await Directory(p.join(project.path, 'lib')).create();
    await File(
      p.join(project.path, 'lib', 'main.dart'),
    ).writeAsString('void main() {}');
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

  test('version prints the current CLI version', () async {
    final output = StringBuffer();

    final result = await FlowerCli().run(<String>['--version'], out: output);

    expect(result, 0);
    expect(output.toString(), contains(FlowerCli.version));
  });
}
