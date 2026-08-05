import 'guard_report.dart';
import 'project_map.dart';
import 'project_mapper.dart';

/// A deterministic rule evaluated against a Flower project map.
abstract interface class ArchitectureRule {
  String get id;

  Iterable<GuardViolation> evaluate(ProjectMap projectMap);
}

/// Runs architecture rules without executing project code.
final class ArchitectureGuard {
  ArchitectureGuard({
    ProjectMapper mapper = const ProjectMapper(),
    Iterable<ArchitectureRule>? rules,
  }) : _projectMapper = mapper,
       _rules = List.unmodifiable(
         rules ??
             const <ArchitectureRule>[
               DependencyCycleRule(),
               LayerDependencyRule(),
               DomainFlutterDependencyRule(),
             ],
       );

  final ProjectMapper _projectMapper;
  final List<ArchitectureRule> _rules;

  Future<GuardReport> inspect(String rootPath) async {
    final projectMap = await _projectMapper.build(rootPath);
    final violations = <GuardViolation>[];
    for (final rule in _rules) {
      violations.addAll(rule.evaluate(projectMap));
    }
    violations.sort((left, right) {
      final severityOrder = right.severity.index.compareTo(left.severity.index);
      if (severityOrder != 0) {
        return severityOrder;
      }
      final pathOrder = left.path.compareTo(right.path);
      if (pathOrder != 0) {
        return pathOrder;
      }
      final ruleOrder = left.ruleId.compareTo(right.ruleId);
      if (ruleOrder != 0) {
        return ruleOrder;
      }
      return (left.targetPath ?? '').compareTo(right.targetPath ?? '');
    });

    return GuardReport(
      packageName: projectMap.packageName,
      rootPath: projectMap.rootPath,
      enabledRules: _rules.map((rule) => rule.id),
      violations: violations,
    );
  }
}

/// Rejects strongly connected internal dependency components.
final class DependencyCycleRule implements ArchitectureRule {
  const DependencyCycleRule();

  @override
  String get id => 'dependency_cycle';

  @override
  Iterable<GuardViolation> evaluate(ProjectMap projectMap) sync* {
    for (final cycle in projectMap.cycles) {
      if (cycle.isEmpty) {
        continue;
      }
      yield GuardViolation(
        ruleId: id,
        severity: GuardSeverity.error,
        path: cycle.first,
        targetPath: cycle.length > 1 ? cycle[1] : cycle.first,
        message: 'Dependency cycle detected: ${cycle.join(' -> ')}.',
        suggestion:
            'Move shared contracts into a lower-level module or reverse one '
            'dependency through an interface.',
      );
    }
  }
}

/// Enforces the default dependency direction between common clean layers.
final class LayerDependencyRule implements ArchitectureRule {
  const LayerDependencyRule();

  static const Map<String, Set<String>> _forbiddenTargets =
      <String, Set<String>>{
        'domain': <String>{'data', 'application', 'presentation'},
        'data': <String>{'application', 'presentation'},
        'application': <String>{'presentation'},
      };

  @override
  String get id => 'layer_dependency';

  @override
  Iterable<GuardViolation> evaluate(ProjectMap projectMap) sync* {
    final nodesById = <String, ProjectMapNode>{
      for (final node in projectMap.nodes) node.id: node,
    };

    for (final edge in projectMap.edges) {
      final source = nodesById[edge.source];
      final target = nodesById[edge.target];
      if (source == null || target == null || source.generated) {
        continue;
      }
      final sourceLayer = _layerOf(source.path);
      final targetLayer = _layerOf(target.path);
      if (sourceLayer == null || targetLayer == null) {
        continue;
      }
      if (!(_forbiddenTargets[sourceLayer] ?? const <String>{}).contains(
        targetLayer,
      )) {
        continue;
      }

      yield GuardViolation(
        ruleId: id,
        severity: GuardSeverity.error,
        path: source.path,
        targetPath: target.path,
        message:
            'The `$sourceLayer` layer depends on the higher-level '
            '`$targetLayer` layer.',
        suggestion:
            'Move the shared contract to `$sourceLayer` or a lower-level '
            'core module, then invert the dependency.',
      );
    }
  }

  String? _layerOf(String path) {
    const layers = <String>{'domain', 'data', 'application', 'presentation'};
    for (final segment in path.split('/')) {
      if (layers.contains(segment)) {
        return segment;
      }
    }
    return null;
  }
}

/// Keeps pure domain files independent from Flutter framework packages.
final class DomainFlutterDependencyRule implements ArchitectureRule {
  const DomainFlutterDependencyRule();

  @override
  String get id => 'domain_flutter_dependency';

  @override
  Iterable<GuardViolation> evaluate(ProjectMap projectMap) sync* {
    for (final node in projectMap.nodes) {
      if (node.generated || !_isDomainPath(node.path)) {
        continue;
      }
      final flutterPackages =
          node.externalPackages
              .where(
                (packageName) =>
                    packageName == 'flutter' ||
                    packageName.startsWith('flutter_'),
              )
              .toList()
            ..sort();
      if (flutterPackages.isEmpty) {
        continue;
      }

      yield GuardViolation(
        ruleId: id,
        severity: GuardSeverity.error,
        path: node.path,
        targetPath: null,
        message:
            'Domain code imports Flutter packages: '
            '${flutterPackages.join(', ')}.',
        suggestion:
            'Move framework-specific behavior to application, data, or '
            'presentation and expose a pure Dart contract to the domain.',
      );
    }
  }

  bool _isDomainPath(String path) => path.split('/').contains('domain');
}
