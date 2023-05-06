import 'dart:io';

import 'package:all_exit_codes/all_exit_codes.dart';
import 'package:args/args.dart';
import 'package:xpm/database/models/package.dart';
import 'package:xpm/database/models/repo.dart';
import 'package:xpm/os/bash_script.dart';
import 'package:xpm/os/bin_directory.dart';
import 'package:xpm/os/executable.dart';
import 'package:xpm/os/get_archicteture.dart';
import 'package:xpm/os/os_release.dart';
import 'package:xpm/os/repositories.dart';
import 'package:xpm/utils/logger.dart';
import 'package:xpm/utils/slugify.dart';
import 'package:xpm/xpm.dart';
import 'package:xpm/utils/leave.dart';
import 'package:xpm/global.dart';

class Prepare {
  final Repo repo;
  final Package package;
  final ArgResults? args;

  static final String distro = osRelease('ID') ?? Platform.operatingSystem;
  static final String distroLike = osRelease('ID_LIKE') ?? '';

  late final String repoSlug, packageName;
  late final Future<Directory> cacheRepoDir;
  late final Future<Directory> packageDir;
  late final File baseScript;
  late final BashScript packageScript;
  bool booted = false;

  Prepare(this.repo, this.package, {this.args});

  Future<void> boot() async {
    if (booted) return;
    repoSlug = repo.url.slugify();
    packageName = package.name;
    cacheRepoDir = XPM.cacheDir("repos/$repoSlug/$packageName");
    packageDir = Repositories.dir(repoSlug, package: packageName);

    final String packageDirPath = (await packageDir).path;
    baseScript = File('$packageDirPath/../base.bash');

    packageScript = BashScript(package.script);

    if (await packageScript.contents() == null) {
      leave(message: 'Script for "{@blue}$packageName{@end}" does not exist.', exitCode: unableToOpenInputFile);
    }

    Global.sudoPath = await Executable('sudo').find() ?? '';

    booted = true;
  }

  Future<File> writeThisBeast(String script) async {
    await boot();

    return File('${(await cacheRepoDir).path}/together.bash').writeAsString(script.trim());
  }

  Future<String> best({to = 'install'}) async {
    await boot();

    final String preferedMethod = args?['method'] ?? 'auto';
    final bool forceMethod = args!['force-method'];

    if (forceMethod) {
      if (preferedMethod == 'auto') {
        leave(message: 'Use --force-method with --method=', exitCode: wrongUsage);
      }
      switch (preferedMethod) {
        case 'any':
          return bestForAny(to: to);
        case 'pack':
          return bestForPack(to: to);
        case 'apt':
          return bestForApt(to: to);
        case 'brew':
          return bestForMacOS(to: to);
        case 'choco':
          return bestForWindows(to: to);
        case 'dnf':
          return bestForFedora(to: to);
        case 'pacman':
          return bestForArch(to: to);
        case 'android':
          return bestForAndroid(to: to);
        case 'zypper':
          return bestForOpenSUSE(to: to);
        case 'swupd':
          return bestForClearLinux(to: to);
        default:
          leave(message: 'Unknown method: $preferedMethod', exitCode: notFound);
      }
    }

    if (preferedMethod == 'any') return bestForAny(to: to);

    if (preferedMethod == 'apt' || distro == 'debian' || distroLike == 'debian') {
      return bestForApt(to: to);
    }

    if (preferedMethod == 'pacman' || distroLike == 'arch') {
      return bestForArch(to: to);
    }

    if (preferedMethod == 'dnf' || distro == 'fedora' || distro == 'rhel' || distroLike == 'rhel fedora') {
      return bestForFedora(to: to);
    }

    if (preferedMethod == 'android' || distro == 'android') {
      return bestForAndroid(to: to);
    }

    if (preferedMethod == 'zypper' || distro == 'opensuse' || distro == 'sles') {
      return bestForOpenSUSE(to: to);
    }

    if (preferedMethod == 'brew' || distro == 'macos') {
      return bestForMacOS(to: to);
    }

    if (preferedMethod == 'choco' || distro == 'windows') {
      return bestForWindows(to: to);
    }

    if (preferedMethod == 'swupd' || distro == 'clear-linux-os' || distroLike == 'clear-linux-os') {
      return bestForClearLinux(to: to);
    }

    return bestForAny(to: to);
  }

  Future<String> bestForAny({String to = 'install'}) async => '${to}_any';

  Future<String> bestForPack({String to = 'install'}) async {
    final String? snap = await Executable('snap').find();
    final String? flatpak = await Executable('flatpak').find();
    final String? appimage = await Executable('appimage').find();

    late final String? bestPack;

    if (snap != null) {
      bestPack = snap;
      Global.isSnap = true;
    } else if (flatpak != null) {
      bestPack = '$flatpak --assumeyes';
      Global.isFlatpak = true;
    } else if (appimage != null) {
      bestPack = appimage;
      Global.isAppImage = true;
    }

    return bestPack != null ? '${to}_pack "$bestPack"' : await bestForAny(to: to);
  }

  Future<String> bestForClearLinux({String to = 'install'}) async {
    final methods = package.methods ?? [];
    if (methods.contains('swupd')) {
      final swupd = await Executable('swupd').find();

      final String? bestSwupd = swupd;

      if (bestSwupd != null) {
        return '${to}_swupd "${Global.sudoPath} $bestSwupd"';
      }
    }

    return await bestForAny(to: to);
  }

