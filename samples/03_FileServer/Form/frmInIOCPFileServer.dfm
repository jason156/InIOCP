object FormInIOCPFileServer: TFormInIOCPFileServer
  Left = 0
  Top = 0
  Caption = 'InIOCP '#25991#20214#26381#21153
  ClientHeight = 399
  ClientWidth = 679
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Position = poDesktopCenter
  Scaled = False
  OnCreate = FormCreate
  PixelsPerInch = 120
  TextHeight = 14
  object Label1: TLabel
    Left = 572
    Top = 218
    Width = 98
    Height = 34
    Caption = '2.0'#29256#26242#26410#23454#29616#25991#20214#25512#36865#21151#33021#12290
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clBlue
    Font.Height = -14
    Font.Name = 'Tahoma'
    Font.Style = []
    ParentFont = False
    WordWrap = True
  end
  object Memo1: TMemo
    Left = 8
    Top = 215
    Width = 545
    Height = 170
    ImeName = #35895#27468#25340#38899#36755#20837#27861' 2'
    Lines.Strings = (
      '1'#12289#24341#29992' InIOCP '#30340#32479#35745#21333#20803' frame\fmIOCPSvrInfo'
      '2'#12289#21152#20837#32479#35745#21333#20803#26694#26550' FrameIOCPSvrInfo1'
      ''
      '3'#12289#21152#20837#26381#21153#31471#32452#20214' InIOCPServer1'#65292#35774#32622'IP/Port'#65306'127.0.0.1/12302'
      '4'#12289#21152#20837#12289#35774#32622#29992#25143#31649#29702#32452#20214#65306'InClientManager1'
      '5'#12289#21152#20837#12289#35774#32622#25991#20214#31649#29702#32452#20214' InFileManager1'
      ''
      '6'#12289#35774#32622#25628#32034#36335#24452#65292#36816#34892#65292#21551#21160#26381#21153
      ''
      #36816#34892#23458#25143#31471#31243#24207#65292#27979#35797#25991#20214#19978#20256#12289#19979#36733#65292#30456#20114#20256#36755#12290)
    ScrollBars = ssBoth
    TabOrder = 0
    WordWrap = False
  end
  object btnStart: TButton
    Left = 580
    Top = 63
    Width = 75
    Height = 25
    Caption = #21551#21160
    TabOrder = 1
    OnClick = btnStartClick
  end
  object btnStop: TButton
    Left = 580
    Top = 107
    Width = 75
    Height = 25
    Caption = #20572#27490
    Enabled = False
    TabOrder = 2
    OnClick = btnStopClick
  end
  inline FrameIOCPSvrInfo1: TFrameIOCPSvrInfo
    Left = 8
    Top = 8
    Width = 547
    Height = 201
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -15
    Font.Name = #23435#20307
    Font.Style = []
    ParentFont = False
    TabOrder = 3
    ExplicitLeft = 8
    ExplicitTop = 8
    ExplicitWidth = 547
  end
  object InIOCPServer1: TInIOCPServer
    IOCPManagers.ClientManager = InClientManager1
    IOCPManagers.FileManager = InFileManager1
    ServerAddr = '127.0.0.1'
    StartParams.TimeOut = 0
    ThreadOptions.BusinessThreadCount = 8
    ThreadOptions.PushThreadCount = 4
    ThreadOptions.WorkThreadCount = 4
    AfterOpen = InIOCPServer1AfterOpen
    AfterClose = InIOCPServer1AfterClose
    Left = 256
    Top = 232
  end
  object InClientManager1: TInClientManager
    OnLogin = InClientManager1Login
    Left = 296
    Top = 232
  end
  object InFileManager1: TInFileManager
    AfterDownload = InFileManager1AfterDownload
    AfterUpload = InFileManager1AfterUpload
    BeforeUpload = InFileManager1BeforeUpload
    BeforeDownload = InFileManager1BeforeDownload
    OnDeleteFile = InFileManager1DeleteFile
    OnQueryFiles = InFileManager1QueryFiles
    OnRenameFile = InFileManager1RenameFile
    OnSetWorkDir = InFileManager1SetWorkDir
    Left = 392
    Top = 232
  end
  object InMessageManager1: TInMessageManager
    Left = 344
    Top = 232
  end
end
