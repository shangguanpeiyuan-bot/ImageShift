#ifndef AppSource
  #error AppSource must point to the verified Windows Release folder
#endif

#ifndef ArtifactLabel
  #define ArtifactLabel "v1.0.0"
#endif
#ifndef DistDir
  #error DistDir must point to the artifact output folder
#endif

[Setup]
#ifdef ValidationOnly
; Dedicated test installer identity; never use for a distribution artifact.
AppId=io.github.shangguanpeiyuanbot.imageshift.validation
AppName=ImageShift Validation
DefaultGroupName=ImageShift Validation
#else
AppId=io.github.shangguanpeiyuanbot.imageshift
AppName=ImageShift
DefaultGroupName=ImageShift
#endif
AppVersion=1.0.0
AppPublisher=shangguanpeiyuan-bot
AppPublisherURL=https://github.com/shangguanpeiyuan-bot/ImageShift
DefaultDirName={localappdata}\Programs\ImageShift
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir={#DistDir}
OutputBaseFilename=ImageShift-{#ArtifactLabel}-Windows-Setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\imageshift.exe
SetupIconFile=..\windows\runner\resources\app_icon.ico
AppMutex=Local\ImageShift.Running
SetupMutex=Local\ImageShift.Setup
CloseApplications=yes
RestartApplications=no
DisableProgramGroupPage=yes

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; Flags: unchecked

[Files]
Source: "{#AppSource}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\ImageShift"; Filename: "{app}\imageshift.exe"
Name: "{group}\Uninstall ImageShift"; Filename: "{uninstallexe}"
Name: "{autodesktop}\ImageShift"; Filename: "{app}\imageshift.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\imageshift.exe"; Description: "Launch ImageShift"; Flags: nowait postinstall skipifsilent

[Code]
function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  Result := '';
  { v1 predates the mutex. Its window must close before DLL replacement. }
  if CheckForMutexes('Local\ImageShift.Running') or
     (FindWindowByWindowName('ImageShift') <> 0) then
    Result := 'ImageShift is running. Please wait for media tasks to finish, close ImageShift, then retry. No files have been replaced.';
end;
