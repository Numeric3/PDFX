#cs ----------------------------------------------------------------------------
    02_Robustness — input guards, lifecycle and metadata.

    This script checks measurable invariants and writes a reference PDF:

        python Tools/regress.py Tests/Reference Examples Tests

    Covered:
      - alpha and colours out of range: @error = 1, values clamped to the interval
      - null dash: "[] 0 d"
      - non-ASCII title: UTF-16BE hexadecimal string
      - UTC dates (Z suffix) and deterministic MD5 /ID
      - second _PDFX_Save() and _PDFX_AddPage() after saving: @error = 2
      - header and footer with their own font, style and colour
      - Adobe CMYK JPEG: /DeviceCMYK and inverted /Decode
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

Func _MiniDocument($sPath)
	Local $oDocument = _PDFX_New("A4", "P", 18)
	_PDFX_SetMeta($oDocument, "Deterministic identifier", "Numeric1", "", "")
	_PDFX_SetFont($oDocument, "Helvetica", 10)
	_PDFX_Text($oDocument, 40, 60, "Identical content")
	_PDFX_Save($oDocument, $sPath)
	_PDFX_Close($oDocument)
EndFunc   ;==>_MiniDocument

; ------------------------------------------------------------------ document
Global $oDocument = _PDFX_New("A4", "P", 18)
_PDFX_SetMeta($oDocument, "Report " & ChrW(233) & "t" & ChrW(233) & " " & ChrW(339) & " " & ChrW(8364), _
		"Numeric1", "Robustness", "pdfx;test")
_PDFX_SetHeader($oDocument, "PDFX", "Robustness", "{date}", 8, "Courier", "B", 0xFF0000)
_PDFX_SetFooter($oDocument, "page {page}/{pages}", "", "", 7, "Times", "I", 0x1F3864)

_PDFX_SetFont($oDocument, "Helvetica", 11)

; ------------------------------------------------------------------ guards
_PDFX_SetAlpha($oDocument, 1.5)
_Check("alpha > 1 flagged", @error = 1)

_PDFX_SetAlpha($oDocument, -0.5)
_Check("alpha < 0 flagged", @error = 1)

_PDFX_SetAlpha($oDocument, 1)

_PDFX_SetFill($oDocument, "300,-5,100")
_Check("out-of-range colour flagged", @error = 1)
_PDFX_Rect($oDocument, 40, 160, 20, 20, $PDFX_FILL)

_PDFX_SetDash($oDocument, 0)

; ------------------------------------------------------------------ content
_PDFX_SetFont($oDocument, "Helvetica", 12, "B")
_PDFX_SetFill($oDocument, 0x101828)
_PDFX_Text($oDocument, 40, 80, "Input robustness")
_PDFX_SetFont($oDocument, "Helvetica", 10)
_PDFX_SetFill($oDocument, 0x333333)
_PDFX_Text($oDocument, 40, 100, "Alpha, colours and dashes are silently clamped, with @error = 1.")

Global $sCmyk = @ScriptDir & "\Assets\cmyk_adobe.jpg"
If FileExists($sCmyk) Then
	_Check("CMYK image accepted", _PDFX_Image($oDocument, $sCmyk, 40, 130, 40))
Else
	ConsoleWrite("SKIP  CMYK image missing (" & $sCmyk & ")" & @CRLF)
EndIf

; ------------------------------------------------------------------ writing
Global $sOut = @ScriptDir & "\02_Robustness.pdf"
Global $sSecond = @ScriptDir & "\02_Robustness_second.pdf"
FileDelete($sSecond)
_Check("save", _PDFX_Save($oDocument, $sOut) And @error = 0)

Global $bAgain = _PDFX_Save($oDocument, $sSecond)
_Check("second save refused", $bAgain = False And @error = 2)
_Check("second file absent", Not FileExists($sSecond))

Global $iPage = _PDFX_AddPage($oDocument)
_Check("page added after save refused", $iPage = -1 And @error = 2)

; ------------------------------------------------------------------ metadata
Global $sPdf = _ReadText($sOut)
_Check("alpha > 1 clamped to 1", StringInStr($sPdf, "/ca 1 /CA 1") > 0)
_Check("alpha < 0 clamped to 0", StringInStr($sPdf, "/ca 0 /CA 0") > 0)
_Check("colour clamped into [0, 255]", StringInStr($sPdf, "1 0 0.392 rg") > 0)
_Check("null dash clears the style", StringInStr($sPdf, "[] 0 d") > 0)
_Check("non-ASCII title in UTF-16BE", StringInStr($sPdf, "/Title <FEFF") > 0)
_Check("creation date in UTC", StringRegExp($sPdf, "D:\d{14}Z") = 1)
_Check("modification date present", StringInStr($sPdf, "/ModDate (D:") > 0)
_Check("32-byte /ID", StringRegExp($sPdf, "/ID \[<([0-9A-F]{32})><\1>\]") = 1)
_Check("Courier-Bold header font", StringInStr($sPdf, "/BaseFont /Courier-Bold") > 0)
_Check("Times-Italic footer font", StringInStr($sPdf, "/BaseFont /Times-Italic") > 0)
_Check("red header colour", StringInStr($sPdf, "1 0 0 rg") > 0)
_Check("red header rule", StringInStr($sPdf, "1 0 0 RG") > 0)

If FileExists($sCmyk) Then
	_Check("CMYK colour space", StringInStr($sPdf, "/DeviceCMYK") > 0)
	_Check("Adobe inverted decode", StringInStr($sPdf, "/Decode [1 0 1 0 1 0 1 0]") > 0)
EndIf

; ------------------------------------------------------------------ determinism
Global $sIdPath1 = @TempDir & "\pdfx_id1.pdf"
Global $sIdPath2 = @TempDir & "\pdfx_id2.pdf"
_MiniDocument($sIdPath1)
_MiniDocument($sIdPath2)
Global $sId1 = _DocumentId($sIdPath1)
Global $sId2 = _DocumentId($sIdPath2)
_Check("identical identifier for identical content", $sId1 <> "" And $sId1 = $sId2, $sId1 & " / " & $sId2)
FileDelete($sIdPath1)
FileDelete($sIdPath2)

; ------------------------------------------------------------------ summary
_PDFX_Close($oDocument)
ConsoleWrite("---- " & ($g_Checks - $g_Failures) & "/" & $g_Checks & " checks passed" & @CRLF)
If $g_Failures > 0 Then Exit 1
