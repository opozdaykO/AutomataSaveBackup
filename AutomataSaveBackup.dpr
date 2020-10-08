program AutomataSaveBackup;

uses
  Vcl.Forms,
  Windows,
  Vcl.Menus,
  Vcl.ExtCtrls,
  Functions in 'Functions.pas';

{$R *.res}

type
  TEventHandlers = class
    procedure OnClick(Sender: TObject);
  end;

  { TEventHandlers }

procedure TEventHandlers.OnClick(Sender: TObject);
begin
  Application.Terminate;
end;

var
  t: nierbackup;
  ti: TTrayIcon;
  p: TPopupMenu;
  item: TMenuItem;
  H: TEventHandlers;

procedure MsgPump;
var
  Unicode: Boolean;
  Msg: TMsg;

begin
  while GetMessage(Msg, 0, 0, 0) do
  begin
    Unicode := (Msg.hwnd = 0) or IsWindowUnicode(Msg.hwnd);
    TranslateMessage(Msg);
    if Unicode then
      DispatchMessageW(Msg)
    else
      DispatchMessageA(Msg);
  end;
end;

begin
  H := TEventHandlers.Create;
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Run;
  item := TMenuItem.Create(nil);
  item.Caption := 'Exit';
  item.OnClick := H.OnClick;
  p := TPopupMenu.Create(nil);
  p.Items.Add(item);
  ti := TTrayIcon.Create(nil);
  ti.Visible := True;
  ti.PopupMenu := p;
  t := nierbackup.Create(1000 * 60 * 5);
  MsgPump;

end.
