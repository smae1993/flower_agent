/// Architectural roles detected from Dart declarations.
enum ProjectSymbolKind {
  repository,
  service,
  provider,
  controller,
  dataSource,
}

/// One architecture-relevant declaration inside a Dart or Flutter project.
final class ProjectSymbol {
  ProjectSymbol({
    required this.name,
    required this.kind,
    required this.path,
    required this.feature,
    required this.line,
    required Map<String, String> metadata,
  }) : metadata = Map.unmodifiable(metadata);

  final String name;
  final ProjectSymbolKind kind;
  final String path;
  final String? feature;
  final int line;
  final Map<String, String> metadata;

  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'kind': kind.name,
    'path': path,
    'feature': feature,
    'line': line,
    'metadata': metadata,
  };
}

/// One route declaration discovered from a supported routing constructor.
final class ProjectRoute {
  const ProjectRoute({
    required this.router,
    required this.path,
    required this.name,
    required this.declaration,
    required this.sourcePath,
    required this.feature,
    required this.line,
  });

  final String router;
  final String? path;
  final String? name;
  final String? declaration;
  final String sourcePath;
  final String? feature;
  final int line;

  Map<String, Object?> toJson() => <String, Object?>{
    'router': router,
    'path': path,
    'name': name,
    'declaration': declaration,
    'sourcePath': sourcePath,
    'feature': feature,
    'line': line,
  };
}

/// A stable symbol and route index for one Dart or Flutter package.
final class ProjectSymbolIndex {
  ProjectSymbolIndex({
    required this.packageName,
    required this.rootPath,
    required Iterable<ProjectSymbol> symbols,
    required Iterable<ProjectRoute> routes,
  }) : symbols = List.unmodifiable(symbols),
       routes = List.unmodifiable(routes);

  static const String schemaVersion = '1.0.0';

  final String packageName;
  final String rootPath;
  final List<ProjectSymbol> symbols;
  final List<ProjectRoute> routes;

  Map<ProjectSymbolKind, int> get counts => <ProjectSymbolKind, int>{
    for (final kind in ProjectSymbolKind.values)
      kind: symbols.where((symbol) => symbol.kind == kind).length,
  };

  ProjectSymbolIndex filtered({ProjectSymbolKind? kind, String? feature}) {
    final normalizedFeature = feature?.trim();
    return ProjectSymbolIndex(
      packageName: packageName,
      rootPath: rootPath,
      symbols: symbols.where(
        (symbol) =>
            (kind == null || symbol.kind == kind) &&
            (normalizedFeature == null ||
                normalizedFeature.isEmpty ||
                symbol.feature == normalizedFeature),
      ),
      routes: routes.where(
        (route) =>
            normalizedFeature == null ||
            normalizedFeature.isEmpty ||
            route.feature == normalizedFeature,
      ),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'packageName': packageName,
    'rootPath': rootPath,
    'counts': <String, int>{
      for (final entry in counts.entries) entry.key.name: entry.value,
    },
    'symbols': symbols.map((symbol) => symbol.toJson()).toList(growable: false),
    'routes': routes.map((route) => route.toJson()).toList(growable: false),
  };
}
