; SEE THE DOCUMENTATION FOR DETAILS ON CREATING .ISS SCRIPT FILES!

[Setup]
AppName=SlapOS
AppVersion=0.158
AppVerName=SlapOS Windows 0.158
DefaultDirName=C:\slapos
DefaultGroupName=SlapOS
OutputDir=D:\slapos\publish\Output
OutputBaseFilename=slapos-0.158-windows-x86
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

[Files]
Source: "opt\git\slapos\component\cygwin\slapos-core.patch"; DestDir: "{app}\cygwin\etc\slapos\patches";
Source: "opt\git\slapos\component\cygwin\slapos-cookbook-inotifyx.patch"; DestDir: "{app}\cygwin\etc\slapos\patches";

Source: "opt\git\re6stnet\dist\re6stnet-0.1.tar.gz"; DestDir: "{app}\cygwin"; DestName: "re6stnet-0.1.tar.gz"; Flags: deleteafterinstall;
Source: "opt\downloads\miniupnpc-1.8.tar.gz"; DestDir: "{app}\cygwin"; DestName: "miniupnpc.tar.gz"; Flags: deleteafterinstall;
Source: "opt\git\slapos.recipe.cmmi\dist\slapos.recipe.cmmi-0.1.tar.gz"; DestDir: "{app}\opt\download-cache\dist";

Source: "opt\git\qooxdoo\application\playground\build\*"; DestDir: "{app}\cygwin\etc\slapos\desktop";
Source: "opt\git\qooxdoo\application\showcase\build\*"; DestDir: "{app}\cygwin\etc\slapos\node";

Source: "cygwin\Cygwin-Terminal.ico"; DestDir: "{app}\images"; DestName: "terminal.ico";
Source: "images\configure.ico"; DestDir: "{app}\images";
Source: "images\register.ico"; DestDir: "{app}\images";
Source: "images\updater.ico"; DestDir: "{app}\images";
Source: "images\manager.ico"; DestDir: "{app}\images";

Source: "src\win32\ip"; DestDir: "{app}\cygwin\usr\local\bin";
Source: "src\win32\useradd"; DestDir: "{app}\cygwin\usr\local\bin";
Source: "src\win32\usermod"; DestDir: "{app}\cygwin\usr\local\bin";
Source: "src\win32\groupadd"; DestDir: "{app}\cygwin\usr\local\bin";
Source: "src\win32\brctl"; DestDir: "{app}\cygwin\usr\local\bin";
Source: "src\win32\tunctl"; DestDir: "{app}\cygwin\usr\local\bin";

Source: "opt\git\slapos.package\windows\babeld\babeld.exe"; DestDir: "{app}\cygwin\usr\local\bin";
Source: "opt\git\slapos.package\windows\openvpn\src\openvpn\.libs\openvpn.exe"; DestDir: "{app}\cygwin\usr\local\bin";

Source: "src\docs\openvpn\devcon.exe"; DestDir: "{app}\cygwin\usr\local\bin";
Source: "src\docs\openvpn\driver\*"; DestDir: "{app}\cygwin\etc\slapos\driver";

Source: "src\win32\init-slapos-node.sh"; DestDir: "{app}\cygwin\etc\slapos\scripts";
Source: "src\win32\init-cygwin.sh"; DestDir: "{app}\cygwin\etc\slapos\scripts";
Source: "src\win32\build-slapos.sh"; DestDir: "{app}\cygwin\etc\slapos\scripts";
Source: "src\win32\init-re6stnet.sh"; DestDir: "{app}\cygwin\etc\slapos\scripts";
Source: "src\win32\build-slapos.sh"; DestDir: "{app}\cygwin\etc\slapos\scripts";

Source: "src\docs\using-slapos-in-windows.html"; DestDir: "{app}"; DestName: "user-guide.html";
Source: "src\win32\README.cygwin"; DestDir: "{app}"; DestName: "readme.txt";

[Icons]
Name: "{commondesktop}\SlapOS"; Filename: "{app}\cygwin\etc\slapos\desktop\index.html"; WorkingDir: "{app}\cygwin\etc\slapos\desktop"; IconFilename: "{app}\imapges\slapos.ico";
Name: "{group}\SlapOS"; Filename: "{app}\cygwin\etc\slapos\desktop\index.html"; WorkingDir: "{app}\cygwin\etc\slapos\desktop"; IconFilename: "{app}\imapges\slapos.ico";
Name: "{group}\Node Manager"; Filename: "{app}\cygwin\etc\slapos\node\index.html"; WorkingDir: "{app}\cygwin\etc\slapos\node"; IconFilename: "{app}\imapges\manager.ico";
Name: "{group}\Register Node"; Filename: "{app}\cygwin\bin\bash.exe"; Parameters: "--login -i /etc/slapos/scripts/register-node.sh"; WorkingDir: "{app}\cygwin\etc\slapos\scripts"; IconFilename: "{app}\imapges\register.ico";
; Name: "{group}\Resilient Configuration"; Filename: "{app}\cygwin\bin\bash.exe"; Parameters: "--login -i /etc/slapos/scripts/re6stnet-configure"; WorkingDir: "{app}\cygwin\etc\slapos\scripts"; IconFilename: "{app}\imapges\configure.ico";
Name: "{group}\Command Console"; Filename: "{app}\cygwin\bin\bash.exe"; Parameters: "--login -i /opt/slapos/bin/slapconsole /etc/opt/slapos/slapos.cfg"; WorkingDir: "{app}\cygwin\etc\slapos\scripts"; IconFilename: "{app}\imapges\terminal.ico";
Name: "{group}\Update Center"; Filename: "{app}\cygwin\bin\bash.exe"; Parameters: "--login -i /etc/slapos/scripts/build-slapos.sh"; WorkingDir: "{app}\cygwin\etc\slapos\scripts"; IconFilename: "{app}\imapges\updater.ico";
Name: "{group}\User Guide"; Filename: "{app}\user-guide.html";
Name: "{group}\Read Me"; Filename: "{app}\readme.txt";
Name: "{group}\SlapOS.org"; Filename: "http://www.slapos.org/";
Name: "{group}\Uninstall SlapOS"; Filename: "{uninstallexe}";

[Run]
Filename: "{app}\setup-cygwin.bat"; Parameters: """{app}"" network"; StatusMsg: "Installing Cygwin...";
Filename: "{app}\cygwin\bin\bash.exe"; Parameters: "--login -i /etc/slapos/scripts/init-cygwin.sh"; WorkingDir: "{app}\cygwin\bin"; Description: "Configure Cygwin"; StatusMsg: "Configure Cygwin...";
Filename: "{app}\cygwin\bin\bash.exe"; Parameters: "--login -i /etc/slapos/scripts/build-slapos.sh"; WorkingDir: "{app}\cygwin\bin"; Description: "Builout process"; StatusMsg: "Building SlapOS...";
Filename: "{app}\cygwin\bin\bash.exe"; Parameters: "--login -i /etc/slapos/scripts/init-re6stnet.sh"; WorkingDir: "{app}\cygwin\bin"; Description: "Configure Re6stnet"; StatusMsg: "Configure Re6stnet...";
Filename: "cmd.exe"; Parameters: "/c {app}\cygwin\etc\postinstall\autorebase.bat.done"; WorkingDir: "{app}\cygwin";  Flags: runhidden;

[UninstallDelete]
Type: filesandordirs; Name: "{app}\cygwin" ;
Type: files; Name: "*.pyc";
Type: files; Name: "*.pyo";

