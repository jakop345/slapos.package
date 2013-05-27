; SEE THE DOCUMENTATION FOR DETAILS ON CREATING .ISS SCRIPT FILES!

[Setup]
AppName=SlapOS
AppVersion=0.158
AppVerName=SlapOS Windows 0.158.2
DefaultDirName=C:\slapos
DefaultGroupName=SlapOS
OutputBaseFilename=slapos-0.158.2-windows-x86-all-in-one
OutputDir=D:\slapos\publish\Output
SourceDir=D:\slapos
Uninstallable=yes

[Dirs]
Name: "{app}\cygwin"
Name: "{app}\cygwin\opt\slapos"
Name: "{app}\cygwin\usr\local\bin"
Name: "{app}\cygwin\etc\slapos\driver"
Name: "{app}\cygwin\etc\slapos\scripts"
Name: "{app}\cygwin\etc\slapos\images"

[Files]
Source: "cygwin-packages\*"; DestDir: "{app}\cygwin-packages"; Flags: recursesubdirs;
Source: "publish\buildout\slapos\*"; DestDir: "{app}\cygwin\opt\slapos"; Flags: recursesubdirs;
Source: "opt\git\slapos.core\slapos.cfg.example"; DestDir: "{app}\cygwin\etc\slapos";
Source: "opt\git\slapos.core\slapos-client.cfg.example"; DestDir: "{app}\cygwin\etc\slapos";
Source: "opt\downloads\pyOpenSSL-0.13.tar.gz"; DestDir: "{app}\cygwin"; DestName: "pyOpenSSL.tar.gz";
Source: "opt\git\re6stnet\dist\re6stnet-0.1.tar.gz"; DestDir: "{app}\cygwin"; DestName: "re6stnet.tar.gz";
Source: "opt\downloads\miniupnpc-1.8.tar.gz"; DestDir: "{app}\cygwin"; DestName: "miniupnpc.tar.gz";

Source: "src\patch\slapos-core-format.patch"; DestDir: "{app}\cygwin\etc\slapos\patches";
Source: "src\patch\slapos-cookbook-inotifyx.patch"; DestDir: "{app}\cygwin\etc\slapos\patches";
Source: "src\patch\slapos-core-env.patch"; DestDir: "{app}\cygwin\etc\slapos\patches";

Source: "opt\git\qooxdoo\application\playground\build\*"; DestDir: "{app}\cygwin\etc\slapos\desktop"; Flags: recursesubdirs;
Source: "opt\git\qooxdoo\application\showcase\build\*"; DestDir: "{app}\cygwin\etc\slapos\node"; Flags: recursesubdirs;

Source: "setup.exe"; DestDir: "{app}";
Source: "opt\git\slapos.package\windows\scripts\setup-cygwin.bat"; DestDir: "{app}";

Source: "images\slapos.ico"; DestDir: "{app}\cygwin\etc\slapos\images";
Source: "cygwin\Cygwin-Terminal.ico"; DestDir: "{app}\cygwin\etc\slapos\images"; DestName: "terminal.ico";
Source: "images\configure.ico"; DestDir: "{app}\cygwin\etc\slapos\images";
Source: "images\node.ico"; DestDir: "{app}\cygwin\etc\slapos\images";
Source: "images\updater.ico"; DestDir: "{app}\cygwin\etc\slapos\images";
Source: "images\manager.ico"; DestDir: "{app}\cygwin\etc\slapos\images";

Source: "setup.exe"; DestDir: "{app}";
Source: "opt\git\slapos.package\windows\scripts\setup-cygwin.bat"; DestDir: "{app}";

Source: "opt\git\slapos.package\windows\scripts\ip"; DestDir: "{app}\cygwin\usr\local\bin";
Source: "opt\git\slapos.package\windows\scripts\useradd"; DestDir: "{app}\cygwin\usr\local\bin";
Source: "opt\git\slapos.package\windows\scripts\usermod"; DestDir: "{app}\cygwin\usr\local\bin";
Source: "opt\git\slapos.package\windows\scripts\groupadd"; DestDir: "{app}\cygwin\usr\local\bin";
Source: "opt\git\slapos.package\windows\scripts\brctl"; DestDir: "{app}\cygwin\usr\local\bin";
Source: "opt\git\slapos.package\windows\scripts\tunctl"; DestDir: "{app}\cygwin\usr\local\bin";
Source: "opt\git\slapos.package\windows\scripts\cyg_wscript"; DestDir: "{app}\cygwin\usr\local\bin";

Source: "opt\git\slapos.package\windows\babeld\babeld.exe"; DestDir: "{app}\cygwin\usr\local\bin";
Source: "opt\git\slapos.package\windows\openvpn\src\openvpn\.libs\openvpn.exe"; DestDir: "{app}\cygwin\usr\local\bin";

