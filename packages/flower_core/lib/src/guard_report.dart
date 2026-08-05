/// Severity assigned to one architecture guard violation.
enum GuardSeverity {
  info,
  warning,
  error;

  bool isAtLeast(GuardSeverity threshold) => index >= threshold.index;
}

/// One deterministic architecture or project-rule violation.
final class GuardViolation {
  const GuardViolation({
    required this.ruleId,
    required this.severity,
    required this.path,
    required this.targetPath,
    required this.message,
    required this.suggestion,
  });

  final String ruleId;
  final GuardSeverity severity;
  final String path;
  final String? targetPath;
  final String message;
  final String suggestion;

  Map<String, Object?> toJson() => <String, Object?>{
    'ruleId': ruleId,
    'severity': severity.name,
    'path': path,
    'targetPath': targetPath,
    'message': message,
    'suggestion': suggestion,
  };
}

/// A stable, machine-readable result from Flower architecture validation.
final class GuardReport {
  GuardReport({
    required this.packageName,
    required this.rootPath,
    required Iterable<String> enabledRules,
    required Iterable<GuardViolation> violations,
  }) : enabledRules = List.unmodifiable(enabledRules),
       violations = List.unmodifiable(violations);

  static const String schemaVersion = '1.0.0';

  final String packageName;
  final String rootPath;
  final List<String> enabledRules;
  final List<GuardViolation> violations;

  Map<GuardSeverity, int> get counts => <GuardSeverity, int>{
    for (final severity in GuardSeverity.values)
      severity: violations.where((item) => item.severity == severity).length,
  };

  bool hasViolationsAtOrAbove(GuardSeverity severity) =>
      violations.any((violation) => violation.severity.isAtLeast(severity));

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'packageName': packageName,
    'rootPath': rootPath,
    'enabledRules': enabledRules,
    'counts': <String, int>{
      for (final entry in counts.entries) entry.key.name: entry.value,
    },
    'passed': violations.isEmpty,
    'violations': violations
        .map((violation) => violation.toJson())
        .toList(growable: false),
  };
}
