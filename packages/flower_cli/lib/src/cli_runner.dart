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
    ProjectSymbolIndexer symbolIndexer = const ProjectSymbolIndexer(),
    ProjectContextEngine? contextEngine,
    ArchitectureGuard? guard,
  }) : _inspector = inspector,
       _initializer = initializer ?? ProjectInitializer(inspector: inspector),
       _mapper = mapper ?? ProjectMapper(inspector: inspector),
       _architectureIndexer = symbolIndexer,
       _taskContextEngine = contextEngine ?? ProjectContextEngine(),
       _architectureGuard = guard ?? ArchitectureGuard(),
       _parser = _buildParser();

  static const String version = '0.4.0-dev.1';

  final ProjectInspector _inspector;
  final ProjectInitializer _initializer;
  final ProjectMapper _mapper;
  final ProjectSymbolIndexer _architectureIndexer;
  final ProjectContextEngine _taskContextEngine;
  final ArchitectureGuard _architectureGuard;
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
        'symbols' => await _runSymbols(command, output),
        'context' => await _runContext(command, output),
        'guard' => await _runGuard(command, output),
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

  Future<int> _runSymbols(ArgResults command, StringSink output) async {
    final projectPath = _resolveProjectPath(command);
    final requestedKind = command['kind'] as String?;
    final feature = command['feature'] as String?;
    final kind = requestedKind == null
        ? null
        : _symbolKindByName(requestedKind);
    final index = (await _architectureIndexer.build(
      projectPath,
    )).filtered(kind: kind, feature: feature);

    if (command['json'] as bool) {
      output.writeln(
        const JsonEncoder.withIndent('  ').convert(index.toJson()),
      );
    } else {
      _writeSymbolIndex(
        output,
        index,
        requestedKind: requestedKind,
        requestedFeature: feature,
      );
    }
    return 0;
  }

  Future<int> _runContext(ArgResults command, StringSink output) async {
    final task = command.rest.join(' ').trim();
    if (task.isEmpty) {
      throw const FlowerException(
        'Provide a task after `flower context`, for example '
        '`flower context "add invoice filtering"`.',
      );
    }

    final limit = int.tryParse(command['limit'] as String);
    if (limit == null) {
      throw const FlowerException('Context limit must be an integer.');
    }
    final context = await _taskContextEngine.build(
      command['path'] as String,
      task,
      limit: limit,
    );

    if (command['json'] as bool) {
      output.writeln(
        const JsonEncoder.withIndent('  ').convert(context.toJson()),
      );
    } else {
      output.write(context.toMarkdown());
    }
    return 0;
  }

  Future<int> _runGuard(ArgResults command, StringSink output) async {
    final report = await _architectureGuard.inspect(_resolveProjectPath(command));
    final failOn = _guardSeverityByName(command['fail-on'] as String);

    if (command['json'] as bool) {
      output.writeln(
        const JsonEncoder.withIndent('  ').convert(report.toJson()),
      );
    } else {
      _writeGuardReport(output, report, failOn: failOn);
    }

    return report.hasViolationsAtOrAbove(failOn) ? 3 : 0;
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

    output
      ..writeln()
      ..writeln('Architecture');
    for (final entry in snapshot.symbolCounts.entries) {
      output.writeln('  ${entry.key}: ${entry.value}');
    }
    output.writeln('  routes: ${snapshot.routes.length}');

    if (snapshot.routes.isNotEmpty) {
      output.writeln();
      output.writeln('Routes');
      for (final route in snapshot.routes) {
        final label =
            route.name ?? route.path ?? route.declaration ?? '<unnamed>';
        output.writeln('  - $label (${route.router})');
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

  void _writeSymbolIndex(
    StringSink output,
    ProjectSymbolIndex index, {
    String? requestedKind,
    String? requestedFeature,
  }) {
    output
      ..writeln('Flower Agent symbol index')
      ..writeln('Project: ${index.packageName}')
      ..writeln('Root: ${index.rootPath}');

    if (requestedKind != null) {
      output.writeln('Kind: $requestedKind');
    }
    if (requestedFeature != null && requestedFeature.trim().isNotEmpty) {
      output.writeln('Feature: ${requestedFeature.trim()}');
    }

    output
      ..writeln()
      ..writeln('Counts');
    for (final entry in index.counts.entries) {
      output.writeln('  ${entry.key.name}: ${entry.value}');
    }
    output.writeln('  routes: ${index.routes.length}');

    if (index.symbols.isNotEmpty) {
      output
        ..writeln()
        ..writeln('Symbols');
      for (final symbol in index.symbols) {
        output.writeln(
          '  - ${symbol.kind.name}: ${symbol.name} '
          '(${symbol.path}:${symbol.line})',
        );
      }
    }

    if (index.routes.isNotEmpty) {
      output
        ..writeln()
        ..writeln('Routes');
      for (final route in index.routes) {
        final label =
            route.name ?? route.path ?? route.declaration ?? '<unnamed>';
        output.writeln(
          '  - $label [${route.router}] '
          '(${route.sourcePath}:${route.line})',
        );
      }
    }
  }

  void _writeGuardReport(
    StringSink output,
    GuardReport report, {
    required GuardSeverity failOn,
  }) {
    output
      ..writeln('Flower Agent architecture guard')
      ..writeln('Project: ${report.packageName}')
      ..writeln('Root: ${report.rootPath}')
      ..writeln('Fail on: ${failOn.name}')
      ..writeln('Rules: ${report.enabledRules.join(', ')}')
      ..writeln()
      ..writeln('Summary');

    for (final entry in report.counts.entries) {
      output.writeln('  ${entry.key.name}: ${entry.value}');
    }

    if (report.violations.isEmpty) {
      output
        ..writeln()
        ..writeln('Result: passed');
      return;
    }

    output
      ..writeln()
      ..writeln('Violations');
    for (final violation in report.violations) {
      output.writeln(
        '  [${violation.severity.name}] ${violation.ruleId}: '
        '${violation.path}',
      );
      if (violation.targetPath != null) {
        output.writeln('    Target: ${violation.targetPath}');
      }
      output
        ..writeln('    ${violation.message}')
        ..writeln('    Fix: ${violation.suggestion}');
    }

    final failed = report.hasViolationsAtOrAbove(failOn);
    output
      ..writeln()
      ..writeln('Result: ${failed ? 'failed' : 'passed with findings'}');
  }

  ProjectSymbolKind _symbolKindByName(String name) {
    for (final kind in ProjectSymbolKind.values) {
      if (kind.name == name) {
        return kind;
      }
    }
    throw FlowerException('Unsupported symbol kind: $name');
  }

  GuardSeverity _guardSeverityByName(String name) {
    for (final severity in GuardSeverity.values) {
      if (severity.name == name) {
        return severity;
      }
    }
    throw FlowerException('Unsupported guard severity: $name');
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
      ..writeln('  flower map --feature invoices --json')
      ..writeln('  flower symbols --kind repository --json')
      ..writeln('  flower context "add invoice filtering" --limit 8')
      ..writeln('  flower guard --fail-on error --json');
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

    final symbolsParser = ArgParser()
      ..addOption(
        'path',
        abbr: 'p',
        defaultsTo: '.',
        help: 'Path to the Dart or Flutter project root.',
      )
      ..addOption(
        'kind',
        abbr: 'k',
        allowed: ProjectSymbolKind.values.map((kind) => kind.name),
        help: 'Limit symbols to one architectural role.',
      )
      ..addOption(
        'feature',
        abbr: 'f',
        help: 'Limit symbols and routes to one feature-first directory.',
      )
      ..addFlag(
        'json',
        negatable: false,
        help: 'Write the stable machine-readable symbol index.',
      )
      ..addFlag('help', abbr: 'h', negatable: false);

    final contextParser = ArgParser()
      ..addOption(
        'path',
        abbr: 'p',
        defaultsTo: '.',
        help: 'Path to the Dart or Flutter project root.',
      )
      ..addOption(
        'limit',
        abbr: 'l',
        defaultsTo: '12',
        help: 'Maximum number of relevant files to select (1-50).',
      )
      ..addFlag(
        'json',
        negatable: false,
        help: 'Write the stable machine-readable task context.',
      )
      ..addFlag('help', abbr: 'h', negatable: false);

    final guardParser = ArgParser()
      ..addOption(
        'path',
        abbr: 'p',
        defaultsTo: '.',
        help: 'Path to the Dart or Flutter project root.',
      )
      ..addOption(
        'fail-on',
        defaultsTo: 'error',
        allowed: GuardSeverity.values.map((severity) => severity.name),
        help: 'Return exit code 3 at or above this severity.',
      )
      ..addFlag(
        'json',
        negatable: false,
        help: 'Write the stable machine-readable guard report.',
      )
      ..addFlag('help', abbr: 'h', negatable: false);

    return ArgParser()
      ..addFlag('help', abbr: 'h', negatable: false)
      ..addFlag('version', negatable: false)
      ..addCommand('inspect', inspectParser)
      ..addCommand('init', initParser)
      ..addCommand('map', mapParser)
      ..addCommand('symbols', symbolsParser)
      ..addCommand('context', contextParser)
      ..addCommand('guard', guardParser);
  }
}
