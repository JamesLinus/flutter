// Copyright 2017 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

// ignore: implementation_imports
import 'package:test/src/executable.dart' as test;

import '../artifacts.dart';
import '../base/common.dart';
import '../base/file_system.dart';
import '../base/io.dart';
import '../base/terminal.dart';
import '../dart/package_map.dart';
import '../globals.dart';
import '../test/flutter_platform.dart' as loader;
import 'watcher.dart';

/// Runs tests using package:test and the Flutter engine.
Future<int> runTests(
    List<String> testFiles, {
    Directory workDir,
    List<String> names: const <String>[],
    List<String> plainNames: const <String>[],
    bool enableObservatory: false,
    bool startPaused: false,
    bool ipv6: false,
    bool json: false,
    TestWatcher watcher,
    }) async {
  // Compute the command-line arguments for package:test.
  final List<String> testArgs = <String>[];
  if (!terminal.supportsColor)
    testArgs.addAll(<String>['--no-color', '-rexpanded']);

  if (enableObservatory) {
    // (In particular, for collecting code coverage.)
    testArgs.add('--concurrency=1');
  }

  if (json) {
    testArgs.addAll(<String>['-r', 'json']);
  }

  for (String name in names) {
    testArgs..add("--name")..add(name);
  }

  for (String plainName in plainNames) {
    testArgs..add("--plain-name")..add(plainName);
  }

  testArgs.add('--');
  testArgs.addAll(testFiles);

  // Configure package:test to use the Flutter engine for child processes.
  final String shellPath = artifacts.getArtifactPath(Artifact.flutterTester);
  if (!fs.isFileSync(shellPath))
    throwToolExit('Cannot find Flutter shell at $shellPath');

  final InternetAddressType serverType =
      ipv6 ? InternetAddressType.IP_V6 : InternetAddressType.IP_V4;

  loader.installHook(
    shellPath: shellPath,
    watcher: watcher,
    enableObservatory: enableObservatory,
    startPaused: startPaused,
    serverType: serverType,
  );

  // Make the global packages path absolute.
  // (Makes sure it still works after we change the current directory.)
  PackageMap.globalPackagesPath =
      fs.path.normalize(fs.path.absolute(PackageMap.globalPackagesPath));

  // Call package:test's main method in the appropriate directory.
  final Directory saved = fs.currentDirectory;
  try {
    if (workDir != null) {
      printTrace('switching to directory $workDir to run tests');
      fs.currentDirectory = workDir;
    }

    printTrace('running test package with arguments: $testArgs');
    await test.main(testArgs);

    // test.main() sets dart:io's exitCode global.
    // TODO(skybrian): restore previous value?
    printTrace('test package returned with exit code $exitCode');

    return exitCode;
  } finally {
    fs.currentDirectory = saved;
  }
}
