{ VirEx (c) [22:27 28.10.2005]
 модуль для полноценной работы с CMD интерпретатором (Windows XP)
}
unit CMDMode;

interface

uses
  Windows;

//function RunConsoleApp(CommandLine: PChar;var Output: array of PChar):boolean;

//устанавливаем командный режим (запускаем CMD)
function CreateCMDMode(CommandLine: PChar):boolean;

//тут и так всё ясно
procedure CloseCMDMode;

//посылаем интерпретатору CMD команду (например dir)
function RunCMDCommand(Command:PChar): Boolean;

//читаем строки исполненой команды (после последней вводимой команды)
procedure ReadCMDResult(var Output:PChar);

implementation
var
  //для CreateProcess
  sa : TSECURITYATTRIBUTES;
  si : TSTARTUPINFO;
  pi : TPROCESSINFORMATION;


  //дескрипторы каналов ввода/вывода
  PipeStdInRead,
  PipeStdInWrite,
  PipeStdOutRead,
  PipeStdOutWrite
  :THandle;

function CreateCMDMode(CommandLine: PChar):boolean;
var
 tmp1,tmp2:THandle;
begin
 sa.nLength := sizeof(sa);
 sa.bInheritHandle := true;
 sa.lpSecurityDescriptor := nil;

 //делаем каналы ввода/вывода
 CreatePipe(PipeStdInRead, PipeStdInWrite, @sa, 0);
 CreatePipe(PipeStdOutRead, PipeStdOutWrite, @sa, 0);
 
 DuplicateHandle(GetCurrentProcess(), PipeStdInWrite, GetCurrentProcess(), @Tmp1, 0, False, DUPLICATE_SAME_ACCESS);
 DuplicateHandle(GetCurrentProcess(), PipeStdOutRead, GetCurrentProcess(), @Tmp2, 0, False, DUPLICATE_SAME_ACCESS);

 CloseHandle(PipeStdInWrite);
 CloseHandle(PipeStdOutRead);

 PipeStdInWrite:=Tmp1;
 PipeStdOutRead:=Tmp2;

 zeromemory(@si,SizeOf(si));
 si.cb := SizeOf(si);

 si.dwFlags := STARTF_USESHOWWINDOW or STARTF_USESTDHANDLES;
 si.wShowWindow := SW_HIDE;
 si.hStdInput :=PipeStdInRead;
 si.hStdOutput := PipeStdOutWrite;


 Result:=CreateProcess(nil,
      PChar(CommandLine),       // command line
      nil,          // process security attributes
      nil,          // primary thread security attributes
      TRUE,         // handles are inherited
      0,            // creation flags
      nil,          // use parent's environment
      nil,          // use parent's current directory
      si,  // STARTUPINFO pointer
      pi);  // receives PROCESS_INFORMATION
end;

procedure CloseCMDMode;
begin
CloseHandle(PipeStdInRead);
CloseHandle(PipeStdInWrite);
CloseHandle(PipeStdOutRead);
CloseHandle(PipeStdOutWrite);
CloseHandle(pi.hThread);//сначало закрываем "нить"
CloseHandle(pi.hProcess);//и только потом сам процесс
end;

function RunCMDCommand(Command:PChar): Boolean;
var
	dwWritten, BufSize: DWORD;
begin
  Command:=PChar(Command+#10#13);
  BufSize:=Length(Command);
  Result:=WriteFile(PipeStdInWrite, Command^, BufSize, dwWritten, Nil);
  Result:=Result and (BufSize = dwWritten);
  //freemem(s);
  //ZeroMemory(@s,Length(s));
end;

procedure ReadCMDResult(var Output: PChar);
var
	i: Integer;
	dwRead, BufSize, DesBufSize: DWORD;
  Res: Boolean;
begin
	try
		BufSize:=0;
    repeat

      for i:=0 to 9 do
  	    begin
			    Res:=PeekNamedPipe(PipeStdOutRead, nil, 0, nil, @DesBufSize, nil);
      	  Res:=Res and (DesBufSize > 0);
          if Res then
            Break;
          Sleep(30);
        end;
      if Res then
      	begin
        	If DesBufSize > BufSize then
          	begin
            	//if PChar(Output^)<>nil then FreeMem(Output);
              //for i:=0 to Length(Output) do Output[i]:=#0;
	            GetMem(Output, DesBufSize);
              BufSize:=DesBufSize;
            end;
	  			Res:=ReadFile(PipeStdOutRead, Output^, BufSize, dwRead, Nil);
        end;
    until not Res;
  except
  end;
end;

end.
 