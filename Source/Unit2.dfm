object ConnectionsForm: TConnectionsForm
  Left = 500
  Top = 122
  BorderIcons = [biSystemMenu, biMinimize]
  BorderStyle = bsSingle
  Caption = #1055#1086#1076#1082#1083#1102#1095#1077#1085#1080#1103
  ClientHeight = 210
  ClientWidth = 248
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  Position = poScreenCenter
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 13
  object ListView: TListView
    Left = 8
    Top = 40
    Width = 233
    Height = 129
    Columns = <
      item
        AutoSize = True
        Caption = #1053#1072#1079#1074#1072#1085#1080#1077
      end
      item
        AutoSize = True
        Caption = 'IP '#1072#1076#1088#1077#1089
      end>
    ReadOnly = True
    RowSelect = True
    TabOrder = 0
    ViewStyle = vsReport
    OnDblClick = ListViewDblClick
    OnMouseDown = ListViewMouseDown
  end
  object SelectBtn: TButton
    Left = 7
    Top = 176
    Width = 75
    Height = 25
    Caption = #1042#1099#1073#1088#1072#1090#1100
    TabOrder = 1
    OnClick = SelectBtnClick
  end
  object CancelBtn: TButton
    Left = 87
    Top = 176
    Width = 75
    Height = 25
    Caption = #1054#1090#1084#1077#1085#1072
    TabOrder = 2
    OnClick = CancelBtnClick
  end
  object AddBtn: TButton
    Left = 7
    Top = 8
    Width = 75
    Height = 25
    Caption = #1044#1086#1073#1072#1074#1080#1090#1100
    TabOrder = 3
    OnClick = AddBtnClick
  end
  object EditBtn: TButton
    Left = 87
    Top = 8
    Width = 75
    Height = 25
    Caption = #1048#1079#1084#1077#1085#1080#1090#1100
    TabOrder = 4
    OnClick = EditBtnClick
  end
  object RemBtn: TButton
    Left = 167
    Top = 8
    Width = 75
    Height = 25
    Caption = #1059#1076#1072#1083#1080#1090#1100
    TabOrder = 5
    OnClick = RemBtnClick
  end
  object PopupMenu: TPopupMenu
    Left = 16
    Top = 64
    object Add2Btn: TMenuItem
      Caption = #1044#1086#1073#1072#1074#1080#1090#1100
      OnClick = Add2BtnClick
    end
    object Edit2Btn: TMenuItem
      Caption = #1048#1079#1084#1077#1085#1080#1090#1100
      OnClick = Edit2BtnClick
    end
    object Line: TMenuItem
      Caption = '-'
    end
    object Rem2Btn: TMenuItem
      Caption = #1059#1076#1072#1083#1080#1090#1100
      OnClick = Rem2BtnClick
    end
  end
end
