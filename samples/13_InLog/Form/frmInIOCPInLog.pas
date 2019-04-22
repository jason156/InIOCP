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
  FActiveCount: Integer = 10;  // 开设线程数

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
  for i := 1 to 1000000 do   // 写100万次
    iocp_log.WriteLog(FIndex + '->测试日志线程，测试日志线程.');
  windows.InterlockedDecrement(FActiveCount);
end;

{$R *.dfm}

procedure TFormInIOCPInLog.btnTestClick(Sender: TObject);
var
  i: Integer;
  TickCount: Cardinal;
begin
  // 开启日志，设置文件路径
  TLogThread.InitLog('log');

  TickCount := GetTickCount;

  for i := 1 to 1000000 do
    iocp_log.WriteLog('->测试日志线程，测试日志线程.');
    
{  for i := 0 to 9 do
    with TTestThread.Create do
    begin
      FIndex := IntToStr(i);
      Resume;
    end;

  // 等全部线程结束
  while FActiveCount > 0 do
    Sleep(10);     }

  // 用10个线程写日志，每线程写百万次...
  Label1.Caption := Label1.Caption + #13#10'结束，耗时: ' +
                    IntToStr(GetTickCount - TickCount);
                    
  // 停止日志
  TLogThread.StopLog;

end;

end.
