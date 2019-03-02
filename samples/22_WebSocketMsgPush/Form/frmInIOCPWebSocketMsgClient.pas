unit frmInIOCPWebSocketMsgClient;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ExtCtrls, iocp_base, iocp_wsClients;

type
  TFormInIOCPWsJSONMsgClient = class(TForm)
    Button1: TButton;
    Memo1: TMemo;
    Timer1: TTimer;
    Panel1: TPanel;
    InWSConnection1: TInWSConnection;
    procedure Button1Click(Sender: TObject);
    procedure InWSConnection1ReceiveData(Sender: TObject; const Msg: string);
    procedure InWSConnection1ReceiveMsg(Sender: TObject; Msg: TJSONResult);
    procedure Timer1Timer(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure InWSConnection1AfterConnect(Sender: TObject);
    procedure InWSConnection1ReturnResult(Sender: TObject; Result: TJSONResult);
  private
    { Private declarations }
    FCount: Integer;
  public
    { Public declarations }
  end;

var
  FormInIOCPWsJSONMsgClient: TFormInIOCPWsJSONMsgClient;

implementation

{$R *.dfm}

procedure TFormInIOCPWsJSONMsgClient.Button1Click(Sender: TObject);
begin
  Timer1.Enabled := not Timer1.Enabled;
  InWSConnection1.Active := not InWSConnection1.Active;
end;

procedure TFormInIOCPWsJSONMsgClient.FormCreate(Sender: TObject);
begin
  InWSConnection1.ServerAddr := '192.168.1.196'; // 'localhost'; //
  InWSConnection1.ServerPort := 800; // '12302';
  InWSConnection1.Active := True;
end;

procedure TFormInIOCPWsJSONMsgClient.InWSConnection1AfterConnect(
  Sender: TObject);
begin
  Timer1.Enabled := InWSConnection1.Active;
  if InWSConnection1.Active then
  begin
    Memo1.Lines.Clear;
    Button1.Caption := 'ֹͣ';
  end else
    Button1.Caption := '�㲥';
end;

procedure TFormInIOCPWsJSONMsgClient.InWSConnection1ReceiveData(Sender: TObject; const Msg: string);
begin
  // �յ��� InIOCP-JSON ��Ϣ���������գ�
  Memo1.Lines.Add('�յ�:' + Msg);
end;

procedure TFormInIOCPWsJSONMsgClient.InWSConnection1ReceiveMsg(Sender: TObject; Msg: TJSONResult);
begin
  // �յ� InIOCP-JSON ��Ϣ���������գ�
//  Memo1.Lines.Add('�յ�:' + Msg.S['msg']);
end;

procedure TFormInIOCPWsJSONMsgClient.InWSConnection1ReturnResult(Sender: TObject; Result: TJSONResult);
begin
  // �յ�����˵ķ�����Ϣ���������գ�
end;

procedure TFormInIOCPWsJSONMsgClient.Timer1Timer(Sender: TObject);
const
  TEXT_MSG = 'AFSFSFLSLFSLFLLLSSLDKDFKDFDSLFKDSKFSLFDKSFLKSLFSLFLSFDSFSLFS';
begin
//  Timer1.Enabled := False;
  Inc(FCount);
  if (FCount > Length(TEXT_MSG)) then
    FCount := 1;
  with InWSConnection1.JSON do
  begin
    Action := 33;  // ������� InIOCPWebSocketJSON������ͬʱ���Թ㲥 �� ���ݿ��ѯ
    S['msg'] := '�ͻ�����Ϣ���ڷ���˹㲥 ' + Copy(Text_msg, 1, FCount);
    Post;
  end;
end;

end.
