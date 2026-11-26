// Copyright 2023 Sony Group Corporation. All rights reserved.
// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:flutter_tools/executable.dart' as flutter;
import 'package:flutter_tools/runner.dart' as runner;
import 'package:flutter_tools/src/application_package.dart';
import 'package:flutter_tools/src/artifacts.dart';
import 'package:flutter_tools/src/base/context.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/template.dart';
import 'package:flutter_tools/src/build_system/build_targets.dart';
import 'package:flutter_tools/src/build_system/targets/hook_runner_native.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/commands/config.dart';
import 'package:flutter_tools/src/commands/devices.dart';
import 'package:flutter_tools/src/commands/doctor.dart';
import 'package:flutter_tools/src/commands/emulators.dart';
import 'package:flutter_tools/src/commands/generate_localizations.dart';
import 'package:flutter_tools/src/commands/install.dart';
import 'package:flutter_tools/src/commands/logs.dart';
import 'package:flutter_tools/src/commands/screenshot.dart';
import 'package:flutter_tools/src/commands/symbolize.dart';
import 'package:flutter_tools/src/context/tool_dependencies.dart';
import 'package:flutter_tools/src/device.dart';
import 'package:flutter_tools/src/doctor.dart';
import 'package:flutter_tools/src/features.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tools/src/hook_runner.dart';
import 'package:flutter_tools/src/isolated/build_targets.dart';
import 'package:flutter_tools/src/isolated/mustache_template.dart';
import 'package:flutter_tools/src/isolated/native_assets/test/native_assets.dart';
import 'package:flutter_tools/src/native_assets.dart';
import 'package:flutter_tools/src/runner/flutter_command.dart';
import 'package:path/path.dart';

import 'commands/analyze.dart';
import 'commands/attach.dart';
import 'commands/build.dart';
import 'commands/clean.dart';
import 'commands/create.dart';
import 'commands/drive.dart';
import 'commands/packages.dart';
import 'commands/precache.dart';
import 'commands/run.dart';
import 'commands/test.dart';
import 'commands/upgrade.dart';
import 'elinux_artifacts.dart';
import 'elinux_cache.dart';
import 'elinux_device_discovery.dart';
import 'elinux_doctor.dart';
import 'elinux_package.dart';

