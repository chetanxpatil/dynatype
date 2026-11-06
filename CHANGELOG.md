# Changelog

All notable changes to the DynaType package will be documented in this file.

## 2.1.0

- Add a reusable schema API: `Dyna.object`, `Dyna.list`, `Dyna.string`,
  `Dyna.integer`, `Dyna.number`, `Dyna.boolean`, `Dyna.nullValue`, and `Dyna.any`.
- Define nested objects and list elements inline, without root marker keys or
  repeated `DynaType(key: ..., type: ...)` declarations.
- Add independent `.optional()` and `.nullable()` modifiers.
- Accept decoded data with `validate` / `check`, and JSON text with
  `validateJson` / `checkJson` on any schema, including root arrays and scalars.
- Return all failures with field paths, list indices, and stable error codes.
  Throwing methods use `DynaValidationException`, a `FormatException` subtype.
- Add strict object validation with `allowUnknownFields: false`.
- Preserve the existing `DynaValidator` and `DynaType` API and behavior.
- Simplify the quick start and add documentation for the original API.
- Link package metadata to the restored GitHub repository.

## 2.0.1

- Fix valid decoded objects being rejected for `Map<String, dynamic>` fields.
- Validate elements of supported typed lists, including empty lists, rather than
  comparing the decoded list's runtime generic type.
- Accept both integers and doubles for `num` fields and `List<num>` elements.
- Report missing, null, or incorrectly typed child objects as `FormatException`
  instead of leaking `TypeError`.
- Distinguish malformed JSON from a valid JSON value with an unsupported root
  shape, and preserve malformed JSON source offsets.
- Include field paths and expected/actual types in validation messages. Error
  message text has changed; catch `FormatException` rather than matching messages.
- Remove success printing from validation. Applications can log after calling
  `validate()` if needed.
- Allow constant `DynaType` declarations without changing the existing API.
- Update installation instructions, supported-type documentation, and examples;
  replace the unavailable homepage with the package page.
- Add regression tests and a Dart VM/Chrome CI workflow.

## 2.0.0

- Major restructuring of the package.
- Simplified the validation process, now done via a single `DynaValidator` class.
- Introduced a more flexible schema definition using `Map<String, List<DynaType>>`.
- Enhanced error handling, now throwing `FormatException` on missing or incorrect fields and invalid JSON data.
- Added detailed comments to the `DynaType` and `DynaValidator` classes.

## 1.0.7

- Solved issue of getting `Map<String, Null>` data type.

## 1.0.6

- Fixed all known issues.

## 1.0.5

- Bug fixes.

## 1.0.4

- Made major changes in map comparison logic.

## 1.0.3

- Updated `README.md`.

## 1.0.2

- Bug fixes.
- Made major type changes.
- Updated example.

## 1.0.1

- Bug fixes.
- Added example.

## 1.0.0

- Initial version.
