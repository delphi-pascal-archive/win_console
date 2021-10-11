{
[22:34 09.11.2005]
VirEx (c) Модуль для WinConsul
загружает/сохраняет историю команд из "пуск-выполнить"
}
unit UseIERunHistory;

interface

uses
  Windows;

function LoadIEHistory(var Output:array of PChar):boolean;
function SaveIEHistory(command:PChar):boolean;

implementation

function LoadIEHistory(var Output:array of PChar):boolean;
var
  key:hKey;
  datatype:integer;
  ValueName:pchar;
  i:integer;
  Values,MaxValueNameLen,MaxDataLen:dword;

begin
RegOpenKeyEx(HKEY_CURRENT_USER,'Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU',0,KEY_ALL_ACCESS,key);
datatype:=REG_SZ;
result:=(RegQueryInfoKey(Key, nil, nil, nil, nil,
    nil, nil, @Values, @MaxValueNameLen,
    @MaxDataLen, nil, nil)=ERROR_SUCCESS);

i:=0;
while i<Values do begin   
  //GetMem(Output[i],MaxDataLen);
  RegEnumValue(key,i,ValueName,MaxValueNameLen,nil,@datatype,PByte(Output[i]), @MaxDataLen);
  Output[i][MaxDataLen-3]:=#0;//обрезаем последние символы "\1"
  inc(i);
  if i>High(Output)  then break;//если в реестре больше записей чем в нашем хистори команд то выход
end;

RegCloseKey(key);
end;

function SaveIEHistory(command:PChar):boolean;
var
  key:hKey;
  datatype:integer;
  ValueName:pchar;
  Values,MaxValueNameLen,MaxDataLen:dword;
begin
RegOpenKeyEx(HKEY_CURRENT_USER,'Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU',0,KEY_ALL_ACCESS,key);
datatype:=REG_SZ;
result:=(RegQueryInfoKey(Key, nil, nil, nil, nil,
    nil, nil, @Values, @MaxValueNameLen,
    @MaxDataLen, nil, nil)=ERROR_SUCCESS);
getmem(ValueName,256);
ValueName[0]:=char(Values+95);
ValueName[1]:=#0;
RegSetValueEx(key,ValueName,0,datatype,PChar(command+'\1'),length(PChar(command+'\1')));
freemem(ValueName,256);
RegCloseKey(key);
end;

end.
