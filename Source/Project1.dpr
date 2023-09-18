program Project1;

uses
  Forms,
  Unit1 in 'Unit1.pas' {Main},
  Unit2 in 'Unit2.pas' {ConnectionsForm},
  Unit3 in 'Unit3.pas' {SettingsForm};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TMain, Main);
  Application.CreateForm(TConnectionsForm, ConnectionsForm);
  Application.CreateForm(TSettingsForm, SettingsForm);
  Application.Run;
end.
