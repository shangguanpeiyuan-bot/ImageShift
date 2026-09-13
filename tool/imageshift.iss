#ifndef AppSource
  #error AppSource must point to the verified Windows Release folder
#endif
#ifndef DistDir
  #error DistDir must point to the artifact output folder
#endif

[Setup]
AppId=io.github.shangguanpeiyuanbot.imageshift
AppName=ImageShift
AppVersion=1.0.0
AppPublisher=shangguanpeiyuan-bot
AppPublisherURL=https://github.com/shangguanpeiyuan-bot/ImageShift
DefaultDirName={localappdata}\Programs\ImageShift
DefaultGroupName=ImageShift
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir={#DistDir}
OutputBaseFilename=ImageShift-v1.0.0-Windows-Setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\imageshift.exe
SetupIconFile=..\windows\runner\resources\app_icon.ico
CloseApplications=no
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
