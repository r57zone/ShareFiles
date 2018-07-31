object Main: TMain
  Left = 192
  Top = 124
  BorderIcons = [biSystemMenu, biMinimize]
  BorderStyle = bsSingle
  Caption = 'eFile current'
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
  object LblInfo: TLabel
    Left = 111
    Top = 72
    Width = 130
    Height = 13
    Caption = #1055#1077#1088#1077#1085#1077#1089#1080#1090#1077' '#1092#1072#1081#1083#1099' '#1089#1102#1076#1072' '
  end
  object ProgressBar: TProgressBar
    Left = 0
    Top = 134
    Width = 350
    Height = 20
    Align = alBottom
    Smooth = True
    TabOrder = 0
    Visible = False
  end
  object StatusBar: TStatusBar
    Left = 0
    Top = 154
    Width = 350
    Height = 19
    Panels = <>
    SimplePanel = True
    OnClick = StatusBarClick
  end
  object ClientSocket: TClientSocket
    Active = False
    ClientType = ctNonBlocking
    Port = 0
    OnDisconnect = ClientSocketDisconnect
    OnRead = ClientSocketRead
    OnError = ClientSocketError
    Left = 40
    Top = 8
  end
  object ServerSocket: TServerSocket
    Active = False
    Port = 0
    ServerType = stNonBlocking
    OnClientConnect = ServerSocketClientConnect
    OnClientRead = ServerSocketClientRead
    OnClientError = ServerSocketClientError
    Left = 72
    Top = 8
  end
  object XPManifest: TXPManifest
    Left = 8
    Top = 8
  end
end
