// Releases the version in pubspec.yaml: checks, git tag, push, pub.dev.
//
//   dart run tool/release.dart            release
//   dart run tool/release.dart --dry-run  checks + `pub publish --dry-run` only
//   dart run tool/release.dart --force    publish without pub's confirmation
//
// Steps (each one stops the release on failure):
//   1. On `master`, clean working tree, not behind origin/master.
//   2. CHANGELOG has `## <version>`, `dart format` changes nothing,
//      `dart analyze` is clean, tests pass. If the podspec's `s.version`
//      differs from pubspec, update it and commit that change.
//   3. Tag HEAD `<version>` (an existing tag must already point at HEAD).
//   4. Push master if ahead of origin, and the tag if origin lacks it.
//   5. `dart pub publish`, unless pub.dev already has this version.

import 'dart:convert';
import 'dart:io';

const _branch = 'master';
const _remote = 'origin';
const _package = 'age_verification';
const _podspec = 'ios/age_verification.podspec';

/// `s.version = '<version>'` in the podspec; group 1 is everything before the
/// quoted version, group 2 is the version.
final _podspecVersion = RegExp(
  r"^(\s*s\.version\s*=\s*)'([^']+)'",
  multiLine: true,
);

Future<void> main(List<String> args) async {
  final dryRun = args.contains('--dry-run');
  final force = args.contains('--force');
  final unknown = args.where((a) => a != '--dry-run' && a != '--force');
  if (unknown.isNotEmpty) _fail('Unknown arguments: ${unknown.join(' ')}');

  if (!File('pubspec.yaml').existsSync() ||
      !File('pubspec.yaml').readAsStringSync().contains('name: $_package')) {
    _fail('Run this from the $_package repository root.');
  }

  final version = _pubspecVersion();
  _step('Releasing $_package $version${dryRun ? ' (dry run)' : ''}');

  // 1. Git state.
  final branch = _git(['rev-parse', '--abbrev-ref', 'HEAD']);
  if (branch != _branch) _fail('On branch "$branch"; switch to $_branch.');
  if (_git(['status', '--porcelain']).isNotEmpty) {
    _fail('Working tree has uncommitted changes. Commit or stash them first.');
  }
  _run('git', ['fetch', _remote, _branch, '--tags']);
  final behind = _git(['rev-list', '--count', 'HEAD..$_remote/$_branch']);
  if (behind != '0') {
    _fail(
      '$_branch is $behind commit(s) behind $_remote/$_branch. Pull first.',
    );
  }

  // 2. Project checks.
  if (!RegExp(
    '^## ${RegExp.escape(version)}\\s*\$',
    multiLine: true,
  ).hasMatch(File('CHANGELOG.md').readAsStringSync())) {
    _fail('CHANGELOG.md has no "## $version" section.');
  }
  _run(_dart, [
    ..._dartPrefix,
    'format',
    '--output=none',
    '--set-exit-if-changed',
    'lib',
    'test',
    'tool',
    'pigeon',
    'example/lib',
    'example/integration_test',
  ]);
  _run(_dart, [..._dartPrefix, 'analyze', '--fatal-infos']);
  _run(_flutter, [..._flutterPrefix, 'test']);

  // Keep the CocoaPods version in step with pubspec.
  final podspec = File(_podspec);
  final podspecText = podspec.readAsStringSync();
  final podspecMatch = _podspecVersion.firstMatch(podspecText);
  if (podspecMatch == null) _fail('No s.version in $_podspec.');
  final podspecVersion = podspecMatch.group(2)!;
  final syncPodspec = podspecVersion != version;
  if (syncPodspec && !dryRun) {
    podspec.writeAsStringSync(
      podspecText.replaceFirst(
        _podspecVersion,
        "${podspecMatch.group(1)}'$version'",
      ),
    );
    _run('git', ['add', _podspec]);
    _run('git', ['commit', '-m', 'chore: sync podspec version to $version']);
    _info('Updated $_podspec from $podspecVersion to $version');
  }

  final published = await _publishedVersions();
  final alreadyOnPub = published.contains(version);
  if (alreadyOnPub) _info('pub.dev already has $version; publish is skipped.');

  // 3. Tag.
  final head = _git(['rev-parse', 'HEAD']);
  final tagCommit = _gitOrNull(['rev-parse', '$version^{commit}']);
  if (tagCommit != null && tagCommit != head) {
    _fail('Tag $version exists but points at $tagCommit, not HEAD ($head).');
  }

  if (dryRun) {
    _step('Dry run: checking the package');
    _run(_dart, [..._dartPrefix, 'pub', 'publish', '--dry-run']);
    _step('Dry run done. A real run would:');
    if (syncPodspec) {
      _info('update $_podspec from $podspecVersion to $version and commit it');
    }
    if (tagCommit == null) _info('tag HEAD as $version');
    _info('push $_branch and tag $version to $_remote if missing');
    if (!alreadyOnPub) _info('publish $version to pub.dev');
    return;
  }

  if (tagCommit == null) {
    _run('git', ['tag', '-a', version, '-m', 'Release $version']);
    _info('Tagged HEAD as $version');
  } else {
    _info('Tag $version already points at HEAD');
  }

  // 4. Push.
  final ahead = _git(['rev-list', '--count', '$_remote/$_branch..HEAD']);
  if (ahead != '0') {
    _run('git', ['push', _remote, _branch]);
  } else {
    _info('$_remote/$_branch is up to date');
  }
  final remoteTag = _git([
    'ls-remote',
    '--tags',
    _remote,
    'refs/tags/$version',
  ]);
  if (remoteTag.isEmpty) {
    _run('git', ['push', _remote, 'refs/tags/$version']);
  } else {
    _info('$_remote already has tag $version');
  }

  // 5. Publish.
  if (!alreadyOnPub) {
    _step('Publishing to pub.dev');
    await _runInteractive(_dart, [
      ..._dartPrefix,
      'pub',
      'publish',
      if (force) '--force',
    ]);
  }

  _step('Released $_package $version');
}

