/*
 * Syntax:
 *
 *     ipwin command options
 *
 * Get guid of interface:
 *
 *     ipwin guid *MSLOOP re6stnet-lo
 *
 * Get connection name by interface guid:
 *
 *     ipwin name {610B0F3F-06A7-47EF-A38D-EF55503C481F}
 *
 * Install network adapter and rename connection
 *
 *     ipwin install "OemWin2k.inf" tap0901 re6stnet-tcp
 *
 *     ipwin install "netloop.inf" *MSLOOP re6stnet-lo
 *
 * Remove network adapter
 *
 *     ipwin remove tap0901 re6stnet-tcp
 *
 *     ipwin remove tap0901 re6stnet-tcp
 *
 * Get system OEM CodePage
 *
 *     ipwin codepage
 *
 * Run all of testcases:
 *
 *     ipwin test
 *
 */
#include <Windows.h>
#include <tchar.h>
#include <stdio.h>

HRESULT SlaposNetCfgWinCreateNetworkInterface(IN LPCWSTR pInfPath,
                                              IN bool bIsInfPathFile,
                                              IN LPCWSTR pHwid,
                                              IN LPCWSTR pConnectionName,
                                              OUT GUID *pGuid,
                                              OUT BSTR *pErrMsg
                                              );
HRESULT SlaposNetCfgWinRemoveNetworkInterface(IN LPCWSTR pHwid,
                                              IN LPCSTR pGUID,
                                              OUT BSTR *pErrMsg
                                              );
HRESULT SlaposNetCfgGetNetworkInterfaceGuid(IN LPCWSTR pHwid,
                                            IN LPCWSTR pConnectionName,
                                            OUT BSTR *pGUID,
                                            OUT BSTR *pErrMsg
                                            );
HRESULT SlaposNetCfgGetNetworkConnectionName(IN LPCWSTR pGUID,
                                             OUT BSTR *pName,
                                             OUT BSTR *pErrMsg
                                             );
void Usage()
{
  printf("Usage: ipwin [command] [options] \n\
\n\
Available command:\n\
  install        Install network adapter\n\
  remove         Remove network adapter\n\
  guid           Get GUID of interface by name\n\
  name           Get name by GUID\n\
  codepage       Get Windows CodePage\n\
\n\
*install\n\
\n\
  Install network adapter and rename connection:\n\
\n\
  ipwin install INF-FILE HWID CONNECTION-NAME\n\
\n\
  For example,\n\
  ipwin install \"OemWin2k.inf\" tap0901 re6stnet-tcp\n\
\n\
  ipwin install \"netloop.inf\" *MSLOOP re6stnet-lo\n\
\n\
*remove\n\
\n\
  Remove network adapter:\n\
  ipwin remove HWID CONNECTIION-NAME\n\
\n\
  For example,\n\
  ipwin remove tap0901 re6stnet-tcp\n\
\n\
*guid\n\
\n\
  Get guid of interface:\n\
  ipwin guid HWID CONNECTION-NAME\n\
\n\
  For example,\n\
  ipwin guid *MSLOOP re6stnet-lo\n\
\n\
*name\n\
\n\
  Get connection name by GUID:\n\
  ipwin name GUID\n\
\n\
  For example,\n\
  ipwin name {610B0F3F-06A7-47EF-A38D-EF55503C481F}\n\
\n\
*codepage\n\
\n\
  Get codepage of Windows:\n\
  ipwin codepage\n\
\n\
\n\
Exit status:\n\
  0  if OK,\n\
  other value if problems\n\
\n");
}

