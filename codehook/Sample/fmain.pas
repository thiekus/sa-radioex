{
  fmain.pas

  This file is part of the GenCodeHook.pas sample application.
  Info at http://flocke.vssd.de/prog/code/pascal/codehook/

  Copyright (C) 2005, 2006 Volker Siebert <flocke@vssd.de>
  All rights reserved.
}

unit fmain;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ComCtrls, ExtCtrls, StdCtrls;

type
  TForm1 = class(TForm)
    Shape1: TShape;
    Shape2: TShape;
    Label1: TLabel;
    Edit1: TEdit;
    Button1: TButton;
    Label2: TLabel;
    Edit2: TEdit;
    Button2: TButton;
    Bevel1: TBevel;
    Button3: TButton;
    OpenDialog1: TOpenDialog;
    SaveDialog1: TSaveDialog;
    Label3: TLabel;
    Label4: TLabel;
    Timer1: TTimer;
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure Timer1Timer(Sender: TObject);
    procedure FormHide(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button1Click(Sender: TObject);
  private
    { Private-Deklarationen }
  public
    { Public-Deklarationen }
    FShapes: array [0 .. 1] of TShape;
    FFlashPoint: array [0 .. 1] of cardinal;
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

{----------------------------------------------------------------------}

uses
  GenCodeHook, CodeMemOpt;

const
  CFlashDurance = 5;

type
  NTSTATUS = LongInt;
  TFnNtReadFile = function(FileHandle, Event: THandle; ApcRoutine: Pointer;
    ApcContext: Pointer; IoStatusBlock: Pointer; Buffer: Pointer;
    Length: ULONG; ByteOffset: Pointer; Key: Pointer): NTSTATUS; stdcall;
  TFnNtWriteFile = function(FileHandle, Event: THandle; ApcRoutine: Pointer;
    ApcContext: Pointer; IoStatusBlock: Pointer; Buffer: Pointer;
    Length: ULONG; ByteOffset: Pointer; Key: Pointer): NTSTATUS; stdcall;
  TFnNtCreateFile = function(FileHandle: Pointer; DesiredAccess: ACCESS_MASK;
    ObjectAttributes: Pointer; IoStatusBlock: Pointer;
    AllocationSize: Pointer; FileAttributes: ULONG;
    ShareAccess: ULONG; CreateDisposition: ULONG; CreateOptions: ULONG;
    EaBuffer: Pointer; EaLength: ULONG): NTSTATUS; stdcall;

  TFnReadFile = function(hFile: THandle; var Buffer; nNumberOfBytesToRead: DWORD;
    var lpNumberOfBytesRead: DWORD; lpOverlapped: POverlapped): BOOL; stdcall;
  TFnWriteFile = function(hFile: THandle; const Buffer; nNumberOfBytesToWrite: DWORD;
    var lpNumberOfBytesWritten: DWORD; lpOverlapped: POverlapped): BOOL; stdcall;

var
  OldNtReadFile: TFnNtReadFile;
  OldNtWriteFile: TFnNtWriteFile;
  OldNtCreateFile: TFnNtCreateFile;
  OldReadFile: TFnReadFile;
  OldWriteFile: TFnWriteFile;

const
  CSlotColor: array [0 .. 1] of TColor = ( clGreen, clRed );

procedure DoBefore(Slot: integer);
begin
  if GetCurrentThreadID = MainThreadID then
  begin
    Form1.FFlashPoint[Slot] := GetTickCount + CFlashDurance;

    if Form1.FShapes[Slot].Brush.Color <> CSlotColor[Slot] then
    begin
      Form1.FShapes[Slot].Brush.Color := CSlotColor[Slot];
      Form1.FShapes[Slot].Repaint;
    end;
  end;
end;

procedure DoAfter(Slot: integer);
begin
  if GetCurrentThreadID = MainThreadID then
    Application.ProcessMessages;
end;

function NewNtReadFile(FileHandle, Event: THandle; ApcRoutine: Pointer;
  ApcContext: Pointer; IoStatusBlock: Pointer; Buffer: Pointer;
  Length: ULONG; ByteOffset: Pointer; Key: Pointer): NTSTATUS; stdcall;
begin
  DoBefore(0);
  Result := OldNtReadFile(FileHandle, Event, ApcRoutine, ApcContext,
              IoStatusBlock, Buffer, Length, ByteOffset, Key);
  DoAfter(0);
end;

function NewNtWriteFile(FileHandle, Event: THandle; ApcRoutine: Pointer;
  ApcContext: Pointer; IoStatusBlock: Pointer; Buffer: Pointer;
  Length: ULONG; ByteOffset: Pointer; Key: Pointer): NTSTATUS; stdcall;
begin
  DoBefore(1);
  Result := OldNtWriteFile(FileHandle, Event, ApcRoutine, ApcContext,
              IoStatusBlock, Buffer, Length, ByteOffset, Key);
  DoAfter(1);
end;

function NewNtCreateFile(FileHandle: Pointer; DesiredAccess: ACCESS_MASK;
  ObjectAttributes: Pointer; IoStatusBlock: Pointer;
  AllocationSize: Pointer; FileAttributes: ULONG;
  ShareAccess: ULONG; CreateDisposition: ULONG; CreateOptions: ULONG;
  EaBuffer: Pointer; EaLength: ULONG): NTSTATUS; stdcall;
const
  FILE_WRITE_DATA  = $0002;
  FILE_APPEND_DATA = $0004;
var
  Slot: integer;
begin
  if (DesiredAccess and (FILE_WRITE_DATA or FILE_APPEND_DATA)) <> 0 then
    Slot := 1
  else
    Slot := 0;

  DoBefore(Slot);
  Result := OldNtCreateFile(FileHandle, DesiredAccess, ObjectAttributes,
              IoStatusBlock, AllocationSize, FileAttributes, ShareAccess,
              CreateDisposition, CreateOptions, EaBuffer, EaLength);
  DoAfter(Slot);
end;

function NewReadFile(hFile: THandle; var Buffer; nNumberOfBytesToRead: DWORD;
  var lpNumberOfBytesRead: DWORD; lpOverlapped: POverlapped): BOOL; stdcall;
begin
  DoBefore(0);
  Result := OldReadFile(hFile, Buffer, nNumberOfBytesToRead, lpNumberOfBytesRead,
              lpOverlapped);
  DoAfter(0);
end;

function NewWriteFile(hFile: THandle; const Buffer; nNumberOfBytesToWrite: DWORD;
  var lpNumberOfBytesWritten: DWORD; lpOverlapped: POverlapped): BOOL; stdcall;
begin
  DoBefore(1);
  Result := OldWriteFile(hFile, Buffer, nNumberOfBytesToWrite,
              lpNumberOfBytesWritten, lpOverlapped);
  DoAfter(1);
end;

procedure UninstallPatch;
begin
  RemoveGenericCodeHook(@OldNtReadFile);
  RemoveGenericCodeHook(@OldNtWriteFile);
  RemoveGenericCodeHook(@OldNtCreateFile);
  RemoveGenericCodeHook(@OldReadFile);
  RemoveGenericCodeHook(@OldWriteFile);
end;

function InstallPatch: boolean;
var
  Module: HMODULE;
  ok: boolean;

  function GPA(Name: PChar): Pointer;
  begin
    Result := GetProcAddress(Module, Name);
  end;

begin
  Module := GetModuleHandle('ntdll.dll');
  if Module <> 0 then
  begin
    ok := CreateGenericCodeHook(GPA('NtReadFile'),   @NewNtReadFile,   @OldNtReadFile) and
          CreateGenericCodeHook(GPA('NtWriteFile'),  @NewNtWriteFile,  @OldNtWriteFile) and
          CreateGenericCodeHook(GPA('NtCreateFile'), @NewNtCreateFile, @OldNtCreateFile);
  end
  else
  begin
    Module := GetModuleHandle('kernel32.dll');
    ok := CreateGenericCodeHook(GPA('ReadFile'),  @NewReadFile,  @OldReadFile) and
          CreateGenericCodeHook(GPA('WriteFile'), @NewWriteFile, @OldWriteFile);
  end;

  if not ok then
  begin
    UninstallPatch;
    MessageDlg('CreateGenericCodeHook did not work!', mtError, [mbOk], 0);
  end;

  Result := ok;
end;

{----------------------------------------------------------------------}

procedure TForm1.FormShow(Sender: TObject);
begin
  FShapes[0] := Shape1;
  FShapes[1] := Shape2;

  FFlashPoint[0] := 0;
  FFlashPoint[1] := 0;

  if not InstallPatch then
    Close;
end;

procedure TForm1.FormHide(Sender: TObject);
begin
  UninstallPatch;
end;

procedure TForm1.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  UninstallPatch;
end;

procedure TForm1.Button1Click(Sender: TObject);
begin
  OpenDialog1.FileName := Edit1.Text;
  if OpenDialog1.Execute then
    Edit1.Text := OpenDialog1.FileName;
end;

procedure TForm1.Button2Click(Sender: TObject);
begin
  SaveDialog1.FileName := Edit2.Text;
  if SaveDialog1.Execute then
    Edit2.Text := SaveDialog1.FileName;
end;

procedure TForm1.Button3Click(Sender: TObject);
begin
  CopyFile(PChar(Edit1.Text), PChar(Edit2.Text), false);
  MessageBeep(MB_ICONINFORMATION);
end;

procedure TForm1.Timer1Timer(Sender: TObject);
var
  k: cardinal;
begin
  k := GetTickCount;

  if (FFlashPoint[0] <> 0) and (k > FFlashPoint[0]) then
  begin
    FFlashPoint[0] := 0;
    Shape1.Brush.Color := clWhite;
    Shape1.Repaint;
  end;

  if (FFlashPoint[1] <> 0) and (k > FFlashPoint[1]) then
  begin
    FFlashPoint[1] := 0;
    Shape2.Brush.Color := clWhite;
    Shape2.Repaint;
  end;
end;

end.
