import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import 'flower_exception.dart';
import 'project_symbol_index.dart';

/// Builds an analyzer-backed index of architecture roles and routes.
final class ProjectSymbolIndexer {
  const ProjectSymbolIndexer();

  Future<ProjectSymbolIndex> build(String rootPath) async {
    final root = Directory(p.normalize(p.absolute(rootPath)));
    if (!await root.exists()) {
      throw FlowerException('Project directory does not exist: ${root.path}');
    }

    final packageName = await _readPackageName(root);
    final libDirectory = Directory(p.join(root.path, 'lib'));
    if (!await libDirectory.exists()) {
      return ProjectSymbolIndex(
        packageName: packageName,
        rootPath: root.path,
        symbols: const <ProjectSymbol>[],
        routes: const <ProjectRoute>[],
      );
    }

    final symbols = <ProjectSymbol>[];
    final routes = <ProjectRoute>[];
    final files = await _listDartFiles(libDirectory);

    for (final file in files) {
      final relativePath = _relativePath(root, file);
      final feature = _featureForPath(relativePath);
      try {
        final parseResult = parseString(
          content: await file.readAsString(),
          path: file.path,
          throwIfDiagnostics: false,
        );
        final collector = _SymbolCollector(
          sourcePath: relativePath,
          feature: feature,
          lineInfo: parseResult.lineInfo,
        );
        parseResult.unit.accept(collector);
        symbols.addAll(collector.symbols);
        routes.addAll(collector.routes);
      } on Object catch (error) {
        throw FlowerException(
          'Unable to index symbols in ${file.path}. Fix the file and retry.',
          cause: error,
        );
      }
    }

    symbols.sort((left, right) {
      final pathOrder = left.path.compareTo(right.path);
      if (pathOrder != 0) {
        return pathOrder;
      }
      final lineOrder = left.line.compareTo(right.line);
      if (lineOrder != 0) {
        return lineOrder;
      }
      return left.name.compareTo(right.name);
    });
    routes.sort((left, right) {
      final pathOrder = left.sourcePath.compareTo(right.sourcePath);
      if (pathOrder != 0) {
        return pathOrder;
      }
      return left.line.compareTo(right.line);
    });

    return ProjectSymbolIndex(
      packageName: packageName,
      rootPath: root.path,
      symbols: symbols,
      routes: routes,
    );
  }

  Future<String> _readPackageName(Directory root) async {
    final pubspecFile = File(p.join(root.path, 'pubspec.yaml'));
    if (!await pubspecFile.exists()) {
      throw FlowerException(
        'No pubspec.yaml found in ${root.path}. '
        'Run Flower from a Dart or Flutter project root.',
      );
    }

    try {
      final document = loadYaml(await pubspecFile.readAsString());
      if (document is YamlMap) {
        final name = document['name']?.toString().trim();
        if (name != null && name.isNotEmpty) {
          return name;
        }
      }
      return p.basename(root.path);
    } on Object catch (error) {
      throw FlowerException(
        'Unable to parse ${pubspecFile.path}. Fix the YAML and retry.',
        cause: error,
      );
    }
  }

  Future<List<File>> _listDartFiles(Directory directory) async {
    final files = <File>[];
    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File &&
          entity.path.endsWith('.dart') &&
          !_isGeneratedDartFile(entity.path)) {
        files.add(entity);
      }
    }
    files.sort((left, right) => left.path.compareTo(right.path));
    return files;
  }

  String _relativePath(Directory root, File file) =>
      p.relative(file.path, from: root.path).split(p.separator).join('/');

  String? _featureForPath(String path) {
    final segments = path.split('/');
    for (var index = 0; index < segments.length - 1; index++) {
      if (segments[index] == 'features') {
        return segments[index + 1];
      }
    }
    return null;
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
}

final class _SymbolCollector extends RecursiveAstVisitor<void> {
  _SymbolCollector({
    required this.sourcePath,
    required this.feature,
    required this.lineInfo,
  });

