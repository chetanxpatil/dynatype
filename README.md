# DynaType

Validate JSON objects, required fields, nested objects, and typed lists in Dart
and Flutter. Validation succeeds silently or throws a `FormatException` with the
location of the problem.

## Installation

```yaml
dependencies:
  dynatype: ^2.0.1
```

```dart
import 'package:dynatype/dynatype.dart';
```

## Quick start

```dart
import 'package:dynatype/dynatype.dart';

void main() {
  const json = '''
  {
    "book": {"name": "Dart Guide", "author": "Ada"},
    "year": 2026,
    "price": 19.5,
    "tags": ["dart", "flutter"]
  }
  ''';

  try {
    DynaValidator(
      json: json,
      schema: const {
        '': [
          DynaType(key: 'book', type: Map<String, dynamic>),
          DynaType(key: 'year', type: int),
          DynaType(key: 'price', type: num),
          DynaType(key: 'tags', type: List<String>),
        ],
        'book': [
          DynaType(key: 'name', type: String),
          DynaType(key: 'author', type: String),
        ],
      },
    ).validate();
    print('The JSON is valid.');
  } on FormatException catch (error) {
    print(error.message);
  }
}
```

The empty schema key (`''`) selects the root object. Other keys, such as `book`,
select an immediate child object. Schema keys are literal: `book.author` selects
a root property named `book.author`; it does not traverse nested objects.

Every declared field must exist. Undeclared fields are allowed. The input must be
a JSON object at the root, even when the schema is empty.

## Supported types

| Declaration | Accepted values |
| --- | --- |
| `String`, `bool`, `int`, `double`, `num` | Values matching Dart's corresponding `is` check; `num` accepts integers and doubles |
| `Null` | An explicitly present field whose value is `null` |
| `Object` | Any non-null JSON value |
| `dynamic` | Any JSON value, including `null`; the key must still exist |
| `Map`, `Map<String, dynamic>`, `Map<String, Object?>` | A JSON object; use a child schema to validate its fields |
| `List`, `List<dynamic>`, `List<Object?>` | A JSON array with any element types |
| `List<String>`, `List<bool>`, `List<int>`, `List<double>`, `List<num>`, `List<Null>`, `List<Object>` | A JSON array in which every element matches the declared type |
| `List<Map>`, `List<Map<String, dynamic>>`, `List<Map<String, Object?>>` | A JSON array containing only objects; object fields are not recursively validated |
| `List<List>` | A JSON array containing only arrays; inner elements are not recursively validated |

Empty arrays satisfy any supported list declaration. Validation does not coerce
values: a string such as `"42"` does not satisfy `int` or `num`.

Numeric checks follow Dart's native and JavaScript number semantics. Use `num`
when either integer or floating-point values are acceptable. See
[Dart's number representation](https://dart.dev/resources/language/number-representation).

Other type declarations retain exact runtime-type matching for compatibility.
Arbitrary typed maps, nested generic collections, nullable scalar declarations,
custom classes, optional fields, and recursive field schemas are not supported
by this API. Use the declarations in the table for predictable JSON validation.

## Errors

Malformed JSON, unsupported root shapes, missing objects or fields, and wrong
field types all throw `FormatException`. For example, a numeric book name can
produce:

```text
Incorrect type at $["book"]["name"]: expected String, got int
```

Paths use bracket notation so keys containing dots or quotes remain unambiguous.
The validator reports all invalid fields in the first failing object. Typed-list
errors identify the field; they do not currently identify the failing index.
Malformed JSON retains the decoder's source and offset information.

Catch `FormatException` rather than matching its message text. Validation does
not print, convert data, or mutate the schema.

## Upgrading from 2.0.0

The `DynaValidator(json: ..., schema: ...).validate()` API is unchanged.
Previously rejected valid object, typed-list, and `num` values now pass.
Invalid child objects produce `FormatException` consistently. Error messages
now include paths, and successful validation no longer prints to the console.

## Development

```sh
dart pub get
dart analyze --fatal-infos
dart test
dart test --platform chrome
dart run example/dynatype_example.dart
dart pub publish --dry-run
```

## License

[BSD 3-Clause](LICENSE).
