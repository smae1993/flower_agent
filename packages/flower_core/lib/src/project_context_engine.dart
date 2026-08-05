import 'flower_exception.dart';
import 'project_context.dart';
import 'project_map.dart';
import 'project_mapper.dart';
import 'project_symbol_index.dart';
import 'project_symbol_indexer.dart';

/// Builds deterministic, task-specific context from Flower project indexes.
final class ProjectContextEngine {
  ProjectContextEngine({
    ProjectMapper mapper = const ProjectMapper(),
    ProjectSymbolIndexer symbolIndexer = const ProjectSymbolIndexer(),
  }) : _graphBuilder = mapper,
       _declarationIndexer = symbolIndexer;

  final ProjectMapper _graphBuilder;
  final ProjectSymbolIndexer _declarationIndexer;

  static const Map<String, String> _builtInAliases = <String, String>{
    'فاکتور': 'invoice',
    'صورتحساب': 'invoice',
    'مشتری': 'customer',
    'محصول': 'product',
    'کالا': 'product',
    'موجودی': 'inventory',
    'انبار': 'inventory',
    'ورود': 'login',
    'احراز': 'auth',
    'کاربر': 'user',
    'تنظیمات': 'settings',
    'گزارش': 'report',
    'پرداخت': 'payment',
    'سفارش': 'order',
  };

  static const Set<String> _stopWords = <String>{
    'a',
    'an',
    'and',
    'add',
    'change',
    'create',
    'feature',
    'for',
    'from',
    'implement',
    'in',
    'make',
    'new',
    'of',
    'on',
    'or',
    'the',
    'to',
    'update',
    'with',
    'از',
    'اضافه',
    'ایجاد',
    'با',
    'به',
    'برای',
    'پیاده',
    'تغییر',
    'جدید',
    'را',
    'سازی',
    'کن',
    'در',
    'و',
    'یا',
    'یک',
  };

  Future<ProjectContext> build(
    String rootPath,
    String task, {
    int limit = 12,
  }) async {
    final normalizedTask = task.trim();
    if (normalizedTask.isEmpty) {
      throw const FlowerException('Context task must not be empty.');
    }
    if (limit < 1 || limit > 50) {
      throw const FlowerException('Context limit must be between 1 and 50.');
    }

    final projectMap = await _graphBuilder.build(rootPath);
    final symbolIndex = await _declarationIndexer.build(rootPath);
    final queryTerms = _queryTerms(normalizedTask);
    final candidates = <String, _ContextCandidate>{
      for (final node in projectMap.nodes)
        node.path: _ContextCandidate(node: node),
    };
    final symbolsByPath = _symbolsByPath(symbolIndex.symbols);
    final routesByPath = _routesByPath(symbolIndex.routes);
    final dependencies = _dependencies(projectMap);
    final dependents = _dependents(projectMap);

    for (final candidate in candidates.values) {
      _scorePath(candidate, queryTerms);
      _scoreFeature(candidate, queryTerms);
      _scoreSymbols(
        candidate,
        symbolsByPath[candidate.node.path] ?? const <ProjectSymbol>[],
        queryTerms,
      );
      _scoreRoutes(
        candidate,
        routesByPath[candidate.node.path] ?? const <ProjectRoute>[],
        queryTerms,
      );
    }

    _propagateGraphContext(
      candidates,
      dependencies: dependencies,
      dependents: dependents,
    );

    final warnings = <String>[];
    if (!candidates.values.any((candidate) => candidate.score > 0)) {
      warnings.add(
        'No lexical or architecture match was found. '
        'Flower selected deterministic project entry points instead.',
      );
      _addFallbackCandidates(
        candidates,
        routes: symbolIndex.routes,
        dependencies: dependencies,
        dependents: dependents,
      );
    }

    final ranked =
        candidates.values.where((candidate) => candidate.score > 0).toList()
          ..sort((left, right) {
            final scoreOrder = right.score.compareTo(left.score);
            if (scoreOrder != 0) {
              return scoreOrder;
            }
            return left.node.path.compareTo(right.node.path);
          });

    final selected = ranked.take(limit).toList(growable: false);
    final selectedPaths = selected
        .map((candidate) => candidate.node.path)
        .toSet();
    final files = <ContextFile>[
      for (final candidate in selected)
        ContextFile(
          path: candidate.node.path,
          feature: candidate.node.feature,
          score: candidate.score,
          reasons: candidate.reasons,
          symbols: <ContextSymbol>[
            for (final symbol
                in symbolsByPath[candidate.node.path] ??
                    const <ProjectSymbol>[])
              ContextSymbol(name: symbol.name, kind: symbol.kind),
          ],
          dependencies:
              (dependencies[candidate.node.path] ?? const <String>{}).toList()
                ..sort(),
          dependents:
              (dependents[candidate.node.path] ?? const <String>{}).toList()
                ..sort(),
        ),
    ];
    final matchedFeatures = <String>{
      for (final file in files)
        if (file.feature != null) file.feature!,
    }.toList()..sort();
    final relevantRoutes = symbolIndex.routes
        .where((route) => selectedPaths.contains(route.sourcePath))
        .toList(growable: false);

    if (ranked.length > limit) {
      warnings.add(
        '${ranked.length - limit} additional relevant files were omitted '
        'by the context limit.',
      );
    }

    return ProjectContext(
      task: normalizedTask,
      packageName: projectMap.packageName,
      rootPath: projectMap.rootPath,
      limit: limit,
      queryTerms: queryTerms,
      matchedFeatures: matchedFeatures,
      files: files,
      routes: relevantRoutes,
      warnings: warnings,
    );
  }

