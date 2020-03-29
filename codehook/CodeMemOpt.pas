{
  CodeMemOpt.pas

  Delphi unit containing a small memory management for virtually allocated
  memory that allows execution of run-time created code. This way many small
  fragments share one 4K VirtualAlloc page.

  Note: this unit is not optimized for speed (no necessity).

  Version 1.4 - Always find the most current version at
  http://flocke.vssd.de/prog/code/pascal/codehook/

  Copyright (C) 2005, 2006 Volker Siebert <flocke@vssd.de>
  All rights reserved.

  Permission is hereby granted, free of charge, to any person obtaining a
  copy of this software and associated documentation files (the "Software"),
  to deal in the Software without restriction, including without limitation
  the rights to use, copy, modify, merge, publish, distribute, sublicense,
  and/or sell copies of the Software, and to permit persons to whom the
  Software is furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in
  all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
  DEALINGS IN THE SOFTWARE.
}

unit CodeMemOpt;

interface

uses
  Windows, SysUtils, CodeMem;

function OptGetCodeMem(Size: integer): pointer;
function OptFreeCodeMem(P: pointer): integer;

implementation

const
  CHUNK_ROUND_SIZE = 16;
  CHUNK_USED_BIT   = $40000000;
  CHUNK_SIZE_MASK  = $3FFFFFFF;

  PAGE_MAGIC       = $6D4D7356;

type
  // The header of a complete page
  PPageHeader = ^TPageHeader;
  TPageHeader = packed record
    Magic: cardinal;            // PAGE_MAGIC
    Next: PPageHeader;          // pointer to the next page header
    Size: integer;              // size of this page
    Dummy: integer;             // not used
  end;

  // A single chunk of allocated memory
  PPageChunk = ^TPageChunk;
  TPageChunk = packed record
    Base: PPageHeader;          // the page's header
    Size: integer;              // complete size incl. this header
  end;

var
  PageCrit: TRTLCriticalSection;        // Critical section to be thread-enabled
  PageCritFlag: boolean = false;        // Flag if InitializeCriticalSection was done
  PageSize: integer = 0;                // System VirtualAlloc page size
  PageList: PPageHeader = nil;          // List of allocated pages

{ The optimized code memory manager }

var
  OptCodeMemManager: TCodeMemoryManager = (
    GetMem:     OptGetCodeMem;
    FreeMem:    OptFreeCodeMem;
    ReallocMem: SysReallocMem
  );

function OptGetCodeMem(Size: integer): pointer;
var
  Page: PPageHeader;

  { Append a new page to the list of pages
  }
  function AppendNewPage(ForceSize: integer = 0): PPageHeader;
  begin
    // Round to full page size
    if ForceSize = 0 then
      ForceSize := PageSize
    else
      ForceSize := PageSize * ((ForceSize + PageSize - 1) div PageSize);

    // Get new physical page
    Result := VirtualAlloc(nil, ForceSize, MEM_COMMIT, PAGE_EXECUTE_READWRITE);
    if Result = nil then
      exit;

    with PPageChunk(integer(Result) + SizeOf(TPageHeader))^ do
    begin
      Size := ForceSize - SizeOf(TPageHeader);
      Base := Result;
    end;

    with Result^ do
    begin
      Magic := PAGE_MAGIC;
      Size := ForceSize;
      Dummy := 0;
      Next := PageList;
    end;

    PageList := Result;
  end;

  { Initialize the page size and the page list
  }
  procedure InitPages;
  var
    Info: TSystemInfo;
  begin
    GetSystemInfo(Info);
    PageSize := Info.dwPageSize;
    if PageSize < 4096 then
      PageSize := 4096;

    if PageSize mod CHUNK_ROUND_SIZE <> 0 then
      PageSize := PageSize - PageSize mod CHUNK_ROUND_SIZE;
  end;

  { Allocate a piece of memory in the given page. Size includes the chunk
    header overhead and is already rounded to CHUNK_ROUND_SIZE.
  }
  function AllocInPage(Page: PPageHeader; Size: integer): pointer;
  var
    Chunk, Next, Limit: integer;
  begin
    Result := nil;

    Chunk := integer(Page) + SizeOf(TPageHeader);
    Limit := integer(Page) + Page^.Size;

    while (Chunk < Limit) and (Result = nil) do
    begin
      if (PPageChunk(Chunk)^.Size and CHUNK_USED_BIT) <> 0 then
        inc(Chunk, PPageChunk(Chunk)^.Size and CHUNK_SIZE_MASK)
      else
      begin
        Next := Chunk + PPageChunk(Chunk)^.Size;
        while (Next < Limit) and ((PPageChunk(Next)^.Size and CHUNK_USED_BIT) = 0) do
        begin
          inc(PPageChunk(Chunk)^.Size, PPageChunk(Next)^.Size);
          Next := Chunk + PPageChunk(Chunk)^.Size;
        end;

        if PPageChunk(Chunk)^.Size > Size then
        begin
          // Allocate from the end, so the next alloc
          // finds the free block as fast as we did.
          dec(PPageChunk(Chunk)^.Size, Size);
          Next := Chunk + PPageChunk(Chunk)^.Size;
          PPageChunk(Next)^.Base := Page;
          PPageChunk(Next)^.Size := Size or CHUNK_USED_BIT;
          Result := pointer(Next + SizeOf(TPageChunk));
        end
        else if PPageChunk(Chunk)^.Size = Size then
        begin
          // Fits exactly
          PPageChunk(Chunk)^.Size := Size or CHUNK_USED_BIT;
          Result := pointer(Chunk + SizeOf(TPageChunk));
        end;

        Chunk := Next;
      end;
    end;
  end;

  { Move the given page to the top of the page list
  }
  procedure LastRecentlyUsed(Page: PPageHeader);
  var
    Fix: ^PPageHeader;
  begin
    Fix := @PageList;
    while Fix^ <> Page do
      Fix := @(Fix^)^.Next;

    Fix^ := Page^.Next;
    Page^.Next := PageList;
    PageList := Page;
  end;

