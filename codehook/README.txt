GenCodeHook.pas (CodeLen.pas, CodeMem.pas, CodeMemOpt.pas)

Delphi unit containing functions to do a generic code hook by replacing the
code location to be patched by a jump to the new location. Additionally, a
new code fragment is created that allows to call the old function.

Version 1.5a - Always find the most current version at
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

---------------------------------------------------------------------------

Delphi versions: 5, 6, 7, 2005, and 2006.

USAGE

Using the function "CreateGenericCodeHook" you can replace an existing
function with your own. Additionally a new code fragment is created that
allows you to call the original function.

Unlike code that modifies the IAT ("Import Address Table") of the module
in question, this function can directly patch the code at the entry point
and thus also catches calls from loaded DLLs and addresses you got from
"GetProcAddress".

Important Notice: Trying to patch system memory in the range from $80000000
to $FFFFFFFF will fail. Since Windows 95/98/Me store system DLLs in that
area, it is not possible to patch the function entry points directly under
that operating systems.

Consider we wanted to catch the call to the "ReadFile" API function (the
sample application shows a possible reason for that). It works like this:
+-------------------------------------------------------------------------
| uses
|   GenCodeHook;
|
| type
|   TFnReadFile = function(hFile: THandle; var Buffer;
|     nNumberOfBytesToRead: DWORD; var lpNumberOfBytesRead: DWORD;
|     lpOverlapped: POverlapped): BOOL; stdcall;
| 
| var
|   OldReadFile: TfnReadFile;
|
| function NewReadFile(hFile: THandle; var Buffer;
|   nNumberOfBytesToRead: DWORD; var lpNumberOfBytesRead: DWORD;
|   lpOverlapped: POverlapped): BOOL; stdcall;
| begin
|   // ... any action before original ReadFile
| 
|   Result := OldReadFile(hFile, Buffer, nNumberOfBytesToRead,
|                         lpNumberOfBytesRead, lpOverlapped);
| 
|   // ... any action after original ReadFile
| end;
|
| procedure InstallPatch;
| var
|   Module: HMODULE;
| begin
|   Module := GetModuleHandle('kernel32.dll');
|   CreateGenericCodeHook(GetProcAddress(Module, 'ReadFile'),
|     @NewReadFile, @OldReadFile);
| end;
+-------------------------------------------------------------------------

HOW DOES IT WORK

The mode of operation is based to a large part on the unit "CodeLen.pas",
which functions make a merely deep code analysis possible.

This way it is not only possible to patch fix instructions like JMP or CALL
but to modify any code of at least 6 bytes length. I show this by the
example of the function "ReadFile."

The original code is located at address $7C80180E:
+-------------------------------------------------------------------------
| kernel32.ReadFile:
| 7C80180E 6A20             push $20
| 7C801810 68D89B807C       push $7c809bd8
| 7C801815 E8B10C0000       call $7c8024cb    ; <-- cutting point
| 7C80181A 33DB             xor ebx,ebx
| 7C80181C 8B4D14           mov ecx,[ebp+$14]
| ...
+-------------------------------------------------------------------------

We need 6 bytes for the instructions that we are going to insert at this
address. So the next possible `cutting point´ is at address $7C801815,
which is 7 bytes after the function's entry point.

Our new function "NewReadFile" is located at address $456D28. After we have
inserted the JMP instruction, the patched code looks like:
+-------------------------------------------------------------------------
| kernel32.ReadFile:
| 7C80180E 68286D4500       push offset NewReadFile
| 7C801813 C3               ret
| 7C801814 90               nop
| 7C801815 E8B10C0000       call $7c8024cb    ; <-- cutting point
| 7C80181A 33DB             xor ebx,ebx
| 7C80181C 8B4D14           mov ecx,[ebp+$14]
| ...
+-------------------------------------------------------------------------

As you can see, the first remaining valid instruction of the original code
is at address $7C801815, exactly 7 bytes after the entry point. To exact
this address points the the new code fragment that "CreateGenericCodeHook"
created, and it looks like this:
+-------------------------------------------------------------------------
| 00A90FE0 6A20             push $20
| 00A90FE2 68D89B807C       push $7c809bd8
| 00A90FE7 E92908D77B       jmp $7c801815
+-------------------------------------------------------------------------

The first 7 bytes were copied from the original code of "kernel32.ReadFile"
and then a jump to the `cut point´ was added.

Notice: in version 1.2 I used the 5 byte instruction "jmp NewReadFile",
but there seem to be some programs that are not able to handle these kind
of instructions correctly. Therefore I changed the instruction to "push
offset NewReadFile : ret" - this code doesn't need to be relocated.

If there are only 5 bytes available at the location to patch, the function
falls back to the old scheme and inserts a pc-relative jump instruction.

SAMPLE APPLICATION

The sample application hooks the functions ReadFile and WriteFile and has
two indicators in green and red on it's form that show the corresponding
activity.

If you chose two filenames and click the "Start" button, the first file
will be copied over the second one using the API function "CopyFile". The
two indicators show each read and write access. To see this clearly, chose
a slow medium like a diskette for your tests.

It is also interesting to view the signalling of the indicators while you
navigate using the OpenDialog resp. the SaveDialog - especially when you
activate the context menu of a file using the right mouse button (open the
"Send to" menu).

THE UNITS

Beside "GenCodeHook.pas" you need just the units "CodeLen.pas" and
"CodeMem.pas". If you want to accomplish several hooks, then in addition
the use of "CodeMemOpt.pas" is recommended. This unit must be included only
by a single uses clauses and optimizes the memory consumption of the pages
requested with VirtualAlloc.

CodeLen.pas

  This unit allows a rather deep code analysis und has functions to
  analyze single CPU instructions along with other's that build and operate
  on complete `maps´ of code areas.

CodeMem.pas

  This unit abstracts the access to executable memory regions. Using the
  functions "AllocCodeMem" and "FreeCodeMem" you can allocate and release
  memory blocks that are marked executable.

  The unit itself does not optimize this but just redirects the request to
  the API functions "VirtualAlloc" and "VirtualFree".

CodeMemOpt.pas

  This unit installs an optimized memory manager in the unit CodeMem.pas
  that allocates pages of 4K size and returns small portions of them.

  It's use is recommended if you plan to hook several functions and not
  only a few ones. The actual memory consumption is not that critical but
  the fact that the virtual address space decreases each time you call
  VirtualAlloc.

  The unit must be included only once anywhere in your project; it is
  sufficient thus to simply add it to the project.
