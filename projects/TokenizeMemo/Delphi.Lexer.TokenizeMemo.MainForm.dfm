object frmMain: TfrmMain
  Left = 0
  Top = 0
  Caption = 'Delphi-Lexer Tokenizer Debug Utility'
  ClientHeight = 848
  ClientWidth = 997
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnCreate = FormCreate
  DesignSize = (
    997
    848)
  TextHeight = 15
  object labSourceCode: TLabel
    Left = 8
    Top = 11
    Width = 104
    Height = 15
    Caption = 'Source To Tokenize:'
  end
  object labStatus: TLabel
    Left = 114
    Top = 277
    Width = 46
    Height = 15
    Caption = '0 Tokens'
  end
  object memSource: TMemo
    Left = 8
    Top = 32
    Width = 981
    Height = 233
    Anchors = [akLeft, akTop, akRight]
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -12
    Font.Name = 'Consolas'
    Font.Style = []
    Lines.Strings = (
      'unit Something;'
      ''
      'interface'
      ''
      'implementation'
      'procedure test;'
      'begin'
      '  {$IFDEF DEBUG} ShowMessage('#39'Debug'#39');'
      '  {$ELSE} ShowMessage('#39'Not Debug'#39'); {$ENDIF}'
      'end;'
      ''
      'end.')
    ParentFont = False
    ScrollBars = ssBoth
    TabOrder = 0
  end
  object butTokenize: TButton
    Left = 8
    Top = 272
    Width = 100
    Height = 25
    Caption = 'Tokenize'
    TabOrder = 1
    OnClick = butTokenizeClick
  end
  object memTokens: TMemo
    Left = 8
    Top = 304
    Width = 981
    Height = 536
    Anchors = [akLeft, akTop, akRight, akBottom]
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -12
    Font.Name = 'Consolas'
    Font.Style = []
    ParentFont = False
    ScrollBars = ssBoth
    TabOrder = 2
  end
end
