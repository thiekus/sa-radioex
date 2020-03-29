GenCodeHook.pas (CodeLen.pas, CodeMem.pas, CodeMemOpt.pas)

Delphi Units zum "Hooken" (�berschreiben, Ersetzen) von existierenden
Funktionen. Zus�tzlich wird ein neues Codefragment erzeugt, dass den
Aufruf der originalen Funktion erm�glicht.

Version 1.5a - die aktuelle Version gibt's immer unter
http://flocke.vssd.de/prog/code/pascal/codehook/

Copyright (C) 2005, 2006 Volker Siebert <flocke@vssd.de>
Alle Rechte vorbehalten.

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

Delphi-Versionen: 5, 6, 7, 2005 und 2006.

ERL�UTERUNG

Mit der Funktion "CreateGenericCodeHook" ist es m�glich, eine existierende
Funktion durch eine eigene zu Ersetzen. Zus�tzlich dazu wird ein neues
Codefragment erzeugt, dass den Aufruf der Originalfunktion erm�glicht.

Im Gegensatz zu den Ans�tzen, die die IAT ("Import Address Table") des
betroffenen Moduls modifizieren, kann diese Funktion direkt den Code an der
Einsprungadresse ersetzen und f�ngt somit auch Aufrufe aus DLLs und �ber
mittels "GetProcAddress" ermittelte Adressen ab.

Wichtiger Hinweis: Der Versuch, Speicher im Systembereich von $80000000 bis
$FFFFFFFF wird fehlschlagen. Da Windows 95/98/Me die System-DLLs dort in 
den Anwendungsspeicher einblenden, ist es unter diesen Systemen nicht
m�glich, direkt den Funktionseinsprungspunkt zu patchen.

Nehmen wir einmal an, wir m�chten den Aufruf von ReadFile abfangen (einen
m�glichen Grund daf�r zeigt die Beispielanwendung). Dies geht so:
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

FUNKTIONSWEISE

Die Funktionsweise basiert zu einem gro�en Teil auf der Unit "CodeLen.pas",
deren Funktionen eine inzwischen schon recht aufw�ndige Codeanalyse
erm�glichen.

Dadurch wird es m�glich, nicht nur einfach eine feste Instruktion wie JMP
oder CALL zu patchen, sondern beliebigen Code der mindestens 6 Bytes lang
ist. Ich zeige das einmal am Beispiel der Funktion "ReadFile".

Der originale ReadFile-Code steht bei Adresse $7C80180E:
+-------------------------------------------------------------------------
| kernel32.ReadFile:
| 7C80180E 6A20             push $20
| 7C801810 68D89B807C       push $7c809bd8
| 7C801815 E8B10C0000       call $7c8024cb    ; <-- Schnittpunkt
| 7C80181A 33DB             xor ebx,ebx
| 7C80181C 8B4D14           mov ecx,[ebp+$14]
| ...
+-------------------------------------------------------------------------

