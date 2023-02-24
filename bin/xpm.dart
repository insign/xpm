import 'dart:io';

import 'package:all_exit_codes/all_exit_codes.dart';
import 'package:args/command_runner.dart';
import 'package:xpm/commands/devs/check.dart';
import 'package:xpm/commands/devs/checksum.dart';
import 'package:xpm/commands/devs/get.dart';
import 'package:xpm/commands/devs/make.dart';
import 'package:xpm/commands/devs/repo/repo.dart';
import 'package:xpm/commands/devs/shortcut.dart';
import 'package:xpm/commands/humans/install.dart';
import 'package:xpm/commands/humans/refresh.dart';
import 'package:xpm/commands/humans/remove.dart';
import 'package:xpm/commands/humans/search.dart';
import 'package:xpm/commands/humans/update.dart';
import 'package:xpm/utils/leave.dart';
import 'package:xpm/xpm.dart';

void main(List<String> args) async {
  if (args.isNotEmpty && (args.first == '-v' || args.first == '--version')) {
    showVersion(args);
  }

  CommandRunner(XPM.name, XPM.description)
    ..argParser.addFlag('version',
        abbr: 'v', negatable: false, help: 'Prints the version of ${XPM.name}.')
    ..addCommand(RefreshCommand())
    ..addCommand(SearchCommand())
    ..addCommand(InstallCommand())
    ..addCommand(UpdateCommand())
    ..addCommand(RemoveCommand())
    ..addCommand(MakeCommand())
    ..addCommand(CheckCommand())
    ..addCommand(RepoCommand())
    ..addCommand(GetCommand())
    ..addCommand(ShortcutCommand())
    ..addCommand(ChecksumCommand())
    ..run(args).catchError((error) {
      if (error is! UsageException) throw error;
      print(error);
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