String _pubspecVersion() {
  final match = RegExp(
    r'^version:\s*(\S+)',
    multiLine: true,
  ).firstMatch(File('pubspec.yaml').readAsStringSync());
  if (match == null) _fail('No version: in pubspec.yaml.');
  return match.group(1)!;
}

/// Versions of the package on pub.dev, or empty if it can't be reached.
Future<Set<String>> _publishedVersions() async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(
      Uri.https('pub.dev', '/api/packages/$_package'),
    );
    final response = await request.close();
    if (response.statusCode != 200) return {};
    final json =
        jsonDecode(await response.transform(utf8.decoder).join())
            as Map<String, dynamic>;
    return {
      for (final v in json['versions'] as List)
        (v as Map<String, dynamic>)['version'] as String,
    };
  } on Object catch (e) {
    _info('Could not check pub.dev ($e); continuing.');
    return {};
  } finally {
    client.close();
  }
}

final bool _hasFvm = () {
  try {
    return Process.runSync('fvm', ['--version'], runInShell: true).exitCode ==
        0;
  } on ProcessException {
    return false;
  }
}();

String get _dart => _hasFvm ? 'fvm' : 'dart';
List<String> get _dartPrefix => _hasFvm ? ['dart'] : [];

String get _flutter => _hasFvm ? 'fvm' : 'flutter';
List<String> get _flutterPrefix => _hasFvm ? ['flutter'] : [];

String _git(List<String> args) {
  final result = Process.runSync('git', args, runInShell: true);
  if (result.exitCode != 0) {
    _fail('git ${args.join(' ')} failed:\n${result.stderr}');
  }
  return (result.stdout as String).trim();
}

String? _gitOrNull(List<String> args) {
  final result = Process.runSync('git', args, runInShell: true);
  return result.exitCode == 0 ? (result.stdout as String).trim() : null;
}

void _run(String exe, List<String> args) {
  stdout.writeln('\n>>> $exe ${args.join(' ')}');
  final result = Process.runSync(exe, args, runInShell: true);
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  if (result.exitCode != 0) {
    _fail('"$exe ${args.join(' ')}" exited with code ${result.exitCode}.');
  }
}

Future<void> _runInteractive(String exe, List<String> args) async {
  stdout.writeln('\n>>> $exe ${args.join(' ')}');
  final process = await Process.start(
    exe,
    args,
    runInShell: true,
    mode: ProcessStartMode.inheritStdio,
  );
  final code = await process.exitCode;
  if (code != 0) _fail('"$exe ${args.join(' ')}" exited with code $code.');
}

void _step(String message) => stdout.writeln('\n🚀 $message');

void _info(String message) => stdout.writeln('   $message');

Never _fail(String message) {
  stderr.writeln('\n❌ $message');
  exit(1);
}
