; Inno Setup script. Put TouchBlock.exe next to this file before compiling.
[Setup]
AppName=TouchBlock
AppVersion=1.0
AppPublisher=KoAlex777
DefaultDirName={autopf}\TouchBlock
DefaultGroupName=TouchBlock
DisableProgramGroupPage=yes
PrivilegesRequired=admin
ArchitecturesInstallIn64BitMode=x64compatible
OutputBaseFilename=TouchBlock_Setup
Compression=lzma2
SolidCompression=yes
UninstallDisplayName=TouchBlock

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"

[CustomMessages]
english.CreatingTask=Creating the autostart task...
russian.CreatingTask=Создаю задачу автозапуска...
english.StartingApp=Starting TouchBlock...
russian.StartingApp=Запускаю TouchBlock...

[Files]
Source: "TouchBlock.exe"; DestDir: "{app}"; Flags: ignoreversion

[Run]
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -Command ""$a=New-ScheduledTaskAction -Execute '{app}\TouchBlock.exe'; $t=New-ScheduledTaskTrigger -AtLogOn; $t.Delay='PT10S'; $p=New-ScheduledTaskPrincipal -GroupId 'S-1-5-32-545' -RunLevel Highest; $s=New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit 0; Register-ScheduledTask -TaskName 'TouchBlock' -Action $a -Trigger $t -Principal $p -Settings $s -Force"""; Flags: runhidden waituntilterminated; StatusMsg: "{cm:CreatingTask}"
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -Command ""Start-ScheduledTask -TaskName 'TouchBlock'"""; Flags: runhidden; StatusMsg: "{cm:StartingApp}"

[UninstallRun]
Filename: "taskkill.exe"; Parameters: "/f /im TouchBlock.exe"; Flags: runhidden; RunOnceId: "KillApp"
Filename: "schtasks.exe"; Parameters: "/delete /tn ""TouchBlock"" /f"; Flags: runhidden; RunOnceId: "DelTask"
Filename: "powershell.exe"; Parameters: "-NoProfile -ExecutionPolicy Bypass -Command ""Get-PnpDevice -FriendlyName '*сенсорный экран*','*touch screen*' -ErrorAction SilentlyContinue | Enable-PnpDevice -Confirm:$false"""; Flags: runhidden; RunOnceId: "EnableTouch"

[UninstallDelete]
Type: filesandordirs; Name: "{userappdata}\TouchBlock"

[Code]
function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  ResultCode: Integer;
begin
  Exec('taskkill.exe', '/f /im TouchBlock.exe', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Result := '';
end;
