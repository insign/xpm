import 'dart:io';

import 'package:all_exit_codes/all_exit_codes.dart';
import 'package:args/command_runner.dart';
import 'package:xpm/commands/devs/check.dart';
import 'package:xpm/commands/devs/checksum.dart';
import 'package:xpm/commands/devs/file/file.dart';
import 'package:xpm/commands/devs/get.dart';
import 'package:xpm/commands/devs/log.dart';
import 'package:xpm/commands/devs/make.dart';
import 'package:xpm/commands/devs/repo/repo.dart';
import 'package:xpm/commands/devs/shortcut.dart';
import 'package:xpm/commands/humans/install.dart';
import 'package:xpm/commands/humans/refresh.dart';
import 'package:xpm/commands/humans/remove.dart';
import 'package:xpm/commands/humans/search.dart';
import 'package:xpm/commands/humans/upgrade.dart';
import 'package:xpm/os/repositories.dart';
import 'package:xpm/setting.dart';
import 'package:xpm/utils/leave.dart';
import 'package:xpm/utils/logger.dart';
import 'package:xpm/xpm.dart';

void main(List<String> args) async {
  if (args.isNotEmpty && (args.first == '-v' || args.first == '--version')) {
    showVersion(args);
  }

  final refresh = 'automatic_refresh';
  final bool refreshExpired = await Setting.get(refresh, defaultValue: false);
  if (!refreshExpired) {
    await Repositories.index();
    final threeDays = DateTime.now().add(Duration(days: 3));
    Setting.set(refresh, true, expires: threeDays, lazy: true);
  }
  
  await Setting.deleteExpired(lazy: true);
  
  final runner = CommandRunner(XPM.name, XPM.description)
    ..argParser.addFlag('version',
        abbr: 'v', negatable: false, help: 'Prints the version of ${XPM.name}.')
    ..addCommand(RefreshCommand())
    ..addCommand(SearchCommand())
    ..addCommand(InstallCommand())
    ..addCommand(UpgradeCommand())
    ..addCommand(RemoveCommand())
    ..addCommand(MakeCommand())
    ..addCommand(CheckCommand())
    ..addCommand(RepoCommand())
    ..addCommand(FileCommand())
    ..addCommand(GetCommand())
    ..addCommand(ShortcutCommand())
    ..addCommand(ChecksumCommand())
    ..addCommand(LogCommand());

  runner.run(args).catchError((error) async {
    if (error is! UsageException) throw error;
    // Use SearchCommand as default command
    // only runs if no elements on args starts with '-'
    if (error.message.startsWith('Could not find a command named')) {
      await runner.run({'search', ...args});
      exit(success);
    }

    print(error);
    Logger.tip('To search packages use: {@cyan}${XPM.name} <package name>');

    exit(wrongUsage);
  });
}

Never showVersion(args) {
  if (args.first == '-v') {
    leave(message: XPM.version, exitCode: success);
  }
  leave(
      message: '${XPM.name} v${XPM.version} - ${XPM.description}',
      exitCode: success);
}
