import 'dart:convert';

/// Builds reusable schemas that follow the shape of your data.
abstract final class Dyna {
  /// A string value.
  static DynaSchema string() =>
      _ValueSchema('string', (value) => value is String);

  /// A boolean value.
  static DynaSchema boolean() =>
      _ValueSchema('boolean', (value) => value is bool);

  /// An integer, using Dart's native or JavaScript integer semantics.
  static DynaSchema integer() =>
      _ValueSchema('integer', (value) => value is int);

  /// An integer or floating-point number.
  static DynaSchema number() => _ValueSchema('number', (value) => value is num);

  /// A null value. An object field using this schema must still be present.
  static DynaSchema nullValue() =>
      _ValueSchema('null', (value) => value == null);

  /// Any value, including null. An object field must still be present.
  static DynaSchema any() => _ValueSchema('any value', (_) => true);

  /// An object whose fields are validated recursively.
  ///
  /// Fields are required unless marked [DynaSchema.optional]. Extra fields are
  /// allowed by default. The field definitions are copied when the schema is
  /// created, so later changes to [fields] do not change the schema.
  static DynaSchema object(
    Map<String, DynaSchema> fields, {
    bool allowUnknownFields = true,
  }) =>
      _ObjectSchema(fields, allowUnknownFields: allowUnknownFields);

  /// A list in which every element must match [item]. Empty lists are valid.
  static DynaSchema list(DynaSchema item) => _ListSchema(item);
}

/// A reusable rule for decoded values or JSON text.
///
/// Use [validate] or [validateJson] to throw on invalid data. Use [check] or
/// [checkJson] to inspect all validation errors without throwing.
sealed class DynaSchema {
  const DynaSchema();

  bool get _allowsMissing => false;

  /// Allows this field to be absent from an object.
  ///
  /// This does not allow null unless the underlying schema accepts null. When
  /// applied to a root value or a list element, it does not skip validation.
  DynaSchema optional() => _OptionalSchema(this);

  /// Allows an explicit null value. An object field is still required.
  DynaSchema nullable() => _NullableSchema(this);

  /// Checks decoded data and returns all errors without changing [value].
  DynaResult check(Object? value) {
    final errors = <DynaError>[];
    _check(value, r'$', errors);
    return DynaResult._(errors);
  }

  /// Decodes JSON text, then checks its value. Malformed JSON is an error result.
  DynaResult checkJson(String source) {
    final Object? value;
    try {
      value = jsonDecode(source);
    } on FormatException catch (error) {
      return DynaResult._([
        DynaError(
          path: r'$',
          code: DynaErrorCode.invalidJson,
          message: 'Invalid JSON: ${error.message}',
          offset: error.offset,
        ),
      ], source: source);
    }
    return check(value);
  }

  /// Throws [DynaValidationException] if decoded data does not match this schema.
  void validate(Object? value) => check(value).throwIfInvalid();

  /// Throws [DynaValidationException] for malformed or non-matching JSON text.
  void validateJson(String source) => checkJson(source).throwIfInvalid();

  void _check(Object? value, String path, List<DynaError> errors);
}

/// The kind of validation failure, independent of human-readable message text.
enum DynaErrorCode {
  /// An object field is absent.
  required,

  /// A value does not match its schema.
  typeMismatch,

  /// An object contains a field disallowed by a strict schema.
  unknownField,

  /// The input is not valid JSON text.
  invalidJson,
}

/// A validation failure at a field path or list index.
class DynaError {
  /// Creates an immutable validation error.
  const DynaError({
    required this.path,
    required this.code,
    required this.message,
    this.expectedType,
    this.actualType,
    this.offset,
  });

  /// A path such as `$["books"][2]["title"]`.
  final String path;

  /// A stable category suitable for programmatic error handling.
  final DynaErrorCode code;

  /// A human-readable explanation without the input value.
  final String message;

  /// The expected type description for a type mismatch.
  final String? expectedType;

