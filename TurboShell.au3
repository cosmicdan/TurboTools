#NoTrayIcon
#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Compression=0
#AutoIt3Wrapper_UseUpx=n
#AutoIt3Wrapper_Add_Constants=n
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#cs ----------------------------------------------------------------------------

 AutoIt Version: 3.3.12.0
 Author:         myName

 Script Function:
	Template AutoIt script.

#ce ----------------------------------------------------------------------------

Opt("MustDeclareVars", 1)

#include <WinAPIGdi.au3>
#include <WindowsConstants.au3>
#include <GuiRichEdit.au3>
#include <GUIConstantsEx.au3>
#include <GuiComboBox.au3>
#include <Array.au3>
#include <GuiEdit.au3>
#include <ScrollBarsConstants.au3>

#include ".\.inc\ConsoleUtils.au3"

Global $hGuiMain
Global $hGuiConsoleRichEdit
Global $hGuiConsoleCombo
Global $hGuiConsoleComboEdit

Global Const $HOTKEYS_TOTAL= 2
Global $aAccelCtrls[$HOTKEYS_TOTAL] ; See _SetupGuiHotkeys() for actual assignments. First dimension is the accelerator index (i.e. the count), and second dimension is 0=hotkey, 1=control.

; These values should be moved to a settings page later
Global $consoleMaxLines = 1000 ;TODO - Actually implement this (not yet gotten there since moving to a RichEdit control)
Global $iGuiWidth = 600
Global $iGuiHeight = 400

OnAutoItExitRegister("_Shutdown")

_StartupGui()
PrintLog("[i] TurboShell v0.x.1 firing up" & @CR)
_SetupGuiHotkeys()
_StartCoreConsole()

Func _StartCoreConsole()
	Local $iPid = Run("cmd", @ScriptDir, @SW_HIDE, $STDIN_CHILD + $STDERR_MERGED)
	;Local $hProcess = DllCall('kernel32.dll', 'ptr', 'OpenProcess', 'int', 0x400, 'int', 0, 'int', $iPid)
	Local $stdOut

	While 1
		$stdOut = StdoutRead($iPid)
		If @error Then Return
		$stdOut = StringReplace($stdOut, @CR & @CR, @CR)
		If $stdOut Then
			Print($stdOut)
		EndIf
		Switch GUIGetMsg()
			Case $GUI_EVENT_CLOSE
				Return
			Case $aAccelCtrls[0] ; ENTER
				If _WinAPI_GetFocus() = $hGuiConsoleComboEdit Then
					StdInWrite($iPid, GUICtrlRead($hGuiConsoleCombo) & @CRLF)
					;clear text from input box
					GUICtrlSetData($hGuiConsoleCombo, "")
				EndIf
			Case $aAccelCtrls[1] ; CTRL+C
				_ConsoleSendCtrlC($iPid)
				; TODO: Show "Break signal unsupported" warning when running uncompiled
				; Actually, I can get the current "active" program via title parsing and just kill it off. For internal commands though that'll require some trickery.
		EndSwitch
	WEnd
EndFunc

Func PrintLog($sText = "")
	ConsoleWrite($sText) ; TODO: Actually implement a logging system
	Print($sText)
EndFunc

Func Print($sText = "")
	; remember the current cursor position in combo input
	Local $tmp = ControlCommand($hGuiMain, "", $hGuiConsoleComboEdit, "GetCurrentCol", "")
	; re-set the font
	_GUICtrlRichEdit_SetFont($hGuiConsoleRichEdit, 8, "Bitstream Vera Sans Mono")
	; write-out the text
	_GUICtrlEdit_AppendText($hGuiConsoleRichEdit, $sText)
	; scroll to last line
	_GUICtrlRichEdit_GotoCharPos($hGuiConsoleRichEdit, -1)
	; return focus to the edit box...
	GUICtrlSetState($hGuiConsoleCombo, $GUI_FOCUS)
	; ... and restore the cursor position
	If $tmp > 0 Then _GUICtrlEdit_SetSel( $hGuiConsoleComboEdit, $tmp-1, $tmp-1 )
EndFunc

