import 'dart:io';

import 'package:fitness_tracker/data/exercise_illustrations.dart';
import 'package:fitness_tracker/data/exercise_library.dart';
import 'package:fitness_tracker/data/exercise_library_generated.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('exercise library loads with images for every exercise', () {
    expect(ExerciseLibrary.all.length, greaterThan(2000));
    // ignore: avoid_print
    print('exercise count: ${ExerciseLibrary.all.length}');
    for (final exercise in ExerciseLibrary.all) {
      final slug = generatedImageOverrides[exercise.name] ??
          exercise.imageSlug ??
          exerciseImageSlugs[exercise.name];
      expect(slug, isNotNull, reason: exercise.name);
      for (final index in const [0, 1]) {
        final path = 'assets/exercises/${slug}_$index.jpg';
        expect(File(path).existsSync(), isTrue, reason: path);
      }
    }
    expect(ExerciseLibrary.findByName('3/4仰卧起坐'), isNotNull);
  });
}