HRESULT PrintCodePage(int asc)
{
  switch(asc ? GetACP() : GetOEMCP()) {
  case 037: printf("IBM037"); break;
  case 437: printf("IBM437"); break;
  case 500: printf("IBM500"); break;
  case 708: printf("ASMO-708"); break;
  case 709: printf(""); break;
  case 710: printf(""); break;
  case 720: printf("DOS-720"); break;
  case 737: printf("ibm737"); break;
  case 775: printf("ibm775"); break;
  case 850: printf("ibm850"); break;
  case 852: printf("ibm852"); break;
  case 855: printf("IBM855"); break;
  case 857: printf("ibm857"); break;
  case 858: printf("IBM00858"); break;
  case 860: printf("IBM860"); break;
  case 861: printf("ibm861"); break;
  case 862: printf("DOS-862"); break;
  case 863: printf("IBM863"); break;
  case 864: printf("IBM864"); break;
  case 865: printf("IBM865"); break;
  case 866: printf("cp866"); break;
  case 869: printf("ibm869"); break;
  case 870: printf("IBM870"); break;
  case 874: printf("windows-874"); break;
  case 875: printf("cp875"); break;
  case 932: printf("shift_jis"); break;
  case 936: printf("gb2312"); break;
  case 949: printf("ks_c_5601-1987"); break;
  case 950: printf("big5"); break;
  case 1026: printf("IBM1026"); break;
  case 1047: printf("IBM01047"); break;
  case 1140: printf("IBM01140"); break;
  case 1141: printf("IBM01141"); break;
  case 1142: printf("IBM01142"); break;
  case 1143: printf("IBM01143"); break;
  case 1144: printf("IBM01144"); break;
  case 1145: printf("IBM01145"); break;
  case 1146: printf("IBM01146"); break;
  case 1147: printf("IBM01147"); break;
  case 1148: printf("IBM01148"); break;
  case 1149: printf("IBM01149"); break;
  case 1200: printf("utf-16"); break;
  case 1201: printf("unicodeFFFE"); break;
  case 1250: printf("windows-1250"); break;
  case 1251: printf("windows-1251"); break;
  case 1252: printf("windows-1252"); break;
  case 1253: printf("windows-1253"); break;
  case 1254: printf("windows-1254"); break;
  case 1255: printf("windows-1255"); break;
  case 1256: printf("windows-1256"); break;
  case 1257: printf("windows-1257"); break;
  case 1258: printf("windows-1258"); break;
  case 1361: printf("Johab"); break;
  case 10000: printf("macintosh"); break;
  case 10001: printf("x-mac-japanese"); break;
  case 10002: printf("x-mac-chinesetrad"); break;
  case 10003: printf("x-mac-korean"); break;
  case 10004: printf("x-mac-arabic"); break;
  case 10005: printf("x-mac-hebrew"); break;
  case 10006: printf("x-mac-greek"); break;
  case 10007: printf("x-mac-cyrillic"); break;
  case 10008: printf("x-mac-chinesesimp"); break;
  case 10010: printf("x-mac-romanian"); break;
  case 10017: printf("x-mac-ukrainian"); break;
  case 10021: printf("x-mac-thai"); break;
  case 10029: printf("x-mac-ce"); break;
  case 10079: printf("x-mac-icelandic"); break;
  case 10081: printf("x-mac-turkish"); break;
  case 10082: printf("x-mac-croatian"); break;
  case 12000: printf("utf-32"); break;
  case 12001: printf("utf-32BE"); break;
  case 20000: printf("x-Chinese_CNS"); break;
  case 20001: printf("x-cp20001"); break;
  case 20002: printf("x_Chinese-Eten"); break;
  case 20003: printf("x-cp20003"); break;
  case 20004: printf("x-cp20004"); break;
  case 20005: printf("x-cp20005"); break;
  case 20105: printf("x-IA5"); break;
  case 20106: printf("x-IA5-German"); break;
  case 20107: printf("x-IA5-Swedish"); break;
  case 20108: printf("x-IA5-Norwegian"); break;
  case 20127: printf("us-ascii"); break;
  case 20261: printf("x-cp20261"); break;
  case 20269: printf("x-cp20269"); break;
  case 20273: printf("IBM273"); break;
  case 20277: printf("IBM277"); break;
  case 20278: printf("IBM278"); break;
  case 20280: printf("IBM280"); break;
  case 20284: printf("IBM284"); break;
  case 20285: printf("IBM285"); break;
  case 20290: printf("IBM290"); break;
  case 20297: printf("IBM297"); break;
  case 20420: printf("IBM420"); break;
  case 20423: printf("IBM423"); break;
  case 20424: printf("IBM424"); break;
  case 20833: printf("x-EBCDIC-KoreanExtended"); break;
  case 20838: printf("IBM-Thai"); break;
  case 20866: printf("koi8-r"); break;
  case 20871: printf("IBM871"); break;
  case 20880: printf("IBM880"); break;
  case 20905: printf("IBM905"); break;
  case 20924: printf("IBM00924"); break;
  case 20932: printf("EUC-JP"); break;
  case 20936: printf("x-cp20936"); break;
  case 20949: printf("x-cp20949"); break;
  case 21025: printf("cp1025"); break;
  case 21027: printf(""); break;
  case 21866: printf("koi8-u"); break;
  case 28591: printf("iso-8859-1"); break;
  case 28592: printf("iso-8859-2"); break;
  case 28593: printf("iso-8859-3"); break;
  case 28594: printf("iso-8859-4"); break;
  case 28595: printf("iso-8859-5"); break;
  case 28596: printf("iso-8859-6"); break;
  case 28597: printf("iso-8859-7"); break;
  case 28598: printf("iso-8859-8"); break;
  case 28599: printf("iso-8859-9"); break;
  case 28603: printf("iso-8859-13"); break;
  case 28605: printf("iso-8859-15"); break;
  case 29001: printf("x-Europa"); break;
  case 38598: printf("iso-8859-8-i"); break;
  case 50220: printf("iso-2022-jp"); break;
  case 50221: printf("csISO2022JP"); break;
  case 50222: printf("iso-2022-jp"); break;
  case 50225: printf("iso-2022-kr"); break;
  case 50227: printf("x-cp50227"); break;
  case 50229: printf(""); break;
  case 50930: printf(""); break;
  case 50931: printf(""); break;
  case 50933: printf(""); break;
  case 50935: printf(""); break;
  case 50936: printf(""); break;
  case 50937: printf(""); break;
  case 50939: printf(""); break;
  case 51932: printf("euc-jp"); break;
  case 51936: printf("EUC-CN"); break;
  case 51949: printf("euc-kr"); break;
  case 51950: printf(""); break;
  case 52936: printf("hz-gb-2312"); break;
  case 54936: printf("GB18030"); break;
  case 57002: printf("x-iscii-de"); break;
  case 57003: printf("x-iscii-be"); break;
  case 57004: printf("x-iscii-ta"); break;
  case 57005: printf("x-iscii-te"); break;
  case 57006: printf("x-iscii-as"); break;
  case 57007: printf("x-iscii-or"); break;
  case 57008: printf("x-iscii-ka"); break;
  case 57009: printf("x-iscii-ma"); break;
  case 57010: printf("x-iscii-gu"); break;
  case 57011: printf("x-iscii-pa"); break;
  case 65000: printf("utf-7"); break;
  case 65001: printf("utf-8"); break;
  default:
    return E_FAIL;
  }
  return S_OK;
}

