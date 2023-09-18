object SettingsForm: TSettingsForm
  Left = 198
  Top = 359
  BorderIcons = [biSystemMenu, biMinimize]
  BorderStyle = bsSingle
  Caption = #1053#1072#1089#1090#1088#1086#1081#1082#1080
  ClientHeight = 257
  ClientWidth = 250
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  OnCreate = FormCreate
  OnShow = FormShow
  PixelsPerInch = 96
  TextHeight = 13
  object PathReceiveFilesLbl: TLabel
    Left = 8
    Top = 8
    Width = 138
    Height = 13
    Caption = #1055#1072#1087#1082#1072' '#1076#1083#1103' '#1087#1088#1080#1105#1084#1072' '#1092#1072#1081#1083#1086#1074':'
  end
  object PortLbl: TLabel
    Left = 8
    Top = 56
    Width = 28
    Height = 13
    Caption = #1055#1086#1088#1090':'
  end
  object ReceiveAllowIPsLbl: TLabel
    Left = 8
    Top = 104
    Width = 222
    Height = 13
    Caption = #1055#1088#1080#1085#1080#1084#1072#1090#1100' '#1089#1086' '#1089#1083#1077#1076#1091#1102#1097#1080#1093' IP '#1085#1077' '#1089#1087#1088#1072#1096#1080#1074#1072#1103':'
  end
  object PathEdt: TEdit
    Left = 8
    Top = 24
    Width = 206
    Height = 21
    ReadOnly = True
    TabOrder = 0
  end
  object Button1: TButton
    Left = 218
    Top = 23
    Width = 25
    Height = 23
    Caption = '...'
    TabOrder = 1
    OnClick = Button1Click
  end
  object PortEdt: TEdit
    Left = 8
    Top = 72
    Width = 57
    Height = 21
    TabOrder = 2
  end
  object AllowIPLB: TListBox
    Left = 8
    Top = 120
    Width = 234
    Height = 97
    ItemHeight = 13
    TabOrder = 3
    OnMouseDown = AllowIPLBMouseDown
  end
  object OkBtn: TButton
    Left = 7
    Top = 224
    Width = 75
    Height = 25
    Caption = #1054#1050
    TabOrder = 4
    OnClick = OkBtnClick
  end
  object CancelBtn: TButton
    Left = 87
    Top = 224
    Width = 75
    Height = 25
    Caption = #1054#1090#1084#1077#1085#1072
    TabOrder = 5
    OnClick = CancelBtnClick
  end
  object PopupMenu1: TPopupMenu
    Left = 16
    Top = 128
    object AddBtn: TMenuItem
      Caption = #1044#1086#1073#1072#1074#1080#1090#1100
      OnClick = AddBtnClick
    end
    object EditBtn: TMenuItem
      Caption = #1048#1079#1084#1077#1085#1080#1090#1100
      OnClick = EditBtnClick
    end
    object Line: TMenuItem
      Caption = '-'
    end
    object RemBtn: TMenuItem
      Caption = #1059#1076#1072#1083#1080#1090#1100
      OnClick = RemBtnClick
    end
  end
end
