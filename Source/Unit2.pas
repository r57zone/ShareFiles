unit Unit2;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ComCtrls, StdCtrls, Menus, IniFiles;

type
  TConnectionsForm = class(TForm)
    ListView: TListView;
    SelectBtn: TButton;
    CancelBtn: TButton;
    PopupMenu1: TPopupMenu;
    AddBtn: TMenuItem;
    EditBtn: TMenuItem;
    RemBtn: TMenuItem;
    Line: TMenuItem;
    procedure ListViewMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure CancelBtnClick(Sender: TObject);
    procedure SelectBtnClick(Sender: TObject);
    procedure AddBtnClick(Sender: TObject);
    procedure EditBtnClick(Sender: TObject);
    procedure RemBtnClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure ListViewDblClick(Sender: TObject);
  private
    procedure SaveAddressBook;
    { Private declarations }
  public
    { Public declarations }
  end;

var
  ConnectionsForm: TConnectionsForm;

implementation

uses Unit1;

{$R *.dfm}

procedure TConnectionsForm.ListViewMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if Button = mbRight then
    PopupMenu1.Popup(Mouse.CursorPos.X, Mouse.CursorPos.Y);
end;

procedure TConnectionsForm.CancelBtnClick(Sender: TObject);
begin
  Close;
end;

procedure TConnectionsForm.SelectBtnClick(Sender: TObject);
begin
  if ListView.ItemIndex = -1 then Exit;
  CurAddress:=ListView.Items.Item[ListView.ItemIndex].SubItems[0];
  Close;
end;

procedure TConnectionsForm.AddBtnClick(Sender: TObject);
var
  IPAddress, PCName: string;
begin
  if (InputQuery(Caption, ID_ENTER_NAME, PCName)) and (Trim(PCName) <> '') and
     (InputQuery(Caption, ID_ENTER_IP, IPAddress)) and (Trim(IPAddress) <> '') then
  begin
    ListView.AddItem(PCName, nil);
    ListView.Items.Item[ListView.Items.Count - 1].SubItems.Add(IPAddress);
    SaveAddressBook;
  end;
end;

procedure TConnectionsForm.EditBtnClick(Sender: TObject);
var
  IPAddress, PCName: string;
begin
  if ListView.ItemIndex = -1 then Exit;
  ListView.Items.Item[ListView.ItemIndex].Caption:=InputBox(Caption, ID_ENTER_NAME, ListView.Items.Item[ListView.ItemIndex].Caption);
  ListView.Items.Item[ListView.ItemIndex].SubItems[0]:=InputBox(Caption, ID_ENTER_IP, ListView.Items.Item[ListView.ItemIndex].SubItems[0]);
  SaveAddressBook;
end;

procedure TConnectionsForm.RemBtnClick(Sender: TObject);
begin
  if ListView.ItemIndex = -1 then Exit;
  ListView.DeleteSelected;
  SaveAddressBook;
end;

procedure TConnectionsForm.FormCreate(Sender: TObject);
var
  TempAddressBook: TStringList; i: integer;
begin
  Caption:=StringReplace(Main.ConsBtn.Caption, '&', '', []);
  ListView.Columns[0].Caption:=ID_NAME;
  ListView.Columns[1].Caption:=ID_IP_ADDRESS;
  SelectBtn.Caption:=ID_SELECT;
  CancelBtn.Caption:=ID_CANCEL;
  AddBtn.Caption:=ID_ADD;
  EditBtn.Caption:=ID_EDIT;
  RemBtn.Caption:=ID_REMOVE;
  TempAddressBook:=TStringList.Create;
  TempAddressBook.Text:=StringReplace(AddressBook, ';', #13#10, [rfReplaceAll]);
  for i:=0 to TempAddressBook.Count - 1 do begin
    ListView.AddItem(Copy(TempAddressBook.Strings[i], 1, Pos('=', TempAddressBook.Strings[i]) - 1), nil);
    ListView.Items.Item[ListView.Items.Count - 1].SubItems.Add(Copy(TempAddressBook.Strings[i], Pos('=', TempAddressBook.Strings[i]) + 1, Length(TempAddressBook.Strings[i])));
  end;
  TempAddressBook.Free;
end;

procedure TConnectionsForm.SaveAddressBook;
var
  TempAddressBook: string; i: integer; Ini: TIniFile;
begin
  TempAddressBook:='';
  for i:=0 to ListView.Items.Count - 1 do
    TempAddressBook:=TempAddressBook + ListView.Items.Item[i].Caption + '=' + ListView.Items.Item[i].SubItems[0] + ';';
  AddressBook:=TempAddressBook;
  Ini:=TIniFile.Create(ExtractFilePath(ParamStr(0)) + 'Setup.ini');
  Ini.WriteString('Main', 'AddressBook', AddressBook);
  Ini.Free;
end;

procedure TConnectionsForm.ListViewDblClick(Sender: TObject);
begin
  SelectBtn.Click;
end;

end.
