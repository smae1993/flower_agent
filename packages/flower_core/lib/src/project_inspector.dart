import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'flower_exception.dart';
import 'project_snapshot.dart';

/// Inspects a Dart or Flutter project without executing project code.
final class ProjectInspector {
  const ProjectInspector();

  static const Map<String, List<String>> _technologyCandidates =
      <String, List<String>>{
        'state_management': <String>[
          'flutter_riverpod',
          'hooks_riverpod',
          'riverpod',
          'flutter_bloc',
          'bloc',
          'provider',
          'get',
          'signals',
        ],
        'routing': <String>['go_router', 'auto_route', 'beamer', 'routemaster'],
        'networking': <String>['dio', 'http', 'retrofit', 'chopper'],
        'database': <String>[
          'drift',
          'isar',
          'hive',
          'hive_ce',
          'objectbox',
          'sqflite',
        ],
        'dependency_injection': <String>['get_it', 'injectable', 'kiwi'],
        'code_generation': <String>[
          'freezed',
          'json_serializable',
          'build_runner',
          'riverpod_generator',
        ],
        'testing': <String>[
          'mocktail',
          'mockito',
          'patrol',
          'integration_test',
        ],
      };

  /// Creates a snapshot for [rootPath].
  Future<ProjectSnapshot> inspect(String rootPath) async {
    final root = Directory(p.normalize(p.absolute(rootPath)));
    if (!await root.exists()) {
      throw FlowerException('Project directory does not exist: ${root.path}');
    }

    final pubspecFile = File(p.join(root.path, 'pubspec.yaml'));
    if (!await pubspecFile.exists()) {
      throw FlowerException(
        'No pubspec.yaml found in ${root.path}. '
        'Run Flower from a Dart or Flutter project root.',
      );
    }

    final YamlMap pubspec;
    try {
      final document = loadYaml(await pubspecFile.readAsString());
      if (document is! YamlMap) {
        throw const FormatException('The YAML root must be a map.');
      }
      pubspec = document;
    } on Object catch (error) {
      throw FlowerException(
        'Unable to parse ${pubspecFile.path}. Fix the YAML and retry.',
        cause: error,
      );
    }

    final packageName =
        _asNonEmptyString(pubspec['name']) ?? p.basename(root.path);
    final description = _asNonEmptyString(pubspec['description']) ?? '';
    final dependencyNames = _readDependencyNames(pubspec);
    final isFlutterProject =
        dependencyNames.contains('flutter') || pubspec.containsKey('flutter');

    final libDirectory = Directory(p.join(root.path, 'lib'));
    final sourceCounts = await _countSourceFiles(libDirectory);
    final testFileCount = await _countDartFiles(
      Directory(p.join(root.path, 'test')),
    );
    final integrationTestFileCount = await _countDartFiles(
      Directory(p.join(root.path, 'integration_test')),
    );
    final featureNames = await _detectFeatures(root);
    final technologies = _detectTechnologies(dependencyNames);

    final warnings = <String>[];
    if (!isFlutterProject) {
      warnings.add(
        'The project does not declare the Flutter SDK dependency. '
        'Flower will inspect it as a Dart project.',
      );
    }
    if (!await libDirectory.exists()) {
      warnings.add('No lib directory was found.');
    }
    if (testFileCount == 0 && integrationTestFileCount == 0) {
      warnings.add('No Dart tests were detected.');
    }

    return ProjectSnapshot(
      rootPath: root.path,
      packageName: packageName,
      description: description,
      isFlutterProject: isFlutterProject,
      sourceFileCount: sourceCounts.source,
      generatedFileCount: sourceCounts.generated,
      testFileCount: testFileCount,
      integrationTestFileCount: integrationTestFileCount,
      featureNames: featureNames,
      technologies: technologies,
      warnings: warnings,
    );
  }

  Set<String> _readDependencyNames(YamlMap pubspec) {
    final names = <String>{};
    for (final sectionName in <String>['dependencies', 'dev_dependencies']) {
      final section = pubspec[sectionName];
      if (section is! YamlMap) {
        continue;
      }
      for (final key in section.keys) {
        if (key is String) {
          names.add(key);
        }
      }
    }
    return names;
  }

  Map<String, List<String>> _detectTechnologies(Set<String> dependencies) {
    final detected = <String, List<String>>{};
    for (final entry in _technologyCandidates.entries) {
      final matches = entry.value
          .where(dependencies.contains)
          .toList(growable: false);
      if (matches.isNotEmpty) {
        detected[entry.key] = matches;
      }
    }
    return detected;
  }

  Future<List<String>> _detectFeatures(Directory root) async {
    final names = <String>{};
    final candidates = <Directory>[
      Directory(p.join(root.path, 'lib', 'features')),
      Directory(p.join(root.path, 'lib', 'src', 'features')),
    ];

    for (final candidate in candidates) {
      if (!await candidate.exists()) {
        continue;
      }
      await for (final entity in candidate.list(followLinks: false)) {
        if (entity is Directory) {
          final name = p.basename(entity.path);
          if (!name.startsWith('.')) {
            names.add(name);
          }
        }
      }
    }

    final sorted = names.toList()..sort();
    return sorted;
  }

  Future<({int source, int generated})> _countSourceFiles(
    Directory directory,
  ) async {
    if (!await directory.exists()) {
      return (source: 0, generated: 0);
    }

    var source = 0;
    var generated = 0;
    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      if (_isGeneratedDartFile(entity.path)) {
        generated++;
      } else {
        source++;
      }
    }
    return (source: source, generated: generated);
  }

  Future<int> _countDartFiles(Directory directory) async {
    if (!await directory.exists()) {
      return 0;
    }

    var count = 0;
    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File && entity.path.endsWith('.dart')) {
        count++;
      }
    }
    return count;
  }

  bool _isGeneratedDartFile(String path) {
    const suffixes = <String>[
      '.g.dart',
      '.freezed.dart',
      '.gr.dart',
      '.mocks.dart',
      '.config.dart',
    ];
    return suffixes.any(path.endsWith);
  }

  String? _asNonEmptyString(Object? value) {
    if (value == null) {
      return null;
    }
    final stringValue = value.toString().trim();
    return stringValue.isEmpty ? null : stringValue;
  }
}
