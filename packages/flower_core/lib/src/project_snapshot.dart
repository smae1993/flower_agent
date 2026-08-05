/// A deterministic snapshot of an inspected Dart or Flutter project.
final class ProjectSnapshot {
  ProjectSnapshot({
    required this.rootPath,
    required this.packageName,
    required this.description,
    required this.isFlutterProject,
    required this.sourceFileCount,
    required this.generatedFileCount,
    required this.testFileCount,
    required this.integrationTestFileCount,
    required Iterable<String> featureNames,
    required Map<String, List<String>> technologies,
    required Iterable<String> warnings,
  }) : featureNames = List.unmodifiable(featureNames),
       technologies = Map.unmodifiable(
         technologies.map(
           (key, value) => MapEntry(key, List<String>.unmodifiable(value)),
         ),
       ),
       warnings = List.unmodifiable(warnings);

  /// The current JSON contract version.
  static const int schemaVersion = 1;

  final String rootPath;
  final String packageName;
  final String description;
  final bool isFlutterProject;
  final int sourceFileCount;
  final int generatedFileCount;
  final int testFileCount;
  final int integrationTestFileCount;
  final List<String> featureNames;
  final Map<String, List<String>> technologies;
  final List<String> warnings;

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'rootPath': rootPath,
    'packageName': packageName,
    'description': description,
    'isFlutterProject': isFlutterProject,
    'files': <String, int>{
      'source': sourceFileCount,
      'generated': generatedFileCount,
      'test': testFileCount,
      'integrationTest': integrationTestFileCount,
    },
    'features': featureNames,
    'technologies': technologies,
    'warnings': warnings,
  };
}
