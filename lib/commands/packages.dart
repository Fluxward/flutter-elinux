// Copyright 2023 Sony Group Corporation. All rights reserved.
// Copyright 2020 Samsung Electronics Co., Ltd. All rights reserved.
// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_tools/src/base/os.dart';
import 'package:flutter_tools/src/build_system/build_system.dart';
import 'package:flutter_tools/src/commands/packages.dart';
import 'package:flutter_tools/src/context/tool_context.dart';
import 'package:flutter_tools/src/dart/pub.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tools/src/project.dart';
import 'package:flutter_tools/src/runner/flutter_command.dart';

import '../elinux_plugins.dart';

/// This class was copied from [PackagesCommand] to substitute its
/// [PackagesGetCommand] and [PackagesInteractiveGetCommand] subcommands with
/// their ELinux equivalents. We may find a better workaround in the future.
///
/// Source: [PackagesCommand] in `packages.dart`
class ELinuxPackagesCommand extends FlutterCommand {
  ELinuxPackagesCommand({required BuildSystem buildSystem, required ToolContext toolContext})
      : super(toolContext: toolContext) {
    addSubcommand(
      ELinuxPackagesGetCommand(
        'get',
        "Get the current package's dependencies.",
        PubContext.pubGet,
        buildSystem: buildSystem,
        toolContext: toolContext,
      ),
    );
    addSubcommand(
      ELinuxPackagesGetCommand(
        'upgrade',
        "Upgrade the current package's dependencies to latest versions.",
        PubContext.pubUpgrade,
        buildSystem: buildSystem,
        toolContext: toolContext,
      ),
    );
    addSubcommand(
      ELinuxPackagesGetCommand(
        'add',
        'Add a dependency to pubspec.yaml.',
        PubContext.pubAdd,
        buildSystem: buildSystem,
        toolContext: toolContext,
      ),
    );
    addSubcommand(
      ELinuxPackagesGetCommand(
        'remove',
        'Removes a dependency from the current package.',
        PubContext.pubRemove,
        buildSystem: buildSystem,
        toolContext: toolContext,
      ),
    );
    addSubcommand(PackagesTestCommand(toolContext: toolContext));
    addSubcommand(
      PackagesForwardCommand(
        'publish',
        'Publish the current package to pub.dartlang.org.',
        toolContext: toolContext,
        requiresPubspec: true,
      ),
    );
    addSubcommand(
      PackagesForwardCommand(
        'downgrade',
        'Downgrade packages in a Flutter project.',
        toolContext: toolContext,
        requiresPubspec: true,
      ),
    );
    addSubcommand(
      PackagesForwardCommand('deps', 'Print package dependencies.', toolContext: toolContext),
    ); // path to package can be specified with --directory argument
    addSubcommand(
      PackagesForwardCommand(
        'run',
        'Run an executable from a package.',
        toolContext: toolContext,
        requiresPubspec: true,
      ),
    );
    addSubcommand(
      PackagesForwardCommand('cache', 'Work with the Pub system cache.', toolContext: toolContext),
    );
    addSubcommand(
      PackagesForwardCommand('version', 'Print Pub version.', toolContext: toolContext),
    );
    addSubcommand(
      PackagesForwardCommand(
        'uploader',
        'Manage uploaders for a package on pub.dev.',
        toolContext: toolContext,
      ),
    );
    addSubcommand(PackagesForwardCommand('login', 'Log into pub.dev.', toolContext: toolContext));
    addSubcommand(
      PackagesForwardCommand('logout', 'Log out of pub.dev.', toolContext: toolContext),
    );
    addSubcommand(
      PackagesForwardCommand('global', 'Work with Pub global packages.', toolContext: toolContext),
    );
    addSubcommand(
      PackagesForwardCommand(
        'outdated',
        'Analyze dependencies to find which ones can be upgraded.',
        toolContext: toolContext,
        requiresPubspec: true,
      ),
    );
    addSubcommand(PackagesPassthroughCommand(toolContext: toolContext));
  }

  @override
  final String name = 'pub';

  @override
  List<String> get aliases => const <String>['packages'];

  @override
  final String description = 'Commands for managing Flutter packages.';

  @override
  Future<FlutterCommandResult> runCommand() async => FlutterCommandResult.fail();
}

class ELinuxPackagesGetCommand extends PackagesGetCommand with _PostRunPluginInjection {
  ELinuxPackagesGetCommand(super.commandName, super.description, super.context,
      {required super.buildSystem, required super.toolContext});
}

mixin _PostRunPluginInjection on FlutterCommand {
  /// See: [PackagesGetCommand.runCommand] in `packages.dart`
  @override
  Future<FlutterCommandResult> runCommand() async {
    final FlutterCommandResult result = await super.runCommand();

    if (result == FlutterCommandResult.success()) {
      final String? workingDirectory = argResults!.rest.isNotEmpty ? argResults!.rest[0] : null;
      final String? target = findProjectRoot(globals.fs, workingDirectory);
      if (target == null) {
        return result;
      }
      final FlutterProject rootProject = FlutterProject.fromDirectory(globals.fs.directory(target));
      await ensureReadyForELinuxTooling(rootProject);
      if (rootProject.hasExampleApp && rootProject.example.pubspecFile.existsSync()) {
        await ensureReadyForELinuxTooling(rootProject.example);
      }
    }

    return result;
  }
}
