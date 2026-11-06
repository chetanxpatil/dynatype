# DynaType

Simple JSON validation for Dart and Flutter. Define a schema once, then reuse it
for API responses, configuration, or other JSON data.

## Install

```yaml
dependencies:
  dynatype: ^2.1.0
```

## Define the shape. Validate the data.

```dart
import 'package:dynatype/dynatype.dart';

void main() {
  final book = Dyna.object({
    'title': Dyna.string(),
    'price': Dyna.number(),
    'tags': Dyna.list(Dyna.string()),
    'subtitle': Dyna.string().optional(),
  });

  book.validateJson(
    '{"title":"Dart Guide","price":19.5,"tags":["dart","flutter"]}',
  );
}
```

Validation succeeds silently or throws `DynaValidationException`, which is also a
`FormatException`. If your HTTP client already decoded the response, use
`book.validate(responseData)` directly.

## Nest schemas naturally

```dart
final catalog = Dyna.object({
  'books': Dyna.list(Dyna.object({
    'title': Dyna.string(),
    'author': Dyna.object({
      'name': Dyna.string(),
      'email': Dyna.string().nullable(),
    }),
  })),
});
```

Objects and lists can nest at any level. A schema can also validate a root list,
string, number, or other value; an object wrapper is not required.

## Optional and nullable fields

Fields are required by default. Missing and null are different:

| Rule | Missing field | Explicit `null` | String |
| --- | --- | --- | --- |
| `Dyna.string()` | Invalid | Invalid | Valid |
| `Dyna.string().optional()` | Valid | Invalid | Valid |
| `Dyna.string().nullable()` | Invalid | Valid | Valid |
| `Dyna.string().optional().nullable()` | Valid | Valid | Valid |

Modifier order does not matter. `optional()` applies only to missing object
fields; it does not skip validation of root values or list elements.

## Inspect errors without exceptions

```dart
final result = catalog.checkJson(responseBody);
if (!result.isValid) {
  for (final error in result.errors) {
    print('${error.path}: ${error.message}');
  }
}
```

An error might read `$["books"][2]["author"]["name"]: Expected string, got int`.
Each error includes a stable `code` (`required`, `typeMismatch`, `unknownField`,
or `invalidJson`), a path, and a message. Type errors also provide `expectedType`
and `actualType`; malformed JSON preserves the decoder's `offset` when available.

| Input | Throw on failure | Return `DynaResult` |
| --- | --- | --- |
| Decoded data | `schema.validate(data)` | `schema.check(data)` |
| JSON text | `schema.validateJson(text)` | `schema.checkJson(text)` |

All failures are collected across fields and list elements. A wrong container
type produces one error at that container, rather than errors for its children.
Schemas do not print, coerce values, or change your data. A string such as `"42"`
does not satisfy a number rule. Results and error lists are immutable.

## Available rules

| Builder | Accepts |
| --- | --- |
| `Dyna.string()` | Strings |
| `Dyna.boolean()` | Booleans |
| `Dyna.integer()` | Dart integers |
| `Dyna.number()` | Dart integers or doubles |
| `Dyna.nullValue()` | Null |
| `Dyna.any()` | Any value, including null; the field must still exist |
| `Dyna.list(item)` | Lists whose elements match `item`; empty lists are valid |
| `Dyna.object(fields)` | Objects with string keys, with each field checked recursively |

Extra object fields are allowed by default. Use
`Dyna.object(fields, allowUnknownFields: false)` to reject them. Keys are literal,
so dots inside a key are not interpreted as paths. Object schemas copy their
field definitions when created and can be reused safely.

Number rules follow [Dart's number semantics](https://dart.dev/resources/language/number-representation),
which differ between native and JavaScript runtimes. Use `number()` when either
integer or floating-point values are acceptable.

## Existing users

`DynaValidator` and `DynaType` continue to work unchanged. You can adopt the new
API one schema at a time. See the [original API guide](doc/legacy-api.md).

## Development

```sh
dart pub get
dart analyze --fatal-infos
dart test
dart test --platform chrome
dart run example/dynatype_example.dart
```

[BSD 3-Clause license](LICENSE).
