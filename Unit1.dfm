object Form1: TForm1
  Left = 192
  Top = 124
  BorderIcons = [biSystemMenu, biMinimize]
  BorderStyle = bsSingle
  Caption = 'eFile w'
  ClientHeight = 173
  ClientWidth = 350
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  OnClose = FormClose
  OnCreate = FormCreate
  OnKeyDown = FormKeyDown
  PixelsPerInch = 96
  TextHeight = 13
  object Label1: TLabel
    Left = 88
    Top = 72
    Width = 169
    Height = 13
    Caption = #1055#1077#1088#1077#1085#1077#1089#1080#1090#1077' '#1092#1072#1081#1083#1099' '#1076#1083#1103' '#1086#1090#1087#1088#1072#1074#1082#1080
  end
  object ProgressBar1: TProgressBar
    Left = 0
    Top = 134
    Width = 350
    Height = 20
    Align = alBottom
    Smooth = True
    TabOrder = 0
    Visible = False
  end
  object StatusBar1: TStatusBar
    Left = 0
    Top = 154
    Width = 350
    Height = 19
    Panels = <>
    SimplePanel = True
    OnClick = StatusBar1Click
  end
  object ClientSocket1: TClientSocket
    Active = False
    ClientType = ctNonBlocking
    Port = 0
    OnDisconnect = ClientSocket1Disconnect
    OnRead = ClientSocket1Read
    OnError = ClientSocket1Error
    Left = 16
    Top = 16
  end
  object ServerSocket1: TServerSocket
    Active = False
    Port = 0
    ServerType = stNonBlocking
    OnClientConnect = ServerSocket1ClientConnect
    OnClientRead = ServerSocket1ClientRead
    OnClientError = ServerSocket1ClientError
    Left = 48
    Top = 16
  end
  object XPManifest1: TXPManifest
    Left = 80
    Top = 16
  end
end
