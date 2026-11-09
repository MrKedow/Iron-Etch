import 'dart:io';

import 'package:fitness_tracker/data/exercise_library.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generated exercise library loads with images', () {
    expect(ExerciseLibrary.all.length, greaterThan(2000));
    // ignore: avoid_print
    print('exercise count: ${ExerciseLibrary.all.length}');
    final generated = ExerciseLibrary.all.where((e) => e.imageSlug != null);
    expect(generated.length, greaterThan(1900));
    for (final exercise in generated) {
      for (final index in const [0, 1]) {
        final path = 'assets/exercises/${exercise.imageSlug}_$index.jpg';
        expect(File(path).existsSync(), isTrue, reason: path);
      }
    }
    expect(ExerciseLibrary.findByName('3/4仰卧起坐'), isNotNull);
  });
}
