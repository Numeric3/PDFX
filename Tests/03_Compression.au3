#cs ----------------------------------------------------------------------------
    03_Compression — optional FlateDecode of content streams.

    This script checks the invariants that are observable without a decompressor:

        python Tools/pdfcheck.py Tests/03_Compression.pdf

    Covered:
      - level 0 (default): no /Filter /FlateDecode
      - level 6: one filter per page, PDF smaller than the uncompressed version
      - /Length strictly smaller than the clear-text stream
      - tiny stream: automatic fallback to the raw stream
      - level out of range clamped into [0, 9] with @error = 1
      - setting refused after saving: @error = 2
      - /ID identical with and without compression (fingerprint of the content, not of the file)
#ce ----------------------------------------------------------------------------

#include "../PDFX.au3"

Global $g_Failures = 0
Global $g_Checks = 0

Func _Check($sName, $bOk, $sDetail = "")
	$g_Checks += 1
	If $bOk Then
		ConsoleWrite("OK    " & $sName & @CRLF)
	Else
		$g_Failures += 1
		ConsoleWrite("FAIL  " & $sName & ($sDetail <> "" ? " (" & $sDetail & ")" : "") & @CRLF)
	EndIf
EndFunc   ;==>_Check

Func _ReadText($sPath)
	Local $hFile = FileOpen($sPath, 16)
	If $hFile = -1 Then Return ""
	Local $bData = FileRead($hFile)
	FileClose($hFile)
	Return BinaryToString($bData, 1)
EndFunc   ;==>_ReadText

Func _DocumentId($sPath)
	Local $aMatch = StringRegExp(_ReadText($sPath), "/ID \[<([0-9A-F]{32})><", 1)
	If UBound($aMatch) = 1 Then Return $aMatch[0]
	Return ""
EndFunc   ;==>_DocumentId

; Two pages of identical text; $iLevel < 0 leaves compression at the document default.
Func _Build($iLevel, $sPath, $iLines = 40)
	Local $oDocument = _PDFX_New("A4", "P", 18)
	_PDFX_SetMeta($oDocument, "Compression", "Numeric1", "FlateDecode", "pdfx;zlib")
	If $iLevel >= 0 Then _PDFX_SetCompression($oDocument, $iLevel)
	_PDFX_SetFont($oDocument, "Helvetica", 10)
	For $iPage = 1 To 2
		If $iPage = 2 Then _PDFX_AddPage($oDocument)
		For $iLine = 0 To $iLines - 1
			_PDFX_Text($oDocument, 40, 40 + $iLine * 16, _
				"Page " & $iPage & ", line " & $iLine & ": The quick brown fox jumps over the lazy dog.")
		Next
	Next
	Local $bSaved = _PDFX_Save($oDocument, $sPath)
	_PDFX_Close($oDocument)
	Return $bSaved
EndFunc   ;==>_Build

; /Length values of the streams whose header ends with $sSuffix.
Func _Lengths($sText, $sSuffix)
	Local $aFound[0]
	Local $iPos = 1
	While True
		Local $iHit = StringInStr($sText, "/Length ", 0, 1, $iPos)
		If $iHit = 0 Then ExitLoop
		Local $iEnd = StringInStr($sText, $sSuffix, 0, 1, $iHit)
		If $iEnd = 0 Then ExitLoop
		Local $sDigits = StringStripWS(StringMid($sText, $iHit + 8, $iEnd - ($iHit + 8)), 8)
		If StringIsDigit($sDigits) Then
			ReDim $aFound[UBound($aFound) + 1]
			$aFound[UBound($aFound) - 1] = Int($sDigits)
		EndIf
		$iPos = $iHit + 8
	WEnd
	Return $aFound
EndFunc   ;==>_Lengths

; ------------------------------------------------------------------ documents
Global $sPlain = @TempDir & "\pdfx_comp_plain.pdf"
Global $sFlate = @ScriptDir & "\03_Compression.pdf"
Global $sOff = @TempDir & "\pdfx_comp_off.pdf"
Global $sTiny = @TempDir & "\pdfx_comp_tiny.pdf"
Global $sLevel9 = @TempDir & "\pdfx_comp_level9.pdf"