Source: "src\docs\openvpn\devcon.exe"; DestDir: "{app}\cygwin\usr\local\bin";
Source: "src\docs\openvpn\driver\*"; DestDir: "{app}\cygwin\etc\slapos\driver";

Source: "opt\git\slapos.package\windows\scripts\init-slapos-node.sh"; DestDir: "{app}\cygwin\etc\slapos\scripts";
Source: "opt\git\slapos.package\windows\scripts\post-install.sh"; DestDir: "{app}\cygwin\etc\slapos\scripts";
Source: "opt\git\slapos.package\windows\scripts\build-slapos.sh"; DestDir: "{app}\cygwin\etc\slapos\scripts";
Source: "opt\git\slapos.package\windows\scripts\slapos-node-config.sh"; DestDir: "{app}\cygwin\etc\slapos\scripts";
Source: "opt\git\slapos.package\windows\scripts\slapos-client-config.sh"; DestDir: "{app}\cygwin\etc\slapos\scripts";


Source: "src\docs\using-slapos-in-windows.html"; DestDir: "{app}"; DestName: "user-guide.html";
Source: "src\docs\README.cygwin"; DestDir: "{app}"; DestName: "readme.txt";

[Icons]
Name: "{commondesktop}\SlapOS"; Filename: "{app}\cygwin\etc\slapos\desktop\index.html"; WorkingDir: "{app}\cygwin\etc\slapos\desktop"; IconFilename: "{app}\cygwin\etc\slapos\images\slapos.ico";
Name: "{group}\SlapOS"; Filename: "{app}\cygwin\etc\slapos\desktop\index.html"; WorkingDir: "{app}\cygwin\etc\slapos\desktop"; IconFilename: "{app}\cygwin\etc\slapos\images\slapos.ico";
Name: "{group}\Node Manager"; Filename: "{app}\cygwin\etc\slapos\node\index.html"; WorkingDir: "{app}\cygwin\etc\slapos\node"; IconFilename: "{app}\cygwin\etc\slapos\images\manager.ico";
Name: "{group}\Configure Client"; Filename: "{app}\cygwin\bin\mintty.exe"; Parameters: "-c ~/.minttyrc -t ""Configure SlapOS Client"" /etc/slapos/scripts/slapos-client-config.sh"; WorkingDir: "{app}\cygwin\bin"; IconFilename: "{app}\cygwin\etc\slapos\images\configure.ico";
Name: "{group}\Configure Node"; Filename: "{app}\cygwin\bin\mintty.exe"; Parameters: "-c ~/.minttyrc -t ""Configure SlapOS Node"" /etc/slapos/scripts/slapos-node-config.sh"; WorkingDir: "{app}\cygwin\bin"; IconFilename: "{app}\cygwin\etc\slapos\images\node.ico";
Name: "{group}\Command Console"; Filename: "{app}\cygwin\bin\mintty.exe"; Parameters: "-c ~/.minttyrc -h always -t ""SlapOS Console"" /opt/slapos/bin/slapconsole /etc/opt/slapos/slapos.cfg"; WorkingDir: "{app}\cygwin\bin"; IconFilename: "{app}\cygwin\etc\slapos\images\terminal.ico";
Name: "{group}\Update Center"; Filename: "{app}\cygwin\bin\mintty.exe"; Parameters: "-c ~/.minttyrc -h always -t ""Building SlapOS"" /etc/slapos/scripts/build-slapos.sh"; WorkingDir: "{app}\cygwin\bin"; IconFilename: "{app}\cygwin\etc\slapos\images\updater.ico";
Name: "{group}\User Guide"; Filename: "{app}\user-guide.html";
Name: "{group}\Read Me"; Filename: "{app}\Readme.txt";
Name: "{group}\SlapOS.org"; Filename: "http://www.slapos.org/";
Name: "{group}\Uninstall SlapOS"; Filename: "{uninstallexe}";

[Run]
Filename: "{app}\setup-cygwin.bat"; Parameters: """{app}"""; StatusMsg: "Installing Cygwin..."; Flags: runhidden;
Filename: "{app}\cygwin\bin\bash.exe"; Parameters: "--login -i /etc/slapos/scripts/post-install.sh"; WorkingDir: "{app}\cygwin\bin"; Description: "Configure Cygwin"; StatusMsg: "Configure Cygwin..."; Flags: skipifdoesntexist runhidden;
Filename: "{app}\cygwin\autorebase.bat"; WorkingDir: "{app}\cygwin";  Flags: skipifdoesntexist runhidden;

[UninstallDelete]
Type: filesandordirs; Name: "{app}\cygwin" ;
Type: files; Name: "*.pyc";
Type: files; Name: "*.pyo";




