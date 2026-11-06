import 'dart:async';
import 'dart:convert';

import 'package:dynatype/dynatype.dart';
import 'package:test/test.dart';

import '../example/dynatype_example.dart' as example;

void main() {
  group('value rules', () {
    final cases = [
      (
        name: 'string',
        schema: Dyna.string(),
        valid: ['', 'Dart'],
        invalid: [null, 1, true]
      ),
      (
        name: 'boolean',
        schema: Dyna.boolean(),
        valid: [true, false],
        invalid: [null, 'true', 1]
      ),
      (
        name: 'integer',
        schema: Dyna.integer(),
        valid: [0, -2, 42],
        invalid: [null, '42', 1.5]
      ),
      (
        name: 'number',
        schema: Dyna.number(),
        valid: [0, -2, 1.5],
        invalid: [null, '1.5', true]
      ),
      (
        name: 'null',
        schema: Dyna.nullValue(),
        valid: [null],
        invalid: ['', 0, false]
      ),
    ];
    for (final item in cases) {
      test('${item.name} accepts matching values and rejects wrong types', () {
        for (final value in item.valid) {
          expect(item.schema.check(value).isValid, isTrue, reason: '$value');
          expect(item.schema.checkJson(jsonEncode(value)).isValid, isTrue);
        }
        for (final value in item.invalid) {
          final result = item.schema.check(value);
          expect(result.isValid, isFalse, reason: '$value');
          expect(result.errors.single.path, r'$');
          expect(result.errors.single.code, DynaErrorCode.typeMismatch);
          expect(result.errors.single.expectedType, isNotEmpty);
          expect(result.errors.single.actualType, value.runtimeType.toString());
        }
      });
    }

    test('any accepts null, scalars, lists, and objects', () {
      for (final value in [null, 1, true, 'text', [], {}]) {
        expect(Dyna.any().check(value).isValid, isTrue);
      }
    });

    test('check does not treat a string as JSON text', () {
      expect(Dyna.string().check('{"name":1}').isValid, isTrue);
      expect(Dyna.object({}).check('{}').isValid, isFalse);
      expect(Dyna.object({}).checkJson('{}').isValid, isTrue);
    });
  });

  group('required, optional, and nullable', () {
    test('required fields distinguish absence from a wrong value', () {
      final schema = Dyna.object({'name': Dyna.string()});
      expect(schema.check({}).errors.single.code, DynaErrorCode.required);
      expect(schema.check({'name': null}).errors.single.code,
          DynaErrorCode.typeMismatch);
    });

    test('optional allows absence but rejects null and wrong types', () {
      final schema = Dyna.object({'name': Dyna.string().optional()});
      expect(schema.check({}).isValid, isTrue);
      expect(schema.check({'name': 'Dart'}).isValid, isTrue);
      expect(schema.check({'name': null}).isValid, isFalse);
      expect(schema.check({'name': 1}).isValid, isFalse);
    });

    test('nullable allows null but still requires the field', () {
      final schema = Dyna.object({'name': Dyna.string().nullable()});
      expect(schema.check({}).errors.single.code, DynaErrorCode.required);
      expect(schema.check({'name': null}).isValid, isTrue);
      expect(schema.check({'name': 'Dart'}).isValid, isTrue);
      expect(schema.check({'name': 1}).isValid, isFalse);
    });

    test('modifier order does not matter', () {
      for (final field in [
        Dyna.string().optional().nullable(),
        Dyna.string().nullable().optional(),
        Dyna.string().optional().optional().nullable().nullable(),
      ]) {
        final schema = Dyna.object({'name': field});
        for (final value in [
          {},
          {'name': null},
          {'name': 'Dart'}
        ]) {
          expect(schema.check(value).isValid, isTrue);
        }
        expect(schema.check({'name': false}).isValid, isFalse);
      }
    });

    test('optional does not skip root or list element checks', () {
      expect(Dyna.string().optional().check(null).isValid, isFalse);
      expect(
          Dyna.list(Dyna.string().optional()).check([null]).isValid, isFalse);
      expect(Dyna.list(Dyna.string().nullable()).check([null]).isValid, isTrue);
    });

    test('any and nullValue still require an object field', () {
      for (final field in [Dyna.any(), Dyna.nullValue()]) {
        final schema = Dyna.object({'value': field});
        expect(schema.check({}).errors.single.code, DynaErrorCode.required);
        expect(schema.check({'value': null}).isValid, isTrue);
      }
    });

    test('optional and nullable work for container fields', () {
      final schema = Dyna.object({
        'book': Dyna.object({'name': Dyna.string()}).optional().nullable(),
        'tags': Dyna.list(Dyna.string()).optional().nullable(),
      });
      expect(schema.check({}).isValid, isTrue);
      expect(schema.check({'book': null, 'tags': null}).isValid, isTrue);
      expect(
          schema.check({'book': {}}).errors.single.path, r'$["book"]["name"]');
      expect(
          schema
              .check({
                'tags': [1]
              })
              .errors
              .single
              .path,
          r'$["tags"][0]');
    });
  });

  group('nested objects and lists', () {
    final catalog = Dyna.object({
      'books': Dyna.list(Dyna.object({
        'title': Dyna.string(),
        'author': Dyna.object({'name': Dyna.string()}),
      })),
      'count': Dyna.integer(),
    });

    test('accepts a deeply nested decoded response or JSON text', () {
      final data = {
        'books': [
          {
            'title': 'Dart',
            'author': {'name': 'Ada'}
          },
          {
            'title': 'Flutter',
            'author': {'name': 'Grace'}
          },
        ],
        'count': 2,
      };
      expect(catalog.check(data).isValid, isTrue);
      expect(() => catalog.validateJson(jsonEncode(data)), returnsNormally);
    });

    test('collects all errors across objects and list elements in order', () {
      final result = catalog.check({
        'books': [
          {'title': 1, 'author': {}},
          {
            'title': 'Dart',
            'author': {'name': false}
          },
        ],
        'count': '2',
      });
      expect(result.errors.map((error) => error.path), [
        r'$["books"][0]["title"]',
        r'$["books"][0]["author"]["name"]',
        r'$["books"][1]["author"]["name"]',
        r'$["count"]',
      ]);
      expect(result.errors[1].code, DynaErrorCode.required);
    });

    test('a wrong container produces one error without descending', () {
      final result = catalog.check({'books': 1, 'count': 0});
      expect(result.errors, hasLength(1));
      expect(result.errors.single.path, r'$["books"]');
      expect(catalog.check(null).errors.single.path, r'$');
    });

    test('root and nested lists validate every element', () {
      final schema = Dyna.list(Dyna.list(Dyna.integer()));
      expect(
          schema.check([
            [],
            [1, 2]
          ]).isValid,
          isTrue);
      expect(
          schema
              .check([
                [1, '2'],
                null
              ])
              .errors
              .map((e) => e.path),
          [r'$[0][1]', r'$[1]']);
      expect(schema.check([]).isValid, isTrue);
    });

    test('accepts maps based on their keys rather than generic declarations',
        () {
      final schema = Dyna.object({'name': Dyna.string()});
      expect(schema.check(<Object?, Object?>{'name': 'Dart'}).isValid, isTrue);
      expect(schema.check({1: 'Dart'}).errors.single.code,
          DynaErrorCode.typeMismatch);
    });

    test('allows extra fields by default and rejects them when strict', () {
      final fields = {'name': Dyna.string()};
      final data = {'name': 'Dart', 'extra': true};
      expect(Dyna.object(fields).check(data).isValid, isTrue);
      final result = Dyna.object(fields, allowUnknownFields: false).check(data);
      expect(result.errors.single.path, r'$["extra"]');
      expect(result.errors.single.code, DynaErrorCode.unknownField);
    });

    test('strict nested schemas report unknown fields at the correct path', () {
      final schema = Dyna.object({
        'book': Dyna.object({'name': Dyna.string()}, allowUnknownFields: false),
      });
      final result = schema.check({
        'book': {'extra': 1},
        'allowed': true
      });
      expect(result.errors.map((e) => e.path),
          [r'$["book"]["name"]', r'$["book"]["extra"]']);
    });

    test('literal, empty, and escaped keys produce unambiguous paths', () {
      const key = 'a.b"\nc';
      final schema = Dyna.object({key: Dyna.string(), '': Dyna.integer()});
      expect(schema.check({key: 'valid', '': 1}).isValid, isTrue);
      expect(schema.check({}).errors.map((e) => e.path),
          ['\$[${jsonEncode(key)}]', r'$[""]']);
    });
  });

  group('results and exceptions', () {
    test('validate is silent and throws a FormatException subtype on failure',
        () {
      final schema = Dyna.string();
      expect(() => schema.validate('valid'), returnsNormally);
      expect(() => schema.validate(1), throwsA(isA<DynaValidationException>()));
      expect(() => schema.validate(1), throwsFormatException);
    });

    test('check and throwIfInvalid expose the same immutable errors', () {
      final result = Dyna.string().check(1);
      expect(() => result.errors.clear(), throwsUnsupportedError);
      expect(
          result.throwIfInvalid,
          throwsA(isA<DynaValidationException>()
              .having((error) => error.errors, 'errors', same(result.errors))));
      expect(Dyna.string().check('valid').throwIfInvalid, returnsNormally);
    });

    for (final source in ['', '{', '{"name":}', '{} trailing']) {
      test('malformed JSON returns a structured error for "$source"', () {
        FormatException? parseError;
        try {
          jsonDecode(source);
        } on FormatException catch (error) {
          parseError = error;
        }
        final schema = Dyna.any();
        final result = schema.checkJson(source);
        expect(result.errors.single.code, DynaErrorCode.invalidJson);
        expect(result.errors.single.path, r'$');
        expect(result.errors.single.offset, parseError!.offset);
        expect(
            () => schema.validateJson(source),
            throwsA(isA<DynaValidationException>()
                .having((error) => error.source, 'source', source)
                .having((error) => error.offset, 'offset', parseError.offset)));
      });
    }

    test('schemas copy definitions and validate repeatedly without mutation',
        () {
      final fields = {'name': Dyna.string()};
      final schema = Dyna.object(fields);
      fields.clear();
      expect(schema.check({}).errors.single.code, DynaErrorCode.required);
      final data = {
        'name': 'Dart',
        'extra': ['kept']
      };
      final before = jsonEncode(data);
      final messages = <String>[];
      runZoned(() {
        schema.validate(data);
        schema.validate(data);
      },
          zoneSpecification: ZoneSpecification(
            print: (self, parent, zone, message) => messages.add(message),
          ));
      expect(jsonEncode(data), before);
      expect(messages, isEmpty);
    });

    test('the new example succeeds', () {
      final messages = <String>[];
      runZoned(example.main,
          zoneSpecification: ZoneSpecification(
            print: (self, parent, zone, message) => messages.add(message),
          ));
      expect(messages, ['The JSON is valid.']);
    });
  });
}