Global $bPlain = _Build(-1, $sPlain)
Global $bFlate = _Build(6, $sFlate)
Global $bOff = _Build(0, $sOff)
_Check("saves", $bPlain And $bFlate And $bOff)

Global $iSizePlain = FileGetSize($sPlain)
Global $iSizeFlate = FileGetSize($sFlate)
Global $sTextPlain = _ReadText($sPlain)
Global $sTextFlate = _ReadText($sFlate)
Global $sTextOff = _ReadText($sOff)

; ------------------------------------------------------------------ filter presence
_Check("default: no filter", StringInStr($sTextPlain, "/FlateDecode") = 0)
_Check("level 0: no filter", StringInStr($sTextOff, "/FlateDecode") = 0)
_Check("level 6: one filter per page", UBound(StringRegExp($sTextFlate, "/Filter /FlateDecode", 3)) = 2)

; ------------------------------------------------------------------ size and lengths
_Check("compressed PDF is smaller", $iSizeFlate < $iSizePlain, $iSizeFlate & " / " & $iSizePlain)

Global $aPlainLength = _Lengths($sTextPlain, " >>")
Global $aFlateLength = _Lengths($sTextFlate, " /Filter /FlateDecode")
_Check("two lengths on each side", UBound($aPlainLength) = 2 And UBound($aFlateLength) = 2)
If UBound($aPlainLength) = 2 And UBound($aFlateLength) = 2 Then
	Global $iPlainSum = Int($aPlainLength[0]) + Int($aPlainLength[1])
	Global $iFlateSum = Int($aFlateLength[0]) + Int($aFlateLength[1])
	_Check("compressed streams are shorter", $iFlateSum < $iPlainSum, $iFlateSum & " / " & $iPlainSum)
	_Check("gain of at least 3:1", $iPlainSum >= 3 * $iFlateSum, $iPlainSum & " / " & $iFlateSum)
EndIf

; ------------------------------------------------------------------ small streams and identifier
Global $oTiny = _PDFX_New("A4", "P", 18)
_PDFX_SetCompression($oTiny, 6)
_PDFX_Save($oTiny, $sTiny)
_PDFX_Close($oTiny)
_Check("stream too short left in clear", StringInStr(_ReadText($sTiny), "/FlateDecode") = 0)

_Check("/ID identical with and without compression", _DocumentId($sPlain) = _DocumentId($sFlate) And _DocumentId($sPlain) <> "")

; ------------------------------------------------------------------ guards
Global $oGuard = _PDFX_New("A4", "P", 18)
_PDFX_SetCompression($oGuard, 42)
_Check("level > 9 flagged and clamped", @error = 1)
_PDFX_SetCompression($oGuard, -3)
_Check("level < 0 flagged and clamped", @error = 1)
_PDFX_SetCompression($oGuard, 9)
_Check("level 9 accepted", @error = 0)
_PDFX_SetFont($oGuard, "Helvetica", 10)
For $iLine = 0 To 24
	_PDFX_Text($oGuard, 40, 40 + $iLine * 16, "Line " & $iLine & ": The quick brown fox jumps over the lazy dog.")
Next
_Check("save at level 9", _PDFX_Save($oGuard, $sLevel9))
_Check("level 9 compresses", StringInStr(_ReadText($sLevel9), "/FlateDecode") > 0)
_Check("setting refused after save", _PDFX_SetCompression($oGuard, 0) = False And @error = 2)
_PDFX_Close($oGuard)

; ------------------------------------------------------------------ summary
FileDelete($sPlain)
FileDelete($sOff)
FileDelete($sTiny)
FileDelete($sLevel9)
ConsoleWrite("---- " & ($g_Checks - $g_Failures) & "/" & $g_Checks & " checks passed" & @CRLF)
If $g_Failures > 0 Then Exit 1
