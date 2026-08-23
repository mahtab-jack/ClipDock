import 'dart:io';
import 'package:flutter/foundation.dart';

class StartupService {
  static const String _regRunPath = r'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run';
  static const String _regApprovedRunPath = r'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run';
  static const String _regApprovedFolder = r'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder';

  /// Check if the application is set to launch on Windows startup and is enabled
  static Future<bool> isLaunchOnStartupEnabled() async {
    if (kIsWeb || !Platform.isWindows) return false;

    try {
      const script = r'''
$startupPath = [Environment]::GetFolderPath([Environment+SpecialFolder]::Startup)
$shortcutPath = Join-Path $startupPath "Clip Dock.lnk"
$hasShortcut = Test-Path $shortcutPath

$hasReg = $false
foreach ($name in @('ClipDock', 'cnote', 'cNote', 'Clip Dock')) {
  if (Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name $name -ErrorAction SilentlyContinue) {
    $hasReg = $true
    break
  }
}

if (-not $hasShortcut -and -not $hasReg) {
  exit 1
}

# Check if disabled by Task Manager in StartupApproved
$isDisabled = $false

if ($hasReg) {
  $runProp = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run" -ErrorAction SilentlyContinue
  if ($runProp) {
    foreach ($name in @('ClipDock', 'cnote', 'cNote', 'Clip Dock')) {
      $val = $runProp.$name
      if ($val -and ($val[0] -eq 1 -or $val[0] -eq 3)) {
        $isDisabled = $true
        break
      }
    }
  }
}

if ($hasShortcut) {
  $folderProp = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder" -ErrorAction SilentlyContinue
  if ($folderProp) {
    foreach ($name in @('Clip Dock.lnk', 'cnote.lnk', 'cNote.lnk', 'ClipDock.lnk')) {
      $val = $folderProp.$name
      if ($val -and ($val[0] -eq 1 -or $val[0] -eq 3)) {
        $isDisabled = $true
        break
      }
    }
  }
}

if ($isDisabled) {
  exit 1
} else {
  exit 0
}
''';

      final result = await Process.run('powershell', [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        script,
      ]);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Enable or disable launch on Windows startup across Registry, Startup Folder, and StartupApproved keys
  static Future<bool> setLaunchOnStartup(bool enable) async {
    if (kIsWeb || !Platform.isWindows) return false;

    try {
      String exePath = Platform.resolvedExecutable.replaceAll('"', '');
      String dirPath = File(exePath).parent.path.replaceAll('"', '');

      final script = enable
          ? '''
\$exePath = "$exePath"
\$dirPath = "$dirPath"
\$startupPath = [Environment]::GetFolderPath([Environment+SpecialFolder]::Startup)
\$shortcutPath = Join-Path \$startupPath "Clip Dock.lnk"

# 1. Create shortcut in shell:startup folder
try {
  \$wsh = New-Object -ComObject WScript.Shell
  \$sc = \$wsh.CreateShortcut(\$shortcutPath)
  \$sc.TargetPath = \$exePath
  \$sc.WorkingDirectory = \$dirPath
  \$sc.Description = "Clip Dock Startup"
  \$sc.Save()
} catch {}

# 2. Add to HKCU Run registry
Set-ItemProperty -Path "$_regRunPath" -Name "ClipDock" -Value "`"\$exePath`"" -ErrorAction SilentlyContinue

# 3. Ensure StartupApproved entries are cleared so Task Manager shows Enabled
foreach (\$reg in @("$_regApprovedRunPath", "$_regApprovedFolder")) {
  if (Test-Path \$reg) {
    foreach (\$name in @('ClipDock', 'cnote', 'cNote', 'Clip Dock', 'Clip Dock.lnk', 'cnote.lnk')) {
      Remove-ItemProperty -Path \$reg -Name \$name -ErrorAction SilentlyContinue
    }
  }
}

exit 0
'''
          : '''
# 1. Remove from HKCU Run registry
foreach (\$name in @('ClipDock', 'cnote', 'cNote', 'Clip Dock')) {
  Remove-ItemProperty -Path "$_regRunPath" -Name \$name -ErrorAction SilentlyContinue
}

# 2. Remove shortcut from shell:startup folder
\$startupPath = [Environment]::GetFolderPath([Environment+SpecialFolder]::Startup)
foreach (\$name in @('Clip Dock.lnk', 'cnote.lnk', 'cNote.lnk', 'ClipDock.lnk')) {
  \$filePath = Join-Path \$startupPath \$name
  if (Test-Path \$filePath) {
    Remove-Item -Path \$filePath -Force -ErrorAction SilentlyContinue
  }
}

# 3. Clean up StartupApproved keys
foreach (\$reg in @("$_regApprovedRunPath", "$_regApprovedFolder")) {
  if (Test-Path \$reg) {
    foreach (\$name in @('ClipDock', 'cnote', 'cNote', 'Clip Dock', 'Clip Dock.lnk', 'cnote.lnk')) {
      Remove-ItemProperty -Path \$reg -Name \$name -ErrorAction SilentlyContinue
    }
  }
}

exit 0
''';

      final result = await Process.run('powershell', [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        script,
      ]);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
}
