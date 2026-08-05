import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:flower_core/flower_core.dart';

/// Runs the Flower Agent command-line interface.
final class FlowerCli {
  FlowerCli({
    ProjectInspector inspector = const ProjectInspector(),
    ProjectInitializer? initializer,
    ProjectMapper? mapper,
  }) : _inspector = inspector,
       _initializer = initializer ?? ProjectInitializer(inspector: inspector),
       _mapper = mapper ?? ProjectMapper(inspector: inspector),
       _parser = _buildParser();

  static const String version = '0.1.0-dev.1';

  final ProjectInspector _inspector;
  final ProjectInitializer _initializer;
  final ProjectMapper _mapper;
  final ArgParser _parser;

  Future<int> run(
    Iterable<String> arguments, {
    StringSink? out,
    StringSink? err,
  }) async {
    final output = out ?? stdout;
    final errorOutput = err ?? stderr;

    final ArgResults results;
    try {
      results = _parser.parse(arguments);
    } on FormatException catch (error) {
      errorOutput.writeln('Error: ${error.message}');
      errorOutput.writeln();
      _writeRootUsage(errorOutput);
      return 64;
    }

    if (results['version'] as bool) {
      output.writeln('Flower Agent $version');
      return 0;
    }

    final command = results.command;
    if (results['help'] as bool || command == null) {
      _writeRootUsage(output);
      return 0;
    }

    if (command['help'] as bool) {
      _writeCommandUsage(output, command.name!);
      return 0;
    }

    try {
      return switch (command.name) {
        'inspect' => await _runInspect(command, output),
        'init' => await _runInit(command, output),
        'map' => await _runMap(command, output),
        _ => _unknownCommand(command.name, errorOutput),
      };
    } on FlowerException catch (error) {
      errorOutput.writeln('Flower error: ${error.message}');
      return 2;
    } on Object catch (error) {
      errorOutput.writeln('Unexpected Flower failure: $error');
      return 1;
    }
  }

  Future<int> _runInspect(ArgResults command, StringSink output) async {
    final projectPath = _resolveProjectPath(command);
    final snapshot = await _inspector.inspect(projectPath);

    if (command['json'] as bool) {
      output.writeln(
        const JsonEncoder.withIndent('  ').convert(snapshot.toJson()),
      );
    } else {
      _writeSnapshot(output, snapshot);
    }
    return 0;
  }

  Future<int> _runInit(ArgResults command, StringSink output) async {
    final projectPath = _resolveProjectPath(command);
    final result = await _initializer.initialize(projectPath);

    if (command['json'] as bool) {
      output.writeln(
        const JsonEncoder.withIndent('  ').convert(<String, Object?>{
          'project': result.snapshot.toJson(),
          'createdFiles': result.createdFiles,
          'skippedFiles': result.skippedFiles,
        }),
      );
      return 0;
    }

    output.writeln('Flower initialized ${result.snapshot.packageName}.');
    if (result.createdFiles.isNotEmpty) {
      output.writeln();
      output.writeln('Created:');
      for (final path in result.createdFiles) {
        output.writeln('  + $path');
      }
    }
    if (result.skippedFiles.isNotEmpty) {
      output.writeln();
      output.writeln('Preserved existing files:');
      for (final path in result.skippedFiles) {
        output.writeln('  = $path');
      }
    }
    return 0;
  }

  Future<int> _runMap(ArgResults command, StringSink output) async {
    final writeJson = command['json'] as bool;
    final writeMermaid = command['mermaid'] as bool;
    if (writeJson && writeMermaid) {
      throw const FlowerException(
        'Choose either --json or --mermaid, not both.',
      );
    }

    final projectPath = _resolveProjectPath(command);
    var projectMap = await _mapper.build(projectPath);
    final feature = command['feature'] as String?;
    if (feature != null && feature.trim().isNotEmpty) {
      projectMap = projectMap.forFeature(feature.trim());
    }

    if (writeJson) {
      output.writeln(
        const JsonEncoder.withIndent('  ').convert(projectMap.toJson()),
      );
    } else if (writeMermaid) {
      output.write(projectMap.toMermaid());
    } else {
      _writeProjectMap(output, projectMap, requestedFeature: feature);
    }
    return 0;
  }

