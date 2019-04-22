unit frmInIOCPInLog;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls;

type
  TFormInIOCPInLog = class(TForm)
    btnTest: TButton;
    Label1: TLabel;
    procedure btnTestClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  FormInIOCPInLog: TFormInIOCPInLog;

implementation

uses
  iocp_log;

type

  TTestThread = class(TThread)
  protected
    FIndex: AnsiString;
    procedure Execute; override;
  public
    constructor Create; reintroduce;
  end;

var
  FActiveCount: Integer = 10;  // �����߳���

{ TTestThread }

constructor TTestThread.Create;
begin
  inherited Create(True);
  FreeOnTerminate := True;
end;

procedure TTestThread.Execute;
var
  i: Integer;
begin
  for i := 1 to 1000000 do   // д100���
    iocp_log.WriteLog(FIndex + '->������־�̣߳�������־�߳�.');
  windows.InterlockedDecrement(FActiveCount);
end;

{$R *.dfm}

procedure TFormInIOCPInLog.btnTestClick(Sender: TObject);
var
  i: Integer;
  TickCount: Cardinal;
begin
  // ������־�������ļ�·��
  TLogThread.InitLog('log');

  TickCount := GetTickCount;

  for i := 1 to 1000000 do
    iocp_log.WriteLog('->������־�̣߳�������־�߳�.');
    
{  for i := 0 to 9 do
    with TTestThread.Create do
    begin
      FIndex := IntToStr(i);
      Resume;
    end;

  // ��ȫ���߳̽���
  while FActiveCount > 0 do
    Sleep(10);     }

  // ��10���߳�д��־��ÿ�߳�д�����...
  Label1.Caption := Label1.Caption + #13#10'��������ʱ: ' +
                    IntToStr(GetTickCount - TickCount);
                    
  // ֹͣ��־
  TLogThread.StopLog;

end;

end.
