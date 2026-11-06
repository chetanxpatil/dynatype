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
  print('The JSON is valid.');
}
