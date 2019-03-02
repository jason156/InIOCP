unit frmInIOCPDbSvrClient;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, iocp_base, iocp_clients, iocp_msgPacks, StdCtrls, DB, DBClient,
  Grids, DBGrids, ExtCtrls;

type
  TFormInIOCPDbSvrClient = class(TForm)
    Memo1: TMemo;
    InConnection1: TInConnection;
    InCertifyClient1: TInCertifyClient;
    btnLogin: TButton;
    edtLoginUser: TEdit;
    btnConnect: TButton;
    btnDisconnect: TButton;
    btnLogout: TButton;
    btnDBUpdate: TButton;
    btnDBUpdate2: TButton;
    btnDBQuery: TButton;
    DataSource1: TDataSource;
    ClientDataSet1: TClientDataSet;
    InDBConnection1: TInDBConnection;
    InDBQueryClient1: TInDBQueryClient;
    InDBSQLClient1: TInDBSQLClient;
    btnQueryDBConnections: TButton;
    btnSetDBConnection: TButton;
    DBGrid1: TDBGrid;
    ComboBox1: TComboBox;
    Image1: TImage;
    btnStoredProc: TButton;
    btnStoredProc2: TButton;
    edtIP: TEdit;
    edtPort: TEdit;
    Button1: TButton;
    procedure btnConnectClick(Sender: TObject);
    procedure btnDisconnectClick(Sender: TObject);
    procedure btnLoginClick(Sender: TObject);
    procedure InCertifyClient1Certify(Sender: TObject; Action: TActionType;
      ActResult: Boolean);
    procedure btnLogoutClick(Sender: TObject);
    procedure btnQueryDBConnectionsClick(Sender: TObject);
    procedure btnSetDBConnectionClick(Sender: TObject);
    procedure InDBConnection1ReturnResult(Sender: TObject;
      Result: TResultParams);
    procedure ComboBox1Change(Sender: TObject);
    procedure btnDBQueryClick(Sender: TObject);
    procedure btnDBUpdateClick(Sender: TObject);
    procedure btnDBUpdate2Click(Sender: TObject);
    procedure InDBSQLClient1ReturnResult(Sender: TObject;
      Result: TResultParams);
    procedure InDBQueryClient1ReturnResult(Sender: TObject;
      Result: TResultParams);
    procedure ClientDataSet1AfterScroll(DataSet: TDataSet);
    procedure InConnection1Error(Sender: TObject; const Msg: string);
    procedure btnStoredProcClick(Sender: TObject);
    procedure btnStoredProc2Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure Button1Click(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  FormInIOCPDbSvrClient: TFormInIOCPDbSvrClient;

implementation

uses
  MidasLib, jpeg, iocp_utils;
  
{$R *.dfm}

procedure TFormInIOCPDbSvrClient.btnStoredProcClick(Sender: TObject);
begin
  // ִ�д洢����
  // �� TInDBSQLClient.ExecStoredProc �������ص����ݼ�
  // �� TInDBQueryClient.ExecStoredProc ����ʾ���ص����ݼ�

  // �������ӣ�����˲���ʵ�ʲ���
  //  ����TdmInIOCPTest.InIOCPDataModuleExecStoredProcedure

  with InDBSQLClient1 do
  begin
    Params.AsString['param'] := '�ı�����';
    Params.AsInteger['param2'] := 999;
    ExecStoredProc('ExecuteStoredProc');
  end;

end;

procedure TFormInIOCPDbSvrClient.Button1Click(Sender: TObject);
var
  inQry: TInDBQueryClient;
begin
  inQry := TInDBQueryClient.Create(Self);
  try
    inQry.Connection := InConnection1;
    InDBConnection1.Connect(1);
    inQry.Params.SQL := 'SELECT * FROM tbl_xzqh';
    inQry.ExecQuery(ClientDataSet1);
  finally
    inQry.Free;
  end;
end;

procedure TFormInIOCPDbSvrClient.btnStoredProc2Click(Sender: TObject);
begin
  // ִ�д洢���� 2
  // �� TInDBQueryClient.ExecStoredProc ��ѯ������һ�����ݼ�
  // ��ʱ��������ֻ���ģ����ܸģ�

  // �������ӣ�����˲���ִ�� ExecuteStoredProc2��
  // ֻ���� SQL ��ѯ������أ�
  // ����TdmInIOCPTest.InIOCPDataModuleExecStoredProcedure��sql\TdmInIOCPTest.sql
  with InDBQueryClient1 do
  begin
    Params.SQLName := 'Stored_select';  // ִ����� SQL ����
    ExecStoredProc('ExecuteStoredProc2');
  end;
end;

procedure TFormInIOCPDbSvrClient.btnConnectClick(Sender: TObject);
begin
  InConnection1.ServerAddr := edtIP.Text;
  InConnection1.ServerPort := StrToInt(edtPort.Text);  
  InConnection1.Active := True;
end;

procedure TFormInIOCPDbSvrClient.btnDisconnectClick(Sender: TObject);
begin
  InConnection1.Active := False;
end;

procedure TFormInIOCPDbSvrClient.btnLoginClick(Sender: TObject);
begin
  InCertifyClient1.UserName := edtLoginUser.Text;
  InCertifyClient1.Password := 'pppp';
  InCertifyClient1.Login;
end;

procedure TFormInIOCPDbSvrClient.btnLogoutClick(Sender: TObject);
begin
  InCertifyClient1.Logout;
end;

procedure TFormInIOCPDbSvrClient.btnQueryDBConnectionsClick(Sender: TObject);
begin
  // ��ѯ��ģ��(���ݿ���������ֻ��һ����ģʱĬ��ʹ�õ�һ��)
  InDBConnection1.GetConnections;
end;

procedure TFormInIOCPDbSvrClient.btnDBQueryClick(Sender: TObject);
begin
  // ��ѯ���ݣ��������� ClientDataSet1
  //   �ͻ��˵� SQL Ҫ�ͷ���˵���ϣ�2.0 ���� SQL��SQLName ����
  with InDBQueryClient1 do
  begin
    // ִ�з��������Ϊ Select_tbl_xzqh �� SQL ����
    //   ��Ȼ����ֱ�Ӵ� SQL �������sql\TdmInIOCPTest.sql
    Params.SQLName := 'Select_tbl_xzqh';  // ���ִ�Сд������TInSQLManager.GetSQL
    ExecQuery;
  end;
end;

procedure TFormInIOCPDbSvrClient.btnDBUpdate2Click(Sender: TObject);
begin
  // ִ�� SQL ����
  // ���µ�ǰ��¼�� picture ͼƬ
  if ClientDataSet1.Active then
    with InDBSQLClient1 do
    begin
      // ֱ���� SQL ����, ����TdmInIOCPTest.InIOCPDataModuleExecSQL
      Params.SQL := 'UPDATE tbl_xzqh SET picture = :picutre WHERE code = :code';
      Params.AsStream['picture'] := TFileStream.Create('pic\test.jpg', fmOpenRead);
      Params.AsString['code'] := ClientDataSet1.FieldByName('code').AsString;
      Params.HasParams := True;  // ��������
      ExecSQL;
    end;
end;

procedure TFormInIOCPDbSvrClient.btnDBUpdateClick(Sender: TObject);
begin
  // ���±����������ԣ�InDBQueryClient1.TableName
  InDBQueryClient1.ApplyUpdates;     // ������������ʱ�����������ݱ�
end;

procedure TFormInIOCPDbSvrClient.btnSetDBConnectionClick(Sender: TObject);
begin
  // ���ӵ�ָ����ŵ����ݿ�����, ֻ��һ����ģʱ���Բ�������
  if ComboBox1.ItemIndex > -1 then
    InDBConnection1.Connect(ComboBox1.ItemIndex);
end;

procedure TFormInIOCPDbSvrClient.ClientDataSet1AfterScroll(DataSet: TDataSet);
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

procedure TFormInIOCPDbSvrClient.ComboBox1Change(Sender: TObject);
begin
  if ComboBox1.ItemIndex > -1 then
    btnSetDBConnection.Enabled := True;
end;

procedure TFormInIOCPDbSvrClient.FormCreate(Sender: TObject);
begin
  edtIP.Text := '127.0.0.1';    // GetLocalIP();   
  iocp_utils.IniDateTimeFormat; // ��������ʱ���ʽ
  MyCreateDir(InConnection1.LocalPath); // �����ļ����·��
end;

procedure TFormInIOCPDbSvrClient.InCertifyClient1Certify(Sender: TObject;
  Action: TActionType; ActResult: Boolean);
begin
  case Action of
    atUserLogin:       // ��¼
      if ActResult then
        Memo1.Lines.Add(InConnection1.UserName + '��¼�ɹ�')
      else
        Memo1.Lines.Add(InConnection1.UserName + '��¼ʧ��');
    atUserLogout:      // �ǳ�
      if ActResult then
        Memo1.Lines.Add(InConnection1.UserName + '�ǳ��ɹ�')
      else
        Memo1.Lines.Add(InConnection1.UserName + '�ǳ�ʧ��');
  end;
end;

procedure TFormInIOCPDbSvrClient.InConnection1Error(Sender: TObject; const Msg: string);
begin
  Memo1.Lines.Add(Msg);
end;

procedure TFormInIOCPDbSvrClient.InDBConnection1ReturnResult(Sender: TObject;
  Result: TResultParams);
begin
  case Result.Action of
    atDBGetConns:        // ��ѯ����
      case Result.ActResult of
        arExists: begin  // �����ݿ�����
          ComboBox1.Items.DelimitedText := Result.AsString['dmCount'];
          Memo1.Lines.Add('���������� = ' + IntToStr(ComboBox1.Items.Count));
        end;
        arMissing:      // û��
          { empty } ;
      end;
    atDBConnect:        // ��������
      case Result.ActResult of
        arOK:
          Memo1.Lines.Add('�����������ӳɹ�.');
        arFail:
          Memo1.Lines.Add('������������ʧ�ܣ�');        
      end;
  end;

end;

procedure TFormInIOCPDbSvrClient.InDBQueryClient1ReturnResult(Sender: TObject;
  Result: TResultParams);
begin
  // ��ѯ�����·��ؽ��
  case Result.Action of
    atDBExecQuery,
    atDBExecStoredProc:
      if Result.ActResult = arOK then
      begin
        ClientDataSet1AfterScroll(nil);
        Memo1.Lines.Add('��ѯ/ִ�гɹ���');
      end else
        Memo1.Lines.Add('��ѯ/ִ��ʧ��:' + Result.ErrMsg);
    atDBApplyUpdates:
      if Result.ActResult = arOK then
        Memo1.Lines.Add('Զ�̸��³ɹ�.')
      else
        Memo1.Lines.Add('Զ�̸���ʧ��:' + Result.ErrMsg);
  end;
end;

procedure TFormInIOCPDbSvrClient.InDBSQLClient1ReturnResult(Sender: TObject;
  Result: TResultParams);
begin
  // ִ�� SQL ���ؽ��
  case Result.Action of
    atDBExecSQL:
      case Result.ActResult of
        arOK:
          Memo1.Lines.Add('Զ�̸��³ɹ�.');
        arFail:
          Memo1.Lines.Add('Զ�̸���ʧ��:' + Result.ErrMsg);
      end;
    atDBExecStoredProc:
      case Result.ActResult of
        arOK:
          Memo1.Lines.Add('ִ�д洢���̳ɹ�.');
        arFail:
          Memo1.Lines.Add('ִ�д洢����ʧ��:' + Result.ErrMsg);
      end;
  end;
end;

end.