int _tmain(int argc, TCHAR * argv[])
{
  GUID guid;
  BSTR pErrMsg[1024] = {0};
  BSTR pGUID[512] = {0};

  HRESULT hr = CoInitialize(NULL);

  if (argc == 1) {
    Usage();
  }
  else if (wcscmp(argv[1], L"install") == 0) {
    if (argc != 5) {
      Usage();
      hr = E_FAIL;
    }
    else
      hr = SlaposNetCfgWinCreateNetworkInterface(argv[2], TRUE, argv[3], argv[4], &guid, pErrMsg);
  }
  else if (wcscmp(argv[1], L"remove") == 0) {
    if (argc != 4) {
      Usage();
      hr = E_FAIL;
    }
    else {
      hr = SlaposNetCfgGetNetworkInterfaceGuid(argv[2], argv[3], pGUID, pErrMsg);
      if (hr == S_OK) {
        hr = SlaposNetCfgWinRemoveNetworkInterface(argv[2], (LPCSTR)pGUID, pErrMsg);
      }
    }
  }
  else if (wcscmp(argv[1], L"guid") == 0) {
    if (argc != 4) {
      Usage();
      hr = E_FAIL;
    }
    else {
      hr = SlaposNetCfgGetNetworkInterfaceGuid(argv[2], argv[3], pGUID, pErrMsg);
      printf("%s", hr == S_OK ? pGUID : pErrMsg);
    }
  }
  else if (wcscmp(argv[1], L"name") == 0) {
    if (argc != 3) {
      Usage();
      hr = E_FAIL;
    }
    else {
      hr = SlaposNetCfgGetNetworkConnectionName(argv[2], pGUID, pErrMsg);
      printf("%s", hr == S_OK ? pGUID : pErrMsg);
    }
  }
  else if (wcscmp(argv[1], L"codepage") == 0) {
    hr = PrintCodePage(0);
  }
  else if (wcscmp(argv[1], L"test") == 0) {
  }
  else {
    Usage();
  }

  CoUninitialize();
  return hr == S_OK ? 0 : 1;
}
