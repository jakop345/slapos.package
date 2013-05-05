; SEE THE DOCUMENTATION FOR DETAILS ON CREATING .ISS SCRIPT FILES!

[Setup]
AppName=SlapOS
AppVersion=0.158
AppVerName=SlapOS Windows 0.158
DefaultDirName=C:\slapos
DefaultGroupName=SlapOS
OutputBaseFilename=slapos-0.158-windows-x86-all-in-one
OutputDir=D:\slapos\publish\Output
SourceDir=D:\slapos
Uninstallable=yes

[Dirs]
Name: "{app}\cygwin"
Name: "{app}\cygwin\opt\slapos"
Name: "{app}\cygwin\usr\local\bin"
Name: "{app}\cygwin\etc\slapos\driver"
Name: "{app}\cygwin\etc\slapos\scripts"

[Files]
Source: "cygwin-packages\*"; DestDir: "{app}\cygwin-packages"; Flags: recursesubdirs;
Source: "publish\buildout\slapos\*"; DestDir: "{app}\cygwin\opt\slapos"; Flags: recursesubdirs;
Source: "opt\git\slapos.core\slapos.cfg.sample"; DestDir: "{app}\cygwin\etc\slapos";
Source: "opt\git\slapos.core\slapos-client.cfg.sample"; DestDir: "{app}\cygwin\etc\slapos";

Source: "opt\git\slapos\component\cygwin\slapos-core.patch"; DestDir: "{app}\cygwin\etc\slapos\patches";
Source: "opt\git\slapos\component\cygwin\slapos-cookbook-inotifyx.patch"; DestDir: "{app}\cygwin\etc\slapos\patches";

Source: "opt\git\re6stnet\dist\re6stnet-0.1.tar.gz"; DestDir: "{app}\cygwin"; DestName: "re6stnet-0.1.tar.gz"; Flags: deleteafterinstall;
Source: "opt\downloads\miniupnpc-1.8.tar.gz"; DestDir: "{app}\cygwin"; DestName: "miniupnpc.tar.gz"; Flags: deleteafterinstall;

Source: "opt\git\qooxdoo\application\playground\build\*"; DestDir: "{app}\cygwin\etc\slapos\desktop";
Source: "opt\git\qooxdoo\application\showcase\build\*"; DestDir: "{app}\cygwin\etc\slapos\node";

Source: "setup.exe"; DestDir: "{app}";
Source: "opt\git\slapos.package\windows\scripts\setup-cygwin.bat"; DestDir: "{app}";

Source: "cygwin\Cygwin-Terminal.ico"; DestDir: "{app}\images"; DestName: "terminal.ico";
Source: "images\configure.ico"; DestDir: "{app}\images";
Source: "images\register.ico"; DestDir: "{app}\images";
Source: "images\updater.ico"; DestDir: "{app}\images";
Source: "images\manager.ico"; DestDir: "{app}\images";

Source: "opt\git\slapos.package\windows\scripts\ip"; DestDir: "{app}\cygwin\usr\local\bin";
Source: "opt\git\slapos.package\windows\scripts\useradd"; DestDir: "{app}\cygwin\usr\local\bin";
Source: "opt\git\slapos.package\windows\scripts\usermod"; DestDir: "{app}\cygwin\usr\local\bin";
Source: "opt\git\slapos.package\windows\scripts\groupadd"; DestDir: "{app}\cygwin\usr\local\bin";
Source: "opt\git\slapos.package\windows\scripts\brctl"; DestDir: "{app}\cygwin\usr\local\bin";
Source: "opt\git\slapos.package\windows\scripts\tunctl"; DestDir: "{app}\cygwin\usr\local\bin";

Source: "opt\git\slapos.package\windows\babeld\babeld.exe"; DestDir: "{app}\cygwin\usr\local\bin";
Source: "opt\git\slapos.package\windows\openvpn\src\openvpn\.libs\openvpn.exe"; DestDir: "{app}\cygwin\usr\local\bin";

