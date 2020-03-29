{
  FlashOnIO.dpr

  This file is part of the GenCodeHook.pas sample application.
  Info at http://flocke.vssd.de/prog/code/pascal/codehook/

  Copyright (C) 2005, 2006 Volker Siebert <flocke@vssd.de>
  All rights reserved.
}

program FlashOnIO;

uses
  Forms,
  fmain in 'fmain.pas' {Form1},
  GenCodeHook in '..\GenCodeHook.pas',
  CodeLen in '..\CodeLen.pas',
  CodeMem in '..\CodeMem.pas',
  CodeMemOpt in '..\CodeMemOpt.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.Title := 'FlashOnIO';
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
