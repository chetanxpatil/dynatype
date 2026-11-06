import 'dart:async';
import 'dart:convert';

import 'package:dynatype/dynatype.dart';
import 'package:test/test.dart';

import '../example/dynatype_example.dart' as example;

void validateField(Object? value, Type type) {
  DynaValidator(
    json: jsonEncode({'value': value}),
    schema: {
      '': [DynaType(key: 'value', type: type)],
    },
  ).validate();
}

Matcher formatErrorContaining(String text) => isA<FormatException>()
    .having((error) => error.message, 'message', contains(text));

void main() {
  group('published examples', () {
    test('accepts the original README object and child fields', () {
      final validator = DynaValidator(
        json: '{"book":{"name":"200","author":"Lingod"},'
            '"language":"english","language2":"english","publish":1988}',
        schema: const {
          '': [
            DynaType(key: 'book', type: Map<String, dynamic>),
            DynaType(key: 'language', type: String),
            DynaType(key: 'language2', type: String),
            DynaType(key: 'publish', type: int),
          ],
          'book': [
            DynaType(key: 'name', type: String),
            DynaType(key: 'author', type: String),
          ],
        },
      );
      expect(validator.validate, returnsNormally);
    });

    test('the packaged example reports success', () {
      final messages = <String>[];
      runZoned(example.main,
          zoneSpecification: ZoneSpecification(
            print: (self, parent, zone, message) => messages.add(message),
          ));
      expect(messages, ['The JSON is valid according to the schema.']);
    });
  });

  group('JSON type declarations', () {
    final valid = <Type, List<Object?>>{
      String: ['', 'Dart'],
      bool: [true, false],
      int: [0, -10, 42],
      double: [1.5, -2.25],
      num: [0, -10, 1.5],
      Null: [null],
      Object: [0, false, '', <Object?>[], <String, Object?>{}],
      dynamic: [null, false, 'text', 2, <Object?>[], <String, Object?>{}],
      Map: [
        <String, Object?>{},
        {'a': null}
      ],
      Map<String, dynamic>: [
        <String, Object?>{},
        {'a': 1}
      ],
      Map<String, Object?>: [
        <String, Object?>{},
        {'a': null}
      ],
      List: [
        <Object?>[],
        ['text', 1, null]
      ],
      List<Object?>: [
        <Object?>[],
        ['text', 1, null]
      ],
      List<Object>: [
        <Object>[],
        ['text', 1, false, <String, Object?>{}]
      ],
      List<String>: [
        <String>[],
        ['a', 'b']
      ],
      List<bool>: [
        <bool>[],
        [true, false]
      ],
      List<int>: [
        <int>[],
        [0, -1, 42]
      ],
      List<double>: [
        <double>[],
        [1.5, -2.25]
      ],
      List<num>: [
        <num>[],
        [1, 1.5, -2]
      ],
      // ignore: prefer_void_to_null
      List<Null>: [
        <Null>[],
        [null, null]
      ],
      List<Map>: [
        <Map>[],
        [
          {'a': 1},
          <String, Object?>{}
        ]
      ],
      List<Map<String, dynamic>>: [
        <Map<String, dynamic>>[],
        [
          {'a': null}
        ]
      ],
      List<Map<String, Object?>>: [
        <Map<String, Object?>>[],
        [
          {'a': 1}
        ]
      ],
      List<List>: [
        <List>[],
        [
          <Object?>[],
          ['a', 1]
        ]
      ],
    };
    for (final entry in valid.entries) {
      test('accepts values declared as ${entry.key}', () {
        for (final value in entry.value) {
          expect(() => validateField(value, entry.key), returnsNormally,
              reason: 'Value: $value');
        }
      });
    }

    final invalid = <Type, List<Object?>>{
      String: [null, 1, true, <Object?>[]],
      bool: [null, 0, 'true'],
      int: [null, 1.5, '42', false],
      double: [null, '1.5', false],
      num: [null, '1', false],
      Null: [0, '', <Object?>[]],
      Object: [null],
      Map: [null, <Object?>[], 'object', 1],
      Map<String, dynamic>: [null, <Object?>[], false],
      Map<String, Object?>: [null, <Object?>[], false],
      List: [null, <String, Object?>{}, 'list'],
      List<Object?>: [null, <String, Object?>{}],
      List<Object>: [
        [1, null],
        null
      ],
      List<String>: [
        ['ok', 1],
        ['ok', null],
        'not a list',
        null
      ],
      List<bool>: [
        [true, 0],
        [false, null]
      ],
      List<int>: [
        [1, 1.5],
        [1, '2'],
        [null]
      ],
      List<double>: [
        [1.5, '2.5'],
        [null]
      ],
      List<num>: [
        [1, 1.5, '2'],
        [null]
      ],
      // ignore: prefer_void_to_null
      List<Null>: [
        [null, 0]
      ],
      List<Map>: [
        [<String, Object?>{}, 1],
        [null]
      ],
      List<Map<String, dynamic>>: [
        [<String, Object?>{}, 'bad'],
        [null]
      ],
      List<Map<String, Object?>>: [
        [<String, Object?>{}, false],
        [null]
      ],
      List<List>: [
        [<Object?>[], 'bad'],
        [null]
      ],
    };
    for (final entry in invalid.entries) {
      test('rejects invalid values declared as ${entry.key}', () {
        for (final value in entry.value) {
          expect(() => validateField(value, entry.key),
              throwsA(formatErrorContaining(r'$["value"]')),
              reason: 'Value: $value');
        }
      });
    }

    test('does not coerce strings to numbers', () {
      expect(() => validateField('123', num), throwsFormatException);
    });

    test('rejects unsupported custom types rather than accepting any value',
        () {
      expect(
          () => validateField('2026-11-06', DateTime), throwsFormatException);
    });
  });

  group('objects and required fields', () {
    test('allows additional fields', () {
      expect(
        DynaValidator(
          json: '{"name":"Dart","extra":true}',
          schema: const {
            '': [DynaType(key: 'name', type: String)]
          },
        ).validate,
        returnsNormally,
      );
    });

    test('requires keys even when the declared type accepts null', () {
      for (final type in [Null, dynamic]) {
        expect(
          DynaValidator(
            json: '{}',
            schema: {
              '': [DynaType(key: 'value', type: type)]
            },
          ).validate,
          throwsA(formatErrorContaining('Missing required field')),
        );
      }
    });

    test('reports all invalid fields in an object with paths and types', () {
      expect(
        DynaValidator(
          json: '{"book":{"name":5}}',
          schema: const {
            'book': [
              DynaType(key: 'name', type: String),
              DynaType(key: 'author', type: String),
            ],
          },
        ).validate,
        throwsA(allOf(
          formatErrorContaining(r'$["book"]["name"]'),
          formatErrorContaining('expected String'),
          formatErrorContaining(
              'Missing required field at \$["book"]["author"]'),
        )),
      );
    });

    test('validates child fields without requiring a root declaration', () {
      expect(
        DynaValidator(
          json: '{"book":{"name":"Dart"}}',
          schema: const {
            'book': [DynaType(key: 'name', type: String)]
          },
        ).validate,
        returnsNormally,
      );
    });

    test('reports a missing child as FormatException', () {
      expect(
        DynaValidator(
          json: '{}',
          schema: const {
            'book': [DynaType(key: 'name', type: String)]
          },
        ).validate,
        throwsA(formatErrorContaining('Missing required object at \$["book"]')),
      );
    });

    for (final value in [null, 1, true, 'text', <Object?>[]]) {
      test('reports invalid child $value as FormatException', () {
        expect(
          DynaValidator(
            json: jsonEncode({'book': value}),
            schema: const {
              'book': [DynaType(key: 'name', type: String)]
            },
          ).validate,
          throwsA(
              formatErrorContaining('Expected a JSON object at \$["book"]')),
        );
      });
    }

    test('treats dots in schema keys as literal characters', () {
      expect(
        DynaValidator(
          json: '{"book.author":{"name":"Ada"}}',
          schema: const {
            'book.author': [DynaType(key: 'name', type: String)]
          },
        ).validate,
        returnsNormally,
      );
    });

    test('escapes quotes and newlines in error paths', () {
      const key = 'a"\nb';
      expect(
        DynaValidator(
          json: '{}',
          schema: const {
            '': [DynaType(key: key, type: String)]
          },
        ).validate,
        throwsA(formatErrorContaining('\$[${jsonEncode(key)}]')),
      );
    });

    test('allows an empty root and empty schema', () {
      expect(DynaValidator(json: '{}', schema: const {}).validate,
          returnsNormally);
    });

    test('validation is silent, repeatable, and does not mutate the schema',
        () {
      const schema = {
        '': [DynaType(key: 'name', type: String)]
      };
      final validator = DynaValidator(json: '{"name":"Dart"}', schema: schema);
      final messages = <String>[];
      runZoned(() {
        validator.validate();
        validator.validate();
      },
          zoneSpecification: ZoneSpecification(
            print: (self, parent, zone, message) => messages.add(message),
          ));
      expect(messages, isEmpty);
      expect(validator.schema, same(schema));
    });
  });

  group('JSON parsing', () {
    for (final json in [
      '[]',
      '[{"name":"Dart"}]',
      'null',
      '1',
      'true',
      '"text"'
    ]) {
      test('rejects non-object root $json with a shape error', () {
        expect(
          DynaValidator(json: json, schema: const {}).validate,
          throwsA(allOf(
            formatErrorContaining('Expected a JSON object at \$'),
            isA<FormatException>().having((error) => error.message, 'message',
                isNot(contains('Invalid JSON'))),
          )),
        );
      });
    }

    for (final json in ['', '{', '{"a":}', '{"a":1,}', '{} trailing']) {
      test('preserves parse diagnostics for malformed input $json', () {
        FormatException? original;
        try {
          jsonDecode(json);
        } on FormatException catch (error) {
          original = error;
        }
        expect(original, isNotNull);
        expect(
          DynaValidator(json: json, schema: const {}).validate,
          throwsA(isA<FormatException>()
              .having((error) => error.message, 'message',
                  startsWith('Invalid JSON:'))
              .having((error) => error.source, 'source', original!.source)
              .having((error) => error.offset, 'offset', original.offset)),
        );
      });
    }
  });
}
