object Form1: TForm1
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu, biMinimize]
  BorderStyle = bsSingle
  Caption = 'Flocke'#39's GenCodeHook Example'
  ClientHeight = 171
  ClientWidth = 443
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  OnClose = FormClose
  OnHide = FormHide
  OnShow = FormShow
  PixelsPerInch = 96
  TextHeight = 13
  object Shape1: TShape
    Left = 352
    Top = 124
    Width = 17
    Height = 17
  end
  object Shape2: TShape
    Left = 352
    Top = 144
    Width = 17
    Height = 17
  end
  object Label1: TLabel
    Left = 8
    Top = 8
    Width = 43
    Height = 13
    Caption = '&Input file:'
    FocusControl = Edit1
  end
  object Label2: TLabel
    Left = 8
    Top = 64
    Width = 51
    Height = 13
    Caption = '&Output file:'
    FocusControl = Edit2
  end
  object Bevel1: TBevel
    Left = 8
    Top = 112
    Width = 425
    Height = 9
    Shape = bsTopLine
  end
  object Label3: TLabel
    Left = 280
    Top = 124
    Width = 65
    Height = 17
    Alignment = taRightJustify
    AutoSize = False
    Caption = 'READ'
    Layout = tlCenter
  end
  object Label4: TLabel
    Left = 280
    Top = 144
    Width = 65
    Height = 17
    Alignment = taRightJustify
    AutoSize = False
    Caption = 'WRITE'
    Layout = tlCenter
  end
  object Edit1: TEdit
    Left = 8
    Top = 24
    Width = 361
    Height = 21
    TabOrder = 0
  end
  object Button1: TButton
    Left = 376
    Top = 8
    Width = 57
    Height = 37
    Caption = 'Select...'
    TabOrder = 1
    OnClick = Button1Click
  end
  object Edit2: TEdit
    Left = 8
    Top = 80
    Width = 361
    Height = 21
    TabOrder = 2
  end
  object Button2: TButton
    Left = 376
    Top = 64
    Width = 57
    Height = 37
    Caption = 'Select...'
    TabOrder = 3
    OnClick = Button2Click
  end
  object Button3: TButton
    Left = 376
    Top = 124
    Width = 57
    Height = 37
    Caption = 'Start'
    TabOrder = 4
    OnClick = Button3Click
  end
  object OpenDialog1: TOpenDialog
    Filter = 'All files|*.*|'
    Options = [ofHideReadOnly, ofFileMustExist, ofEnableSizing]
    Title = 'Select input file'
    Left = 8
    Top = 128
  end
  object SaveDialog1: TSaveDialog
    Filter = 'All files|*.*|'
    Options = [ofHideReadOnly, ofPathMustExist, ofEnableSizing]
    Title = 'Select output file'
    Left = 40
    Top = 128
  end
  object Timer1: TTimer
    Interval = 10
    OnTimer = Timer1Timer
    Left = 72
    Top = 128
  end
end
