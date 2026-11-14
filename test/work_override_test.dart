import 'package:fitness_tracker/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('strength work override takes precedence and round-trips', () {
    final project = WorkoutProject(
      name: '卧推',
      part: '胸',
      weight: 60,
      sets: 3,
      repsPerSet: 8,
      feeling: '',
      supplement: '',
      category: '力量',
      workOverride: 12345,
    );
    expect(project.calculateWork(), 12345);
    final restored = WorkoutProject.fromJson(project.toJson());
    expect(restored.workOverride, 12345);
    expect(restored.calculateWork(), 12345);
  });

  test('cardio calories override drives work', () {
    final project = WorkoutProject(
      name: '跑步',
      part: '有氧',
      weight: 0,
      sets: 0,
      repsPerSet: 0,
      feeling: '',
      supplement: '',
      category: '有氧',
      caloriesOverride: 400,
    );
    expect(project.estimatedCalories(), 400);
    expect(project.calculateWork(), closeTo(400 * 4184, 0.01));
  });
}
