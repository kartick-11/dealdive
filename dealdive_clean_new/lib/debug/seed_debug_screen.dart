import 'package:flutter/material.dart';
import 'seed_deals.dart'; // same folder, so this relative import works

class SeedDebugScreen extends StatefulWidget {
  const SeedDebugScreen({super.key});

  @override
  State<SeedDebugScreen> createState() => _SeedDebugScreenState();
}

class _SeedDebugScreenState extends State<SeedDebugScreen> {
  bool _isSeeding = false;
  String _status = 'Press the button below to seed sample deals.';

  Future<void> _runSeed() async {
    setState(() {
      _isSeeding = true;
      _status = 'Seeding deals into Firestore...';
    });

    try {
      await DealSeeder.insertSampleData();
      setState(() {
        _status = '✅ Done! Sample deals inserted.\nCheck the Deals & Map tabs.';
      });
    } catch (e) {
      setState(() {
        _status = '❌ Error while seeding: $e';
      });
    } finally {
      setState(() {
        _isSeeding = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Seed sample deals'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _status,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton.icon(
                onPressed: _isSeeding ? null : _runSeed,
                icon: _isSeeding
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload),
                label: Text(_isSeeding ? 'Seeding...' : 'Seed sample deals'),
              ),
            ),
            const SizedBox(height: 12),
            const Center(
              child: Text(
                '⚠️ Debug-only tool.\nUse once to fill Firestore with sample data.',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
