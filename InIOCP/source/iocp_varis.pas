(*
 * icop ȫ�ֱ�����Ԫ
 *)
unit iocp_varis;

interface

 uses
   SysUtils, iocp_utils;

var
       gAppPath: String;  // ����·��
      gTempPath: String;  // ��ʱ·��
  gUserDataPath: String;  // ������û�����·��

     WriteInLog: procedure(const Msg: AnsiString) = nil;

implementation

initialization
   gAppPath := ExtractFilePath(ParamStr(0));
  gTempPath := AddBackslash(GetSystemTempDir());

finalization

end.
