unit frmInIOCPPushMessage;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, iocp_clients, ExtCtrls;

type
  TForm3 = class(TForm)
    Memo1: TMemo;
    InConnection: TInConnection;
    InCertifyClient1: TInCertifyClient;
    lbl1: TLabel;
    Label4: TLabel;
    edtPort: TEdit;
    edtAddress: TEdit;
    Button1: TButton;
    Timer1: TTimer;
    procedure Button1Click(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
    procedure InConnectionError(Sender: TObject; const Msg: string);
    procedure InConnectionReceiveMsg(Sender: TObject; Msg: TResultParams);
    procedure FormCreate(Sender: TObject);
    procedure InConnectionAfterConnect(Sender: TObject);
    procedure InConnectionReturnResult(Sender: TObject; Result: TResultParams);
  private
    { Private declarations }
    FCount: Integer;
  public
    { Public declarations }
  end;

var
  Form3: TForm3;

implementation

uses
  iocp_base;

{$R *.dfm}

procedure TForm3.Button1Click(Sender: TObject);
begin
  if not InConnection.Active then
  begin
    Button1.Caption := 'ֹͣ';
    InConnection.ServerAddr := edtAddress.Text;
    InConnection.ServerPort := StrToInt(edtPort.Text);
    InConnection.Active := True;

    // �°�ı䣺
    // ���������֤�������ʱ���ͻ������¼�����Ӻ󼴿����̷�������
    
    InCertifyClient1.UserName := 'USER_A' + IntToStr(GetTickCount);
    InCertifyClient1.Password := 'AAAA';
    InCertifyClient1.Login; 

    Timer1.Enabled := True;
    Memo1.Lines.Add('Start');
  end else
  begin
    Timer1.Enabled := False;
    InConnection.Active := False;
    Button1.Caption := '�㲥';    
  end;
end;

procedure TForm3.FormCreate(Sender: TObject);
begin
  edtAddress.Text := '127.0.0.1';  // '192.168.1.196'; //
  edtPort.Text := '12302';  // '80';    
end;

procedure TForm3.InConnectionAfterConnect(Sender: TObject);
begin
{  InCertifyClient1.UserName := 'USER_A' + IntToStr(GetTickCount);
  InCertifyClient1.Password := 'AAAA';
  InCertifyClient1.Login;
  Timer1.Enabled := True;    }
end;

procedure TForm3.InConnectionError(Sender: TObject; const Msg: string);
begin
  Memo1.Lines.Add(Msg);
end;

procedure TForm3.InConnectionReceiveMsg(Sender: TObject; Msg: TResultParams);
begin
  // �����ﴦ���յ���������Ϣ������������Ϣ�����󲢷�ʱ��Ҫ��ʾ
  Memo1.Lines.Add(Msg.Msg);
end;

procedure TForm3.InConnectionReturnResult(Sender: TObject;
  Result: TResultParams);
begin
  // Memo1.Lines.Add(Result.Msg);
end;

procedure TForm3.Timer1Timer(Sender: TObject);
const
  TEXT_MSG = 'AFSFSFLSLFSLFLLLSSLDKDFKDFDSLFKDSKFSLFDKSFLKSLFSLFLSFDSFSLFS';
var
  Msg: TMessagePack;
begin
  if not InConnection.Active then
    Button1Click(nil);

  Inc(FCount);
  if (FCount > Length(TEXT_MSG)) then
    FCount := 1;
    
  // ��������ֱ�ӷ�����Ϣ
  Msg := TMessagePack.Create(InConnection);
  Msg.Msg := '������Ϣ AAAAAAAAAAA' + Copy(Text_msg, 1, FCount);

  // ��У���루��ʵ������û��Ҫ��
  // ����ͻ��˵�У�����۶ϴ���������������ʱ�п��ܳ����쳣
{  Msg.CheckType := ctMurmurHash;
  Msg.CheckType := ctMD5;  }

  Msg.Post(atTextBroadcast);

  // ������Ϣ
{  Msg := TMessagePack.Create(InConnection);
  Msg.Msg := '������Ϣ BBBBBBBBBBBBBB' + Copy(Text_msg, 1, FCount);
  Msg.Post(atTextBroadcast); }

//  Memo1.Lines.Add('Push' + IntToStr(FCount));
end;

end.