Wir ben�tigen 6 Bytes f�r die Instruktionen, die wir an dieser Stelle
einf�gen m�chten. Der n�chste m�gliche `Schnittpunkt� ist also bei Adresse
$7C801815, das liegt 7 Bytes hinter dem Eintrittspunkt der Funktion.

Unsere neue Funktion "NewReadFile" steht bei Adresse $456D28. Nach dem
Einf�gen der Instruktionen sieht der gepatchte Code dann z.B. so aus:
+-------------------------------------------------------------------------
| kernel32.ReadFile:
| 7C80180E 68286D4500       push offset NewReadFile
| 7C801813 C3               ret
| 7C801814 90               nop
| 7C801815 E8B10C0000       call $7c8024cb    ; <-- Schnittpunkt
| 7C80181A 33DB             xor ebx,ebx
| 7C80181C 8B4D14           mov ecx,[ebp+$14]
| ...
+-------------------------------------------------------------------------

Wie man sieht, steht bei $7C801815 die erste noch g�ltige Instruktion des
originalen Codes, also exakt 7 Bytes hinter dem Eintrittspunkt. An genau
diese Stelle springt jetzt das von "CreateGenericCodeHook" erstellte 
Codefragment, und das sieht dann so aus:
+-------------------------------------------------------------------------
| 00A90FE0 6A20             push $20
| 00A90FE2 68D89B807C       push $7c809bd8
| 00A90FE7 E92908D77B       jmp $7c801815
+-------------------------------------------------------------------------

Die ersten 7 Bytes wurden aus dem Originalcode von "kernel32.ReadFile"
her�ber kopiert und der anschlie�ende Sprung zeigt 7 Bytes dahinter.

Hinweis: die Version 1.2 hat den 5 Byte langen Befehl "jmp NewReadFile"
eingef�gt. Weiteren Informationen nach gibt es durchaus einige Programme
(insbesondere Virenscanner fern�stliche), die damit nicht klar kommen.
Daher habe ich die Befehlsfolge auf "push offset NewReadFile : ret"
ge�ndert - dieser Code muss nicht reloziert werden.

Stehen an der gew�nschten Stelle nur 5 Byte zur Verf�gung, dann f�llt die
Routine in das alte Schema zur�ck und setzen einen PC-relativen Sprung ein.

BEISPIELANWENDUNG

Die Beispielanwendung erweitert die Funktionen ReadFile und WriteFile und
zeigt auf dem Formular zwei Indikatoren in gr�n und rot, die die jeweilige
E/A-Aktivit�t anzeigen.

Wenn man zwei Dateinamen ausw�hlt und dann auf "Start" klickt, dann wird
die erste Datei mit der API-Funktion "CopyFile" �ber die zweite kopiert.
Die beiden Indikatoren zeigen dabei den Lese- und Schreibzugriff an. Am
deutlichsten wird dies, wenn man ein langsames Medium w�hlt, wie z.B. eine
Diskette.

Interessant ist es auch schon, einfach nur das Flackern der Indikatoren zu
beobachten, w�hrend man mit dem OpenDialog oder SaveDialog navigiert;
besonders deutlich wird dies, wenn man �ber die rechte Maustaste das
Kontextmen� von Dateien aufruft, insbesondere das "Senden an"-Men�.

DIE UNITS

CodeLen.pas

  Diese Unit erm�glich eine recht tiefe Code-Analyse und bietet Funktionen,
  die einzelne CPU-Instruktionen analysieren sowie auch komplette
  `Landkarten� von Codebereichen bilden und darauf operieren k�nnen.

CodeMem.pas

  Diese Unit abstrahiert den Zugriff auf ausf�hrbare Speicherbl�cke. �ber
  die Funktionen "AllocCodeMem" und "FreeCodeMem" kann man als ausf�hrbar
  gekennzeichneten Speicher anfordern und wieder freigeben.

  Die Unit selbst optimiert aber noch nichts sondern ruft einfach die API-
  Funktionen "VirtualAlloc" und "VirtualFree" auf.

CodeMemOpt.pas

  Diese Unit bindet einen (auf Verbrauch) optimierten Speichermanager in
  die Unit CodeMem.pas ein. Es werden immer jeweils 4K-Bl�cke angefordert
  und aus diesen dann H�ppchen zur�ckgeliefert.

  Die Verwendung empfiehlt sich, wenn man nicht nur einen sondern mehrere
  Hooks setzen will, da jeder generierte Code auf einer 4K-Grenze landet.
  Der eigentliche Speicherverbraucht ist dabei nicht so wichtig, sondern
  die Tatsache, dass einem irgendwann die virtuellen Adressen ausgehen.

  Die Unit muss nur einmal im Projekt mit uses eingebunden werden, die
  Stelle, an der dies geschieht, ist nicht relevant; es reicht also aus,
  sie einfach dem Projekt hinzuzuf�gen.
