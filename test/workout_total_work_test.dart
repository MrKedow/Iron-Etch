import 'package:fitness_tracker/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('provider totalWork follows record add and delete', () {
    SharedPreferences.setMockInitialValues({});
    final provider = WorkoutProvider();
    final first = WorkoutRecord(
      id: 'a',
      date: DateTime(2026, 1, 1),
      sessionNumber: 1,
      projects: [
        WorkoutProject(
          name: '杠铃卧推',
          part: '胸',
          weight: 60,
          sets: 3,
          repsPerSet: 10,
          feeling: '',
          supplement: '',
        ),
      ],
      timestamp: DateTime(2026, 1, 1),
    );
    provider.loadRecords([first]);
    final firstWork = provider.totalWork;
    expect(firstWork, greaterThan(0));

    final second = WorkoutRecord(
      id: 'b',
      date: DateTime(2026, 1, 2),
      sessionNumber: 2,
      projects: [
        WorkoutProject(
          name: '杠铃深蹲',
          part: '腿',
          weight: 80,
          sets: 3,
          repsPerSet: 8,
          feeling: '',
          supplement: '',
        ),
      ],
      timestamp: DateTime(2026, 1, 2),
    );
    provider.loadRecords([first, second]);
    expect(provider.totalWork, greaterThan(firstWork));

    provider.deleteRecord('b');
    expect(provider.totalWork, closeTo(firstWork, 0.01));
  });
}
