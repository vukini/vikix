{ clicker.lpr — a window with a button, made with the LCL (Lazarus's
  component library), all in code.

  Lazarus usually draws forms in its designer and keeps them in .lfm
  files; building one by hand shows what the designer writes for you:
  create a component, set its properties, give it a parent, and hang a
  method on its OnClick event. }
program clicker;

{$mode objfpc}{$H+}

uses
  Interfaces,   { picks the widget set (Qt5 on Vikix); must come first }
  Classes, SysUtils, Forms, StdCtrls, Controls;

type
  { An event handler has to be a method of an object, so the window's
    parts and the handler live together in one class. }
  TClicker = class(TForm)
  private
    Clicks: Integer;
    Button: TButton;
    Counter: TLabel;
    procedure ButtonClick(Sender: TObject);
  public
    constructor CreateNew(AOwner: TComponent; Num: Integer = 0); override;
  end;

constructor TClicker.CreateNew(AOwner: TComponent; Num: Integer);
begin
  inherited CreateNew(AOwner, Num);
  Caption := 'Clicker';
  Width := 260;
  Height := 120;
  Position := poScreenCenter;

  Counter := TLabel.Create(Self);
  Counter.Parent := Self;          { a control shows inside its parent }
  Counter.Caption := 'No clicks yet';
  Counter.Left := 20;
  Counter.Top := 20;

  Button := TButton.Create(Self);
  Button.Parent := Self;
  Button.Caption := 'Click me';
  Button.Left := 20;
  Button.Top := 60;
  Button.Width := 100;
  Button.OnClick := @ButtonClick;  { @ passes the method itself }
end;

procedure TClicker.ButtonClick(Sender: TObject);
begin
  Inc(Clicks);
  if Clicks = 1 then
    Counter.Caption := '1 click'
  else
    Counter.Caption := IntToStr(Clicks) + ' clicks';
end;

var
  Window: TClicker;
begin
  Application.Initialize;
  Window := TClicker.CreateNew(Application);
  Window.Show;
  Application.Run;
end.