  final String sourcePath;
  final String? feature;
  final LineInfo lineInfo;
  final List<ProjectSymbol> symbols = <ProjectSymbol>[];
  final List<ProjectRoute> routes = <ProjectRoute>[];

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final name = node.name.lexeme;
    final supertypes = <String>[
      if (node.extendsClause != null)
        node.extendsClause!.superclass.toSource(),
      if (node.withClause != null)
        ...node.withClause!.mixinTypes.map((type) => type.toSource()),
      if (node.implementsClause != null)
        ...node.implementsClause!.interfaces.map((type) => type.toSource()),
    ];
    final kind = _classify(name, supertypes);
    if (kind != null) {
      symbols.add(
        ProjectSymbol(
          name: name,
          kind: kind,
          path: sourcePath,
          feature: feature,
          line: _lineFor(node.offset),
          metadata: <String, String>{
            'declaration': 'class',
            if (supertypes.isNotEmpty) 'supertypes': supertypes.join(', '),
          },
        ),
      );
    }
    super.visitClassDeclaration(node);
  }

  @override
  void visitMixinDeclaration(MixinDeclaration node) {
    final name = node.name.lexeme;
    final kind = _classify(name, const <String>[]);
    if (kind != null) {
      symbols.add(
        ProjectSymbol(
          name: name,
          kind: kind,
          path: sourcePath,
          feature: feature,
          line: _lineFor(node.offset),
          metadata: const <String, String>{'declaration': 'mixin'},
        ),
      );
    }
    super.visitMixinDeclaration(node);
  }

  @override
  void visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) {
    for (final variable in node.variables.variables) {
      final initializer = variable.initializer?.toSource() ?? '';
      final normalizedName = _normalize(variable.name.lexeme);
      if (normalizedName.endsWith('provider') ||
          _looksLikeProviderInitializer(initializer)) {
        symbols.add(
          ProjectSymbol(
            name: variable.name.lexeme,
            kind: ProjectSymbolKind.provider,
            path: sourcePath,
            feature: feature,
            line: _lineFor(variable.offset),
            metadata: <String, String>{
              'declaration': 'topLevelVariable',
              if (initializer.isNotEmpty) 'initializer': initializer,
            },
          ),
        );
      }
    }
    super.visitTopLevelVariableDeclaration(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    final hasRiverpodAnnotation = node.metadata.any(
      (annotation) => _normalize(annotation.name.name).contains('riverpod'),
    );
    if (hasRiverpodAnnotation) {
      symbols.add(
        ProjectSymbol(
          name: node.name.lexeme,
          kind: ProjectSymbolKind.provider,
          path: sourcePath,
          feature: feature,
          line: _lineFor(node.offset),
          metadata: const <String, String>{
            'declaration': 'annotatedFunction',
            'annotation': 'riverpod',
          },
        ),
      );
    }
    super.visitFunctionDeclaration(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final routeType = node.constructorName.type.toSource().split('<').first;
    final router = _routerForType(routeType);
    if (router != null) {
      final pathExpression = _namedArgument(node.argumentList, 'path');
      final nameExpression = _namedArgument(node.argumentList, 'name');
      final declarationExpression =
          _namedArgument(node.argumentList, 'page') ??
          _namedArgument(node.argumentList, 'builder') ??
          _namedArgument(node.argumentList, 'pageBuilder');
      routes.add(
        ProjectRoute(
          router: router,
          path: _stringValue(pathExpression) ??
              (router == 'get' ? _stringValue(nameExpression) : null),
          name: router == 'get' ? null : _stringValue(nameExpression),
          declaration: declarationExpression?.toSource(),
          sourcePath: sourcePath,
          feature: feature,
          line: _lineFor(node.offset),
        ),
      );
    }
    super.visitInstanceCreationExpression(node);
  }

  ProjectSymbolKind? _classify(String name, Iterable<String> supertypes) {
    final candidates = <String>[name, ...supertypes].map(_normalize);
    for (final candidate in candidates) {
      if (candidate.endsWith('repository') ||
          candidate.endsWith('repositoryimpl') ||
          candidate.endsWith('repositoryimplementation')) {
        return ProjectSymbolKind.repository;
      }
      if (candidate.endsWith('datasource') || candidate.endsWith('dao')) {
        return ProjectSymbolKind.dataSource;
      }
      if (candidate.endsWith('service')) {
        return ProjectSymbolKind.service;
      }
      if (candidate.endsWith('provider')) {
        return ProjectSymbolKind.provider;
      }
      if (candidate.endsWith('controller') ||
          candidate.endsWith('cubit') ||
          candidate.endsWith('bloc') ||
          candidate.endsWith('notifier') ||
          candidate.endsWith('asyncnotifier') ||
          candidate.endsWith('statenotifier') ||
          candidate.endsWith('changenotifier') ||
          candidate.endsWith('viewmodel')) {
        return ProjectSymbolKind.controller;
      }
    }
    return null;
  }

  bool _looksLikeProviderInitializer(String initializer) {
    if (initializer.isEmpty) {
      return false;
    }
    return RegExp(r'\b[A-Za-z0-9_]*Provider\s*(?:<[^;]+>)?\s*\(')
        .hasMatch(initializer);
  }

  String? _routerForType(String type) {
    final normalized = type.split('.').last;
    return switch (normalized) {
      'GoRoute' => 'go_router',
      'AutoRoute' || 'RouteConfig' => 'auto_route',
      'GetPage' => 'get',
      _ => null,
    };
  }

  Expression? _namedArgument(ArgumentList arguments, String name) {
    for (final argument in arguments.arguments) {
      if (argument is NamedExpression && argument.name.label.name == name) {
        return argument.expression;
      }
    }
    return null;
  }

  String? _stringValue(Expression? expression) {
    return switch (expression) {
      SimpleStringLiteral() => expression.value,
      _ => null,
    };
  }

  String _normalize(String value) =>
      value.replaceAll(RegExp('[^A-Za-z0-9]'), '').toLowerCase();

  int _lineFor(int offset) => lineInfo.getLocation(offset).lineNumber;
}
