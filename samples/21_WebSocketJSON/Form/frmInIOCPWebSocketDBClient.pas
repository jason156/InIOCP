unit frmInIOCPWebSocketDBClient;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, fmIOCPSvrInfo, iocp_managers, iocp_base,
  http_objects, iocp_server, iocp_sockets, iocp_wsClients, DB, DBClient, Grids,
  DBGrids, ExtCtrls;

type
  TFormInIOCPWsDBClient = class(TForm)
    InWSConnection1: TInWSConnection;
    btnConnect: TButton;
    btnSend: TButton;
    btnDBQuery: TButton;
    Memo1: TMemo;
    ClientDataSet1: TClientDataSet;
    DataSource1: TDataSource;
    DBGrid1: TDBGrid;
    Image1: TImage;
    btnDBUpdate: TButton;
    btnListFiles: TButton;
    Button3: TButton;
    procedure btnConnectClick(Sender: TObject);
    procedure InWSConnection1AfterConnect(Sender: TObject);
    procedure btnSendClick(Sender: TObject);
    procedure InWSConnection1ReceiveData(Sender: TObject; const Msg: string);
    procedure InWSConnection1ReceiveMsg(Sender: TObject; Msg: TJSONResult);
    procedure InWSConnection1ReturnResult(Sender: TObject; Result: TJSONResult);
    procedure btnDBQueryClick(Sender: TObject);
    procedure ClientDataSet1AfterScroll(DataSet: TDataSet);
    procedure btnDBUpdateClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure btnListFilesClick(Sender: TObject);
    procedure Button3Click(Sender: TObject);
  private
    { Private declarations }
    FSourceTable: string;
  public
    { Public declarations }
  end;

var
  FormInIOCPWsDBClient: TFormInIOCPWsDBClient;

implementation

uses
  MidasLib, iocp_varis, jpeg, iocp_utils, iocp_log,
  iocp_msgPacks, dm_iniocp_test;

{$R *.dfm}

procedure TFormInIOCPWsDBClient.btnConnectClick(Sender: TObject);
begin
  InWSConnection1.Active := not InWSConnection1.Active;
end;

procedure TFormInIOCPWsDBClient.btnSendClick(Sender: TObject);
var
  JSON: TJSONMessage;
begin

  // ���� 1��ʹ�� InWSConnection1 ������ JSON��
{  with InWSConnection1.JSON do
  begin
    S['aaa'] := 'WebSocket test + ����.';
    S['BBB'] := 'ba +����';
    Post;
  end;     }

  // ���� 2��
  JSON := TJSONMessage.Create(InWSConnection1);
  JSON.S['aaa'] := '���� InIOCP �� WebSocket �ͻ��ˣ�����.';
  JSON.S['BBB'] := 'bbb ����';

  JSON.Attachment := TFileStream.Create('doc\InIOCPWebSocketJSON.7z', fmOpenRead);
  JSON.S['attach'] := 'InIOCPWebSocketJSON.7z';  // �������������������˱���

  JSON.Post;

end;

procedure TFormInIOCPWsDBClient.Button3Click(Sender: TObject);
begin
  Memo1.Lines.Clear;
end;

procedure TFormInIOCPWsDBClient.btnDBQueryClick(Sender: TObject);
begin
  // ���ݿ��ѯ
  //   Ϊ�������������������� Action ����
  with InWSConnection1.JSON do
  begin
    Action := 11;  // �����Ҫ������������빩�ͻ����ж�ʹ��
    S['aaa'] := 'WebSocket ���ݿ��ѯ.';
//    Text := '{"Id":123,"Name":"��","Boolean":True,"Stream":Null,"_Variant":' +
//            '{"Length":5,"Data":"abcde"},"_zzz":2345,"KKK":"aaabbbccc"}'; 
    Post;
  end;
end;

procedure TFormInIOCPWsDBClient.btnDBUpdateClick(Sender: TObject);
begin
  // ���ݿ����
  //   Ϊ�������������������� Action ����
  with InWSConnection1.JSON do
  begin
    Action := 12; // �����Ҫ������������빩�ͻ����ж�ʹ��
    // �� Variant ���ͣ�ѹ���������ȡ V['_delta', True] ���£����Բ�ѹ��
    SetRemoteTable(ClientDataSet1, FSourceTable); // ����Ҫ���µ����ݱ�������Ѿ��رգ�
    V['_delta'] := ClientDataSet1.Delta;
    Post;
  end;
end;

procedure TFormInIOCPWsDBClient.btnListFilesClick(Sender: TObject);
begin
  // �Ȳ�ѯ����� Form �µ��ļ�
  // InIOCP-JSON ֧�ּ�¼���� R[]��ÿ�ļ�����һ����¼��
  //   ����Ԫ iocp_WsJSON��iocp_managers �� TInFileManager.ListFiles
  with InWSConnection1.JSON do
  begin
    Action := 20;
    S['Path'] := 'form\';
    Post;
  end;