  List<String> _queryTerms(String task) {
    final terms = <String>{};
    for (final rawTerm in _tokenize(task)) {
      final term = _singularize(rawTerm);
      if (term.length < 2 || _stopWords.contains(term)) {
        continue;
      }
      terms.add(term);
      final alias = _builtInAliases[term];
      if (alias != null) {
        terms.add(alias);
      }
    }
    return terms.toList(growable: false);
  }

  void _scorePath(_ContextCandidate candidate, List<String> queryTerms) {
    final pathTerms = _tokenize(candidate.node.path).map(_singularize).toSet();
    final matched = queryTerms.where(pathTerms.contains).toList();
    if (matched.isEmpty) {
      return;
    }
    candidate
      ..score += 20 * matched.length
      ..reasons.add('Path matches task terms: ${matched.join(', ')}.');

    final basenameTerms = _tokenize(
      candidate.node.path.split('/').last,
    ).map(_singularize).toSet();
    final basenameMatches = queryTerms.where(basenameTerms.contains).toList();
    if (basenameMatches.isNotEmpty) {
      candidate
        ..score += 15
        ..reasons.add('File name directly matches the task.');
    }
  }

  void _scoreFeature(_ContextCandidate candidate, List<String> queryTerms) {
    final feature = candidate.node.feature;
    if (feature == null) {
      return;
    }
    final featureTerms = _tokenize(feature).map(_singularize).toSet();
    final matched = queryTerms.where(featureTerms.contains).toList();
    if (matched.isEmpty) {
      return;
    }
    candidate
      ..score += 80
      ..reasons.add('Belongs to matched feature `$feature`.');
  }

  void _scoreSymbols(
    _ContextCandidate candidate,
    List<ProjectSymbol> symbols,
    List<String> queryTerms,
  ) {
    for (final symbol in symbols) {
      final symbolTerms = _tokenize(symbol.name).map(_singularize).toSet();
      final matched = queryTerms.where(symbolTerms.contains).toList();
      if (matched.isNotEmpty) {
        candidate
          ..score += 50 + (10 * matched.length)
          ..reasons.add(
            'Declares ${symbol.kind.name} `${symbol.name}` matching the task.',
          );
      }
      final kindTerm = _singularize(symbol.kind.name.toLowerCase());
      if (queryTerms.contains(kindTerm)) {
        candidate
          ..score += 25
          ..reasons.add('Declares requested architecture role `$kindTerm`.');
      }
    }
  }

  void _scoreRoutes(
    _ContextCandidate candidate,
    List<ProjectRoute> routes,
    List<String> queryTerms,
  ) {
    for (final route in routes) {
      final routeText = <String>[
        if (route.name != null) route.name!,
        if (route.path != null) route.path!,
        if (route.declaration != null) route.declaration!,
      ].join(' ');
      final routeTerms = _tokenize(routeText).map(_singularize).toSet();
      final matched = queryTerms.where(routeTerms.contains).toList();
      if (matched.isEmpty) {
        continue;
      }
      final label =
          route.name ?? route.path ?? route.declaration ?? '<unnamed>';
      candidate
        ..score += 60
        ..reasons.add('Defines matched route `$label` via ${route.router}.');
    }
  }