begin
  if not PageCritFlag then
  begin
    PageCritFlag := true;
    InitializeCriticalSection(PageCrit);
  end;

  EnterCriticalSection(PageCrit);
  try
    if PageSize = 0 then
      InitPages;

    Result := nil;
    Size := (Size + SizeOf(TPageChunk) + CHUNK_ROUND_SIZE - 1) and (-CHUNK_ROUND_SIZE);

    Page := PageList;
    while Page <> nil do
    begin
      Result := AllocInPage(Page, Size);
      if Result <> nil then
        break;

      Page := Page^.Next;
    end;

    if Result = nil then
    begin
      if Size > PageSize - 128 then
        Page := AppendNewPage(Size + SizeOf(TPageHeader))
      else
        Page := AppendNewPage(0);

      Result := AllocInPage(Page, Size);
    end;

    if Page <> PageList then
      if 8 * Size <= PageSize then
        LastRecentlyUsed(Page);

    if Result = nil then
      SetLastError(ERROR_NOT_ENOUGH_MEMORY);
  finally
    LeaveCriticalSection(PageCrit);
  end;
end;

{ Free the memory pointed to by P
}
function OptFreeCodeMem(P: pointer): integer;
var
  Chunk: PPageChunk;
begin
  Result := 0;

  if P = nil then
    exit;

  if (not PageCritFlag) or (PageSize = 0) or (PageList = nil) then
  begin
    SetLastError(ERROR_INVALID_FUNCTION);
    Result := 1;
    exit;
  end;

  EnterCriticalSection(PageCrit);
  try
    if P <> nil then
    begin
      Chunk := PPageChunk(integer(P) - SizeOf(TPageChunk));
      // Check the chunk and the page
      if ((Chunk^.Size and CHUNK_USED_BIT) = 0) or
         ((Chunk^.Size and (CHUNK_ROUND_SIZE - 1)) <> 0) or
         (Chunk^.Base^.Magic <> PAGE_MAGIC) or
         (cardinal(Chunk) < cardinal(Chunk^.Base)) or
         (cardinal(Chunk) >= cardinal(Chunk^.Base) + cardinal(Chunk^.Base^.Size)) then
      begin
        SetLastError(ERROR_INVALID_BLOCK);
        Result := 1;
      end
      else
        // Everything seems to be ok
        Chunk^.Size := Chunk^.Size and CHUNK_SIZE_MASK;
    end;
  finally
    LeaveCriticalSection(PageCrit);
  end;
end;

initialization
  SetCodeMemManager(OptCodeMemManager);
finalization
  if PageCritFlag then
  begin
    DeleteCriticalSection(PageCrit);
    PageCritFlag := false;
  end;
end.

