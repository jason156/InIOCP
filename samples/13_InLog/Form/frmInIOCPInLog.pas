unit frmInIOCPInLog;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls;

type
  TFormInIOCPInLog = class(TForm)
    btnTest: TButton;
    Label1: TLabel;
    Label2: TLabel;
    btnTest2: TButton;
    Memo1: TMemo;
    procedure btnTestClick(Sender: TObject);
    procedure btnTest2Click(Sender: TObject);
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
  FActiveCount: Integer = 0;  // �����߳���

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
  for i := 1 to 100000 do   // д10���
    iocp_log.WriteLog(FIndex + '->������־�̣߳�������־�߳�.');
  windows.InterlockedDecrement(FActiveCount);
end;

{$R *.dfm}

procedure TFormInIOCPInLog.btnTest2Click(Sender: TObject);
var
  i: Integer;
  TickCount: Cardinal;
begin
  // ������־�������ļ�·��
  TLogThread.InitLog('log');

  FActiveCount := 10;
  TickCount := GetTickCount;

  // �� 10 ���߳�
  for i := 1 to FActiveCount do
    with TTestThread.Create do
    begin
      FIndex := IntToStr(i);
      Resume;
    end;

  // ��ȫ���߳̽���
  while FActiveCount > 0 do
    Sleep(10);

  // ���
  Memo1.Lines.Add('10���߳�д��־�����...');
  Memo1.Lines.Add('��ʱ�����ף�: ' + IntToStr(GetTickCount - TickCount));
                    
  // ֹͣ��־
  TLogThread.StopLog;

end;

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

  // ���
  Memo1.Lines.Add('���߳�ѭ��д��־�����...');
  Memo1.Lines.Add('��ʱ�����ף�: ' + IntToStr(GetTickCount - TickCount));

  // ֹͣ��־
  TLogThread.StopLog;

end;

end.