  void _propagateGraphContext(
    Map<String, _ContextCandidate> candidates, {
    required Map<String, Set<String>> dependencies,
    required Map<String, Set<String>> dependents,
  }) {
    final seeds = <String, int>{
      for (final entry in candidates.entries)
        if (entry.value.score > 0) entry.key: entry.value.score,
    };
    for (final seed in seeds.entries) {
      for (final dependency in dependencies[seed.key] ?? const <String>{}) {
        final candidate = candidates[dependency];
        if (candidate == null) {
          continue;
        }
        candidate
          ..score += 14
          ..reasons.add('Direct dependency of `${seed.key}`.');
      }
      for (final dependent in dependents[seed.key] ?? const <String>{}) {
        final candidate = candidates[dependent];
        if (candidate == null) {
          continue;
        }
        candidate
          ..score += 12
          ..reasons.add('Direct dependent of `${seed.key}`.');
      }
    }
  }

  void _addFallbackCandidates(
    Map<String, _ContextCandidate> candidates, {
    required List<ProjectRoute> routes,
    required Map<String, Set<String>> dependencies,
    required Map<String, Set<String>> dependents,
  }) {
    final mainCandidate = candidates['lib/main.dart'];
    if (mainCandidate != null) {
      mainCandidate
        ..score += 40
        ..reasons.add('Application entry point fallback.');
    }

    for (final route in routes) {
      final candidate = candidates[route.sourcePath];
      if (candidate == null) {
        continue;
      }
      candidate
        ..score += 30
        ..reasons.add('Router declaration fallback.');
    }

    for (final candidate in candidates.values) {
      final degree =
          (dependencies[candidate.node.path]?.length ?? 0) +
          (dependents[candidate.node.path]?.length ?? 0);
      if (degree > 0) {
        candidate
          ..score += degree.clamp(1, 20).toInt()
          ..reasons.add('Connected project file fallback with degree $degree.');
      }
    }
  }

  Map<String, List<ProjectSymbol>> _symbolsByPath(List<ProjectSymbol> symbols) {
    final result = <String, List<ProjectSymbol>>{};
    for (final symbol in symbols) {
      result.putIfAbsent(symbol.path, () => <ProjectSymbol>[]).add(symbol);
    }
    return result;
  }

  Map<String, List<ProjectRoute>> _routesByPath(List<ProjectRoute> routes) {
    final result = <String, List<ProjectRoute>>{};
    for (final route in routes) {
      result.putIfAbsent(route.sourcePath, () => <ProjectRoute>[]).add(route);
    }
    return result;
  }

  Map<String, Set<String>> _dependencies(ProjectMap projectMap) {
    final result = <String, Set<String>>{
      for (final node in projectMap.nodes) node.path: <String>{},
    };
    for (final edge in projectMap.edges) {
      result[edge.source]?.add(edge.target);
    }
    return result;
  }

  Map<String, Set<String>> _dependents(ProjectMap projectMap) {
    final result = <String, Set<String>>{
      for (final node in projectMap.nodes) node.path: <String>{},
    };
    for (final edge in projectMap.edges) {
      result[edge.target]?.add(edge.source);
    }
    return result;
  }

  Iterable<String> _tokenize(String value) sync* {
    final withCamelBoundaries = value.replaceAllMapped(
      RegExp('([a-z0-9])([A-Z])'),
      (match) => '${match.group(1)} ${match.group(2)}',
    );
    final normalized = withCamelBoundaries
        .toLowerCase()
        .replaceAll('ي', 'ی')
        .replaceAll('ك', 'ک');
    for (final token in normalized.split(RegExp(r'[^a-z0-9؀-ۿ]+'))) {
      if (token.isNotEmpty) {
        yield token;
      }
    }
  }

  String _singularize(String term) {
    if (term.length > 4 && term.endsWith('ies')) {
      return '${term.substring(0, term.length - 3)}y';
    }
    if (term.length > 3 && term.endsWith('s') && !term.endsWith('ss')) {
      return term.substring(0, term.length - 1);
    }
    return term;
  }
}

final class _ContextCandidate {
  _ContextCandidate({required this.node});

  final ProjectMapNode node;
  final Set<String> reasons = <String>{};
  int score = 0;
}
