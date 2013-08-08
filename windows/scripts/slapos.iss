; SEE THE DOCUMENTATION FOR DETAILS ON CREATING .ISS SCRIPT FILES!

[Setup]
AppName=SlapOS
AppVersion=0.158
AppVerName=SlapOS Windows 0.158.7
DefaultDirName=C:\slapos-node
DefaultGroupName=SlapOS
OutputDir=D:\slapos\publish\Output
OutputBaseFilename=slapos-0.158.7-windows-x86
SourceDir=D:\slapos
Uninstallable=yes

[Dirs]
Name: "{app}\cygwin"
Name: "{app}\images"
Name: "{app}\cygwin\opt\slapos"
Name: "{app}\cygwin\usr\local\bin"
Name: "{app}\cygwin\etc\slapos\driver"
Name: "{app}\cygwin\etc\slapos\scripts"
Name: "{app}\cygwin\etc\slapos\patches"
Name: "{app}\cygwin\etc\slapos\images"

[Files]
Source: "cygwin\opt\patches\slapos-core-format.patch"; DestDir: "{app}\cygwin\etc\slapos\patches";
Source: "cygwin\opt\patches\slapos-cookbook-inotifyx.patch"; DestDir: "{app}\cygwin\etc\slapos\patches";

Source: "cygwin\opt\images\slapos.ico"; DestDir: "{app}\cygwin\etc\slapos\images";
Source: "cygwin\opt\images\terminal.ico"; DestDir: "{app}\cygwin\etc\slapos\images"; DestName: "terminal.ico";
Source: "cygwin\opt\images\configure.ico"; DestDir: "{app}\cygwin\etc\slapos\images";
Source: "cygwin\opt\images\node.ico"; DestDir: "{app}\cygwin\etc\slapos\images";
Source: "cygwin\opt\images\updater.ico"; DestDir: "{app}\cygwin\etc\slapos\images";
Source: "cygwin\opt\images\manager.ico"; DestDir: "{app}\cygwin\etc\slapos\images";

Source: "setup.exe"; DestDir: "{app}";
Source: "cygwin\opt\git\slapos.package\windows\scripts\setup-cygwin.bat"; DestDir: "{app}";

Source: "cygwin\opt\git\slapos.package\windows\scripts\ip"; DestDir: "{app}\cygwin\bin"; Permissions: everyone-readexec;
Source: "cygwin\opt\git\slapos.package\windows\scripts\useradd"; DestDir: "{app}\cygwin\bin"; Permissions: everyone-readexec;
Source: "cygwin\opt\git\slapos.package\windows\scripts\usermod"; DestDir: "{app}\cygwin\bin"; Permissions: everyone-readexec;
Source: "cygwin\opt\git\slapos.package\windows\scripts\groupadd"; DestDir: "{app}\cygwin\bin"; Permissions: everyone-readexec;
Source: "cygwin\opt\git\slapos.package\windows\scripts\brctl"; DestDir: "{app}\cygwin\bin"; Permissions: everyone-readexec;
Source: "cygwin\opt\git\slapos.package\windows\scripts\tunctl"; DestDir: "{app}\cygwin\bin"; Permissions: everyone-readexec;
Source: "cygwin\opt\git\slapos.package\windows\scripts\slapos-cron-config"; DestDir: "{app}\cygwin\bin"; Permissions: everyone-readexec;

Source: "cygwin\opt\git\slapos.package\windows\ipwin\ipwin\ipwin.exe"; DestDir: "{app}\cygwin\bin"; Permissions: everyone-readexec;

Source: "cygwin\opt\git\slapos.package\windows\babeld\babeld.exe"; DestDir: "{app}\cygwin\bin"; Permissions: everyone-readexec;
Source: "cygwin\opt\git\slapos.package\windows\openvpn\src\openvpn\.libs\openvpn.exe"; DestDir: "{app}\cygwin\bin"; Permissions: everyone-readexec;

Source: "cygwin\opt\openvpn\bin\devcon.exe"; DestDir: "{app}\cygwin\bin"; Permissions: everyone-readexec;
Source: "cygwin\opt\openvpn\bin\addtap.bat"; DestDir: "{app}\cygwin\bin"; Permissions: everyone-readexec;
Source: "cygwin\opt\openvpn\bin\deltapall.bat"; DestDir: "{app}\cygwin\bin"; Permissions: everyone-readexec;
Source: "cygwin\opt\openvpn\driver\*"; DestDir: "{app}\cygwin\etc\slapos\driver"; Permissions: everyone-readexec;

