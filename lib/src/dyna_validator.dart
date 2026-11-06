import 'dart:convert';

import 'type.dart';

/// Validates a JSON object against required fields and their types.
///
/// The empty schema key selects the root object. Other schema keys select an
/// immediate child object by its literal key; they are not dot-separated paths.
/// Additional fields are allowed. Every declared field is required.
class DynaValidator {
  /// The JSON text to validate.
  final String json;

  /// Required fields for the root object and its immediate child objects.
  final Map<String, List<DynaType>> schema;

  /// Creates a validator for [json] using [schema].
  DynaValidator({required this.json, required this.schema});

  /// Validates the JSON without printing or modifying the input or schema.
  ///
  /// Throws [FormatException] for malformed JSON, a non-object root, missing
  /// objects or fields, or values that do not match their declared types.
  void validate() {
    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException catch (error) {
      throw FormatException(
        'Invalid JSON: ${error.message}',
        error.source,
        error.offset,
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw FormatException(
        'Expected a JSON object at \$, got ${decoded.runtimeType}.',
      );
    }

    for (final entry in schema.entries) {
      final key = entry.key;
      final path = key.isEmpty ? r'$' : _fieldPath(r'$', key);
      if (key.isNotEmpty && !decoded.containsKey(key)) {
        throw FormatException('Missing required object at $path.');
      }

      final Object? data = key.isEmpty ? decoded : decoded[key];
      if (data is! Map<String, dynamic>) {
        throw FormatException(
          'Expected a JSON object at $path, got ${data.runtimeType}.',
        );
      }
      _verifyFields(data, entry.value, path);
    }
  }

  void _verifyFields(
    Map<String, dynamic> data,
    List<DynaType> fields,
    String path,
  ) {
    final errors = <String>[];
    for (final field in fields) {
      final fieldPath = _fieldPath(path, field.key);
      if (!data.containsKey(field.key)) {
        errors.add('Missing required field at $fieldPath');
      } else if (!_matchesType(data[field.key], field.type)) {
        errors.add(
          'Incorrect type at $fieldPath: expected ${field.type}, '
          'got ${data[field.key].runtimeType}',
        );
      }
    }
    if (errors.isNotEmpty) {
      throw FormatException(errors.join('; '));
    }
  }
}

String _fieldPath(String parent, String key) => '$parent[${jsonEncode(key)}]';

// A Type object cannot be used as the right-hand side of an `is` expression.
// Register JSON types explicitly, checking list contents rather than the generic
// type of a decoded List<dynamic>. Do not parse runtime type names: they differ
// between Dart backends and are not a stable reflection API.
typedef _NullableObject = Object?;

final Map<Type, bool Function(Object?)> _scalarChecks = {
  String: (value) => value is String,
  bool: (value) => value is bool,
  int: (value) => value is int,
  double: (value) => value is double,
  num: (value) => value is num,
  Null: (value) => value == null,
  Object: (value) => value != null,
  _NullableObject: (value) => true,
  dynamic: (value) => true,
  Map: (value) => value is Map<String, dynamic>,
  Map<String, dynamic>: (value) => value is Map<String, dynamic>,
  Map<String, Object?>: (value) => value is Map<String, dynamic>,
  List: (value) => value is List,
};

final Map<Type, bool Function(Object?)> _listElementChecks = {
  List<String>: (value) => value is String,
  List<bool>: (value) => value is bool,
  List<int>: (value) => value is int,
  List<double>: (value) => value is double,
  List<num>: (value) => value is num,
  // Null describes JSON null elements; void would accept other values.
  // ignore: prefer_void_to_null
  List<Null>: (value) => value == null,
  List<Object>: (value) => value != null,
  List<Object?>: (value) => true,
  List<Map>: (value) => value is Map<String, dynamic>,
  List<Map<String, dynamic>>: (value) => value is Map<String, dynamic>,
  List<Map<String, Object?>>: (value) => value is Map<String, dynamic>,
  List<List>: (value) => value is List,
};

bool _matchesType(Object? value, Type type) {
  final scalarCheck = _scalarChecks[type];
  if (scalarCheck != null) return scalarCheck(value);

  final elementCheck = _listElementChecks[type];
  if (elementCheck != null) {
    return value is List && value.every(elementCheck);
  }

  // Preserve exact matching for declarations outside the documented JSON types.
  return value.runtimeType == type;
}
