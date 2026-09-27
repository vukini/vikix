{ wordfreq.pas — the ten most common words in a text file.

  A word is a run of letters, compared in lower case. The words go in a
  growing array, found again by a plain search; an insertion sort then
  puts the most common first.

    ./wordfreq text.txt }
program wordfreq;

{$mode objfpc}{$H+}

uses
  Classes, SysUtils;

type
  TEntry = record
    Word: string;
    Count: Integer;
  end;

var
  Entries: array of TEntry;

{ Count one more of W: a new entry the first time, +1 after that. }
procedure CountWord(const W: string);
var
  I: Integer;
begin
  for I := 0 to High(Entries) do
    if Entries[I].Word = W then
    begin
      Inc(Entries[I].Count);
      Exit;
    end;
  SetLength(Entries, Length(Entries) + 1);
  Entries[High(Entries)].Word := W;
  Entries[High(Entries)].Count := 1;
end;

{ True when A belongs before B: the higher count, or the same count and
  earlier in the alphabet. }
function Before(const A, B: TEntry): Boolean;
begin
  if A.Count <> B.Count then
    Result := A.Count > B.Count
  else
    Result := A.Word < B.Word;
end;

var
  Lines: TStringList;
  Text, Word: string;
  C: Char;
  I, J: Integer;
  Item: TEntry;
begin
  if ParamCount <> 1 then
  begin
    WriteLn(StdErr, 'usage: wordfreq FILE');
    Halt(2);
  end;
  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(ParamStr(1));
    Text := LowerCase(Lines.Text);
  finally
    Lines.Free;
  end;

  Word := '';
  for C in Text do
    if C in ['a'..'z'] then
      Word := Word + C
    else if Word <> '' then
    begin
      CountWord(Word);
      Word := '';
    end;
  if Word <> '' then
    CountWord(Word);

  for I := 1 to High(Entries) do   { insertion sort }
  begin
    Item := Entries[I];
    J := I - 1;
    while (J >= 0) and Before(Item, Entries[J]) do
    begin
      Entries[J + 1] := Entries[J];
      Dec(J);
    end;
    Entries[J + 1] := Item;
  end;

  for I := 0 to High(Entries) do
  begin
    if I = 10 then
      Break;
    WriteLn(Format('%4d %s', [Entries[I].Count, Entries[I].Word]));
  end;
end.
