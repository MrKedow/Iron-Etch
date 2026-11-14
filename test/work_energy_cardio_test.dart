import 'package:fitness_tracker/services/work_energy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final profile = IronProfile.instance;

  test('cardio estimate derives speed from distance and duration', () {
    profile.update(bodyWeightKg: 70);
    final explicit = profile.estimateCardioCaloriesFromMetrics(
      category: '有氧',
      minutes: 30,
      distanceKm: 5,
      speedKmH: 10,
    );
    final derived = profile.estimateCardioCaloriesFromMetrics(
      category: '有氧',
      minutes: 30,
      distanceKm: 5,
      speedKmH: 0,
    );
    expect(derived, closeTo(explicit, 0.01));
  });

  test('cardio estimate depends only on entered data and body weight', () {
    profile.update(bodyWeightKg: 70);
    final light = profile.estimateCardioCaloriesFromMetrics(
      category: '有氧',
      minutes: 30,
      distanceKm: 4,
      speedKmH: 8,
    );
    profile.update(bodyWeightKg: 90);
    final heavy = profile.estimateCardioCaloriesFromMetrics(
      category: '有氧',
      minutes: 30,
      distanceKm: 4,
      speedKmH: 8,
    );
    expect(heavy, greaterThan(light));
    profile.update(bodyWeightKg: 70);
  });

  test('cardio estimate returns zero without time or distance', () {
    profile.update(bodyWeightKg: 70);
    final kcal = profile.estimateCardioCaloriesFromMetrics(
      category: '有氧',
      minutes: 0,
      distanceKm: 0,
      speedKmH: 0,
    );
    expect(kcal, 0);
  });

  test('duration-only cardio uses a fixed intensity', () {
    profile.update(bodyWeightKg: 70);
    final session = profile.estimateCardioCaloriesFromMetrics(
      category: '有氧',
      minutes: 30,
      distanceKm: 0,
      speedKmH: 0,
    );
    final flexibility = profile.estimateCardioCaloriesFromMetrics(
      category: '柔韧',
      minutes: 30,
      distanceKm: 0,
      speedKmH: 0,
    );
    expect(session, greaterThan(0));
    expect(flexibility, greaterThan(0));
    expect(session, greaterThan(flexibility));
  });
}