end;

procedure TFormInIOCPWsDBClient.ClientDataSet1AfterScroll(DataSet: TDataSet);
var
  Field: TField;
  Stream: TMemoryStream;
  JpegPic: TJpegImage;
begin
  if ClientDataSet1.Active then
  begin
    Field := ClientDataSet1.FieldByName('picture');
    if Field.IsNull then
      Image1.Picture.Graphic := nil
    else begin
      Stream := TMemoryStream.Create;
      JpegPic := TJpegImage.Create;
      try
        TBlobField(Field).SaveToStream(Stream);
        Stream.Position := 0;           // ����
        JpegPic.LoadFromStream(Stream);
        Image1.Picture.Graphic := JpegPic;
      finally
        JpegPic.Free;
        Stream.Free;
      end;
    end;
  end;
end;

procedure TFormInIOCPWsDBClient.FormCreate(Sender: TObject);
begin
  InWSConnection1.ServerAddr := 'localhost'; //'192.168.1.196';
end;

procedure TFormInIOCPWsDBClient.InWSConnection1AfterConnect(Sender: TObject);
begin
  if InWSConnection1.Active then
  begin
    btnConnect.Caption := '�Ͽ�';
    btnSend.Enabled := True;
    btnListFiles.Enabled := True;
    btnDBQuery.Enabled := True;
    btnDBUpdate.Enabled := True;
  end else
  begin
    btnConnect.Caption := '����';
    btnSend.Enabled := False;
    btnListFiles.Enabled := False;
    btnDBQuery.Enabled := False;
    btnDBUpdate.Enabled := False;
  end;
end;

procedure TFormInIOCPWsDBClient.InWSConnection1ReceiveData(Sender: TObject; const Msg: string);
begin
  // Sender: �� TInWSConnection
  //    Msg���յ���Ϣ�ı�
  // �����յ��Ĳ��� InIOCP-JSON ��Ϣ������δ��װ�����ݣ�
  // ���Է����������������һ����Ϣ���ڷ���˹㲥��
end;

procedure TFormInIOCPWsDBClient.InWSConnection1ReceiveMsg(Sender: TObject; Msg: TJSONResult);
begin
  //  Sender: �� TInWSConnection
  //     Msg: JSON ��Ϣ��ϵͳ���Զ��ͷ�
  // �����յ����������ͻ����������� InIOCP-JSON ��Ϣ���������գ�
  // ���Է������� TJSONMessage ������Ϣ���ڷ���˹㲥��
end;

procedure TFormInIOCPWsDBClient.InWSConnection1ReturnResult(Sender: TObject; Result: TJSONResult);
var
  i: Integer;
begin
  // Sender: �� TInWSConnection
  // Result: JSON ��Ϣ��ϵͳ���Զ��ͷ�
  
  // Result.MsgType: ��Ϣ����
  //   1. mtJSON��Result �� JSON ��Ϣ
  //   2. mtAttachment��Result �Ǹ�������ϵͳ�Զ��ͷţ���Ҫ Result.Attachment.Free��

  // ���Է�����������յ���Ϣ������ Socket.Result���� Socket.SendResult ���ͻ�����

  if Result.MsgType = mtJSON then
    case Result.Action of
      11: begin
        // ����˷��ص����ݼ�������Ҫѹ��
        FSourceTable := Result.S['_table'];  // ����Ҫ���µ����ݱ�����
        ClientDataSet1.Data := Result.V['_data'];
      end;

      12: begin
        // ����˷��� ���½��
        // ����Ҫ�ϲ��޸Ĺ�������
        ClientDataSet1.MergeChangeLog;
        Memo1.Lines.Add(Result.S['result']);
      end;

      20:  // ����˷��� �ļ��б�
        if Result.I['count'] = -1 then  // ·������
          Memo1.Lines.Add('·������.')
        else
          for i := 1 to Result.I['count'] do  
            with Result.R[IntToStr(i)] do  // ��һȡ��¼
            begin
              Memo1.Lines.Add(S['name']);  // ���Լ�������Ϣ������
              Free; // �ͷż�¼ R[IntToStr(i)]
            end;

      else begin
        if Result.HasAttachment then  // �и����������գ����Բ����գ�
          Result.Attachment := TFileStream.Create('temp\�ͻ����յ�' + Result.S['attach'], fmCreate);
        Memo1.Lines.Add('����˷��ظ��Լ��� JSON ��Ϣ: ' + Result.S['return']);
      end;

    end
    
  else  // �Ǹ�����
  if Assigned(Result.Attachment) then  // �յ��ļ���
  begin
    Memo1.Lines.Add('�����ļ���ϣ�ϵͳ���Զ��رո�������');
  end else
    Memo1.Lines.Add('û�н����ļ�');
end;

end.
