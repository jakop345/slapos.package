How to build for x86:

Open ipwin.vcproj in the Microsoft Visual Studio 2008, Press F7

How to build for x64:

1. Download and install Windows SDK 7.0 and install it in your Windows 7 (x64)

wget http://download.microsoft.com/download/2/E/9/2E911956-F90F-4BFB-8231-E292A7B6F287/GRMSDKX_EN_DVD.iso

You can find other sdks for different architecture: http://www.microsoft.com/en-us/download/details.aspx?id=18950

2. Click Start -> Microsoft Windows SDK V7.0 -> CMD Shell

   cd \slapos\opt\git\slapos.packages\windows\ipwin\ipwin
   cl.exe ipwin.cpp netcfg.cpp setupapi.lib iphlpapi.lib advapi32.lib
   copy ipwin.exe \slapos\cygwin\bin
