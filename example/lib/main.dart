import 'dart:io';

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
    return MaterialApp(
      title: 'Age Verification Demo',
      theme: ThemeData(useMaterial3: true),
      home: const AgeVerificationPage(),
    );
  }
}

// ---------------------------------------------------------------------------
// Scenarios
// ---------------------------------------------------------------------------
class _Scenario {
  const _Scenario(this.label, this.config);
  final String label;
  final AgeVerificationMockConfig config;
}

final _scenarios = [
  _Scenario(
    'Supervised 13-15',
    AgeVerificationMockConfig(
      status: AgeSignalsStatus.supervised,
      ageLower: 13,
      ageUpper: 15,
      installId: 'mock-install-001',
    ),
  ),
  _Scenario(
    'Supervised 16-17',
    AgeVerificationMockConfig(
      status: AgeSignalsStatus.supervised,
      ageLower: 16,
      ageUpper: 17,
      installId: 'mock-install-002',
    ),
  ),
  _Scenario(
    'Verified 18+',
    AgeVerificationMockConfig(status: AgeSignalsStatus.verified, ageLower: 18),
  ),
  _Scenario(
    'Approval Pending',
    AgeVerificationMockConfig(
      status: AgeSignalsStatus.supervisedApprovalPending,
      ageLower: 13,
      ageUpper: 15,
      installId: 'mock-install-003',
    ),
  ),
  _Scenario(
    'Approval Denied',
    AgeVerificationMockConfig(
      status: AgeSignalsStatus.supervisedApprovalDenied,
      ageLower: 13,
      ageUpper: 15,
      installId: 'mock-install-004',
    ),
  ),
  _Scenario(
    'Declared',
    AgeVerificationMockConfig(
      status: AgeSignalsStatus.declared,
      ageLower: 13,
      ageUpper: 15,
    ),
  ),
  _Scenario(
    'Declined (iOS)',
    AgeVerificationMockConfig(status: AgeSignalsStatus.declined),
  ),
  _Scenario(
    'Unknown',
    AgeVerificationMockConfig(status: AgeSignalsStatus.unknown),
  ),
];

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------
class AgeVerificationPage extends StatefulWidget {
  const AgeVerificationPage({super.key});

  @override
  State<AgeVerificationPage> createState() => _AgeVerificationPageState();
}

class _AgeVerificationPageState extends State<AgeVerificationPage> {
  final _plugin = AgeVerification();

  bool _useMock = false;
  int _selectedScenario = 0;

  bool _initialized = false;
  bool _loading = false;
  String? _error;
  AgeVerificationResult? _result;

  static const _ageGates = [13, 18];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize({AgeVerificationMockConfig? mockConfig}) async {
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
      _initialized = false;
    });
    try {
      await _plugin.init(mockConfig: mockConfig);
      setState(() => _initialized = true);
    } on PlatformException catch (e) {
      setState(() => _error = 'Init failed [${e.code}]: ${e.message}');
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
      final result = await _plugin.verifyAge(_ageGates);
      setState(() => _result = result);
    } on PlatformException catch (e) {
      setState(() => _error = '[${e.code}] ${e.message}');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _onMockToggled(bool value) {
    setState(() {
      _useMock = value;
      _selectedScenario = 0;
    });
    _initialize(
      mockConfig: value ? _scenarios[_selectedScenario].config : null,
    );
  }

  void _onScenarioSelected(int index) {
    setState(() => _selectedScenario = index);
    _initialize(mockConfig: _scenarios[index].config);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Age Verification'), elevation: 2),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildInfoCard(),
            const SizedBox(height: 12),
            _buildMockCard(),
            if (!_useMock && Platform.isIOS) ...[
              const SizedBox(height: 12),
              _buildIosEntitlementNote(),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _initialized && !_loading ? _verifyAge : null,
              icon: const Icon(Icons.verified_user),
              label: Text(_loading ? 'Checking…' : 'Check Age'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 24),
            if (_loading) const Center(child: CircularProgressIndicator()),
            if (_error != null) _ErrorCard(message: _error!),
            if (_result != null) _ResultCard(result: _result!),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Info card
  // ---------------------------------------------------------------------------
  Widget _buildInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _initialized ? Icons.check_circle : Icons.hourglass_empty,
                  size: 16,
                  color: _initialized ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 6),
                Text(
                  _initialized ? 'Initialized' : 'Initializing…',
                  style: TextStyle(
                    color: _initialized ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Chip(
                  label: Text(Platform.isAndroid ? 'Android' : 'iOS'),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Age gates: ${_ageGates.join(', ')} (iOS only)',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (_useMock) ...[
              const SizedBox(height: 4),
              Text(
                'Mode: Mock — "${_scenarios[_selectedScenario].label}"',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.blue[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Mock toggle + scenario chips
  // ---------------------------------------------------------------------------
  Widget _buildMockCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mock mode',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Bypass native API — no entitlement or supervised account needed.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Switch(value: _useMock, onChanged: _onMockToggled),
              ],
            ),
            if (_useMock) ...[
              const Divider(height: 24),
              Text(
                'Scenario',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(_scenarios.length, (i) {
                  final selected = i == _selectedScenario;
                  return FilterChip(
                    label: Text(_scenarios[i].label),
                    selected: selected,
                    onSelected: (_) => _onScenarioSelected(i),
                  );
                }),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // iOS entitlement note (real mode only)
  // ---------------------------------------------------------------------------
  Widget _buildIosEntitlementNote() {
    return Card(
      color: Colors.orange[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Entitlement required',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.orange[800],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'The real DeclaredAgeRange API needs the '
                    'com.apple.developer.declared-age-range entitlement '
                    'and iOS 26.0+. Enable Mock mode above to test without it.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Result card
// ---------------------------------------------------------------------------
class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});
  final AgeVerificationResult result;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.green[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.green[700]),
                const SizedBox(width: 8),
                Text(
                  'Result',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.green[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _Row('Status', _statusLabel(result.status)),
            if (result.ageLower != null || result.ageUpper != null)
              _Row(
                'Age range',
                '${result.ageLower ?? '?'} - ${result.ageUpper ?? '?'}',
              ),
            if (result.source != null)
              _Row('Source', _sourceLabel(result.source!)),
            if (result.installId != null) _Row('Install ID', result.installId!),
          ],
        ),
      ),
    );
  }

  String _statusLabel(AgeSignalsStatus s) => switch (s) {
    AgeSignalsStatus.verified => 'Verified — meets age requirement',
    AgeSignalsStatus.supervised => 'Supervised — below age threshold',
    AgeSignalsStatus.supervisedApprovalPending =>
      'Supervised — approval pending',
    AgeSignalsStatus.supervisedApprovalDenied => 'Supervised — approval denied',
    AgeSignalsStatus.declared => 'Declared — age self-declared via Play',
    AgeSignalsStatus.declined => 'Declined — user chose not to share',
    AgeSignalsStatus.unknown => 'Unknown — no signal available',
  };

  String _sourceLabel(AgeDeclarationSource s) => switch (s) {
    AgeDeclarationSource.selfDeclared => 'Self declared',
    AgeDeclarationSource.guardianDeclared => 'Guardian declared',
  };
}

// ---------------------------------------------------------------------------
// Error card
// ---------------------------------------------------------------------------
class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Row helper
// ---------------------------------------------------------------------------
class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
