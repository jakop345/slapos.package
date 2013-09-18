; SEE THE DOCUMENTATION FOR DETAILS ON CREATING .ISS SCRIPT FILES!

[Setup]
AppName=SlapOS
AppVersion=0.158
AppVerName=SlapOS Windows 0.158.8
DefaultDirName=C:\slapos-node
DefaultGroupName=SlapOS
OutputBaseFilename=slapos-testing
OutputDir=C:\slapos\publish\Output
SourceDir=C:\slapos
Uninstallable=yes

[Dirs]
Name: "{app}\cygwin"
Name: "{app}\cygwin\opt\slapos"
Name: "{app}\cygwin\opt\downloads"
Name: "{app}\cygwin\bin"
Name: "{app}\cygwin\etc\slapos\driver"
Name: "{app}\cygwin\etc\slapos\scripts"
Name: "{app}\cygwin\etc\slapos\images"

[Files]
Source: "cygwin-packages\*"; DestDir: "{app}\cygwin-packages"; Flags: recursesubdirs;
Source: "cygwin\opt\slapos\slapos.tar.gz"; DestDir: "{app}\cygwin\opt\downloads";
Source: "cygwin\opt\downloads\pyOpenSSL-0.13.tar.gz"; DestDir: "{app}\cygwin\opt\downloads"; DestName: "pyOpenSSL.tar.gz";
Source: "cygwin\opt\git\re6stnet\dist\re6stnet-0.1.tar.gz"; DestDir: "{app}\cygwin\opt\downloads"; DestName: "re6stnet.tar.gz";
Source: "cygwin\opt\downloads\miniupnpc-1.8.tar.gz"; DestDir: "{app}\cygwin\opt\downloads"; DestName: "miniupnpc.tar.gz";

Source: "cygwin\opt\git\slapos.package\windows\patches\slapos-core-format.patch"; DestDir: "{app}\cygwin\etc\slapos\patches";
Source: "cygwin\opt\git\slapos.package\windows\patches\slapos-cookbook-inotifyx.patch"; DestDir: "{app}\cygwin\etc\slapos\patches";
Source: "cygwin\opt\slapos\slapos.cfg.example"; DestDir: "{app}\cygwin\etc\slapos";
Source: "cygwin\opt\slapos\slapos-client.cfg.example"; DestDir: "{app}\cygwin\etc\slapos";

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
Source: "cygwin\opt\git\slapos.package\windows\scripts\set_primary_group"; DestDir: "{app}\cygwin\bin"; Permissions: everyone-readexec;
Source: "cygwin\opt\git\slapos.package\windows\scripts\brctl"; DestDir: "{app}\cygwin\bin"; Permissions: everyone-readexec;
Source: "cygwin\opt\git\slapos.package\windows\scripts\tunctl"; DestDir: "{app}\cygwin\bin"; Permissions: everyone-readexec;
Source: "cygwin\opt\git\slapos.package\windows\scripts\slapos-cron-config"; DestDir: "{app}\cygwin\bin"; Permissions: everyone-readexec;
Source: "cygwin\opt\git\slapos.package\windows\scripts\regpwd.exe"; DestDir: "{app}\cygwin\bin"; Permissions: everyone-readexec;

Source: "cygwin\opt\git\slapos.package\windows\ipwin\ipwin\ipwin.exe"; DestDir: "{app}\cygwin\bin"; Permissions: everyone-readexec;
Source: "cygwin\opt\git\slapos.package\windows\babeld\babeld.exe"; DestDir: "{app}\cygwin\bin"; Permissions: everyone-readexec;
Source: "cygwin\opt\openvpn\bin\devcon.exe"; DestDir: "{app}\cygwin\bin"; Permissions: everyone-readexec;
Source: "cygwin\opt\openvpn\bin\openvpn.exe"; DestDir: "{app}\cygwin\bin"; Permissions: everyone-readexec;
Source: "cygwin\opt\openvpn\bin\liblzo2-2.dll"; DestDir: "{app}\cygwin\bin"; Permissions: everyone-readexec;
Source: "cygwin\opt\openvpn\bin\libeay32.dll"; DestDir: "{app}\cygwin\bin"; Permissions: everyone-readexec;
Source: "cygwin\opt\openvpn\bin\libpkcs11-helper-1.dll"; DestDir: "{app}\cygwin\bin"; Permissions: everyone-readexec;
Source: "cygwin\opt\openvpn\bin\ssleay32.dll"; DestDir: "{app}\cygwin\bin"; Permissions: everyone-readexec;
Source: "cygwin\opt\openvpn\driver\*"; DestDir: "{app}\cygwin\etc\slapos\driver"; Permissions: everyone-readexec;

Source: "cygwin\opt\git\slapos.package\windows\scripts\slapos-include.sh"; DestDir: "{app}\cygwin\etc\slapos\scripts"; Permissions: everyone-readexec;
Source: "cygwin\opt\git\slapos.package\windows\scripts\slapos-node.sh"; DestDir: "{app}\cygwin\etc\slapos\scripts"; Permissions: everyone-readexec;
Source: "cygwin\opt\git\slapos.package\windows\scripts\build-slapos.sh"; DestDir: "{app}\cygwin\etc\slapos\scripts"; Permissions: everyone-readexec;
Source: "cygwin\opt\git\slapos.package\windows\scripts\slapos-cygwin-bootstrap.sh"; DestDir: "{app}\cygwin\etc\slapos\scripts"; Permissions: everyone-readexec;
Source: "cygwin\opt\git\slapos.package\windows\scripts\slapos-configure.sh"; DestDir: "{app}\cygwin\etc\slapos\scripts"; Permissions: everyone-readexec;
Source: "cygwin\opt\git\slapos.package\windows\scripts\slap-runner.html"; DestDir: "{app}\cygwin\etc\slapos\scripts"; Permissions: everyone-readexec;
Source: "cygwin\opt\git\slapos.package\windows\scripts\slapos-cleanup.sh"; DestDir: "{app}\cygwin\etc\slapos\scripts"; Permissions: everyone-readexec;

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
Filename: "{app}\setup-cygwin.bat"; Parameters: """{app}"""; StatusMsg: "Installing Cygwin..."; Flags: runhidden;
Filename: "{app}\cygwin\bin\bash.exe"; Parameters: "--login -i /etc/slapos/scripts/slapos-cygwin-bootstrap.sh"; WorkingDir: "{app}\cygwin\bin"; Description: "Configure Cygwin"; StatusMsg: "Configure Cygwin..."; Flags: skipifdoesntexist;
Filename: "{app}\cygwin\bin\bash.exe"; Parameters: "--login -i -c ""cd /opt ; tar -xzf /opt/downloads/slapos.tar.gz"""; WorkingDir: "{app}\cygwin\bin"; Description: "Configure Cygwin"; StatusMsg: "Extract slapos node ...";

[UninstallRun]
Filename: "{app}\cygwin\bin\mintty.exe"; Parameters: "-c ~/.minttyrc -h never -t ""Uninstall SlapOS"" /etc/slapos/scripts/slapos-cleanup.sh"; WorkingDir: "{app}\cygwin\bin"; Flags: skipifdoesntexist;

[UninstallDelete]
Type: filesandordirs; Name: "{app}\cygwin" ;
Type: files; Name: "*.pyc";
Type: files; Name: "*.pyo";




