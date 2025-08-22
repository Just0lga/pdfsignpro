// shared_state_example.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(
    ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shared State Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: SharedStateExample(),
    );
  }
}

// Single provider - creates ONE instance of state
final counterProvider = StateNotifierProvider<CounterNotifier, int>((ref) {
  return CounterNotifier();
});

class CounterNotifier extends StateNotifier<int> {
  CounterNotifier() : super(0);

  void increment() => state++;
  void decrement() => state--;
}

class SharedStateExample extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text('Shared State Example')),
      body: Column(
        children: [
          // Both widgets share the SAME counter state
          CounterWidget(title: "Counter A"),
          CounterWidget(title: "Counter B"),
        ],
      ),
    );
  }
}

class CounterWidget extends ConsumerWidget {
  final String title;

  CounterWidget({required this.title});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Both instances watch the SAME provider
    final count = ref.watch(counterProvider);
    final notifier = ref.read(counterProvider.notifier);

    return Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text('$title: $count', style: TextStyle(fontSize: 18)),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () => notifier.decrement(),
                  child: Text('-'),
                ),
                SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () => notifier.increment(),
                  child: Text('+'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Result: When you tap + on Counter A, Counter B also updates!
// Both widgets show the same value because they share state.