  /// The actual Dart type for a type mismatch.
  final String? actualType;

  /// The decoder's character offset for malformed JSON, when available.
  final int? offset;

  @override
  String toString() => '$path: $message';
}

/// The immutable result of checking a schema.
class DynaResult {
  DynaResult._(Iterable<DynaError> errors, {String? source})
      : errors = List.unmodifiable(errors),
        _source = source;

  /// All errors, in schema field and list element order.
  final List<DynaError> errors;
  final String? _source;

  /// Whether the data satisfies every rule.
  bool get isValid => errors.isEmpty;

  /// Throws [DynaValidationException] when this result contains errors.
  void throwIfInvalid() {
    if (!isValid) throw DynaValidationException._(errors, source: _source);
  }
}

/// A validation exception that can also be caught as [FormatException].
class DynaValidationException extends FormatException {
  DynaValidationException._(this.errors, {String? source})
      : super(errors.join('; '), source,
            errors.length == 1 ? errors.single.offset : null);

  /// The same immutable errors returned by [DynaResult.errors].
  final List<DynaError> errors;
}

class _ValueSchema extends DynaSchema {
  const _ValueSchema(this.expected, this.matches);

  final String expected;
  final bool Function(Object?) matches;

  @override
  void _check(Object? value, String path, List<DynaError> errors) {
    if (!matches(value)) errors.add(_typeError(path, expected, value));
  }
}

class _ObjectSchema extends DynaSchema {
  _ObjectSchema(Map<String, DynaSchema> fields,
      {required this.allowUnknownFields})
      : fields = Map.unmodifiable(fields);

  final Map<String, DynaSchema> fields;
  final bool allowUnknownFields;

  @override
  void _check(Object? value, String path, List<DynaError> errors) {
    if (value is! Map || value.keys.any((key) => key is! String)) {
      errors.add(_typeError(path, 'object with string keys', value));
      return;
    }

    for (final field in fields.entries) {
      final fieldPath = _fieldPath(path, field.key);
      if (value.containsKey(field.key)) {
        field.value._check(value[field.key], fieldPath, errors);
      } else if (!field.value._allowsMissing) {
        errors.add(DynaError(
          path: fieldPath,
          code: DynaErrorCode.required,
          message: 'Missing required field',
        ));
      }
    }

    if (!allowUnknownFields) {
      for (final key in value.keys) {
        if (!fields.containsKey(key)) {
          errors.add(DynaError(
            path: _fieldPath(path, key as String),
            code: DynaErrorCode.unknownField,
            message: 'Unknown field',
          ));
        }
      }
    }
  }
}

class _ListSchema extends DynaSchema {
  const _ListSchema(this.item);

  final DynaSchema item;

  @override
  void _check(Object? value, String path, List<DynaError> errors) {
    if (value is! List) {
      errors.add(_typeError(path, 'list', value));
      return;
    }
    for (var index = 0; index < value.length; index++) {
      item._check(value[index], '$path[$index]', errors);
    }
  }
}

class _OptionalSchema extends DynaSchema {
  const _OptionalSchema(this.inner);

  final DynaSchema inner;

  @override
  bool get _allowsMissing => true;

  @override
  void _check(Object? value, String path, List<DynaError> errors) =>
      inner._check(value, path, errors);
}

class _NullableSchema extends DynaSchema {
  const _NullableSchema(this.inner);

  final DynaSchema inner;

  @override
  bool get _allowsMissing => inner._allowsMissing;

  @override
  void _check(Object? value, String path, List<DynaError> errors) {
    if (value != null) inner._check(value, path, errors);
  }
}

String _fieldPath(String parent, String key) => '$parent[${jsonEncode(key)}]';

DynaError _typeError(String path, String expected, Object? value) {
  final actual = value.runtimeType.toString();
  return DynaError(
    path: path,
    code: DynaErrorCode.typeMismatch,
    message: 'Expected $expected, got $actual',
    expectedType: expected,
    actualType: actual,
  );
}
