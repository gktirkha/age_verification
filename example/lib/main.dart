import 'package:age_verification/age_verification.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: AgeVerificationPage());
  }
}

class AgeVerificationPage extends StatefulWidget {
  const AgeVerificationPage({super.key});

  @override
  State<AgeVerificationPage> createState() => _AgeVerificationPageState();
}

class _AgeVerificationPageState extends State<AgeVerificationPage> {
  final _plugin = AgeVerification();

  bool _initialized = false;
  bool _loading = false;
  String? _error;
  AgeVerificationResult? _result;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _plugin.init();
      setState(() => _initialized = true);
    } on PlatformException catch (e) {
      setState(() => _error = 'Init failed: ${e.code} — ${e.message}');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _verifyAge() async {
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });
    try {
      final result = await _plugin.verifyAge([18, 21]);
      setState(() => _result = result);
    } on PlatformException catch (e) {
      setState(() => _error = '${e.code} — ${e.message}');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Age Verification')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StatusChip(initialized: _initialized),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _initialized && !_loading ? _verifyAge : null,
              child: _loading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Check Age'),
            ),
            const SizedBox(height: 24),
            if (_error != null)
              _ErrorCard(message: _error!)
            else if (_result != null)
              _ResultCard(result: _result!),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.initialized});
  final bool initialized;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          initialized ? Icons.check_circle : Icons.hourglass_empty,
          color: initialized ? Colors.green : Colors.orange,
          size: 18,
        ),
        const SizedBox(width: 8),
        Text(initialized ? 'SDK initialized' : 'Initializing…'),
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});
  final AgeVerificationResult result;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Row('Status', result.status.name),
            if (result.ageLower != null || result.ageUpper != null)
              _Row(
                'Age range',
                '${result.ageLower ?? '?'} – ${result.ageUpper ?? '?'}',
              ),
            if (result.source != null) _Row('Source', result.source!.name),
            if (result.installId != null) _Row('Install ID', result.installId!),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          message,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
        ),
      ),
    );
  }
}
