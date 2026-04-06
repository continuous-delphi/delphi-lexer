object frmMain: TfrmMain
  Left = 0
  Top = 0
  Caption = 'Delphi-Lexer Tokenizer Debug Utility'
  ClientHeight = 813
  ClientWidth = 997
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  DesignSize = (
    997
    813)
  TextHeight = 15
  object memSource: TMemo
    Left = 8
    Top = 8
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
      ''
      'end.')
    ParentFont = False
    ScrollBars = ssBoth
    TabOrder = 0
  end
  object butTokenize: TButton
    Left = 8
    Top = 247
    Width = 75
    Height = 25
    Caption = 'Tokenize'
    TabOrder = 1
    OnClick = butTokenizeClick
  end
  object memTokens: TMemo
    Left = 8
    Top = 278
    Width = 981
    Height = 527
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
