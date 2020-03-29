library RadioEx;

(*==============================================================================

  San Andreas RadioEx - Custom internet radio for GTA San Andreas
  by Faris Khowarizmi
  e-Mail: thekill96[at]gmail.com
  Website: http://www.khayalan.web.id

  Copyright © Faris Khowarizmi 2014
  Project Homepage at: https://code.google.com/p/sa-radioex/

  This file is part of San Andreas RadioEx.

  San Andreas RadioEx is free software; you can redistribute it and/or modify
  it under the terms of the GNU Lesser General Public License as
  published by the Free Software Foundation; either version 2.1,
  or (at your option) any later version.

  San Andreas RadioEx is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
  GNU Lesser General Public License for more details.

  You should have received a copy of the GNU Lesser General Public License
  along with San Andreas RadioEx see the file COPYING.  If not, write to
  the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
  Boston, MA  02110-1301, USA.
  http://www.gnu.org/copyleft/lgpl.html

  RadioEx is use any third parties

  GenCodeHook.pas (http://flocke.vssd.de/prog/code/pascal/codehook/)
  Copyright (C) 2005, 2006 Volker Siebert <flocke@vssd.de>

  BASS 2.4 audio library (http://www.un4seen.com)
  Copyright (c) 1999-2013 Un4seen Developments Ltd.

==============================================================================*)

uses
  Windows,
  SysUtils,
  IniFiles,
  GenCodeHook,
  CodeMemOpt,
  bass,
  WinInet;

{$E asi}
{$R *.res}
{$R Res\Resc.res}

type
  TResStream = packed record
    Handle: HRSRC;
    Location: Pointer;
    Size: LongInt;
  end;

  TRadioStation = packed record
    Enable: ByteBool;
    Nulled: ByteBool;
    Name: AnsiString;
    Location: AnsiString;
    TempFile: AnsiString;
    Handle: THandle;
  end;

const
  RadioIndexp = $008CB7E1;
  StopStatus1 = $00BA68A5;
  StopStatus2 = $00B6F5F0;
  VolumePtrlc = $00B5FCC8;
  Stop2Ptrloc = $530;
  LoadTextJmp = $004E9E30;

  FakeFileSize = $A00000; // 10MB
  StreamPath = 'AUDIO\STREAMS\';

  DummyBlock: array[0..15] of byte = ($15, $C5, $3B, $5E, $9A, $A8, $14, $F3,
                                      $B7, $4F, $28, $DC, $9D, $E8, $FF, $F1);

  // Hook are radio count + 2 files that are adverts and AA (police car radio)
  HookStreamName: array[0..11] of AnsiString = (
    StreamPath + 'CH', // Playback FM
    StreamPath + 'CO', // K Rose
    StreamPath + 'CR', // K-DST
    StreamPath + 'DS', // Bounce FM
    StreamPath + 'HC', // SF-UR
    StreamPath + 'MH', // Radio Los Santos
    StreamPath + 'MR', // Radio X
    StreamPath + 'NJ', // CSR 103.9
    StreamPath + 'RE', // K-JAH West
    StreamPath + 'RG', // Master Sounds 98.3
    StreamPath + 'TK', // WCTR
    // v1.1.0 emulates ADVERTS
    StreamPath + 'ADVERTS' // Advertisement
  );

  RadioCount  = 10; // n-1
  FileHkCnt   = RadioCount + 1;  // Count of radio + 1 advertisement stream

resourcestring
  WndCap   = 'GTA: San Andreas';
  WndClass = 'Grand theft auto San Andreas';

  err_bassinc = 'An incorrect version of BASS.DLL was loaded';
  err_initsnd = 'Can''t initialize device';

  ini_Options = 'Options';
  ini_Plugins = 'Plugins';
  ini_RadChnl = 'RadioChannels';

var
  Radio: array[0..11] of TRadioStation;
  RadioNStr: array[0..255] of AnsiChar;
  Vol: ^Float = nil;
  LastChlIndex: integer = -1;
  ChlPlay: integer = -1;
  Chl: HSTREAM = 0;
  LoadChl: HSTREAM = 0;
  ChlThread: DWORD = 0;
  ChlTrId: DWORD = 0;
  GTAWnd: HWND = 0;
  ExitStatus: boolean;
  PoolThread: DWORD = 0;
  PoolTrId: DWORD = 0;
  RadioStop: boolean = TRUE;
  OriginTxtPrc: LongInt = 0;
  TxPatch: boolean = FALSE;
  OriginCallPoint: procedure = nil;
  EnableBassInit: boolean;
  BassInited: boolean = FALSE;
  MainThreadCs: TRtlCriticalSection;
  AbortChg: boolean = FALSE;

  LoadingRs: TResStream;
  NoRadioRs: TResStream;
  NoIConnRs: TResStream;

  AACPlugin: HPLUGIN = 0;
  OPSPlugin: HPLUGIN = 0;

  origin_CreateFileA: function(lpFileName: PAnsiChar; dwDesiredAccess, dwShareMode: DWORD;
                                lpSecurityAttributes: PSecurityAttributes; dwCreationDisposition, dwFlagsAndAttributes: DWORD;
                                hTemplateFile: THandle): THandle; stdcall;

  origin_CloseHandle: function(hObject: THandle): BOOL; stdcall;

  origin_GetFileSize: function(hFile: THandle; lpFileSizeHigh: Pointer): DWORD; stdcall;

  origin_ReadFile: function(hFile: THandle; var Buffer; nNumberOfBytesToRead: DWORD;
                            var lpNumberOfBytesRead: DWORD; lpOverlapped: POverlapped): BOOL; stdcall;

  origin_SetFilePointer: function(hFile: THandle; lDistanceToMove: Longint;
                                  lpDistanceToMoveHigh: Pointer; dwMoveMethod: DWORD): DWORD; stdcall;

  origin_gta_LoadString: function(arg: Cardinal): PAnsiChar; cdecl;

//==============================================================================

function GetGTAWindow: HWND;
begin
  Result:= FindWindow(PChar(WndClass), PChar(WndCap));
end;

//==============================================================================

function LoadRescData(Name: string): TResStream;
begin
  Result.Handle:= FindResource(HInstance, PChar(Name), RT_RCDATA);
  Result.Location:= LockResource(LoadResource(HInstance, Result.Handle));
  Result.Size:= SizeOfResource(HInstance, Result.Handle);
end;

//==============================================================================

function MakeTempFile: AnsiString;
var
  bufp, bufr: array[0..255] of AnsiChar;
begin
  GetTempPathA(SizeOf(bufp), @bufp);
  GetTempFileNameA(@bufp, PChar('RDX_'), 0, @bufr);
  Result:= bufr;
end;

//==============================================================================

function IsConnected: Boolean;
var
  ConnectTypes: integer;
begin

  try
    ConnectTypes:= INTERNET_CONNECTION_MODEM + INTERNET_CONNECTION_LAN + INTERNET_CONNECTION_PROXY;
    Result:= InternetGetConnectedState(@ConnectTypes, 0);
  except
    Result:= FALSE;
  end;

end;

//==============================================================================

function BukaChannel(Index: Integer): DWORD;
// Opening stream based bass delphi sample code
var
  Len, Progress: DWORD;
begin

  try

    BASS_StreamFree(Chl);
    LoadChl:= BASS_StreamCreateFile(TRUE, LoadingRs.Location, 0, LoadingRs.Size, BASS_SAMPLE_LOOP or BASS_STREAM_AUTOFREE);
    BASS_ChannelPlay(LoadChl, FALSE);
    BASS_ChannelSetAttribute(LoadChl, BASS_ATTRIB_VOL, Vol^);

    try

      Chl:= BASS_StreamCreateURL(PAnsiChar(Radio[Index].Location), 0, BASS_STREAM_BLOCK or BASS_STREAM_AUTOFREE, nil, nil);
      if (Chl <> 0) then
        begin
        Progress:= 0;
        repeat
          Len:= BASS_StreamGetFilePosition(Chl, BASS_FILEPOS_END);
          if (Len = DW_Error) then
            Break;
          Progress:= BASS_StreamGetFilePosition(Chl, BASS_FILEPOS_BUFFER) * 100 div Len;
        until (Progress > 75) or (BASS_StreamGetFilePosition(Chl, BASS_FILEPOS_CONNECTED) = 0) or (AbortChg); // over 75% full (or end of download)
      end
      else
        Chl:= BASS_StreamCreateFile(TRUE, NoRadioRs.Location, 0, NoRadioRs.Size, BASS_STREAM_AUTOFREE);

    finally
      BASS_StreamFree(LoadChl);
    end;

    if (not AbortChg) then
      begin
      BASS_ChannelPlay(Chl, FALSE);
      BASS_ChannelSetAttribute(Chl, BASS_ATTRIB_VOL, Vol^);
      RadioStop:= FALSE;
    end;

  finally
    ChlThread:= 0;
    Result:= 0;
  end;

end;

//==============================================================================

procedure GantiChannel(ChlIndex: integer);
begin
  LastChlIndex:= ChlIndex;
  if IsConnected then
    begin
    if (ChlThread <> 0) then
      begin
      AbortChg:= TRUE;
      WaitForSingleObject(ChlThread, INFINITE);
    end;
    AbortChg:= FALSE;
    ChlThread:= BeginThread(nil, 0, @BukaChannel, Pointer(ChlIndex), 0, ChlTrId);
  end
  else
    begin // Not connected? Tell him!
    BASS_StreamFree(Chl);
    Chl:= BASS_StreamCreateFile(TRUE, NoIConnRs.Location, 0, NoIConnRs.Size, BASS_STREAM_AUTOFREE);
    BASS_ChannelPlay(Chl, FALSE);
    RadioStop:= FALSE;
  end;
end;

//==============================================================================

procedure StopRadio;
begin
  if (ChlThread <> 0) then
    WaitForSingleObject(ChlThread, INFINITE);
  BASS_ChannelStop(Chl);
  BASS_StreamFree(Chl);
  RadioStop:= TRUE;
  LastChlIndex:= -1;
end;

//==============================================================================

function PoolProc(ExtStatus: boolean): DWORD;
var
  StopLoc2: PCardinal;
  RadioIndex: PByte;
  StopByte1: PByte;
  StopByte2: Byte;
  ChlIdx: integer;
begin

  try

    RadioIndex:= Pointer(RadioIndexp);
    StopByte1:= Pointer(StopStatus1);
    StopLoc2:= Pointer(StopStatus2);
    Vol:= Pointer(VolumePtrlc);
    while (not ExitStatus) do
      begin

      if (RadioIndex^ > 0) and (RadioIndex^ < 12) then
        ChlIdx:= RadioIndex^-1
      else
        ChlIdx:= -1;
      if not IsWindow(GTAWnd) then
        begin
        GTAWnd:= GetGTAWindow;
        if IsWindow(GTAWnd) then
          begin
          // Inisialisasi Bass
          EnterCriticalSection(MainThreadCs);
          try
            if EnableBassInit then
              if BASS_Init(-1, 44100, 0, GTAWnd, nil) then
                BassInited:= TRUE
              else
                if (BASS_ErrorGetCode() <> BASS_ERROR_ALREADY) then
                  begin
                  ShowWindow(GTAWnd, SW_HIDE);
                  MessageBox(GTAWnd, PChar(err_initsnd), nil, MB_ICONERROR);
                  ShowWindow(GTAWnd, SW_SHOW);
                end;
          finally
            LeaveCriticalSection(MainThreadCs);
          end;
        end;
      end;
      if (Chl <> 0) then
        if (GetForegroundWindow() = GTAWnd) then
          begin
          BASS_ChannelSetAttribute(Chl, BASS_ATTRIB_VOL, Vol^);
          if (LoadChl <> 0) then
            BASS_ChannelSetAttribute(LoadChl, BASS_ATTRIB_VOL, Vol^);
        end
        else
          begin // Window lost focus, mute it!
          BASS_ChannelSetAttribute(Chl, BASS_ATTRIB_VOL, 0);
          if (LoadChl <> 0) then
            BASS_ChannelSetAttribute(LoadChl, BASS_ATTRIB_VOL, 0);
        end;
      if (StopLoc2^ <> 0) then // Get Stop properties from reference 2
        StopByte2:= PByte(StopLoc2^ + Cardinal(Stop2Ptrloc))^
      else
        StopByte2:= 0;
      if ((StopByte1^ <> 3) and (StopByte2 = 0)) or (StopByte2 = 1) or (ChlIdx < 0) then
        // Is radio usable?
        begin
        if (not RadioStop) then
          StopRadio;
      end
      else
      if (ChlIdx > -1) and (LastChlIndex <> ChlIdx) then
        if (Radio[ChlIdx].Enable) then // That radio is hooked?
          GantiChannel(ChlIdx)
        else
          StopRadio; // Meant you want to use default radio...

      // Delay for 1/100 second
      Sleep(10);

    end;

  finally
    PoolThread:= 0;
    Result:= 0;
  end;

end;

//==============================================================================

function hook_CreateFileA(lpFileName: PAnsiChar; dwDesiredAccess, dwShareMode: DWORD;
                          lpSecurityAttributes: PSecurityAttributes; dwCreationDisposition, dwFlagsAndAttributes: DWORD;
                          hTemplateFile: THandle): THandle; stdcall;
var
  x: integer;
  idx: integer;
  RdHnd: THandle;
begin

  idx:= -1;
  for x:= 0 to FileHkCnt do
    if (Radio[x].Enable) and (lpFileName = HookStreamName[x]) then // Radio file?
      begin
      idx:= x;
      Break;
    end;

  if (idx < 0) then // Default CreateFile behaviour
    Result:= origin_CreateFileA(lpFileName, dwDesiredAccess, dwShareMode, lpSecurityAttributes, dwCreationDisposition, dwFlagsAndAttributes, hTemplateFile)
  else
    begin
    if (Radio[idx].Handle = INVALID_HANDLE_VALUE) then
      begin
      RdHnd:= origin_CreateFileA(PChar(Radio[idx].TempFile), GENERIC_READ, 0, nil, CREATE_ALWAYS, FILE_ATTRIBUTE_TEMPORARY + FILE_FLAG_DELETE_ON_CLOSE, 0);
      Radio[idx].Handle:= RdHnd;
      Result:= RdHnd;
    end
    else
      Result:= Radio[idx].Handle; // We don't create handle more than once
  end;

end;

//==============================================================================

function hook_CloseHandle(hObject: THandle): BOOL; stdcall;
var
  x: integer;
  handled: boolean;
begin

  Result:= FALSE;
  handled:= FALSE;
  for x:= 0 to FileHkCnt do
    if (Radio[x].Enable) and (Radio[x].Handle <> INVALID_HANDLE_VALUE) and (hObject = Radio[x].Handle) then
      begin
      Result:= TRUE;
      handled:= TRUE;
      SetLastError(ERROR_SUCCESS);
      Break;
    end;

  if (not handled) then
    Result:= origin_CloseHandle(hObject);

end;

//==============================================================================

function hook_GetFileSize(hFile: THandle; lpFileSizeHigh: Pointer): DWORD; stdcall;
var
  x: integer;
  handled: boolean;
begin

  Result:= 0;
  handled:= FALSE;
  for x:= 0 to FileHkCnt do
    if (Radio[x].Enable) and (Radio[x].Handle <> INVALID_HANDLE_VALUE) and (hFile = Radio[x].Handle) then
      begin
      Result:= FakeFileSize; // Tell is right file with size
      handled:= TRUE;
      SetLastError(ERROR_SUCCESS);
      Break;
    end;

  if (not handled) then
    Result:= origin_GetFileSize(hFile, lpFileSizeHigh);

end;

//==============================================================================

function hook_ReadFile(hFile: THandle; var Buffer; nNumberOfBytesToRead: DWORD;
  var lpNumberOfBytesRead: DWORD; lpOverlapped: POverlapped): BOOL; stdcall;
var
  x: integer;
  handled: boolean;
  bfill: LongInt;
  bfpos: Pointer;
  aligs: LongInt;
begin

  Result:= FALSE;
  handled:= FALSE;
  for x:= 0 to FileHkCnt do
    if (Radio[x].Enable) and (Radio[x].Handle <> INVALID_HANDLE_VALUE) and (hFile = Radio[x].Handle) then
      begin
      bfill:= nNumberOfBytesToRead;
      bfpos:= @Buffer;
      aligs:= 16;
      repeat // fill with dummy file
        if (bfill < 16) then
          aligs:= bfill;
        CopyMemory(bfpos, @DummyBlock, aligs);
        bfpos:= Pointer(LongInt(bfpos) + aligs);
        Dec(bfill, aligs);
      until bfill = 0;
      lpNumberOfBytesRead:= nNumberOfBytesToRead;
      Result:= TRUE;
      handled:= TRUE;
      SetLastError(ERROR_SUCCESS);
      Break;
    end;

  if (not handled) then
    Result:= origin_ReadFile(hFile, Buffer, nNumberOfBytesToRead, lpNumberOfBytesRead, lpOverlapped);

end;

//==============================================================================

function hook_SetFilePointer(hFile: THandle; lDistanceToMove: Longint;
  lpDistanceToMoveHigh: Pointer; dwMoveMethod: DWORD): DWORD; stdcall;
var
  x: integer;
  handled: boolean;
begin

  Result:= 0;
  handled:= FALSE;
  for x:= 0 to FileHkCnt do
    if (Radio[x].Enable) and (Radio[x].Handle <> INVALID_HANDLE_VALUE) and (hFile = Radio[x].Handle) then
      begin
      Result:= lDistanceToMove;
      handled:= TRUE;
      SetLastError(ERROR_SUCCESS);
      Break;
    end;

  if (not handled) then
    Result:= origin_SetFilePointer(hFile, lDistanceToMove, lpDistanceToMoveHigh, dwMoveMethod);

end;

//==============================================================================

procedure hook_gta_LoadString; assembler;
// text hook must be assembly hardcoded
// IMPORTANT: don't declare any variables here, because variable initialization
// makes you into trouble!

  function GetRadioName(Index: Byte): PAnsiChar; register;
  begin
    ZeroMemory(@RadioNStr, 255);
    CopyMemory(@RadioNStr, @Radio[Index].Name[1], Length(Radio[Index].Name));
    Result:= @RadioNStr;
  end;

asm

  call origin_gta_LoadString
  push eax
  xor eax, eax
  mov al, BYTE PTR[RadioIndexp]
  sub eax, 1
  cmp eax, 0
  jl @@nohook
  cmp eax, RadioCount+1
  jl @@hook_rdname

@@nohook:
  pop eax
  jmp OriginCallPoint

// To remind: result are stored on eax register,
// and Delphi register call first argument are stored on eax register too...
@@hook_rdname:
  pop ecx
  call GetRadioName
  jmp OriginCallPoint

end;

//==============================================================================

procedure InitAsi;
// Start DLL Initialization
var
  MainDir: string;
  ini: TIniFile;
  x: integer;
  modul: HMODULE;
  lang: string;
  EnableTxPatch: boolean;
  JmpOp: PByte;
  CallP: PLongInt;
  OldProt: Cardinal;
  AACPlug, OpusPlug: boolean;

  function ProcAddr(Addr: string): Pointer;
  begin
    Result:= GetProcAddress(modul, PChar(Addr));
  end;

begin

  InitializeCriticalSection(MainThreadCs);
  MainDir:= ExtractFilePath(ParamStr(0));
  ini:= TIniFile.Create(MainDir + 'RadioEx.ini');
  try
    // Options
    EnableBassInit:= ini.ReadBool(ini_Options, 'EnableBassInit', TRUE);
    lang:= ini.ReadString(ini_Options, 'NoticeLang', 'ID');
    EnableTxPatch:= ini.ReadBool(ini_Options, 'RadioNamePatch', TRUE);
    // Plugins
    AACPlug:= ini.ReadBool(ini_Plugins, 'BASS_AAC', FALSE);
    OpusPlug:= ini.ReadBool(ini_Plugins, 'BASS_OPUS', FALSE);
    // Radio Station preferences
    for x:= 0 to RadioCount do
      begin
      Radio[x].Enable:= ini.ReadBool(ini_RadChnl, Format('Track%d_Enable', [x]), FALSE);
      Radio[x].Nulled:= FALSE;
      Radio[x].Name:= ini.ReadString(ini_RadChnl, Format('Track%d_Name', [x]), '');
      Radio[x].Location:= ini.ReadString(ini_RadChnl, Format('Track%d_URL', [x]), '');
      Radio[x].TempFile:= MakeTempFile;
      Radio[x].Handle:= INVALID_HANDLE_VALUE;
    end;
    // radio 11 are emulated adverts
    Radio[11].Nulled:= FALSE;
    Radio[11].TempFile:= MakeTempFile;
    Radio[11].Handle:= INVALID_HANDLE_VALUE;
  finally
    ini.Free;
  end;

  // Load noticement sound
  LoadingRs:= LoadRescData('LOADING');
  NoRadioRs:= LoadRescData(Format('NORADIO_%s', [lang]));
  NoIConnRs:= LoadRescData(Format('NOICONN_%s', [lang]));

  GTAWnd:= GetGTAWindow;
  if (HIWORD(BASS_GetVersion) <> BASSVERSION) then
    begin
    ShowWindow(GTAWnd, SW_HIDE);
    MessageBox(GTAWnd, PChar(err_bassinc), nil, MB_ICONERROR);
    ShowWindow(GTAWnd, SW_SHOW);
    Exit;
  end;

  BASS_SetConfig(BASS_CONFIG_NET_PLAYLIST, 1); // enable playlist processing
  BASS_SetConfig(BASS_CONFIG_NET_PREBUF, 0); // minimize automatic pre-buffering, so we can do it (and display it) instead

  if (AACPlug) then
    AACPlugin:= BASS_PluginLoad(PAnsiChar('bass_aac.dll'), 0);
  if (OpusPlug) then
    OPSPlugin:= BASS_PluginLoad(PAnsiChar('bassopus.dll'), 0);

  // Inject WinAPI code
  modul:= GetModuleHandle(PChar('kernel32.dll'));
  CreateGenericCodeHook(ProcAddr('CreateFileA'), @hook_CreateFileA, @origin_CreateFileA);
  CreateGenericCodeHook(ProcAddr('CloseHandle'), @hook_CloseHandle, @origin_CloseHandle);
  CreateGenericCodeHook(ProcAddr('GetFileSize'), @hook_GetFileSize, @origin_GetFileSize);
  CreateGenericCodeHook(ProcAddr('ReadFile'), @hook_ReadFile, @origin_ReadFile);
  CreateGenericCodeHook(ProcAddr('SetFilePointer'), @hook_SetFilePointer, @origin_SetFilePointer);

  // Hardcoded text injection :D
  if (EnableTxPatch) then
    begin

    // Undress him
    if VirtualProtect(Pointer(LoadTextJmp), 5, PAGE_EXECUTE_READWRITE, OldProt) then
      try
        JmpOp:= Pointer(LoadTextJmp);
        if (JmpOp^ = $E8) then // valid call opcode
          begin
          JmpOp^:= $E9; //replace with jmp
          CallP:= Pointer(LoadTextJmp+1);
          @OriginCallPoint:= Pointer(LoadTextJmp+5);
          OriginTxtPrc:= CallP^; // Reserve original location
          if (CallP^ > 0) then
            @origin_gta_LoadString:= Pointer(LoadTextJmp+CallP^+5)
          else
            @origin_gta_LoadString:= Pointer(LoadTextJmp+CallP^-1);
          // location for back to code
          if (LoadTextJmp < LongInt(@hook_gta_LoadString)) then
            CallP^:= LongInt(@hook_gta_LoadString)-LoadTextJmp-5
          else
            CallP^:= LongInt(@hook_gta_LoadString)-LoadTextJmp-1;
          TxPatch:= TRUE;
        end;
      finally
        VirtualProtect(Pointer(LoadTextJmp), 5, OldProt, OldProt);
      end;

  end;

  ExitStatus:= FALSE;
  // Start Main Pool thread
  PoolThread:= BeginThread(nil, 0, @PoolProc, @ExitStatus, 0, PoolTrId);

end;

//==============================================================================

procedure UnInitAsi;
var
  x: integer;
  JmpOp: PByte;
  CallP: PLongInt;
  OldProt: Cardinal;
begin

  ExitStatus:= TRUE;
  if (PoolThread <> 0) then
    WaitForSingleObject(PoolThread, INFINITE);
  DeleteCriticalSection(MainThreadCs);

  if BassInited then
    BASS_StreamFree(Chl);
  if (AACPlugin <> 0) then
    BASS_PluginFree(AACPlugin);
  if (OPSPlugin <> 0) then
    BASS_PluginFree(OPSPlugin);
  if (EnableBassInit) then
    BASS_Free;

  RemoveGenericCodeHook(@origin_CreateFileA);
  RemoveGenericCodeHook(@origin_CloseHandle);
  RemoveGenericCodeHook(@origin_GetFileSize);
  RemoveGenericCodeHook(@origin_ReadFile);
  RemoveGenericCodeHook(@origin_SetFilePointer);

  // Restore text injection
  if (TxPatch) then
    if VirtualProtect(Pointer(LoadTextJmp), 5, PAGE_EXECUTE_READWRITE, OldProt) then
      try
        JmpOp:= Pointer(LoadTextJmp);
        JmpOp^:= $E8;
        CallP:= Pointer(LoadTextJmp+1);
        CallP^:= OriginTxtPrc;
      finally
        VirtualProtect(Pointer(LoadTextJmp), 5, OldProt, OldProt);
      end;

  for x:= 0 to FileHkCnt do
    begin
    if (Radio[x].Handle <> INVALID_HANDLE_VALUE) then
      CloseHandle(Radio[x].Handle);
    if FileExists(Radio[x].TempFile) then
      DeleteFile(Radio[x].TempFile);
  end;

end;

//==============================================================================

procedure DllMain(Reason: integer) ;
begin
  case Reason of
    DLL_PROCESS_ATTACH: InitAsi;
    DLL_PROCESS_DETACH: UnInitAsi;
  end;
end;

//==============================================================================

begin

  DllProc:= @DllMain;
  DllProc(DLL_PROCESS_ATTACH);

end.