  void _writeSnapshot(StringSink output, ProjectSnapshot snapshot) {
    output
      ..writeln('Flower Agent inspection')
      ..writeln('Project: ${snapshot.packageName}')
      ..writeln('Root: ${snapshot.rootPath}')
      ..writeln('Flutter: ${snapshot.isFlutterProject ? 'yes' : 'no'}')
      ..writeln()
      ..writeln('Files')
      ..writeln('  Source: ${snapshot.sourceFileCount}')
      ..writeln('  Generated: ${snapshot.generatedFileCount}')
      ..writeln('  Tests: ${snapshot.testFileCount}')
      ..writeln('  Integration tests: ${snapshot.integrationTestFileCount}')
      ..writeln()
      ..writeln('Features: ${snapshot.featureNames.length}');

    if (snapshot.featureNames.isEmpty) {
      output.writeln('  No feature-first directories detected.');
    } else {
      for (final feature in snapshot.featureNames) {
        output.writeln('  - $feature');
      }
    }

    output
      ..writeln()
      ..writeln('Technologies');
    if (snapshot.technologies.isEmpty) {
      output.writeln('  No supported packages detected.');
    } else {
      for (final entry in snapshot.technologies.entries) {
        final category = entry.key.replaceAll('_', ' ');
        output.writeln('  $category: ${entry.value.join(', ')}');
      }
    }

    if (snapshot.warnings.isNotEmpty) {
      output
        ..writeln()
        ..writeln('Warnings');
      for (final warning in snapshot.warnings) {
        output.writeln('  ! $warning');
      }
    }
  }

  void _writeProjectMap(
    StringSink output,
    ProjectMap projectMap, {
    String? requestedFeature,
  }) {
    final generatedCount = projectMap.nodes
        .where((node) => node.generated)
        .length;
    output
      ..writeln('Flower Agent project map')
      ..writeln('Project: ${projectMap.packageName}')
      ..writeln('Root: ${projectMap.rootPath}');

    if (requestedFeature != null && requestedFeature.trim().isNotEmpty) {
      output.writeln('Feature: ${requestedFeature.trim()}');
    }

    output
      ..writeln()
      ..writeln('Graph')
      ..writeln('  Files: ${projectMap.nodes.length}')
      ..writeln('  Generated files: $generatedCount')
      ..writeln('  Internal dependencies: ${projectMap.edges.length}')
      ..writeln('  Dependency cycles: ${projectMap.cycles.length}')
      ..writeln()
      ..writeln('Features');

    final features = projectMap.features.toList()..sort();
    if (features.isEmpty) {
      output.writeln('  No feature-first files detected.');
    } else {
      for (final feature in features) {
        output.writeln('  - $feature');
      }
    }

    if (projectMap.cycles.isNotEmpty) {
      output
        ..writeln()
        ..writeln('Cycles');
      for (final cycle in projectMap.cycles) {
        output.writeln('  ! ${cycle.join(' <-> ')}');
      }
    }
  }

  String _resolveProjectPath(ArgResults command) {
    if (command.rest.isNotEmpty) {
      return command.rest.first;
    }
    return command['path'] as String;
  }

  int _unknownCommand(String? commandName, StringSink errorOutput) {
    errorOutput.writeln('Unknown command: ${commandName ?? '<none>'}');
    return 64;
  }

  void _writeRootUsage(StringSink output) {
    output
      ..writeln('Flower Agent $version')
      ..writeln()
      ..writeln('Usage: flower <command> [arguments]')
      ..writeln()
      ..writeln(_parser.usage)
      ..writeln()
      ..writeln('Examples:')
      ..writeln('  flower inspect --path .')
      ..writeln('  flower inspect . --json')
      ..writeln('  flower init')
      ..writeln('  flower map --mermaid')
      ..writeln('  flower map --feature invoices --json');
  }

  void _writeCommandUsage(StringSink output, String commandName) {
    final commandParser = _parser.commands[commandName];
    output
      ..writeln('Usage: flower $commandName [project-path] [options]')
      ..writeln()
      ..writeln(commandParser?.usage ?? 'No command help is available.');
  }

  static ArgParser _buildParser() {
    final inspectParser = ArgParser()
      ..addOption(
        'path',
        abbr: 'p',
        defaultsTo: '.',
        help: 'Path to the Dart or Flutter project root.',
      )
      ..addFlag(
        'json',
        negatable: false,
        help: 'Write the stable machine-readable JSON snapshot.',
      )
      ..addFlag('help', abbr: 'h', negatable: false);

    final initParser = ArgParser()
      ..addOption(
        'path',
        abbr: 'p',
        defaultsTo: '.',
        help: 'Path to the Dart or Flutter project root.',
      )
      ..addFlag(
        'json',
        negatable: false,
        help: 'Write a machine-readable initialization result.',
      )
      ..addFlag('help', abbr: 'h', negatable: false);

    final mapParser = ArgParser()
      ..addOption(
        'path',
        abbr: 'p',
        defaultsTo: '.',
        help: 'Path to the Dart or Flutter project root.',
      )
      ..addOption(
        'feature',
        abbr: 'f',
        help: 'Limit the graph to one feature-first directory.',
      )
      ..addFlag(
        'json',
        negatable: false,
        help: 'Write the stable machine-readable project map.',
      )
      ..addFlag('mermaid', negatable: false, help: 'Write a Mermaid flowchart.')
      ..addFlag('help', abbr: 'h', negatable: false);

    return ArgParser()
      ..addFlag('help', abbr: 'h', negatable: false)
      ..addFlag('version', negatable: false)
      ..addCommand('inspect', inspectParser)
      ..addCommand('init', initParser)
      ..addCommand('map', mapParser);
  }
}