Func _StartupGui()
	; Load our fixed-width font for display
	If _WinAPI_AddFontResourceEx(@ScriptDir & ".\.res\VeraMono.ttf") = 0 Then
		MsgBox($MB_OK + $MB_ICONERROR, "Error", "TurboShell was unable to register fonts. Ensure you are running as Administrator.")
		Exit
	EndIf
	; Create our main GUI window
	$hGuiMain = GUICreate("TurboShell", 600, 400, -1, -1, $WS_MINIMIZEBOX + $WS_MAXIMIZEBOX + $WS_SIZEBOX + $WS_CAPTION + $WS_POPUP + $WS_SYSMENU, -1)
	; Add our main console display control - We use a RichEdit box so we can have colors and hyperlinks and other such fancy things
	$hGuiConsoleRichEdit = _GUICtrlRichEdit_Create($hGuiMain, "", 0, 0, 600, $iGuiHeight - 20, BitOR ($WS_HSCROLL, $WS_VSCROLL, $ES_MULTILINE, $ES_READONLY))
		; set default colors (white on black)
		_GUICtrlRichEdit_SetBkColor($hGuiConsoleRichEdit, 0x000000)
		_GUICtrlRichEdit_SetCharColor($hGuiConsoleRichEdit, 0xFFFFFF)
	; Add our main console combo control (edit + pulldown control)
	$hGuiConsoleCombo = GUICtrlCreateCombo("", 0, $iGuiHeight - 20, $iGuiWidth, 20)
	;$hGuiConsoleCombo = GUICtrlCreateCombo("", 0, $iGuiHeight - 20, $iGuiWidth, 20, BitOR($CBS_SIMPLE, $CBS_AUTOHSCROLL, $WS_VSCROLL))
		; set our font again, this one is a little bigger though
		GUICtrlSetFont($hGuiConsoleCombo, "9", 600, 0, "Bitstream Vera Sans Mono", 5)
		; get a handle on the edit "sub-control" of the combo box. We need this for handling special input like ENTER and CTRL+C.
		Local $tmp = $tagCOMBOBOXINFO
		If _GUICtrlComboBox_GetComboBoxInfo($hGuiConsoleCombo, $tmp) Then
			$hGuiConsoleComboEdit = DllStructGetData($tmp, "hEdit")
		Else
			MsgBox($MB_OK + $MB_ICONERROR, "Error", "Something went terribly wrong while getting a handle on the edit control. This shouldn't happen.")
		EndIf
	; register listener for window size changes. Unfortunately, due to rich-edit, we can't use AutoIt's built-in handler and need to do this logic manually
	GUIRegisterMsg($WM_SIZE, "_WM_SIZE")
	; GUI ready, show it
	GUISetState(@SW_SHOW, $hGuiMain)
	GUICtrlSetState($hGuiConsoleCombo, $GUI_FOCUS)
EndFunc

Func _SetupGuiHotkeys()

	For $i = 0 To UBound($aAccelCtrls) - 1
		$aAccelCtrls[$i] = GUICtrlCreateDummy()
	Next

	Local $aAccelerators[2][$HOTKEYS_TOTAL] = [ _
		["{ENTER}", $aAccelCtrls[0]], _  ; [Enter] - passed-on to cmd.exe (only if the combo edit - i.e. command input box -has focus)
		["^c",      $aAccelCtrls[1]]  _  ; [Ctrl+C] - passed-on to cmd.exe
	]

	GUISetAccelerators($aAccelerators,$hGuiMain)
EndFunc

Func _Shutdown()
	If _WinAPI_RemoveFontResourceEx(@ScriptDir & ".\fonts\VeraMono.ttf") Then
		PrintLog("[i] Font(s) unregistered OK" & @CR)
	Else
		PrintLog("[!] Font(s) unregister failure" & @CR)
	EndIf
EndFunc   ;==>_Exit

Func _WM_SIZE($hWnd, $iMsg, $wParam, $lParam)
	$iGuiWidth = _WinAPI_LoWord($lParam)
	$iGuiHeight = _WinAPI_HiWord($lParam)
	; main console display
    _WinAPI_MoveWindow($hGuiConsoleRichEdit, 0, 0, $iGuiWidth, $iGuiHeight - 20)
	; main console combo control
	GUICtrlSetPos($hGuiConsoleCombo, 0, $iGuiHeight - 20, $iGuiWidth, 20)
    Return 0
EndFunc
