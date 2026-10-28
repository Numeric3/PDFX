#cs ----------------------------------------------------------------------------
    04_Navigation — hierarchical bookmarks, internal links and opening mode.

    This script checks measurable invariants and writes a reference PDF:

        python Tools/regress.py Tests/Reference Examples Tests
        python Tools/pdfcheck.py Tests/04_Navigation.pdf
        python Tools/outline.py Tests/04_Navigation.pdf

    Covered:
      - eight bookmarks over five pages, levels 0 to 2
      - a level that is too deep is clamped to the previous level + 1
      - ASCII titles in literal form, accented title in UTF-16BE
      - /Count = number of descendants, First/Last and Parent/Prev/Next chains
      - /Fit and /XYZ destinations (y converted for each page)
      - internal link to a page created later, out-of-range link ignored
      - /PageMode, /PageLayout, automatic UseOutlines mode with bookmarks
      - lifecycle: settings refused after _PDFX_Save
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

Func _PageRefs($sPdf)
	Local $aKids = StringRegExp($sPdf, "/Kids \[([^\]]*)\]", 1)
	If UBound($aKids) <> 1 Then Return 0
	Local $aRefs = StringRegExp($aKids[0], "\d+ 0 R", 3)
	For $iIndex = 0 To UBound($aRefs) - 1
		$aRefs[$iIndex] = StringReplace($aRefs[$iIndex], " 0 R", "")
	Next
	Return $aRefs
EndFunc   ;==>_PageRefs

Func _Item($sPdf, $sTitle)
	Local $aMatch = StringRegExp($sPdf, "/Title " & $sTitle & "[^\r\n]*", 1)
	If UBound($aMatch) = 1 Then Return $aMatch[0]
	Return ""
EndFunc   ;==>_Item

Func _MinimalDocument($sPath, $sMode = "")
	Local $oDocument = _PDFX_New("A4", "P", 18)
	_PDFX_SetMeta($oDocument, "No bookmarks", "Numeric1", "", "")
	If $sMode <> "" Then _PDFX_SetPageMode($oDocument, $sMode)
	_PDFX_SetFont($oDocument, "Helvetica", 12)
	_PDFX_Text($oDocument, 40, 60, "Document without navigation")
	_PDFX_Save($oDocument, $sPath)
	_PDFX_Close($oDocument)
EndFunc   ;==>_MinimalDocument

; ------------------------------------------------------------------ document
Global $oDocument = _PDFX_New("A4", "P", 18)
_PDFX_SetMeta($oDocument, "Navigation manual", "Numeric1", "Bookmarks and internal links", "pdfx;bookmarks")
_PDFX_SetCompression($oDocument, 6)
_PDFX_SetHeader($oDocument, "Manual", "Navigation", "{date}")
_PDFX_SetFooter($oDocument, "page {page}/{pages}", "", "")
_PDFX_SetFont($oDocument, "Helvetica", 24, "B")
_PDFX_Text($oDocument, 40, 60, "Navigation manual")

Global $aAdded[8]
$aAdded[0] = _PDFX_AddBookmark($oDocument, "Cover", 0, 1)

_PDFX_AddPage($oDocument)
_PDFX_Text($oDocument, 40, 60, "Contents")
_Check("forward page link accepted", _PDFX_LinkPage($oDocument, 40, 110, 300, 14, 3))
_Check("out-of-range page link accepted", _PDFX_LinkPage($oDocument, 40, 136, 300, 14, 99))

_PDFX_AddPage($oDocument)
_PDFX_Text($oDocument, 40, 60, "Chapter 1")

_PDFX_AddPage($oDocument)
_PDFX_Text($oDocument, 40, 60, "Chapter 2")

_PDFX_AddPage($oDocument)
_PDFX_Text($oDocument, 40, 60, "Appendix")

$aAdded[1] = _PDFX_AddBookmark($oDocument, "Contents", 0, 2, 40)
$aAdded[2] = _PDFX_AddBookmark($oDocument, "Chapter 1", 1, 3)
$aAdded[3] = _PDFX_AddBookmark($oDocument, "Section 1.1", 2, 3, 60)
$aAdded[4] = _PDFX_AddBookmark($oDocument, "Section 1.2", 2, 4)
$aAdded[5] = _PDFX_AddBookmark($oDocument, "Chapter 2", 1, 5)
$aAdded[6] = _PDFX_AddBookmark($oDocument, "Appendix", 0, 5)
$aAdded[7] = _PDFX_AddBookmark($oDocument, "R" & ChrW(233) & "sum" & ChrW(233), 5, 1)
_Check("eight bookmarks numbered", $aAdded[0] = 1 And $aAdded[7] = 8)

; ------------------------------------------------------------------ guards
_Check("empty title refused", _PDFX_AddBookmark($oDocument, "  ", 0, 1) = -1 And @error = 1)
_Check("page zero refused", _PDFX_AddBookmark($oDocument, "Off page", 0, 0) = -1 And @error = 1)
_Check("missing page refused", _PDFX_AddBookmark($oDocument, "Off page", 0, 99) = -1 And @error = 1)
_Check("link to page zero refused", _PDFX_LinkPage($oDocument, 40, 162, 300, 14, 0) = False And @error = 1)

_Check("outline mode accepted", _PDFX_SetPageMode($oDocument, "useoutlines"))
_Check("unknown mode refused", _PDFX_SetPageMode($oDocument, "Sidebar") = False And @error = 1)
_Check("layout accepted", _PDFX_SetPageLayout($oDocument, "TwoColumnLeft"))
_Check("unknown layout refused", _PDFX_SetPageLayout($oDocument, "Mosaic") = False And @error = 1)