Source: "src\docs\openvpn\devcon.exe"; DestDir: "{app}\cygwin\usr\local\bin";
Source: "src\docs\openvpn\driver\*"; DestDir: "{app}\cygwin\etc\slapos\driver";

Source: "opt\git\slapos.package\windows\scripts\init-slapos-node.sh"; DestDir: "{app}\cygwin\etc\slapos\scripts";
Source: "opt\git\slapos.package\windows\scripts\post-install.sh"; DestDir: "{app}\cygwin\etc\slapos\scripts";
Source: "opt\git\slapos.package\windows\scripts\build-slapos.sh"; DestDir: "{app}\cygwin\etc\slapos\scripts";
Source: "opt\git\slapos.package\windows\scripts\slapos-node-config.sh"; DestDir: "{app}\cygwin\etc\slapos\scripts";

Source: "src\docs\using-slapos-in-windows.html"; DestDir: "{app}"; DestName: "user-guide.html";
Source: "src\docs\README.cygwin"; DestDir: "{app}"; DestName: "readme.txt";

[Icons]
Name: "{commondesktop}\SlapOS"; Filename: "{app}\cygwin\etc\slapos\desktop\index.html"; WorkingDir: "{app}\cygwin\etc\slapos\desktop"; IconFilename: "{app}\imapges\slapos.ico";
Name: "{group}\SlapOS"; Filename: "{app}\cygwin\etc\slapos\desktop\index.html"; WorkingDir: "{app}\cygwin\etc\slapos\desktop"; IconFilename: "{app}\imapges\slapos.ico";
Name: "{group}\Node Manager"; Filename: "{app}\cygwin\etc\slapos\node\index.html"; WorkingDir: "{app}\cygwin\etc\slapos\node"; IconFilename: "{app}\imapges\manager.ico";
Name: "{group}\Configure Node"; Filename: "{app}\cygwin\bin\bash.exe"; Parameters: "--login -i /etc/slapos/scripts/slapos-node-config.sh"; WorkingDir: "{app}\cygwin\etc\slapos\scripts"; IconFilename: "{app}\imapges\register.ico";
Name: "{group}\Command Console"; Filename: "{app}\cygwin\bin\bash.exe"; Parameters: "--login -i /opt/slapos/bin/slapconsole /etc/opt/slapos/slapos.cfg"; WorkingDir: "{app}\cygwin\etc\slapos\scripts"; IconFilename: "{app}\imapges\terminal.ico";
Name: "{group}\Update Center"; Filename: "{app}\cygwin\bin\bash.exe"; Parameters: "--login -i /etc/slapos/scripts/build-slapos.sh"; WorkingDir: "{app}\cygwin\etc\slapos\scripts"; IconFilename: "{app}\imapges\updater.ico";
Name: "{group}\User Guide"; Filename: "{app}\user-guide.html";
Name: "{group}\Read Me"; Filename: "{app}\readme.txt";
Name: "{group}\SlapOS.org"; Filename: "http://www.slapos.org/";
Name: "{group}\Uninstall SlapOS"; Filename: "{uninstallexe}";

[Run]
Filename: "{app}\setup-cygwin.bat"; Parameters: """{app}"" network"; StatusMsg: "Installing Cygwin...";
Filename: "{app}\cygwin\bin\bash.exe"; Parameters: "--login -i /etc/slapos/scripts/post-install.sh"; WorkingDir: "{app}\cygwin\bin"; Description: "Configure Cygwin"; StatusMsg: "Configure Cygwin...";
Filename: "cmd.exe"; Parameters: "/c {app}\cygwin\etc\postinstall\autorebase.bat.done"; WorkingDir: "{app}\cygwin";  Flags: runhidden;

[UninstallDelete]
Type: filesandordirs; Name: "{app}\cygwin" ;
Type: files; Name: "*.pyc";
Type: files; Name: "*.pyo";