Source: "cygwin\opt\git\slapos.package\windows\scripts\slapos-include.sh"; DestDir: "{app}\cygwin\etc\slapos\scripts"; Permissions: everyone-readexec;
Source: "cygwin\opt\git\slapos.package\windows\scripts\slapos-node.sh"; DestDir: "{app}\cygwin\etc\slapos\scripts"; Permissions: everyone-readexec;
Source: "cygwin\opt\git\slapos.package\windows\scripts\post-install.sh"; DestDir: "{app}\cygwin\etc\slapos\scripts"; Permissions: everyone-readexec;
Source: "cygwin\opt\git\slapos.package\windows\scripts\build-slapos.sh"; DestDir: "{app}\cygwin\etc\slapos\scripts"; Permissions: everyone-readexec;
Source: "cygwin\opt\git\slapos.package\windows\scripts\slapos-configure.sh"; DestDir: "{app}\cygwin\etc\slapos\scripts"; Permissions: everyone-readexec;
Source: "cygwin\opt\git\slapos.package\windows\scripts\slap-runner.html"; DestDir: "{app}\cygwin\etc\slapos\scripts"; Permissions: everyone-readexec;
Source: "cygwin\opt\git\slapos.package\windows\scripts\pre-uninstall.sh"; DestDir: "{app}\cygwin\etc\slapos\scripts"; Permissions: everyone-readexec;

Source: "cygwin\opt\git\slapos.package\windows\docs\using-slapos-in-windows.html"; DestDir: "{app}"; DestName: "user-guide.html"; Permissions: everyone-readexec;
Source: "cygwin\opt\git\slapos.package\windows\docs\README.cygwin"; DestDir: "{app}"; DestName: "readme.txt"; Permissions: everyone-readexec;

[Icons]
Name: "{commondesktop}\SlapOS"; Filename: "https://www.slapos.org/"; IconFilename: "{app}\cygwin\etc\slapos\images\slapos.ico";
Name: "{group}\Command Console"; Filename: "{app}\cygwin\cygtty.bat";  WorkingDir: "{app}\cygwin\opt\slapos"; IconFilename: "{app}\cygwin\etc\slapos\images\terminal.ico";
Name: "{group}\Configure SlapOS"; Filename: "{app}\cygwin\bin\mintty.exe"; Parameters: "-c ~/.minttyrc -h error -t ""Configure SlapOS"" /etc/slapos/scripts/slapos-configure.sh"; WorkingDir: "{app}\cygwin\bin"; IconFilename: "{app}\cygwin\etc\slapos\images\configure.ico";
Name: "{group}\SlapOS Runner"; Filename: "{app}\cygwin\etc\slapos\scripts\slap-runner.html"; IconFilename: "{app}\cygwin\etc\slapos\images\manager.ico";
Name: "{group}\SlapOS"; Filename: "https://www.slapos.org/"; IconFilename: "{app}\cygwin\etc\slapos\images\slapos.ico";
Name: "{group}\SlapOS Node"; Filename: "{app}\cygwin\bin\mintty.exe"; Parameters: "-c ~/.minttyrc -h error -t ""SlapOS Node"" /etc/slapos/scripts/slapos-node.sh"; WorkingDir: "{app}\cygwin\bin"; IconFilename: "{app}\cygwin\etc\slapos\images\node.ico";
Name: "{group}\Uninstall SlapOS"; Filename: "{uninstallexe}";
Name: "{group}\User Guide"; Filename: "{app}\user-guide.html";

[Run]
Filename: "{app}\setup-cygwin.bat"; Parameters: """{app}"" network"; StatusMsg: "Installing Cygwin..."; Flags: runhidden;
Filename: "{app}\cygwin\bin\bash.exe"; Parameters: "--login -i /etc/slapos/scripts/post-install.sh"; WorkingDir: "{app}\cygwin\bin"; Description: "Configure Cygwin"; StatusMsg: "Configure Cygwin..."; Flags: skipifdoesntexist;
Filename: "{app}\cygwin\bin\bash.exe"; Parameters: "--login -i /etc/slapos/scripts/build-slapos.sh"; WorkingDir: "{app}\cygwin\bin"; Description: "Builout process"; StatusMsg: "Building SlapOS..."; Flags: skipifdoesntexist;
Filename: "{app}\cygwin\autorebase.bat"; WorkingDir: "{app}\cygwin";  Flags: skipifdoesntexist runhidden;

[UninstallRun]
Filename: "{app}\cygwin\bin\mintty.exe"; Parameters: "-c ~/.minttyrc -h never -t ""Uninstall SlapOS"" /etc/slapos/scripts/pre-uninstall.sh"; WorkingDir: "{app}\cygwin\bin"; Flags: skipifdoesntexist;

[UninstallDelete]
Type: filesandordirs; Name: "{app}\cygwin" ;
Type: files; Name: "*.pyc";
Type: files; Name: "*.pyo";

