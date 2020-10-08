unit Functions;

interface

uses
  System.Win.Registry, System.SysUtils, Winapi.PsAPI, Winapi.TlHelp32,
  Winapi.Windows, System.Classes, System.Zip,
  Vcl.ExtCtrls;

type
  NierBackup = class(TComponent)
  private
    function SavePath: string;
    function Run: boolean;
    function GamePath: string;
    function GetPid(ExeName: string): cardinal;
    function GetPathFromPID(const PID: cardinal): string;
    function SteamPath: string;
    function Installed: boolean;
    procedure ZipSaves;
    procedure Backup(Sender: TObject);
  public
    constructor Create(timeout: cardinal);
    destructor Destroy; override;
  end;

implementation

{ NierBackup }

const
  NierExe: string = 'NieRAutomata.exe';

var
  Backuper: TTimer;

procedure NierBackup.Backup(Sender: TObject);
begin
  if Run then
    ZipSaves;
end;

constructor NierBackup.Create(timeout: cardinal);
begin
  Backuper := TTimer.Create(self);
  Backuper.Interval := timeout;
  Backuper.OnTimer := Backup;
  if Run then
    Backup(self);
  Backuper.Enabled := true;
end;

destructor NierBackup.Destroy;
begin
  Backuper.Enabled:=false;
  Backuper.Free;
  inherited;
end;

function NierBackup.GamePath: string;
  function pars(_from, _to, _source: string): string;
  begin
    if pos(_from, _source) <> 0 then
    begin
      delete(_source, 1, pos(_from, _source) + length(_from) - 1);
      if pos(_to, _source) <> 0 then
      begin
        delete(_source, pos(_to, _source), length(_source));
        result := _source;
      end
      else
        result := '';
    end
    else
      result := '';
  end;

var
  S: TStringList;
const
  DirName: string = 'NieRAutomata';
begin
  if Installed then
    if FileExists(SteamPath + '\steamapps\common\' + DirName + '\' + NierExe)
    then
      result := SteamPath + '\steamapps\common\' + DirName + '\'
    else if FileExists(SteamPath + '\steamapps\libraryfolders.vdf') then
    begin
      S := TStringList.Create;
      S.LoadFromFile(SteamPath + '\steamapps\libraryfolders.vdf');
      if FileExists(StringReplace(pars('"1"		"', '"', S.Text), '\\', '\', []) +
        '\steamapps\common\' + DirName + '\' + NierExe) then
        result := StringReplace(pars('"1"		"', '"', S.Text), '\\', '\', []) +
          '\steamapps\common\' + DirName + '\';
      S.Free;
    end
    else
      result := ''
  else
    result := '';
end;

function NierBackup.GetPathFromPID(const PID: cardinal): string;
type
  TQueryFullProcessImageName = function(hProcess: Thandle; dwFlags: DWORD;
    lpExeName: PChar; nSize: PDWORD): BOOL; stdcall;
var
  hProcess: Thandle;
  path: array [0 .. MAX_PATH - 1] of char;
  QueryFullProcessImageName: TQueryFullProcessImageName;
  nSize: cardinal;
begin
  hProcess := OpenProcess(PROCESS_QUERY_INFORMATION or PROCESS_VM_READ,
    false, PID);
  if hProcess <> 0 then
    try
      if GetModuleFileNameEx(hProcess, 0, path, MAX_PATH) <> 0 then
      begin
        result := path;
      end
      else if Win32MajorVersion >= 6 then
      begin
        nSize := MAX_PATH;
        ZeroMemory(@path, MAX_PATH);
        @QueryFullProcessImageName :=
          GetProcAddress(GetModuleHandle('kernel32'),
          'QueryFullProcessImageNameW');
        if Assigned(QueryFullProcessImageName) then
          if QueryFullProcessImageName(hProcess, 0, path, @nSize) then
            result := path;
      end;
    finally
      CloseHandle(hProcess)
    end
  else
    RaiseLastOSError;
end;

function NierBackup.GetPid(ExeName: string): cardinal;
var
  hSnapShot: Thandle;
  ProcInfo: TProcessEntry32;
begin
  result := 0;
  hSnapShot := CreateToolHelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if (hSnapShot <> Thandle(-1)) then
  begin
    ProcInfo.dwSize := SizeOf(ProcInfo);
    if (Process32First(hSnapShot, ProcInfo)) then
    begin
      while (Process32Next(hSnapShot, ProcInfo)) do
      begin
        if ProcInfo.szExeFile = ExeName then
          result := ProcInfo.th32ProcessID;
      end;
    end;
    CloseHandle(hSnapShot);
  end;
end;

function NierBackup.Installed: boolean;
var
  reg: TRegistry;
begin
  reg := TRegistry.Create;
  reg.RootKey := HKEY_CURRENT_USER;
  if reg.KeyExists('SOFTWARE\Valve\Steam\Apps\524220') then
  begin
    reg.OpenKeyReadOnly('SOFTWARE\Valve\Steam\Apps\524220');
    if reg.ValueExists('Installed') then
      if reg.ReadInteger('Installed') = 1 then
        result := true
      else
        result := false;
  end
  else
    result := false;
  reg.Free;
end;

function NierBackup.SavePath: string;
begin
  if Installed then
    if DirectoryExists(GetEnvironmentVariable('USERPROFILE') +
      '\Documents\My Games\NieR_Automata') then
      result := GetEnvironmentVariable('USERPROFILE') +
        '\Documents\My Games\NieR_Automata'
    else
      result := ''
  else
    result := '';
end;

function NierBackup.SteamPath: string;
var
  reg: TRegistry;
begin
  reg := TRegistry.Create;
  reg.RootKey := HKEY_CURRENT_USER;
  if reg.KeyExists('SOFTWARE\Valve\Steam') then
  begin
    reg.OpenKeyReadOnly('SOFTWARE\Valve\Steam');
    if reg.ValueExists('SteamPath') then
      if DirectoryExists(reg.ReadString('SteamPath')) then
        result := reg.ReadString('SteamPath')
      else
        result := ''
    else
      result := '';
  end
  else
    result := '';
  reg.Free;
end;

procedure NierBackup.ZipSaves;
var
  Zip: TZIPFile;
  sDateTime: string;
begin
  DateTimeToString(sDateTime, 'hh.mm_dd.mm.yy', Now);
  Zip := TZIPFile.Create;
  Zip.Open(SavePath + '\backup_' + sDateTime + '.zip', zmWrite);
  if FileExists(SavePath + '\SlotData_0.dat') then
    Zip.Add(SavePath + '\SlotData_0.dat', 'SlotData_0.dat');
  if FileExists(SavePath + '\SlotData_1.dat') then
    Zip.Add(SavePath + '\SlotData_1.dat', 'SlotData_1.dat');
  if FileExists(SavePath + '\SlotData_2.dat') then
    Zip.Add(SavePath + '\SlotData_2.dat', 'SlotData_2.dat');
  Zip.Close;
  Zip.Free;
end;

function NierBackup.Run: boolean;
var
  PID: cardinal;
begin
  result := false;
  PID := GetPid(ExtractFileName(NierExe));
  if PID <> 0 then
    if GetPathFromPID(PID) = GamePath + NierExe then
      result := true;
end;

end.