  Future<String> bestForApt({String to = 'install'}) async {
    final methods = package.methods ?? [];
    if (methods.contains('apt')) {
      final apt = await Executable('apt').find();
      final aptGet = await Executable('apt-get').find();

      final String? bestApt = apt ?? aptGet;

      if (bestApt != null) {
        return '${to}_apt "${Global.sudoPath} $bestApt -y"';
      }
    }

    return await bestForAny(to: to);
  }

  Future<String> bestForArch({String to = 'install'}) async {
    final methods = package.methods ?? [];
    if (methods.contains('pacman')) {
      final paru = await Executable('paru').find();
      final yay = await Executable('yay').find();
      final pacman = await Executable('pacman').find();
      String? bestArchLinux = paru ?? yay ?? pacman;

      if (bestArchLinux != null) {
        return '${to}_pacman "${Global.sudoPath} $bestArchLinux --noconfirm"';
      }
    }

    return await bestForAny(to: to);
  }

  Future<String> bestForFedora({String to = 'install'}) async {
    final methods = package.methods ?? [];
    if (methods.contains('dnf')) {
      final dnf = await Executable('dnf').find();

      String? bestFedora = dnf;

      if (bestFedora != null) {
        return '${to}_dnf "${Global.sudoPath} $bestFedora -y"';
      }
    }

    return await bestForAny(to: to);
  }

  Future<String> bestForMacOS({String to = 'install'}) async {
    final methods = package.methods ?? [];
    if (methods.contains('brew')) {
      final brew = await Executable('brew').find();

      if (brew != null) {
        return '${to}_macos "$brew"';
      }
    }

    return await bestForAny(to: to);
  }

  Future<String> bestForOpenSUSE({String to = 'install'}) async {
    final methods = package.methods ?? [];
    if (methods.contains('zypper')) {
      final zypper = await Executable('zypper').find();

      if (zypper != null) {
        return '${to}_zypper "${Global.sudoPath} $zypper --non-interactive"';
      }
    }

    return await bestForAny(to: to);
  }

  Future<String> bestForAndroid({String to = 'install'}) async {
    final methods = package.methods ?? [];
    if (methods.contains('termux')) {
      final pkg = await Executable('pkg').find(); // termux

      if (pkg != null) {
        return '${to}_android "${Global.sudoPath} $pkg -y"';
      }
    }

    return await bestForAny(to: to);
  }

  Future<String> bestForWindows({String to = 'install'}) async {
    final methods = package.methods ?? [];

    if (methods.contains('choco')) {
      final choco = await Executable('choco').find();
      final scoop = await Executable('scoop').find();

      late final String? bestWindows;

      if (choco != null) {
        bestWindows = '$choco -y';
      } else if (scoop != null) {
        bestWindows = '$scoop --yes';
      }

      if (bestWindows != null) {
        return '${to}_windows "$bestWindows"';
      }
    }

    throw Exception('No package manager found for Windows');
  }

  Future<String> toInstall() async {
    await boot();

    String togetherContents = '''
#!/usr/bin/env bash

${await dynamicCode()}

${await baseScriptContents()}

${await packageScript.contents()}

${await best(to: 'install')}
''';

    final togetherFile = await writeThisBeast(togetherContents);

    return togetherFile.path;
  }

  Future<String> toRemove() async {
    await boot();

    String togetherContents = '''
#!/usr/bin/env bash

${await dynamicCode()}

${await baseScriptContents()}

${await packageScript.contents()}

${await best(to: 'remove')}
''';

    return (await writeThisBeast(togetherContents)).path;
  }

  Future<String> toValidate({removing = false}) async {
    await boot();

    String? bestValidateExecutable;

    final String? firstProvides = await packageScript.getFirstProvides();
    if (firstProvides != null) {
      final firstProvidesExecutable = await Executable(firstProvides).find(cache: false);
      if (firstProvidesExecutable != null) {
        bestValidateExecutable = firstProvidesExecutable;
      }
    }
    if (bestValidateExecutable == null) {
      final String? nameExecutable = await Executable(packageName).find(cache: false);
      if (nameExecutable != null) {
        bestValidateExecutable = nameExecutable;
      }
    }

    String togetherContents = '''
#!/usr/bin/env bash

# no need to validate using bash
''';

    if (removing && bestValidateExecutable == null) {
      Logger.info('Validation for removing package $packageName passed!');
    } else if (bestValidateExecutable == null) {
      leave(
        message: 'No executable found for $packageName, validation failed.',
        exitCode: notFound,
      );
    } else {
      togetherContents = '''
#!/usr/bin/env bash

${await dynamicCode()}

${await baseScriptContents()}

${await packageScript.contents()}

validate "$bestValidateExecutable"
''';
    }

    return (await writeThisBeast(togetherContents)).path;
  }

  Future<String> dynamicCode() async {
    String executable = Platform.resolvedExecutable;

    if (Platform.script.path.endsWith('.dart') || executable.endsWith('/dart')) {
      // If we are running from a dart file or from a dart executable, add the
      // executable to the script.
      executable += ' ${Platform.script.path}';
    }

    String yARCH = getArchitecture();
    String yCHANNEL = args!['channel'] ?? '';

    return '''
readonly XPM="$executable";
readonly yARCH="$yARCH";
readonly yCHANNEL="$yCHANNEL";
readonly yBIN="${binDirectory().path}";
readonly ySUDO="${Global.sudoPath}";
readonly isSnap="${Global.isSnap}";
readonly isFlatpak="${Global.isFlatpak}";
readonly isAppImage="${Global.isAppImage}";
''';
  }

  Future<String> baseScriptContents() async {
    if (!await baseScript.exists()) {
      return '';
    }

    return await baseScript.readAsString();
  }
}
