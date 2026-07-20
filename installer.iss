[Setup]
AppName=Hardware POS
AppVersion=1.0
DefaultDirName={localappdata}\HardwarePOS
DefaultGroupName=Hardware POS
OutputDir=installer_output
OutputBaseFilename=HardwarePOS_Setup
Compression=lzma
SolidCompression=yes
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Hardware POS"; Filename: "{app}\hardware_pos.exe"
Name: "{autodesktop}\Hardware POS"; Filename: "{app}\hardware_pos.exe"

[Run]
Filename: "{app}\hardware_pos.exe"; Description: "Launch Hardware POS"; Flags: nowait postinstall skipifsilent