; ------------------------------------------------------------------ writing
Global $sOut = @ScriptDir & "\04_Navigation.pdf"
Global $sSecond = @ScriptDir & "\04_Navigation_second.pdf"
FileDelete($sOut)
FileDelete($sSecond)
_Check("save", _PDFX_Save($oDocument, $sOut) And @error = 0)

Global $bAgain = _PDFX_Save($oDocument, $sSecond)
_Check("second save refused", $bAgain = False And @error = 2)
_Check("second file absent", Not FileExists($sSecond))
_Check("bookmark after save refused", _PDFX_AddBookmark($oDocument, "Late") = -1 And @error = 2)
_Check("link after save refused", _PDFX_LinkPage($oDocument, 40, 188, 300, 14, 2) = False And @error = 2)
_Check("mode after save refused", _PDFX_SetPageMode($oDocument, "UseNone") = False And @error = 2)
_Check("layout after save refused", _PDFX_SetPageLayout($oDocument, "SinglePage") = False And @error = 2)

; ------------------------------------------------------------------ structure
Global $sPdf = _ReadText($sOut)
Global $aPages = _PageRefs($sPdf)
_Check("five pages referenced", UBound($aPages) = 5)
_Check("catalog references the outline", StringRegExp($sPdf, "/Outlines \d+ 0 R") = 1)
_Check("catalog mode and layout", StringInStr($sPdf, "/PageMode /UseOutlines") > 0 And _
		StringInStr($sPdf, "/PageLayout /TwoColumnLeft") > 0)
_Check("outline root", StringRegExp($sPdf, "/Type /Outlines /First \d+ 0 R /Last \d+ 0 R /Count 8") = 1)
_Check("ASCII titles", StringInStr($sPdf, "/Title (Cover)") > 0 And StringInStr($sPdf, "/Title (Appendix)") > 0)
_Check("accented title in UTF-16BE", StringInStr($sPdf, "/Title <FEFF") > 0)
_Check("chapter counting two sections", StringRegExp($sPdf, "(?s)/Title \(Chapter 1\).*?/Count 2") = 1)
_Check("deep level clamped under Appendix", StringRegExp($sPdf, "(?s)/Title \(Appendix\).*?/Count 1") = 1)
_Check("Parent and Prev/Next chains", StringInStr(_Item($sPdf, "\(Chapter 1\)"), "/Parent ") > 0 And _
		StringInStr(_Item($sPdf, "\(Section 1.1\)"), "/Next ") > 0 And _
		StringInStr(_Item($sPdf, "\(Section 1.1\)"), "/Prev ") = 0 And _
		StringInStr(_Item($sPdf, "\(Section 1.2\)"), "/Prev ") > 0 And _
		StringInStr(_Item($sPdf, "\(Section 1.2\)"), "/Next ") = 0)
_Check("cover /Fit destination", StringInStr(_Item($sPdf, "\(Cover\)"), "/Dest [" & $aPages[0] & " 0 R /Fit]") > 0, $aPages[0])
_Check("section /XYZ destination", StringRegExp(_Item($sPdf, "\(Section 1.1\)"), "/Dest \[" & $aPages[2] & " 0 R /XYZ 0 [0-9.]+ null\]") = 1)

; ------------------------------------------------------------------ links
Global $aLink = StringRegExp($sPdf, "/Subtype /Link[^\r\n]*", 1)
_Check("a single link annotation", UBound($aLink) = 1)
If UBound($aLink) = 1 Then
	_Check("internal link to the third page", StringInStr($aLink[0], "/Dest [" & $aPages[2] & " 0 R /Fit]") > 0, $aLink[0])
	_Check("link without placeholder", StringInStr($aLink[0], "[0 0 R") = 0)
EndIf
_Check("page two carries the annotation", StringRegExp($sPdf, "/Annots \[\d+ 0 R\]") = 1)

; ------------------------------------------------------------------ automatic mode
Global $sAuto = @TempDir & "\pdfx_nav_auto.pdf"
FileDelete($sAuto)
Global $oAuto = _PDFX_New("A4", "P", 18)
_PDFX_SetFont($oAuto, "Helvetica", 12)
_PDFX_Text($oAuto, 40, 60, "Automatic mode")
_PDFX_AddBookmark($oAuto, "Unique", 0, 1)
_PDFX_Save($oAuto, $sAuto)
_PDFX_Close($oAuto)
Global $sAutoPdf = _ReadText($sAuto)
_Check("automatic outline mode", StringInStr($sAutoPdf, "/PageMode /UseOutlines") > 0)
FileDelete($sAuto)

Global $sPlain = @TempDir & "\pdfx_nav_plain.pdf"
Global $sNone = @TempDir & "\pdfx_nav_none.pdf"
_MinimalDocument($sPlain)
_MinimalDocument($sNone, "UseNone")
Global $sPlainPdf = _ReadText($sPlain)
Global $sNonePdf = _ReadText($sNone)
_Check("document without bookmarks: no outline", StringInStr($sPlainPdf, "/Outlines") = 0 And _
		StringInStr($sPlainPdf, "/PageMode") = 0)
_Check("document without bookmarks: explicit mode", StringInStr($sNonePdf, "/Outlines") = 0 And _
		StringInStr($sNonePdf, "/PageMode /UseNone") > 0)
FileDelete($sPlain)
FileDelete($sNone)

; ------------------------------------------------------------------ summary
_PDFX_Close($oDocument)
ConsoleWrite("---- " & ($g_Checks - $g_Failures) & "/" & $g_Checks & " checks passed" & @CRLF)
If $g_Failures > 0 Then Exit 1
