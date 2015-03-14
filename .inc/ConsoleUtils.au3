; #FUNCTION# ====================================================================================================================
; Name ..........: _ConsoleSendCtrlC
; Description....: Send Ctrl-C to cancel a process running as a console or a process running in a cmd.exe prompt.
; Syntax ........: _ConsoleSendCtrlC($PID, $iMode = 0, $iDll = "kernel32.dll")
; Parameters.....: hWnd        - Process ID of a ConsoleWindowClass window
;                 $iEvent    - 0 = Send CTRL_C_EVENT=0
;                 $iEvent    - 1 = Send CTRL_BREAK_EVENT=1
;                 $iMode    - 0 = No Callback required - Block CTRL_C_EVENT only for calling process
;                 $iMode    - 1 = Callback required - Block CTRL_C_EVENT and CTRL_BREAK_EVENT for calling process
;                 $iLoop    - Number of times to send Ctrl-C/Break event (Run in loop with ProcessExists check and 10ms Sleep)
;                 $iSlp    - Sleep value - Default 10ms
;                 $iDll    - Optional handle from DllOpen()
; Return values..: Succcess - 1
;                 Failure - -1 and sets @error
; Author.........: rover 2k12
; Remarks .......: Allows cancelled process to do cleanup before exiting.
;                 Event handler blocking of Ctrl-C/Break prevents script exiting when GenerateConsoleCtrlEvent called on a shared process console
;
;                 Note: It is preferable to send a CTRL_C_EVENT ($iEvent = 0) without the callback ($iMode = 0). (callback is created in a thread)
;
;                 Note: Console window and process checking is untested and unfinished in this version (Return = -1 and Error = 2 indicates console window is unresponsive)
;                 Script crash has occurred when sending Ctrl+C in a tight loop to an unresponsive process
;                 Test console window or process reponsiveness and send Ctrl+C one or more times with long sleep then if still unreponsive use ProcessClose.
;
; Related .......: _ConsoleEventHandler
; Example .......: Yes
;
; Optional: Callback Event Handler Function (for $iMode = 1 only)
; Func _ConsoleEventHandler()
;       Return 1 ; Ctrl-C/Break exiting blocked
; EndFunc   ;==>_ConsoleEventHandler
;
; ===============================================================================================================================
Func _ConsoleSendCtrlC($PID, $iEvent = 0, $iMode = 0, $iLoop = 1, $iSlp = 10, $iDll = "kernel32.dll")
    ;Author: rover 2k12
    Local $aRet = DllCall($iDll, "bool", "AttachConsole", "dword", $PID)
    If @error Or $aRet[0] = 0 Then Return SetError(1, 0, -1)
    ;sets GetLastError to ERROR_GEN_FAILURE (31) if process does not exist
    ;sets GetLastError to ERROR_ACCESS_DENIED (5) if already attached to a console
    ;sets GetLastError to ERROR_INVALID_HANDLE (6) if process does not have a console

    $aRet = DllCall("Kernel32.dll", "hwnd", "GetConsoleWindow") ;must be attached to console to get hWnd
    If Not @error And IsHWnd($aRet[0]) Then
        $aRet = DllCall('user32.dll', 'int', 'IsHungAppWindow', 'hwnd', $aRet[0]);from Yashieds' WinAPIEx.au3
        If Not @error And $aRet[0] Then
            DllCall($iDll, "bool", "FreeConsole")
            Return SetError(2, 0, -1)
        EndIf
    Else
        Return SetError(3, 0, -1)
    EndIf

    Local $iCTRL = 0, $iRet = 1, $pCB = 0, $iCB = 0, $iErr = 0, $iCnt = 0
    ;check params
    $iLoop = Int($iLoop)
    If $iLoop < 1 Then $iLoop = 1
    If $iEvent Then $iCTRL = 1
    If $iSlp < 10 Then $iSlp = 10

    If $iMode Then
        Local $sCB = "_ConsoleEventHandler"
        Call($sCB)
        If @error <> 0xDEAD And @extended <> 0xBEEF Then
            Local $iCB = DllCallbackRegister($sCB, "long", "")
            If Not $iCB Then
                DllCall($iDll, "bool", "FreeConsole")
                Return SetError(4, 0, -1)
            EndIf
            $pCB = DllCallbackGetPtr($iCB)
        Else
            $iCTRL = 0
        EndIf
    EndIf

    $aRet = DllCall($iDll, "bool", "SetConsoleCtrlHandler", "ptr", $pCB, "bool", 1)
    If @error Or $aRet[0] = 0 Then
        If $iMode Then DllCallbackFree($iCB)
        DllCall($iDll, "bool", "FreeConsole")
        Return SetError(5, @error, -1)
    EndIf

    ;send ctrl-c, free console and unregister event handler
    Do
        $aRet = DllCall($iDll, "bool", "GenerateConsoleCtrlEvent", "dword", $iCTRL, "dword", 0)
        If @error Or $aRet[0] = 0 Then $iRet = -1
        $iCnt += 1
        Sleep($iSlp)
    Until $iCnt = $iLoop Or ProcessExists($PID) = 0

    $aRet = DllCall($iDll, "bool", "FreeConsole")
    If Not @error Then $iErr = $aRet[0]
    If $iMode Then Sleep(50) ;10ms o.k, but margin for error better (DllCallbackFree can crash script if called too soon after console freed when using callback)
    $aRet = DllCall($iDll, "bool", "SetConsoleCtrlHandler", "ptr", 0, "bool", 0)
    If $iMode Then DllCallbackFree($iCB)
    Return SetError(@error, $iErr, $iRet)
EndFunc   ;==>_ConsoleSendCtrlC


Func _GetExitCode(ByRef $hProc)
    If Not IsArray($hProc) Then Return -1
    Local $retval = -1
    Local $i_ExitCode = DllCall('kernel32.dll', 'ptr', 'GetExitCodeProcess', 'ptr', $hProc[0], 'int*', 0)
    If Not @error Then $retval = $i_ExitCode[2]
    DllCall('kernel32.dll', 'ptr', 'CloseHandle', 'ptr', $hProc[0])
    Return $retval
EndFunc   ;==>_GetExitCode


Func _ConsoleEventHandler() ;single dword param $dwCtrlType in callback can sometimes cause - Error: Variable used without being declared. (event handler is run in a new thread)
    ;Optional: Callback Event Handler Function (for $iMode = 1 only)
    Return 1 ; Ctrl-C/Break exiting blocked
EndFunc   ;==>_ConsoleEventHandler
