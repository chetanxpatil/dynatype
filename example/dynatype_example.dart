import 'package:dynatype/dynatype.dart';

void main() {
  // Define a JSON string
  const String jsonString =
      '{"title": "Title 1", "author": "Author 1", "year": 2023, "tags": ["Tag 1", "Tag 2"]}';

  // Define a schema for the JSON string
  final Map<String, List<DynaType>> schema = {
    "": [
      DynaType(key: "title", type: String),
      DynaType(key: "author", type: String),
      DynaType(key: "year", type: int),
      DynaType(key: "tags", type: List<String>),
    ],
  };

  // Validate the JSON string against the schema
  try {
    DynaValidator(json: jsonString, schema: schema).validate();
    print("The JSON is valid according to the schema.");
  } catch (e) {
    print('Error: $e');
  }
}