/// Main entry point for commands.
///
/// Source: [flutter.main] in `executable.dart` (some commands and options were omitted)
Future<void> main(List<String> args) async {
  final bool veryVerbose = args.contains('-vv');
  final bool verbose = args.contains('-v') || args.contains('--verbose') || veryVerbose;

  final bool doctor = (args.isNotEmpty && args.first == 'doctor') ||
      (args.length == 2 && verbose && args.last == 'doctor');
  final bool help = args.contains('-h') ||
      args.contains('--help') ||
      (args.isNotEmpty && args.first == 'help') ||
      (args.length == 1 && verbose);
  final bool muteCommandLogging = (help || doctor) && !veryVerbose;
  final bool verboseHelp = help && verbose;

  final bool hasSpecifiedDeviceId = args.contains('-d') || args.contains('--device-id');

  args = <String>[
    '--suppress-analytics', // Suppress flutter analytics by default.
    '--no-version-check',
    if (!hasSpecifiedDeviceId) ...<String>['--device-id', 'elinux'],
    ...args,
  ];

  Cache.flutterRoot = join(rootPath, 'flutter');

  await runner.run(
    args,
    (ToolDependencies toolDependencies) => <FlutterCommand>[
      ConfigCommand(
        verboseHelp: verboseHelp,
        androidContext: toolDependencies.androidContext,
        toolContext: toolDependencies.toolContext,
        featureFlags: featureFlags,
        extensionManager: toolDependencies.extensionManager,
      ),
      DevicesCommand(
        deviceManager: toolDependencies.deviceManager,
        doctor: globals.doctor!,
        toolContext: toolDependencies.toolContext,
        verboseHelp: verboseHelp,
      ),
      DoctorCommand(
        doctor: toolDependencies.doctor,
        extensionManager: toolDependencies.extensionManager,
        toolContext: toolDependencies.toolContext,
        verbose: verbose,
      ),
      EmulatorsCommand(
        doctor: toolDependencies.doctor,
        emulatorManager: toolDependencies.emulatorManager,
        toolContext: toolDependencies.toolContext,
        verboseHelp: verboseHelp,
      ),
      GenerateLocalizationsCommand(toolContext: toolDependencies.toolContext),
      InstallCommand(toolContext: toolDependencies.toolContext, verboseHelp: verboseHelp),
      LogsCommand(toolContext: toolDependencies.toolContext),
      ScreenshotCommand(toolContext: toolDependencies.toolContext),
      SymbolizeCommand(toolContext: toolDependencies.toolContext),
      ELinuxUpgradeCommand(toolContext: toolDependencies.toolContext, verboseHelp: verboseHelp),
      ELinuxAnalyzeCommand(
        toolContext: toolDependencies.toolContext,
        verboseHelp: verboseHelp,
      ),
      ELinuxAttachCommand(
        buildSystem: toolDependencies.buildSystem,
        buildTargets: const BuildTargetsImpl(),
        toolContext: toolDependencies.toolContext,
        xcode: toolDependencies.appleContext.xcode,
        verboseHelp: verboseHelp,
      ),
      ELinuxBuildCommand(
        androidContext: toolDependencies.androidContext,
        appleContext: toolDependencies.appleContext,
        buildSystem: toolDependencies.buildSystem,
        extensionBuildManager: toolDependencies.extensionBuildManager,
        featureFlags: toolDependencies.featureFlags,
        templateRenderer: const MustacheTemplateRenderer(),
        toolContext: toolDependencies.toolContext,
        verboseHelp: verboseHelp,
      ),
      ELinuxCleanCommand(
        verbose: verbose,
        toolContext: toolDependencies.toolContext,
        xcode: toolDependencies.appleContext.xcode,
        xcodeProjectInterpreter: toolDependencies.appleContext.xcodeProjectInterpreter,
      ),
      ELinuxCreateCommand(
        androidContext: toolDependencies.androidContext,
        appleContext: toolDependencies.appleContext,
        templateRenderer: const MustacheTemplateRenderer(),
        toolContext: toolDependencies.toolContext,
        verboseHelp: verboseHelp,
      ),
      ELinuxDriveCommand(
        buildSystem: toolDependencies.buildSystem,
        buildTargets: const BuildTargetsImpl(),
        toolContext: toolDependencies.toolContext,
        verboseHelp: verboseHelp,
      ),
      ELinuxPackagesCommand(
        buildSystem: toolDependencies.buildSystem,
        toolContext: toolDependencies.toolContext,
      ),
      ELinuxPrecacheCommand(
        verboseHelp: verboseHelp,
        cache: toolDependencies.toolContext.cache,
        logger: toolDependencies.toolContext.logger,
        platform: toolDependencies.toolContext.platform,
        featureFlags: featureFlags,
      ),
      ELinuxRunCommand(toolContext: toolDependencies.toolContext, verboseHelp: verboseHelp),
      ELinuxTestCommand(
        toolContext: toolDependencies.toolContext,
        verboseHelp: verboseHelp,
        verbose: verbose,
        nativeAssetsBuilder: toolDependencies.toolContext.nativeAssetsBuilder,
      ),
    ],
    verbose: verbose,
    verboseHelp: verboseHelp,
    muteCommandLogging: muteCommandLogging,
    reportCrashes: false,
    overrides: <Type, Generator>{
      Cache: () => ELinuxFlutterCache(
            fileSystem: globals.fs,
            logger: globals.logger,
            platform: globals.platform,
            osUtils: globals.os,
            projectFactory: globals.projectFactory,
            processManager: globals.processManager,
          ),
      TemplateRenderer: () => const MustacheTemplateRenderer(),
      ApplicationPackageFactory: () => ELinuxApplicationPackageFactory(),
      Artifacts: () => ELinuxArtifacts(
            fileSystem: globals.fs,
            cache: globals.cache,
            platform: globals.platform,
            operatingSystemUtils: globals.os,
          ),
      DeviceManager: () => ELinuxDeviceManager(),
      DoctorValidatorsProvider: () => ELinuxDoctorValidatorsProvider(),
      ELinuxWorkflow: () => ELinuxWorkflow(
            operatingSystemUtils: globals.os,
          ),
      ELinuxValidator: () => ELinuxValidator(
            processManager: globals.processManager,
            userMessages: globals.userMessages,
          ),
      FlutterHookRunner: () => FlutterHookRunnerNative(),
      TestCompilerNativeAssetsBuilder: () => const TestCompilerNativeAssetsBuilderImpl(),
      BuildTargets: () => const BuildTargetsImpl(),
      if (verbose && !muteCommandLogging)
        Logger: () => VerboseLogger(StdoutLogger(
              stdio: globals.stdio,
              terminal: globals.terminal,
              outputPreferences: globals.outputPreferences,
            )),
    },
    shutdownHooks: globals.shutdownHooks,
  );
}

/// See: [Cache.defaultFlutterRoot] in `cache.dart`
String get rootPath {
  final String scriptPath = Platform.script.toFilePath();
  return normalize(join(
    scriptPath,
    scriptPath.endsWith('.snapshot') ? '../../..' : '../..',
  ));
}
