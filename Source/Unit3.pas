unit Unit3;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ExtCtrls, IniFiles, Menus, ShlObj;

type
  TSettingsForm = class(TForm)
    PathReceiveFilesLbl: TLabel;
    PathEdt: TEdit;
    Button1: TButton;
    PortLbl: TLabel;
    AllowIPLB: TListBox;
    ReceiveAllowIPsLbl: TLabel;
    PortEdt: TEdit;
    PopupMenu1: TPopupMenu;
    AddBtn: TMenuItem;
    EditBtn: TMenuItem;
    Line: TMenuItem;
    RemBtn: TMenuItem;
    OkBtn: TButton;
    CancelBtn: TButton;
    procedure CancelBtnClick(Sender: TObject);
    procedure OkBtnClick(Sender: TObject);
    procedure AllowIPLBMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure AddBtnClick(Sender: TObject);
    procedure EditBtnClick(Sender: TObject);
    procedure RemBtnClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure Button1Click(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  SettingsForm: TSettingsForm;

implementation

uses Unit1;

{$R *.dfm}

procedure TSettingsForm.CancelBtnClick(Sender: TObject);
begin
  Close;
end;

procedure TSettingsForm.OkBtnClick(Sender: TObject);
var
  Ini: TIniFile;
begin
  Ini:=TIniFile.Create(ExtractFilePath(ParamStr(0)) + 'Setup.ini');
  Ini.ReadString('Main', 'Path', PathEdt.Text);
  CurPath:=PathEdt.Text;
  Ini.WriteString('Main', 'IPsWithoutRequest', StringReplace(AllowIPLB.Items.Text, #13#10, ';', [rfReplaceAll]));
  AllowIPs.Text:=AllowIPLB.Items.Text;
  Ini.WriteInteger('Main', 'Port', StrToIntDef(PortEdt.Text, 5371));
  Ini.Free;
  Close;
end;

procedure TSettingsForm.AllowIPLBMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if Button = mbRight then
    PopupMenu1.Popup(Mouse.CursorPos.X, Mouse.CursorPos.Y);
end;

procedure TSettingsForm.AddBtnClick(Sender: TObject);
var
  IPAddress: string;
begin
  if (InputQuery(Caption, ID_ENTER_IP, IPAddress)) and (Trim(IPAddress) <> '') then
    AllowIPLB.Items.Add(IPAddress);
end;

procedure TSettingsForm.EditBtnClick(Sender: TObject);
var
  IPAddress: string;
begin
  if AllowIPLB.ItemIndex = -1 then Exit;
  AllowIPLB.Items.Strings[AllowIPLB.ItemIndex]:=InputBox(Caption, ID_ENTER_IP, AllowIPLB.Items.Strings[AllowIPLB.ItemIndex]);
end;

procedure TSettingsForm.RemBtnClick(Sender: TObject);
begin
  if AllowIPLB.ItemIndex = -1 then Exit;
  AllowIPLB.Items.Delete(AllowIPLB.ItemIndex);
end;

procedure TSettingsForm.FormShow(Sender: TObject);
begin
  AllowIPLB.Items.Text:=AllowIPs.Text;
  PathEdt.Text:=CurPath;
end;

procedure TSettingsForm.FormCreate(Sender: TObject);
begin
  SetWindowLong(PortEdt.Handle, GWL_STYLE, GetWindowLong(PortEdt.Handle, GWL_STYLE) or ES_NUMBER);
  PortEdt.Text:=IntToStr(Main.ServerSocket.Port);
  Caption:=Main.SettingsBtn.Caption;
  OkBtn.Caption:=ID_OK;
  CancelBtn.Caption:=ID_CANCEL;
  AddBtn.Caption:=ID_ADD;
  EditBtn.Caption:=ID_EDIT;
  RemBtn.Caption:=ID_REMOVE;
  PathReceiveFilesLbl.Caption:=ID_FOLDER_RECEIVING_FILES;
  PortLbl.Caption:=ID_PORT;
  ReceiveAllowIPsLbl.Caption:=ID_IPS_WITOUT_ASKING;
end;

function BrowseFolderDialog(Title: PChar): string;
var
  TitleName: string;
  lpItemid: pItemIdList;
  BrowseInfo: TBrowseInfo;
  DisplayName: array[0..MAX_PATH] of Char;
  TempPath: array[0..MAX_PATH] of Char;
begin
  FillChar(BrowseInfo, SizeOf(TBrowseInfo), #0);
  BrowseInfo.hwndOwner:=GetDesktopWindow;
  BrowseInfo.pSzDisplayName:=@DisplayName;
  TitleName:=Title;
  BrowseInfo.lpSzTitle:=PChar(TitleName);
  BrowseInfo.ulFlags:=BIF_NEWDIALOGSTYLE;
  //BrowseInfo.ulFlags:=BIF_RETURNONLYFSDIRS;
  lpItemId:=shBrowseForFolder(BrowseInfo);
  if lpItemId <> nil then begin
    shGetPathFromIdList(lpItemId, TempPath);
    Result:=TempPath;
    GlobalFreePtr(lpItemId);
  end;
end;

procedure TSettingsForm.Button1Click(Sender: TObject);
var
  TempPath: string; Ini: TIniFile;
begin
  TempPath:=BrowseFolderDialog(PChar(ID_SELECT_FOLDER));
  if TempPath = '' then Exit;
  if TempPath[Length(TempPath)] <> '\' then TempPath:=TempPath + '\';
  PathEdt.Text:=TempPath;
end;

end.
