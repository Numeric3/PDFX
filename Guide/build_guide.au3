#cs ----------------------------------------------------------------------------
    build_guide — generates Guide\PDFX_Developer_Guide.pdf with PDFX itself.

    The guide is built twice. The first pass records the page on which each
    chapter starts; the second pass writes those numbers in the table of
    contents. Chapter layouts do not depend on the numbers, so the two passes
    paginate identically.

    Author: Numeric1 — https://www.autoitscript.com/forum/
#ce ----------------------------------------------------------------------------

#include "../PDFX.au3"

Global $g_Doc = 0
Global $g_Pass = 1
Global $g_Ch = 0
Global $g_Y = 0
Global $g_ChapterTitle = ""
Global $g_PageNo[18]
Global $g_ChapterY[18]

Global $g_X = 0
Global $g_W = 0
Global $g_Top = 0
Global $g_Bottom = 0

Global Const $G_INK = 0x1B2433
Global Const $G_BODY = 0x333B4A
Global Const $G_DARK = 0x1F3864
Global Const $G_ACCENT = 0x2E75B6
Global Const $G_MUTED = 0x6B7484
Global Const $G_RULE = 0xD8DFE8
Global Const $G_PANEL = 0xF3F6FB
Global Const $G_NOTEBG = 0xEAF1FB

Global $g_Titles[17][2] = [ _
    ["01", "Why PDFX"], _
    ["02", "Quick start"], _
    ["03", "The document model"], _
    ["04", "Coordinates and units"], _
    ["05", "Text and fonts"], _
    ["06", "Colour, stroke and opacity"], _
    ["07", "Shapes"], _
    ["08", "Images"], _
    ["09", "Tables"], _
    ["10", "Header, footer and metadata"], _
    ["11", "Navigation"], _
    ["12", "Saving and validity"], _
    ["13", "Compression"], _
    ["14", "Testing and validation"], _
    ["15", "Performance and limits"], _
    ["16", "API reference"], _
    ["17", "References and licence"]]

; ================================================================== driver
Global $sOut = @ScriptDir & "\PDFX_Developer_Guide.pdf"

ConsoleWrite("Pass 1: layout and page numbers..." & @CRLF)
_G_Build(1)
_PDFX_Close($g_Doc)

ConsoleWrite("Pass 2: final document..." & @CRLF)
_G_Build(2)
If Not _PDFX_Save($g_Doc, $sOut) Then
    ConsoleWrite("! Save failed, @error=" & @error & @CRLF)
    Exit 1
EndIf
Global $iPages = _PDFX_PageCount($g_Doc)
_PDFX_Close($g_Doc)

ConsoleWrite("OK " & $sOut & " (" & FileGetSize($sOut) & " bytes, " & $iPages & " pages)" & @CRLF)

; ================================================================== document
Func _G_Build($iPass)
    $g_Pass = $iPass
    $g_Ch = 0
    $g_Y = 0
    $g_ChapterTitle = ""
    $g_Doc = _PDFX_New("A4", "P", 20)

    $g_X = _PDFX_Mm(20)
    $g_W = _PDFX_PageWidth($g_Doc) - 2 * $g_X
    $g_Top = _PDFX_Mm(38)
    $g_Bottom = _PDFX_PageHeight($g_Doc) - _PDFX_Mm(27)

    _PDFX_SetMeta($g_Doc, "PDFX Developer Guide", "Numeric1", _
        "Writing PDF files in pure AutoIt — text, shapes, images, tables, navigation", _
        "pdf;autoit;guide;tutorial;iso 32000")
    _PDFX_SetCompression($g_Doc, 6)
    _PDFX_SetHeader($g_Doc, "PDFX 1.4", "Developer guide", "ISO 32000-1", 7.5, "Helvetica", "", 0x8A94A6)
    _PDFX_SetFooter($g_Doc, "Numeric1  ·  autoitscript.com/forum", "", "{page} / {pages}", 7.5, "Helvetica", "", 0x8A94A6)
    _PDFX_SetPageMode($g_Doc, "UseOutlines")
    _PDFX_SetPageLayout($g_Doc, "SinglePage")

    _G_Cover()
    _G_Toc()
    _G_Ch01()
    _G_Ch02()
    _G_Ch03()
    _G_Ch04()
    _G_Ch05()
    _G_Ch06()
    _G_Ch07()
    _G_Ch08()
    _G_Ch09()
    _G_Ch10()
    _G_Ch11()
    _G_Ch12()
    _G_Ch13()
    _G_Ch14()
    _G_Ch15()
    _G_Ch16()
    _G_Ch17()
EndFunc

; ================================================================== helpers
Func _G_Push(ByRef $aArray, $vValue)
    Local $iCount = UBound($aArray)
    ReDim $aArray[$iCount + 1]
    $aArray[$iCount] = $vValue
EndFunc

Func _G_FitCount($sLine, $fWidth, $iSize)
    Local $iCount = StringLen($sLine)
    While $iCount > 1 And _PDFX_TextWidth($g_Doc, StringLeft($sLine, $iCount), $iSize) > $fWidth
        $iCount -= 1
    WEnd
    Return $iCount
EndFunc

Func _G_WrapLines($sText, $fWidth, $iSize, $sFamily = "Helvetica", $sStyle = "")
    _PDFX_SetFont($g_Doc, $sFamily, $iSize, $sStyle)
    Local $aOut[0]
    Local $aParas = StringSplit(StringReplace($sText, @CRLF, @LF), @LF, 2)
    For $iPara = 0 To UBound($aParas) - 1
        Local $sPara = $aParas[$iPara]
        If $sPara = "" Then
            _G_Push($aOut, "")
            ContinueLoop
        EndIf
        Local $aWords = StringSplit($sPara, " ", 2)
        Local $sLine = ""
        For $iWord = 0 To UBound($aWords) - 1
            Local $sWord = $aWords[$iWord]
            If $sLine = "" Then
                $sLine = $sWord
            ElseIf _PDFX_TextWidth($g_Doc, $sLine & " " & $sWord, $iSize) <= $fWidth Then
                $sLine &= " " & $sWord
            Else
                _G_Push($aOut, $sLine)
                $sLine = $sWord
            EndIf
            While _PDFX_TextWidth($g_Doc, $sLine, $iSize) > $fWidth And StringLen($sLine) > 1
                Local $iCut = _G_FitCount($sLine, $fWidth, $iSize)
                _G_Push($aOut, StringLeft($sLine, $iCut))
                $sLine = StringMid($sLine, $iCut + 1)
            WEnd
        Next
        _G_Push($aOut, $sLine)
    Next
    Return $aOut
EndFunc

Func _G_NewPage()
    _PDFX_AddPage($g_Doc)
    $g_Y = $g_Top

    If $g_ChapterTitle <> "" Then
        _PDFX_SetFill($g_Doc, 0x8A94A6)
        _PDFX_SetFont($g_Doc, "Helvetica", 7.5)
        _PDFX_Text($g_Doc, $g_X, $g_Y, $g_ChapterTitle & "  (continued)", 7.5)

        _PDFX_SetStroke($g_Doc, $G_RULE)
        _PDFX_SetLineWidth($g_Doc, 0.5)
        _PDFX_Line($g_Doc, $g_X, $g_Y + _PDFX_Mm(5), $g_X + $g_W, $g_Y + _PDFX_Mm(5))
    EndIf

    $g_Y = _PDFX_Mm(48)
EndFunc

Func _G_P($sText, $iSize = 10, $fLeading = 14.6, $sFamily = "Helvetica", $sStyle = "", $vColor = 0x333B4A, $fIndent = 0)
    Local $aLines = _G_WrapLines($sText, $g_W - $fIndent, $iSize, $sFamily, $sStyle)
    For $iLine = 0 To UBound($aLines) - 1
        If $g_Y + $fLeading > $g_Bottom Then
            _G_NewPage()
            $g_Y = _PDFX_Mm(48)
        EndIf
        _PDFX_SetFill($g_Doc, $vColor)
        _PDFX_SetFont($g_Doc, $sFamily, $iSize, $sStyle)
        _PDFX_Text($g_Doc, $g_X + $fIndent, $g_Y, $aLines[$iLine], $iSize)
        $g_Y += $fLeading
    Next
    $g_Y += _PDFX_Mm(2.4)
EndFunc

Func _G_Chapter($sNumber, $sTitle, $sDeck, $bFreshPage = False)
; A chapter band opens on the current page unless fewer than 64 mm remain.
    If $bFreshPage Or $g_Y + _PDFX_Mm(64) > $g_Bottom Then
        _PDFX_AddPage($g_Doc)
        $g_Y = _PDFX_Mm(40)
    Else
        $g_Y += _PDFX_Mm(16)
    EndIf

    Local $iPage = _PDFX_PageCount($g_Doc)
    Local $fTop = $g_Y
    $g_Ch += 1
    If $g_Pass = 1 Then
        $g_PageNo[$g_Ch] = $iPage
        $g_ChapterY[$g_Ch] = $fTop
    EndIf
    $g_ChapterTitle = $sTitle

    _PDFX_SetFill($g_Doc, $G_ACCENT)
    _PDFX_SetFont($g_Doc, "Helvetica", 8.5, "B")
    _PDFX_Text($g_Doc, $g_X, $fTop, "CHAPTER " & $sNumber)

    _PDFX_SetFill($g_Doc, 0x111827)
    _PDFX_SetFont($g_Doc, "Helvetica", 25, "B")
    _PDFX_Text($g_Doc, $g_X, $fTop + _PDFX_Mm(7), $sTitle)

    _PDFX_SetStroke($g_Doc, $G_ACCENT)
    _PDFX_SetLineWidth($g_Doc, 2)
    _PDFX_Line($g_Doc, $g_X, $fTop + _PDFX_Mm(24), $g_X + _PDFX_Mm(26), $fTop + _PDFX_Mm(24))

    $g_Y = $fTop + _PDFX_Mm(32)
    _PDFX_AddBookmark($g_Doc, $sTitle, 0, $iPage, $fTop)

    If $sDeck <> "" Then _G_P($sDeck, 10.5, 15.6, "Times", "I", 0x556070)
EndFunc

Func _G_H2($sTitle, $bBookmark = True, $fReserveMm = 42)
    If $g_Y + _PDFX_Mm($fReserveMm) > $g_Bottom Then
        _G_NewPage()
        $g_Y = _PDFX_Mm(48)
    EndIf
    $g_Y += _PDFX_Mm(2.5)
    _PDFX_SetFill($g_Doc, $G_DARK)
    _PDFX_SetFont($g_Doc, "Helvetica", 13, "B")
    _PDFX_Text($g_Doc, $g_X, $g_Y, $sTitle, 13)
    If $bBookmark Then _PDFX_AddBookmark($g_Doc, $sTitle, 1, _PDFX_PageCount($g_Doc), $g_Y)
    $g_Y += _PDFX_Mm(7.4)
EndFunc

Func _G_H3($sTitle, $bBookmark = False)
    If $g_Y + _PDFX_Mm(26) > $g_Bottom Then
        _G_NewPage()
        $g_Y = _PDFX_Mm(48)
    EndIf
    $g_Y += _PDFX_Mm(1.5)
    _PDFX_SetFill($g_Doc, $G_ACCENT)
    _PDFX_SetFont($g_Doc, "Helvetica", 10.5, "B")
    _PDFX_Text($g_Doc, $g_X, $g_Y, $sTitle, 10.5)
    If $bBookmark Then _PDFX_AddBookmark($g_Doc, $sTitle, 2, _PDFX_PageCount($g_Doc), $g_Y)
    $g_Y += _PDFX_Mm(5.6)
EndFunc

Func _G_Bullets($aItems, $iSize = 10, $fLeading = 14.2)
    For $iItem = 0 To UBound($aItems) - 1
        Local $aLines = _G_WrapLines($aItems[$iItem], $g_W - _PDFX_Mm(6), $iSize)
        For $iLine = 0 To UBound($aLines) - 1
            If $g_Y + $fLeading > $g_Bottom Then
                _G_NewPage()
                $g_Y = _PDFX_Mm(48)
            EndIf
            If $iLine = 0 Then
                _PDFX_SetFill($g_Doc, $G_ACCENT)
                _PDFX_Circle($g_Doc, $g_X + 3, $g_Y + 3.6, 1.4, $PDFX_FILL)
            EndIf
            _PDFX_SetFill($g_Doc, $G_BODY)
            _PDFX_SetFont($g_Doc, "Helvetica", $iSize)
            _PDFX_Text($g_Doc, $g_X + _PDFX_Mm(6), $g_Y, $aLines[$iLine], $iSize)
            $g_Y += $fLeading
        Next
        $g_Y += _PDFX_Mm(1)
    Next
    $g_Y += _PDFX_Mm(2)
EndFunc

Func _G_Code($sCode)
    Local $aLines = StringSplit(StringReplace($sCode, @CRLF, @LF), @LF, 2)
    Local $fLead = 11.2
    Local $iStart = 0

    While $iStart < UBound($aLines)
        Local $fAvailable = $g_Bottom - $g_Y - _PDFX_Mm(10)
        Local $iFit = Int($fAvailable / $fLead)
        If $iFit < 4 Then
            _G_NewPage()
            $g_Y = _PDFX_Mm(48)
            ContinueLoop
        EndIf
        Local $iCount = UBound($aLines) - $iStart
        If $iCount > $iFit Then $iCount = $iFit
        Local $fHeight = $iCount * $fLead + _PDFX_Mm(7)

        _PDFX_SetFill($g_Doc, $G_PANEL)
        _PDFX_Rect($g_Doc, $g_X, $g_Y, $g_W, $fHeight, $PDFX_FILL)
        _PDFX_SetFill($g_Doc, $G_ACCENT)
        _PDFX_Rect($g_Doc, $g_X, $g_Y, _PDFX_Mm(1.2), $fHeight, $PDFX_FILL)
        _PDFX_SetFill($g_Doc, 0x17324F)
        _PDFX_SetFont($g_Doc, "Courier", 8)
        For $iLine = 0 To $iCount - 1
            _PDFX_Text($g_Doc, $g_X + _PDFX_Mm(4), $g_Y + _PDFX_Mm(3.2) + $iLine * $fLead, $aLines[$iStart + $iLine], 8)
        Next

        $g_Y += $fHeight + _PDFX_Mm(4)
        $iStart += $iCount
        If $iStart < UBound($aLines) Then
            _G_NewPage()
            $g_Y = _PDFX_Mm(48)
        EndIf
    WEnd
EndFunc

Func _G_Note($sTitle, $sText)
    Local $aLines = _G_WrapLines($sText, $g_W - _PDFX_Mm(12), 9)
    Local $fHeight = _PDFX_Mm(15) + UBound($aLines) * 12
    If $g_Y + $fHeight > $g_Bottom Then
        _G_NewPage()
        $g_Y = _PDFX_Mm(48)
    EndIf

    _PDFX_SetFill($g_Doc, $G_NOTEBG)
    _PDFX_RoundRect($g_Doc, $g_X, $g_Y, $g_W, $fHeight, _PDFX_Mm(2), $PDFX_FILL)

    _PDFX_SetFill($g_Doc, $G_DARK)
    _PDFX_SetFont($g_Doc, "Helvetica", 8, "B")
    _PDFX_Text($g_Doc, $g_X + _PDFX_Mm(6), $g_Y + _PDFX_Mm(4.5), StringUpper($sTitle), 8)

    _PDFX_SetFill($g_Doc, 0x24303F)
    _PDFX_SetFont($g_Doc, "Helvetica", 9)
    For $iLine = 0 To UBound($aLines) - 1
        _PDFX_Text($g_Doc, $g_X + _PDFX_Mm(6), $g_Y + _PDFX_Mm(10) + $iLine * 12, $aLines[$iLine], 9)
    Next

    $g_Y += $fHeight + _PDFX_Mm(5)
EndFunc

Func _G_Table($aColumns, $aRows, $fFontSize = 8.5, $fReserveMm = 90)
    If $g_Y + _PDFX_Mm($fReserveMm) > $g_Bottom Then
        _G_NewPage()
        $g_Y = _PDFX_Mm(48)
    EndIf
    _PDFX_SetFont($g_Doc, "Helvetica", $fFontSize)
    $g_Y = _PDFX_Table($g_Doc, $g_X, $g_Y, $g_W, $aColumns, $aRows, _
        "padding=4.5;fontsize=" & $fFontSize & ";border=0.4;bordercolor=0xD8DFE8;" & _
        "headfill=0x1F3864;headcolor=0xFFFFFF;zebra=1;zebracolor=0xF6F8FC") + _PDFX_Mm(6)
EndFunc

Func _G_Flow($aSteps)
    Local $fBoxH = _PDFX_Mm(9), $fGap = _PDFX_Mm(6)
    Local $fHeight = UBound($aSteps) * $fBoxH + (UBound($aSteps) - 1) * $fGap
    If $g_Y + $fHeight > $g_Bottom Then
        _G_NewPage()
        $g_Y = _PDFX_Mm(48)
    EndIf

    For $iStep = 0 To UBound($aSteps) - 1
        Local $fTop = $g_Y + $iStep * ($fBoxH + $fGap)
        _PDFX_SetFill($g_Doc, $G_NOTEBG)
        _PDFX_RoundRect($g_Doc, $g_X + _PDFX_Mm(22), $fTop, $g_W - _PDFX_Mm(44), $fBoxH, _PDFX_Mm(2), $PDFX_FILL)
        _PDFX_SetFill($g_Doc, $G_DARK)
        _PDFX_SetFont($g_Doc, "Helvetica", 9)
        _PDFX_TextAlign($g_Doc, $g_X + _PDFX_Mm(22), $fTop + _PDFX_Mm(2.8), $g_W - _PDFX_Mm(44), $aSteps[$iStep], "C", 9)

        If $iStep < UBound($aSteps) - 1 Then
            Local $fMidX = $g_X + $g_W / 2
            _PDFX_SetStroke($g_Doc, 0x8FB2D9)
            _PDFX_SetLineWidth($g_Doc, 1)
            _PDFX_Line($g_Doc, $fMidX, $fTop + $fBoxH, $fMidX, $fTop + $fBoxH + $fGap - 3)
            Local $aHead[3][2] = [[$fMidX - 3.2, $fTop + $fBoxH + $fGap - 4], [$fMidX + 3.2, $fTop + $fBoxH + $fGap - 4], [$fMidX, $fTop + $fBoxH + $fGap]]
            _PDFX_SetFill($g_Doc, 0x8FB2D9)
            _PDFX_Polyline($g_Doc, $aHead, True, $PDFX_FILL)
        EndIf
    Next
    $g_Y += $fHeight + _PDFX_Mm(6)
EndFunc

; ================================================================== cover
Func _G_Cover()
    _PDFX_SetFill($g_Doc, $G_DARK)
    _PDFX_Rect($g_Doc, 0, _PDFX_Mm(36), _PDFX_PageWidth($g_Doc), _PDFX_Mm(114), $PDFX_FILL)
    _PDFX_SetFill($g_Doc, $G_ACCENT)
    _PDFX_Rect($g_Doc, 0, _PDFX_Mm(36), _PDFX_PageWidth($g_Doc), _PDFX_Mm(1.4), $PDFX_FILL)

    _PDFX_SetFill($g_Doc, 0xFFFFFF)
    _PDFX_SetFont($g_Doc, "Helvetica", 46, "B")
    _PDFX_Text($g_Doc, _PDFX_Mm(20), _PDFX_Mm(52), "PDFX")
    _PDFX_SetFont($g_Doc, "Helvetica", 21)
    _PDFX_Text($g_Doc, _PDFX_Mm(20), _PDFX_Mm(84), "Developer guide")

    _PDFX_SetStroke($g_Doc, 0x5B86C4)
    _PDFX_SetLineWidth($g_Doc, 1)
    _PDFX_Line($g_Doc, _PDFX_Mm(20), _PDFX_Mm(101), _PDFX_Mm(80), _PDFX_Mm(101))

    _PDFX_SetFill($g_Doc, 0xC9D8EE)
    _PDFX_SetFont($g_Doc, "Helvetica", 12.5)
    _PDFX_Text($g_Doc, _PDFX_Mm(20), _PDFX_Mm(107), "Writing PDF files in pure AutoIt, with no dependency")
    _PDFX_SetFont($g_Doc, "Helvetica", 9.5)
    _PDFX_Text($g_Doc, _PDFX_Mm(20), _PDFX_Mm(128), "Version 1.4.0  ·  AutoIt 3.3.16.1  ·  ISO 32000-1 (PDF 1.7)")
    _PDFX_Text($g_Doc, _PDFX_Mm(20), _PDFX_Mm(135), "Numeric1  ·  https://www.autoitscript.com/forum/")

    $g_Y = _PDFX_Mm(158)
    _G_P("PDFX writes the file itself — objects, cross-reference table, trailer — from a single " & _
        "#include. No COM component, no printer driver, no DLL.", 10.5, 15.2, "Helvetica", "", 0x2B3444)

    _PDFX_SetStroke($g_Doc, $G_RULE)
    _PDFX_SetLineWidth($g_Doc, 0.5)
    _PDFX_Line($g_Doc, $g_X, _PDFX_Mm(186), $g_X + $g_W, _PDFX_Mm(186))

    Local $aFigures[4] = ["42", "4", "1", "0"]
    Local $aCaption[4] = ["public functions", "worked examples", "include file", "external dependencies"]
    For $iFigure = 0 To 3
        Local $fFigureX = $g_X + $iFigure * _PDFX_Mm(42.5)
        _PDFX_SetFill($g_Doc, $G_DARK)
        _PDFX_SetFont($g_Doc, "Helvetica", 22, "B")
        _PDFX_Text($g_Doc, $fFigureX, _PDFX_Mm(191), $aFigures[$iFigure], 22)
        _PDFX_SetFill($g_Doc, $G_MUTED)
        _PDFX_SetFont($g_Doc, "Helvetica", 8.5)
        _PDFX_Text($g_Doc, $fFigureX, _PDFX_Mm(203), $aCaption[$iFigure], 8.5)
    Next

    _PDFX_SetFill($g_Doc, $G_MUTED)
    _PDFX_SetFont($g_Doc, "Helvetica", 8, "B")
    _PDFX_Text($g_Doc, $g_X, _PDFX_Mm(217), "IN THIS GUIDE")

    $g_Y = _PDFX_Mm(224)
    Local $aInside[4] = ["The document model and the coordinate system", _
        "Text with exact AFM metrics, colours, shapes, images and tables", _
        "Navigation: bookmarks, forward links and opening mode", _
        "Saving, compression, validation and the complete API reference"]
    _G_Bullets($aInside, 9.5, 14)

    _PDFX_SetStroke($g_Doc, $G_RULE)
    _PDFX_SetLineWidth($g_Doc, 0.5)
    _PDFX_Line($g_Doc, $g_X, _PDFX_Mm(256), $g_X + $g_W, _PDFX_Mm(256))

    _PDFX_SetFill($g_Doc, 0x8A94A6)
    _PDFX_SetFont($g_Doc, "Helvetica", 8)
    _PDFX_Text($g_Doc, $g_X, _PDFX_Mm(260), "Produced by the engine it documents: contents, bookmarks and links are generated by PDFX.")

    _PDFX_AddBookmark($g_Doc, "Cover", 0, 1)
EndFunc

; ================================================================== contents
Func _G_Toc()
    _PDFX_AddPage($g_Doc)
    $g_Y = _PDFX_Mm(38)

    _PDFX_SetFill($g_Doc, 0x111827)
    _PDFX_SetFont($g_Doc, "Helvetica", 24, "B")
    _PDFX_Text($g_Doc, $g_X, $g_Y, "Contents")

    _PDFX_SetFill($g_Doc, $G_MUTED)
    _PDFX_SetFont($g_Doc, "Helvetica", 9)
    _PDFX_Text($g_Doc, $g_X, _PDFX_Mm(50), "Every entry is clickable; every heading is also a bookmark in the reader pane.")

    Local $fTop = _PDFX_Mm(61)
    Local $fStep = _PDFX_Mm(11.6)

    For $iEntry = 1 To 17
        Local $fY = $fTop + ($iEntry - 1) * $fStep
        Local $iPage = $g_PageNo[$iEntry]
        Local $sPage = "··"
        If $iPage > 0 Then $sPage = StringFormat("%02d", $iPage)

        _PDFX_SetFill($g_Doc, 0xAEB8C8)
        _PDFX_SetFont($g_Doc, "Courier", 8.5)
        _PDFX_Text($g_Doc, $g_X, $fY + 0.8, $g_Titles[$iEntry - 1][0], 8.5)

        _PDFX_SetFill($g_Doc, $G_INK)
        _PDFX_SetFont($g_Doc, "Helvetica", 11, "B")
        _PDFX_Text($g_Doc, $g_X + _PDFX_Mm(11), $fY, $g_Titles[$iEntry - 1][1], 11)

        Local $fNameWidth = _PDFX_TextWidth($g_Doc, $g_Titles[$iEntry - 1][1], 11)
        _PDFX_SetStroke($g_Doc, $G_RULE)
        _PDFX_SetLineWidth($g_Doc, 0.5)
        _PDFX_Line($g_Doc, $g_X + _PDFX_Mm(13) + $fNameWidth, $fY + _PDFX_Mm(4.4), $g_X + $g_W - _PDFX_Mm(9), $fY + _PDFX_Mm(4.4))

        _PDFX_SetFill($g_Doc, $G_ACCENT)
        _PDFX_SetFont($g_Doc, "Helvetica", 9.5, "B")
        _PDFX_TextAlign($g_Doc, $g_X + $g_W - _PDFX_Mm(9), $fY - 0.6, _PDFX_Mm(9), $sPage, "R", 9.5)

        If $iPage > 0 Then
            _PDFX_LinkPage($g_Doc, $g_X - _PDFX_Mm(2), $fY - _PDFX_Mm(2), $g_W + _PDFX_Mm(4), _PDFX_Mm(10), $iPage, $g_ChapterY[$iEntry])
        EndIf
    Next

    _PDFX_SetFill($g_Doc, $G_MUTED)
    _PDFX_SetFont($g_Doc, "Helvetica", 8.5)
    _PDFX_Text($g_Doc, $g_X, _PDFX_Mm(268), "Chapters 1 to 15 build the mental model; chapter 16 is the reference to keep at hand.")

    _PDFX_AddBookmark($g_Doc, "Contents", 0, 2, _PDFX_Mm(38))
    $g_Y = $g_Bottom
EndFunc

; ================================================================== chapters
Func _G_Ch01()
    _G_Chapter("01", "Why PDFX", "A PDF writer for AutoIt, written from the specification.")

    _G_P("AutoIt handles text files, CSV, INI and GUIs very well. When the result has to be printed, " & _
        "e-mailed or archived with a stable layout, the format that opens everywhere is PDF. " & _
        "PDFX produces that file directly, from the script.")

    _G_P("The usual routes to a PDF are indirect: drive Word or Excel through COM, install a virtual " & _
        "printer, or ship a third-party DLL. Each one adds a dependency that may be missing on the " & _
        "target machine, a licence to review, or a version to maintain. PDFX has none of them: one " & _
        "include file, no registration, no temporary document.")

    _G_H2("What the engine covers")
    Local $aCols[3][3] = [["Area", 0.30, "L"], ["What PDFX provides", 0.45, "L"], ["What it does not", 0.25, "L"]]
    Local $aRows[8][3] = [ _
        ["Text", "Core 14 fonts, WinAnsi, exact metrics, wrap and align", "TTF/OTF embedding"], _
        ["Vector graphics", "Lines, rectangles, ellipses, polylines, Bezier", "Gradients, clipping paths"], _
        ["Images", "JPEG passthrough, PNG/BMP/GIF via GDI+", "JPEG 2000, SVG"], _
        ["Layout", "Paginated tables, headers, footers", "Floating boxes, columns"], _
        ["Navigation", "Bookmarks, internal and external links", "Named destinations, JavaScript"], _
        ["Metadata", "Title, author, subject, keywords, UTC dates", "XMP, PDF/A"], _
        ["Output", "PDF 1.7, FlateDecode, deterministic /ID", "Encryption, signatures, forms"], _
        ["Reading", "Nothing — the engine only writes", "Merge, extract, fill"]]
    _G_Table($aCols, $aRows, 8, 80)

    _G_H2("Design rules")
    Local $aRules[5] = [ _
        "One handle, no globals: every call receives the document and changes it. Two documents can be built at the same time.", _
        "Top-left coordinates: the number you write is the position you see; the conversion to PDF space happens once, at emission.", _
        "Exact metrics: text is measured on the real AFM tables of the standard fonts, never estimated from a character count.", _
        "Bounded inputs: a colour component or an opacity outside its range is clamped and reported with @error = 1, never silently wrapped.", _
        "Deterministic bytes: the document identifier is a fingerprint of the content, so two runs produce the same file and a regression test can compare bytes."]
    _G_Bullets($aRules)

    _G_Note("Scope", "PDFX is a writer, not a toolkit. Chapters 15 and 17 state the limits precisely: " & _
        "no reading, no encryption, no signatures, no PDF/A. Within that scope the output is complete " & _
        "and standards-compliant, and it opens identically in Acrobat, Chrome, Edge, Firefox, SumatraPDF and Preview.")
EndFunc

Func _G_Ch02()
    _G_Chapter("02", "Quick start", "Five lines from an empty folder to a file that opens.")

    _G_P("Copy PDFX.au3 next to your script, or into an include folder. AutoIt 3.3.16.1 is the reference " & _
        "version. Crypt.au3 and GDI+ ship with AutoIt and are used only to compute the document " & _
        "identifier and to convert non-JPEG images; nothing else is required.")

    _G_Code('#include "PDFX.au3"' & @CRLF & @CRLF & _
        'Global $pdf = _PDFX_New("A4", "P", 20)         ; A4 portrait, 20 mm margins' & @CRLF & _
        '_PDFX_SetFont($pdf, "Helvetica", 18, "B")' & @CRLF & _
        '_PDFX_Text($pdf, _PDFX_Mm(20), _PDFX_Mm(30), "Hello from PDFX")' & @CRLF & @CRLF & _
        '_PDFX_Save($pdf, @ScriptDir & "\hello.pdf")' & @CRLF & _
        '_PDFX_Close($pdf)')

    _G_P("_PDFX_New creates the document and its first page. The drawing calls append to the current page; " & _
        "_PDFX_Save freezes the page, applies the header and footer, and writes the file. _PDFX_Close " & _
        "releases GDI+ if the engine started it, which matters only at the end of a script that uses images. " & _
        "At the top level of a script the variable is Global; inside a function, declare it Local.")

    _G_H2("Check the result")
    _G_P("The Tools folder contains three independent Python scripts with no third-party dependency. " & _
        "The first one reads the file structure and reports anything invalid:")
    _G_Code("python Tools/pdfcheck.py hello.pdf" & @CRLF & _
        "hello.pdf: 1035 bytes, 7 objects, 1 stream (0 compressed), 0 bookmarks, 0 internal links, OK")
    _G_P("The counts vary with the content. OK at the end means the file is consistent.", 9.5, 14)

    _G_Note("If nothing happens", "A script that closes with no output has usually hit a syntax error or a " & _
        "duplicated function name. Run Au3Check.exe PDFX.au3 (or press Ctrl+F5 in SciTE) to see the line. " & _
        "An out-of-range array index stops AutoIt silently with exit code 1: check the row and column indices " & _
        "of your tables.")

    _G_H2("The four examples")
    Local $aCols2[3][3] = [["File", 0.28, "L"], ["What it demonstrates", 0.52, "L"], ["Pages", 0.20, "C"]]
    Local $aRows2[4][3] = [ _
        ["01_Report.au3", "Cover band, KPI cards, bar chart, paginated table, shapes, alpha", "2"], _
        ["02_Invoice.au3", "Business document, five-column table, totals block, link", "1"], _
        ["03_Images.au3", "JPEG passthrough, PNG conversion, three sizing rules, dedup", "1"], _
        ["04_Manual.au3", "Contents written before chapters, forward links, 11 bookmarks", "7"]]
    _G_Table($aCols2, $aRows2, 8.5, 55)

    _G_P("Each example is a complete script of fewer than 200 lines. Reading 01_Report.au3 after this " & _
        "guide is the fastest way to see the API in context.")
EndFunc

Func _G_Ch03()
    _G_Chapter("03", "The document model", "One array holds everything; every function receives it.")

    _G_P("A document is a plain AutoIt array. It contains the pages, the font and image resources, the " & _
        "current graphic state, the bookmarks, the pending links and the metadata. AutoIt passes arrays " & _
        "by reference, so no ByRef is needed at the call site: the handle is always the first argument.")

    _G_Code('Local $a = _PDFX_New("A4")   ; page 1 exists' & @CRLF & _
        'Local $b = _PDFX_New("A5", "L") ; a second, independent document' & @CRLF & _
        '_PDFX_Text($a, 56, 56, "In A")' & @CRLF & _
        '_PDFX_Text($b, 40, 40, "In B")')

    _G_H2("Lifecycle")
    Local $aSteps3[5] = ["_PDFX_New — allocates the handle, opens page 1", _
        "Drawing calls — append operators to the current page", _
        "_PDFX_AddPage — closes the page, opens the next one", _
        "_PDFX_Save — header/footer, objects, xref, trailer", _
        "_PDFX_Close — releases GDI+ and the engine state"]
    _G_Flow($aSteps3)

    _G_P("Nothing reaches the disk before _PDFX_Save. A document is written only once: after a successful " & _
        "save, _PDFX_AddPage and a second _PDFX_Save return @error = 2 instead of producing an inconsistent " & _
        "second file. If the file cannot be created, nothing is frozen and the call can be retried.")

    _G_H2("Error convention")
    _G_P("A failed call returns False (or -1, or 0, depending on its normal return type) and sets @error. " & _
        "The two values used throughout the API are:")
    Local $aCols3[3][3] = [["@error", 0.12, "C"], ["Meaning", 0.46, "L"], ["Typical call", 0.42, "L"]]
    Local $aRows3[3][3] = [ _
        ["1", "Input was clamped or is invalid; the call still succeeded", "_PDFX_SetAlpha($d, 1.4) → opacity 1"], _
        ["2", "The document is already saved and is therefore frozen", "_PDFX_AddPage($d) → -1"], _
        ["0", "Success", "—"]]
    _G_Table($aCols3, $aRows3, 8.5, 40)

    _G_Note("Why a frozen document", "Allowing a second save would silently produce two files whose xref tables " & _
        "claim the same object numbers. Returning an error is the cheapest way to make the mistake visible. " & _
        "Build a new document with _PDFX_New when the content changes.")
EndFunc

Func _G_Ch04()
    _G_Chapter("04", "Coordinates and units", "The origin is at the top left, where you expect it.")

    _G_P("PDF itself places the origin at the bottom-left corner and grows upwards. That convention comes " & _
        "from printing; it is awkward when a script thinks in screen coordinates. PDFX takes every Y " & _
        "coordinate from the top of the page and converts it once, when the operator is written.")

    _G_P("The unit is the point, 1/72 inch, in both worlds. _PDFX_Mm converts millimetres; " & _
        "_PDFX_Mm(20) is 56.69 points. The accessors _PDFX_PageWidth(), _PDFX_PageHeight() and _PDFX_Margin() " & _
        "return points as well.")

    _G_H2("Text is anchored by its top")
    _G_P("_PDFX_Text($pdf, x, y, text) places the top of the text at y, not the baseline. The visible " & _
        "top of a 12-point line lands where you asked, so blocks of text stack predictably: to place the " & _
        "next paragraph, add the leading to y, or simply use the value returned by _PDFX_TextWrap.")

    _G_Code('Local $y = _PDFX_Mm(40)' & @CRLF & _
        '$y = _PDFX_TextWrap($pdf, _PDFX_Mm(20), $y, _PDFX_Mm(170), $intro, 10)' & @CRLF & _
        '$y = _PDFX_TextWrap($pdf, _PDFX_Mm(20), $y + _PDFX_Mm(4), _PDFX_Mm(170), $body, 10)')

    _G_H2("Page formats")
    Local $aCols4[4][3] = [["Format", 0.22, "L"], ["Millimetres", 0.28, "L"], ["Points", 0.30, "L"], ["Note", 0.20, "L"]]
    Local $aRows4[6][4] = [ _
        ["A4", "210 × 297", "595.28 × 841.89", "default"], _
        ["A3", "297 × 420", "841.89 × 1190.55", ""], _
        ["A5", "148 × 210", "419.53 × 595.28", ""], _
        ["Letter", "215.9 × 279.4", "612 × 792", ""], _
        ["Legal", "215.9 × 355.6", "612 × 1008", ""], _
        ["Custom", '"WxH" in mm', "converted", 'e.g. "120x200"']]
    _G_Table($aCols4, $aRows4, 8.5, 60)
    _G_P("The third argument of _PDFX_New is the margin, in millimetres. It is used by the header, the footer, " & _
        "and by the automatic page break of _PDFX_TextWrap and _PDFX_Table. It does not clip: a rectangle " & _
        "drawn at x = 0 covers the whole width, which is how a full-bleed cover band is made.")

    _G_H2("Orientation and custom sizes")
    _G_P('Pass "P" (portrait) or "L" (landscape) as the second argument. _PDFX_AddPage accepts an explicit ' & _
        'width and height in points for mixed-format documents: _PDFX_AddPage($pdf, _PDFX_Mm(148), _PDFX_Mm(210)) ' & _
        "adds an A5 page after an A4 one.")
EndFunc

Func _G_Ch05()
    _G_Chapter("05", "Text and fonts", "Three families, fourteen fonts, exact measurements.")

    _G_P("The engine uses the fourteen standard PDF fonts. They are not embedded: every reader already " & _
        "has them, so the file stays small and no licence has to be managed. The default font is " & _
        "Helvetica 10, black, left aligned.")

    _G_H2("Families and styles")
    Local $aCols5[4][3] = [["Family", 0.22, "L"], ["Aliases", 0.28, "L"], ["Styles", 0.30, "L"], ["Use", 0.20, "L"]]
    Local $aRows5[3][4] = [ _
        ["Helvetica", "Arial, sans", "normal, B, I, BI", "running text, UI"], _
        ["Times", "serif", "normal, B, I, BI", "body copy, quotes"], _
        ["Courier", "mono", "normal, B, I, BI", "code, columns"]]
    _G_Table($aCols5, $aRows5, 8.5, 45)

    _G_Code('_PDFX_SetFont($pdf, "Times", 11, "I")   ; family, size, style' & @CRLF & _
        '_PDFX_Text($pdf, 56, 72, "Text with a top-anchored Y")' & @CRLF & _
        '_PDFX_TextAlign($pdf, 56, 100, _PDFX_Mm(80), "Centred", "C")' & @CRLF & _
        'Local $w = _PDFX_TextWidth($pdf, $label, 11) ; exact width, in points')

    _G_H2("Encoding")
    _G_P("Text is written in WinAnsi, the Windows code page 1252. French, German, Spanish and Italian " & _
        "accented letters pass through unchanged, with the guillemets, the euro sign, the degree sign, " & _
        "the plus-minus sign, the middle dot, the ellipsis and the em dash. A character outside WinAnsi " & _
        "(CJK, Cyrillic, emoji) becomes a question mark rather than corrupting the file. Save the .au3 " & _
        "file as UTF-8 so that accented literals arrive intact.")

    _G_H2("Three text functions")
    Local $aTextFns[3] = [ _
        "_PDFX_Text writes one line at a given point. No wrapping, no clipping: the caller decides where the line ends.", _
        "_PDFX_TextAlign writes one line inside a horizontal box, aligned left, centre or right. It is the tool for table-like layouts.", _
        "_PDFX_TextWrap wraps a paragraph at a width and returns the top of the next free line, which makes chained paragraphs natural."]
    _G_Bullets($aTextFns)

    _G_P("_PDFX_TextWrap accepts a leading (0 means 1.2 times the size), an alignment, and a page-break " & _
        "flag. With the flag set to True, a paragraph that reaches the bottom margin adds a page and " & _
        "continues on it. The continuation starts at the document margin: when the page carries a running " & _
        "header, leave the flag off and manage the break yourself, as the examples do.")

    _G_Note("Why AFM tables", "A width estimated as characters × 0.5 em drifts by several points per line: " & _
        "right-aligned columns stop lining up and centred titles look off-centre. PDFX carries the AFM " & _
        "widths of the fourteen standard fonts, so _PDFX_TextWidth returns the exact advance needed by " & _
        "the alignment and by the word wrapper.")
EndFunc

Func _G_Ch06()
    _G_Chapter("06", "Colour, stroke and opacity", "A small graphic state, changed by explicit calls.")

    _G_P("Fill and stroke are two separate colours. _PDFX_SetFill paints the interior of shapes and the " & _
        "glyphs of text; _PDFX_SetStroke paints lines, outlines and table borders. Both accept the same " & _
        "four forms: an integer 0xRRGGBB, a colour name, an array [R, G, B], or the string ""R,G,B"".")

    _G_Code('_PDFX_SetFill($pdf, 0x1F3864)          ; hex' & @CRLF & _
        '_PDFX_SetStroke($pdf, "navy")           ; name' & @CRLF & _
        '_PDFX_SetFill($pdf, "46,117,182")       ; string components' & @CRLF & _
        'Local $aNavy[3] = [31, 56, 100]' & @CRLF & _
        '_PDFX_SetStroke($pdf, $aNavy)           ; zero-based array')

    _G_P("An array is read from index 0, so a StringSplit() result is not suitable: its first element is the " & _
        "count. Build the array explicitly, as above. Names are matched case-insensitively: black, white, red, green, blue, gray (or grey), lightgray, " & _
        "navy, teal, orange, purple (or violet), yellow, silver, maroon, olive, lime, aqua (or cyan), " & _
        "fuchsia (or magenta). An unknown name is treated as an integer and gives black.")

    _G_H2("Clamping")
    _G_P("Components outside 0..255, or an opacity outside 0..1, are clamped into range and reported once: " & _
        "the call succeeds, @error is 1. The result is always a valid colour; the error tells you that the " & _
        "value you passed was not what you meant.")

    _G_H2("Width, dash and opacity")
    Local $aCols6[3][3] = [["Call", 0.34, "L"], ["Effect", 0.44, "L"], ["Default", 0.22, "L"]]
    Local $aRows6[4][3] = [ _
        ["_PDFX_SetLineWidth($d, $w)", "Stroke width in points; 0 or less becomes 0.1", "1"], _
        ["_PDFX_SetDash($d, $on, $off)", "Dash pattern; $off = 0 reuses $on; $on = 0 restores solid", "solid"], _
        ["_PDFX_SetAlpha($d, $a, $stroke)", "Fill and stroke opacity; negative stroke = same as fill", "1"], _
        ["_PDFX_SetDash($d, 0)", "Emits [] 0 d and restores a solid line", "solid"]]
    _G_Table($aCols6, $aRows6, 8.5, 55)

    _G_P("Opacity is implemented with an ExtGState entry, /ca for the fill and /CA for the stroke. The " & _
        "engine creates one object per distinct pair of values and reuses it, so repeating the same opacity " & _
        "costs nothing. Set it back to 1 before drawing content that must stay opaque.")

    _G_Note("State is sequential", "There is no stack of graphic states to push and pop. Each call changes the " & _
        "current state until the next call changes it, exactly like a drawing program. Set the colour " & _
        "immediately before the shape that needs it.")
EndFunc

Func _G_Ch07()
    _G_Chapter("07", "Shapes", "Seven primitives, one style flag.")

    _G_P("Every shape receives a style: $PDFX_STROKE draws the outline, $PDFX_FILL paints the interior, " & _
        "$PDFX_BOTH does both. The fill colour is the one set by _PDFX_SetFill, the outline uses " & _
        "_PDFX_SetStroke, the current width and the current dash pattern.")

    Local $aCols7[3][3] = [["Call", 0.41, "L"], ["Geometry", 0.41, "L"], ["Style", 0.18, "C"]]
    Local $aRows7[7][3] = [ _
        ["_PDFX_Line($d, x1, y1, x2, y2)", "Segment; stroke only", "—"], _
        ["_PDFX_Rect($d, x, y, w, h, $style)", "Axis-aligned rectangle", "all"], _
        ["_PDFX_RoundRect($d, x, y, w, h, $r, $style)", "Rectangle with a corner radius", "all"], _
        ["_PDFX_Ellipse($d, cx, cy, rx, ry, $style)", "Centre and two radii", "all"], _
        ["_PDFX_Circle($d, cx, cy, $r, $style)", "Centre and radius", "all"], _
        ["_PDFX_Polyline($d, $points, $close, $style)", "[n][2] array of x, y pairs", "all"], _
        ["_PDFX_Bezier($d, x1, y1, c1x, c1y, c2x, c2y, x2, y2, $style)", "Cubic curve, two control points", "all"]]
    _G_Table($aCols7, $aRows7, 8, 75)

    _G_Code('_PDFX_SetFill($pdf, 0xE8EEF7)' & @CRLF & _
        '_PDFX_SetStroke($pdf, 0x1F3864)' & @CRLF & _
        '_PDFX_SetLineWidth($pdf, 1.2)' & @CRLF & _
        '_PDFX_RoundRect($pdf, _PDFX_Mm(20), _PDFX_Mm(40), _PDFX_Mm(55), _PDFX_Mm(22), _PDFX_Mm(4), $PDFX_BOTH)' & @CRLF & @CRLF & _
        'Local $aPoints[4][2] = [[10, 10], [40, 10], [40, 30], [10, 30]]' & @CRLF & _
        '_PDFX_Polyline($pdf, $aPoints, True, $PDFX_FILL)')

    _G_P("Coordinates always describe the bounding box or the centre in the top-left system, so a shape " & _
        "placed at y = 40 mm starts 40 mm from the top edge. Curves are written with the native PDF " & _
        "operator c; there is no approximation by line segments.")

    _G_Note("Text uses the fill colour", "There is no separate text colour. _PDFX_SetFill sets the colour of " & _
        "both text and shape interiors, which keeps the mental model small: one fill, one stroke, shared " & _
        "by everything drawn afterwards.")
EndFunc

Func _G_Ch08()
    _G_Chapter("08", "Images", "JPEG bytes are copied, not re-encoded.")

    _G_P("_PDFX_Image inserts a JPEG, PNG, BMP or GIF file. The path can be relative to the script; " & _
        "build it from @ScriptDir when the document is produced from another working directory.")

    _G_H2("Two paths, one object")
    Local $aCols8[4][3] = [["Input", 0.20, "L"], ["Path through the engine", 0.46, "L"], ["Quality", 0.19, "L"], ["Speed", 0.15, "L"]]
    Local $aRows8[3][4] = [ _
        ["JPEG", "Stream copied byte for byte, /DCTDecode", "unchanged", "instant"], _
        ["PNG, BMP, GIF", "Drawn on white by GDI+, encoded as JPEG", "JPEG q≈85", "slower"], _
        ["TIFF", "Same GDI+ path when the codec is installed", "JPEG q≈85", "slower"]]
    _G_Table($aCols8, $aRows8, 8.5, 50)

    _G_P("A JPEG is never decoded. The engine reads its SOF marker to learn the pixel size and the number " & _
        "of components: 1 is greyscale, 3 is RGB, 4 is CMYK. A CMYK file carrying the Adobe APP14 marker is " & _
        "declared with /Decode [1 0 1 0 1 0 1 0], because Adobe stores inverted values; without the marker " & _
        "the PDF order is used. The result is a PDF whose embedded image is exactly the original file.")

    _G_P("PNG, BMP and GIF files are converted through GDI+ to JPEG on a white background. The alpha " & _
        "channel is flattened: a transparent logo becomes white, which is the expected behaviour for " & _
        "print. A PNG image is therefore stored approximately at the size of an equivalent JPEG, not at " & _
        "its original PNG size.")

    _G_H2("Sizing rules")
    Local $aCols8b[3][3] = [["Arguments", 0.34, "L"], ["Result", 0.46, "L"], ["Example", 0.20, "L"]]
    Local $aRows8b[4][3] = [ _
        ["width, height = 0", "Natural size at 96 dpi", "0, 0"], _
        ["width only", "Height deduced from the aspect ratio", "48 mm, 0"], _
        ["height only", "Width deduced from the aspect ratio", "0, 30 mm"], _
        ["both", "Exact rectangle: proportions are not preserved", "48, 24 mm"]]
    _G_Table($aCols8b, $aRows8b, 8.5, 55)

    _G_Code('_PDFX_Image($pdf, $jpg, _PDFX_Mm(20), _PDFX_Mm(40), _PDFX_Mm(48), 0)   ; height inferred' & @CRLF & _
        '_PDFX_ImageFit($pdf, $logo, _PDFX_Mm(80), _PDFX_Mm(40), _PDFX_Mm(50), _PDFX_Mm(50), "C")' & @CRLF & _
        'Local $a = _PDFX_ImageInfo($pdf, $jpg)' & @CRLF & _
        'ConsoleWrite($a[0] & " x " & $a[1] & " px, " & $a[4] & " bytes, " & $a[5] & @CRLF)')

    _G_P("_PDFX_ImageInfo returns width and height in pixels (0 and 1), the natural size in points at 96 dpi " & _
        "(2 and 3), the file size in bytes (4) and the extension in upper case (5). It registers the image " & _
        "in the document even if nothing is drawn, which is harmless.")

    _G_H2("Deduplication")
    _G_P("Images are cached by absolute path. Inserting the same file ten times creates one XObject and ten " & _
        "references to it: the file size grows once. Copying a file to a second name defeats the cache, " & _
        "because the key is the path.")

    _G_Note("Progressive JPEG", "Progressive files are accepted but rendered unevenly by some readers. " & _
        "Saving the image as baseline JPEG (GDI+ does this by default) removes the ambiguity. The engine " & _
        "does not re-encode a JPEG, so it cannot convert one for you.")
EndFunc

Func _G_Ch09()
    _G_Chapter("09", "Tables", "Columns as fractions, pagination included.")

    _G_P("_PDFX_Table draws a header row, a grid and the data, and paginates by itself. Columns are described " & _
        "by an [n][3] array: title, width fraction, alignment. Fractions are normalised, so 0.6 / 0.15 / 0.25 " & _
        "and 6 / 1.5 / 2.5 produce the same layout.")

    _G_Code('Local $aCols[3][3] = [ _' & @CRLF & _
        '    ["Item",  0.60, "L"], _' & @CRLF & _
        '    ["Qty",   0.15, "C"], _' & @CRLF & _
        '    ["Total", 0.25, "R"]]' & @CRLF & @CRLF & _
        'Local $aRows[2][3] = [ _' & @CRLF & _
        '    ["Design", "1", "1,450.00"], _' & @CRLF & _
        '    ["Print",  "2",   "640.00"]]' & @CRLF & @CRLF & _
        'Local $y = _PDFX_Table($pdf, _PDFX_Mm(20), _PDFX_Mm(80), _PDFX_Mm(170), $aCols, $aRows, _' & @CRLF & _
        '    "padding=5;fontsize=9;zebra=1;headfill=0x1F3864;headcolor=0xFFFFFF")')

    _G_H2("Options", True, 105)
    Local $aCols9[4][3] = [["Option", 0.24, "L"], ["Default", 0.26, "L"], ["Role", 0.32, "L"], ["Range", 0.18, "L"]]
    Local $aRows9[10][4] = [ _
        ["padding", "4", "Inner margin of a cell, in points", "0.."], _
        ["fontsize", "current", "Body size; the header uses the same size in bold", "> 0"], _
        ["headfill", "0xE8EEF7", "Header background; -1 removes it", "colour"], _
        ["headcolor", "0x1F3864", "Header text colour", "colour"], _
        ["zebra", "0", "1 alternates row backgrounds", "0 / 1"], _
        ["zebracolor", "0xF7F9FC", "Background of odd rows", "colour"], _
        ["border", "0.5", "Grid line width; 0 removes the lines", "0.."], _
        ["bordercolor", "0xBFC9D9", "Grid colour", "colour"], _
        ["textcolor", "0x000000", "Body text colour", "colour"], _
        ["pagebreak", "1", "0 disables the automatic page break", "0 / 1"]]
    _G_Table($aCols9, $aRows9, 8, 90)

    _G_P("The function returns the Y coordinate of the bottom of the last row, ready for the following block. " & _
        "With pagebreak = 1, a row that would cross the bottom margin starts a new page and the header is " & _
        "redrawn at the top of it. The break happens at the document margin, as with _PDFX_TextWrap, so a " & _
        "table on a page with a running header should either fit on one page or accept that the repeated " & _
        "header starts at the margin.")

    _G_Note("Cell content", "Any value is converted with String(), so numbers, booleans and expressions can be " & _
        "placed directly in the array. A cell that is too long for its column wraps onto additional lines and " & _
        "the row grows; alignment applies to every line of the cell.")
EndFunc

Func _G_Ch10()
    _G_Chapter("10", "Header, footer and metadata", "Set once, repeated on every page at save time.")

    _G_P("_PDFX_SetHeader and _PDFX_SetFooter each take three zones: left, centre and right. An empty " & _
        "string hides its zone, which makes a quiet pagination easy to compose. Three tokens are replaced " & _
        "when the document is saved: {page}, {pages} and {date}.")

    _G_Code('_PDFX_SetHeader($pdf, "ACME Ltd", "", "Annual report")' & @CRLF & _
        '_PDFX_SetFooter($pdf, "", "Page {page} / {pages}", "{date}")' & @CRLF & @CRLF & _
        '; size, family, style and colour are per document' & @CRLF & _
        '_PDFX_SetFooter($pdf, "", "Page {page} / {pages}", "", 7, "Times", "I", 0x6B7280)')

    _G_H2("Geometry")
    _G_P("The header starts at the document margin: its text is anchored there and a thin rule is drawn " & _
        "below it, at the margin plus 1.2 times the size plus 3 points. The footer sits in the bottom " & _
        "margin, its text about 14 mm above the edge for a 20 mm margin. Both are drawn after the page " & _
        "content, so a coloured band placed at the top of the page does not hide them.")

    _G_P("That ordering has a consequence worth knowing: the header is applied to every page, including a " & _
        "cover. If the cover carries a full-bleed coloured band, start the band below the header " & _
        "(around 36 mm) or accept grey text over the colour. The examples and this guide start the band " & _
        "below the header strip.")

    _G_H2("Metadata")
    _G_P("_PDFX_SetMeta fills /Title, /Author, /Subject and /Keywords. ASCII strings are written in literal " & _
        "form; anything else is written in hexadecimal UTF-16BE with a byte-order mark, so a title " & _
        "containing €, œ or a CJK character stays exact in the reader's window. /CreationDate and /ModDate " & _
        "are in universal time and end with Z, which makes the file independent of the machine's time zone.")

    _G_P("The document identifier in the trailer is an MD5 fingerprint of the content, the metadata and the " & _
        "navigation data. Two runs over the same document produce the same /ID, so the bytes can be compared " & _
        "in a regression test. Only the timestamps need neutralising, and Tools/regress.py does that.")
EndFunc

Func _G_Ch11()
    _G_Chapter("11", "Navigation", "A PDF can carry its own table of contents.")

    _G_P("Navigation in PDFX has three parts: bookmarks, which appear in the reader's pane; links, which make " & _
        "a rectangle clickable; and the opening mode, which decides what the reader shows first.")

    _G_H2("Bookmarks")
    _G_P("_PDFX_AddBookmark($pdf, $title, $level, $page, $y) adds an entry. The page is one-based, as " & _
        "everywhere in the API; the level is zero-based. Without a Y, the destination is /Fit and the whole " & _
        "page is shown. With a Y, it becomes /XYZ and the reader places that point at the top of the window.")

    _G_Code('_PDFX_AddBookmark($pdf, "Cover", 0, 1)' & @CRLF & _
        '_PDFX_AddBookmark($pdf, "Chapter 1", 1, 3)' & @CRLF & _
        '_PDFX_AddBookmark($pdf, "Section 1.1", 2, 3, _PDFX_Mm(120))' & @CRLF & _
        '_PDFX_SetPageMode($pdf, "UseOutlines")')

    _G_P("A bookmark cannot descend more than one level below the previous one. A request that goes deeper " & _
        "is clamped to that maximum without an error, so an outline built in a loop always stays valid. The " & _
        "function returns the ordinal number of the new bookmark, or -1 with @error = 1 when the title is " & _
        "empty or the page is outside the document.")

    _G_P("The tree is complete: /Parent, /Prev, /Next, /First, /Last and /Count. The /Count of a node is its " & _
        "number of descendants, and the root counts them all. Counts are positive, so every node is open. " & _
        "Titles that are pure ASCII are written literally; others use hexadecimal UTF-16BE, so an accented " & _
        "title stays exact in the pane. When bookmarks exist and no mode was requested, /PageMode " & _
        "/UseOutlines is added automatically.")

    _G_H2("Links")
    _G_P("_PDFX_Link adds a URL annotation. _PDFX_LinkPage adds an internal link and accepts a target page " & _
        "that does not exist yet: the engine keeps the request pending and resolves it at save time, when " & _
        "every page has its object number. A table of contents can therefore be written before the chapters " & _
        "it points to, without a second pass. A target that never materialises is dropped silently; only a " & _
        "page below 1 is refused immediately.")

    _G_Code('; written on the contents page, before the chapters exist' & @CRLF & _
        '_PDFX_LinkPage($pdf, $x, $y, $w, $h, 5, _PDFX_Mm(32))' & @CRLF & @CRLF & _
        '; an external link' & @CRLF & _
        '_PDFX_Link($pdf, $x, $y, $w, $h, "https://www.autoitscript.com/forum/")')

    _G_H2("Opening mode")
    Local $aCols11[3][3] = [["Call", 0.26, "L"], ["Accepted values", 0.60, "L"], ["Default", 0.14, "L"]]
    Local $aRows11[2][3] = [ _
        ["_PDFX_SetPageMode", "UseNone, UseOutlines, UseThumbs, FullScreen", "automatic"], _
        ["_PDFX_SetPageLayout", "SinglePage, OneColumn, TwoColumnLeft, TwoColumnRight, TwoPageLeft, TwoPageRight", "reader"]]
    _G_Table($aCols11, $aRows11, 8, 42)
    _G_P("Case and spaces are ignored in both lists; an empty string restores the automatic choice.")

    _G_P("After _PDFX_Save, the navigation functions return @error = 2: the document is frozen. The four " & _
        "examples and this guide all use the deferred mechanism; Tools/outline.py reads the result back " & _
        "without any dependency:")
    _G_Code("python Tools/outline.py Examples/04_Manual.pdf" & @CRLF & _
        "Cover                               page 1  /Fit" & @CRLF & _
        "Contents                            page 2  y=739.843" & @CRLF & _
        "Getting started                     page 3  y=717.165" & @CRLF & _
        "  Installation                      page 3  y=467.717" & @CRLF & _
        "---- 11 bookmark(s)")
EndFunc

Func _G_Ch12()
    _G_Chapter("12", "Saving and validity", "Offsets, xref, trailer: the file is assembled once.")

    _G_P("_PDFX_Save is the only function that touches the disk. It freezes the current page, appends the " & _
        "header and footer to every page, serialises the objects, then writes the cross-reference table, " & _
        "the trailer and startxref. The /Length of every stream is the number of bytes actually written.")

    Local $aSave[5] = ["Pages — content stream per page", _
        "Objects — catalog, page tree, fonts, XObjects, outlines", _
        "xref — one 20-byte entry per object", _
        "trailer — /Size, /Root, /Info, /ID", _
        "startxref — byte offset of the xref table"]
    _G_Flow($aSave)

    _G_H2("What the reader checks")
    Local $aChecks[5] = [ _
        "The header %PDF-1.7 and the binary comment on the second line.", _
        "startxref points to the literal token xref, and each entry points to the bytes %d 0 obj.", _
        "Each /Length matches the stream between stream and endstream, including the line break.", _
        "The trailer contains /Root and /Size, and /Size equals the number of xref entries plus one.", _
        "The page tree /Count equals the number of /Kids, and every /Kids entry is a page object."]
    _G_Bullets($aChecks)

    _G_P("Tools/pdfcheck.py verifies all of this, and inflates every FlateDecode stream with zlib: a corrupt " & _
        "stream or a wrong length is reported, which validates the compressor end to end. It also checks the " & _
        "outline chain, the /Count of each node, the /Annots arrays and every internal destination.")

    _G_Code("python Tools/pdfcheck.py Examples/01_Report.pdf" & @CRLF & _
        "01_Report.pdf: 5775 bytes, 14 objects, 2 streams (2 compressed), 0 bookmarks, 0 internal links, OK")

    _G_H2("One document, one save")
    _G_P("A document is written once. After a successful save, _PDFX_Save and _PDFX_AddPage return @error = 2 " & _
        "instead of writing a second, contradictory file. If the output path cannot be created, nothing is " & _
        "frozen: fix the path and call again. The examples delete the target first when the file may still " & _
        "be open in a reader on Windows.")

    _G_Note("Determinism", "The /ID is an MD5 digest of the version, the metadata, the page content and the " & _
        "navigation data. Two generations of the same document therefore produce the same bytes, timestamps " & _
        "aside. Tests/Reference keeps one PDF per suite, and Tools/regress.py compares them byte for byte after " & _
        "neutralising /CreationDate, /ModDate and the {date} token.")
EndFunc

Func _G_Ch13()
    _G_Chapter("13", "Compression", "FlateDecode written in AutoIt, with no DLL.")

    _G_P("Text, vectors and table grids produce long content streams full of repeated operators. " & _
        "_PDFX_SetCompression($pdf, $level) writes those streams with FlateDecode: a zlib wrapper around " & _
        "DEFLATE, implemented in the include file itself.")

    _G_Code('_PDFX_SetCompression($pdf, 6)   ; 0 = raw, 1..9 = increasing effort')

    Local $aCols13[3][3] = [["Level", 0.16, "C"], ["Search", 0.40, "L"], ["Use", 0.44, "L"]]
    Local $aRows13[4][3] = [ _
        ["0", "none — streams stay readable in a text editor", "debugging, teaching"], _
        ["1..3", "few LZ77 candidates", "drafts, interactive generation"], _
        ["6", "balanced", "recommended default"], _
        ["9", "longest chains", "archives"]]
    _G_Table($aCols13, $aRows13, 8.5, 45)

    _G_H2("How it works")
    _G_P("The compressor scans the stream with a 3-byte hash table and a chain of previous positions. The " & _
        "level bounds the number of candidates examined, which is the only difference between levels: the " & _
        "Huffman table is the fixed DEFLATE table, so decompression is the same fast path for every reader. " & _
        "A stream that does not shrink is written uncompressed, so /Filter is not guaranteed on every page.")

    _G_P("Only content streams are compressed. JPEG images stay as they are — they are already compressed — " & _
        "and dictionaries, fonts and metadata are too small to gain anything. The two example documents " & _
        "below are text-heavy; the gallery is dominated by a JPEG, hence the small gain.")

    Local $aCols13b[4][3] = [["Document", 0.34, "L"], ["Raw", 0.18, "R"], ["Level 6", 0.18, "R"], ["Gain", 0.30, "L"]]
    Local $aRows13b[3][4] = [ _
        ["01_Report.pdf", "18,505 B", "5,775 B", "about 3.2×"], _
        ["02_Invoice.pdf", "10,891 B", "3,348 B", "about 3.3×"], _
        ["03_Images.pdf", "57,906 B", "53,220 B", "about 1.1× (JPEG)"]]
    _G_Table($aCols13b, $aRows13b, 8.5, 45)

    _G_Note("Speed", "The compressor runs at roughly 30 KB/s, which is the price of pure AutoIt. It reaches the " & _
        "ratio of zlib level 1. For a very large document, lower the level or leave compression off; rendering is " & _
        "identical either way. The output remains deterministic at every level.")
EndFunc

Func _G_Ch14()
    _G_Chapter("14", "Testing and validation", "Three tools and four suites, all dependency-free.")

    _G_P("A PDF writer is easy to write and hard to trust. PDFX ships with three small Python scripts that " & _
        "read the output independently of the engine, plus four AutoIt test suites that exercise the API.")

    _G_H2("The tools")
    Local $aCols14[3][3] = [["Script", 0.24, "L"], ["What it verifies", 0.56, "L"], ["Dependency", 0.20, "L"]]
    Local $aRows14[3][3] = [ _
        ["Tools/pdfcheck.py", "Header, xref offsets, stream lengths, trailer, page tree, outline, annotations, internal destinations", "Python 3"], _
        ["Tools/outline.py", "Reads /Outlines, decodes titles, resolves each destination to a page number", "Python 3"], _
        ["Tools/regress.py", "Compares reference PDFs byte for byte, dates and {date} neutralised", "Python 3"]]
    _G_Table($aCols14, $aRows14, 8, 62)

    _G_Code("python Tools/pdfcheck.py Examples/*.pdf" & @CRLF & _
        "python Tools/outline.py Examples/04_Manual.pdf" & @CRLF & _
        "python Tools/regress.py Tests/Reference Examples Tests")

    _G_H2("The suites")
    Local $aCols14b[3][3] = [["Suite", 0.30, "L"], ["What it covers", 0.48, "L"], ["Checks", 0.22, "C"]]
    Local $aRows14b[4][3] = [ _
        ["Tests/01_Torture.au3", "Nine pages of worst cases: long words, accents, every shape, every font", "runs to end"], _
        ["Tests/02_Robustness.au3", "Clamping, frozen document, invalid arguments, UTF-16 metadata", "23/23"], _
        ["Tests/03_Compression.au3", "Round-trip of compressed streams, gain, determinism", "16/16"], _
        ["Tests/04_Navigation.au3", "Bookmark levels, counts, forward links, opening modes", "36/36"]]
    _G_Table($aCols14b, $aRows14b, 8, 62)

    _G_P("Tools/regress.py is the safety net for engine changes. Each reference PDF is regenerated by its " & _
        "suite, normalised, and compared byte for byte. A single changed byte prints DIFFERENT with both " & _
        "digests, which makes an accidental change visible before it reaches a user. The rule for the engine " & _
        "is simple: unless a behaviour is intentionally changed, the reference files must stay identical.")

    _G_Note("Adding a test", "Write a small script that saves a PDF to Tests\, run it once, copy the file into " & _
        "Tests\Reference\, and add the regeneration command to the regression run. The /ID makes the new file " & _
        "stable from the first run, so the reference does not need to be regenerated later.")
EndFunc

Func _G_Ch15()
    _G_Chapter("15", "Performance and limits", "What to expect, and what the engine deliberately omits.")

    _G_P("PDFX keeps the whole document in memory until _PDFX_Save. For the documents it targets — reports, " & _
        "invoices, manuals, certificates — that is a few megabytes at most. The cost of a save is dominated " & _
        "by compression when it is enabled, and by image conversion when PNG or BMP files are used.")

    _G_H2("Limits")
    Local $aCols15[3][3] = [["Area", 0.30, "L"], ["Status", 0.16, "C"], ["Reason", 0.54, "L"]]
    Local $aRows15[9][3] = [ _
        ["Reading, merging, splitting", "absent", "A writer is not a parser; out of scope by design"], _
        ["Encryption, signatures", "absent", "Requires cryptographic structures and key management"], _
        ["PDF/A, PDF/X", "absent", "Requires embedded fonts and colour profiles"], _
        ["TTF/OTF embedding", "absent", "Core 14 fonts cover the supported encodings"], _
        ["Transparency groups, masks", "absent", "Constant opacity through ExtGState only"], _
        ["Gradients, patterns", "absent", "Simulate with bands or an image"], _
        ["Named destinations, JavaScript", "absent", "Links and bookmarks target pages only"], _
        ["Attachments, /GoToR", "absent", "Navigation stays inside the document"], _
        ["Text extraction", "absent", "No reading; use a parser"]]
    _G_Table($aCols15, $aRows15, 8, 80)

    _G_H2("Memory")
    _G_P("Everything lives in one array until the last page is written: page content streams, image bytes, " & _
        "font references and the navigation tables. Memory grows with the amount of content, not with its " & _
        "complexity: ten thousand short lines cost less than one full-page photograph.")
    _G_P("Images are the part worth planning for. A JPEG is kept as the original bytes, so a 2 MB photograph " & _
        "costs 2 MB. A PNG or BMP is converted once, at insertion, and only the resulting JPEG is kept; the " & _
        "source file is never held in memory. The same absolute path inserted again reuses that object.")

    _G_H2("Practical advice")
    Local $aAdvice[5] = [ _
        "Reuse the font selection: fonts are cached per family, size and style, but switching between many sizes on every line produces many text objects.", _
        "Insert each image once. Deduplication is by absolute path, so the same file inserted ten times costs one stream.", _
        "Prefer JPEG for photographs: it is copied without recompression. Use PNG only for flat graphics, and remember that it becomes a JPEG on white.", _
        "Enable compression for documents that leave the machine, and leave it off while debugging: an uncompressed content stream is readable in a text editor.", _
        "Keep the number of pages reasonable. Each page has its own content stream and resources dictionary; a thousand-page document is possible but slow to build."]
    _G_Bullets($aAdvice)

    _G_P("A report of two pages with a cover band, cards, a chart and a table takes well under a second to " & _
        "produce without compression, and a few seconds with level 6. The gallery example, which converts a " & _
        "PNG through GDI+, is dominated by the conversion, not by the PDF writer.")
EndFunc

Func _G_Ch16()
    _G_Chapter("16", "API reference", "All public functions, grouped by task.")

    _G_P("Every public function takes the document handle as its first argument. Pass the variable returned " & _
        "by _PDFX_New to every call: the state travels with it. Optional arguments keep their default when " & _
        "omitted; passing 0 for a size or a width usually means ""use the current value"" or ""infer it"".")
    _G_P("Signatures are written in their shortest readable form: $doc is the handle, called $oDocument in the " & _
        "source, and parameter names lose their type prefix. AutoIt binds arguments by position, so a call " & _
        "copied from here works as written.")

    _G_ApiGroup("Document")
    _G_ApiFn('_PDFX_New($format="A4", $orient="P", $margin=15)', "Creates a document and page 1. Format: A3, A4, A5, Letter, Legal or ""WxH"" in mm. Returns the handle.", "_PDFX_New")
    _G_ApiFn('_PDFX_Mm($millimetres)', "Converts millimetres to points. Use it everywhere a coordinate is written.", "_PDFX_Mm")
    _G_ApiFn('_PDFX_AddPage($doc, $w=0, $h=0)', "Adds a page, freezes the previous one, returns its 0-based index. @error = 2 when saved.", "_PDFX_AddPage")
    _G_ApiFn('_PDFX_PageCount($doc)', "Number of pages currently in the document.", "_PDFX_PageCount")
    _G_ApiFn('_PDFX_PageWidth($doc)   _PDFX_PageHeight($doc)', "Dimensions of the current page, in points.", "_PDFX_PageWidth")
    _G_ApiFn('_PDFX_Margin($doc)', "Default margin, in points, as given to _PDFX_New.", "_PDFX_Margin")
    _G_ApiFn('_PDFX_SavePage($doc)', "Freezes the current page content without opening a new page.", "_PDFX_SavePage")

    _G_ApiGroup("Text")
    _G_ApiFn('_PDFX_SetFont($doc, $family="Helvetica", $size=0, $style="")', "Selects family, size and style (B, I, BI). Size 0 keeps the current size.", "_PDFX_SetFont")
    _G_ApiFn('_PDFX_Font($doc)   _PDFX_FontSize($doc)', "Current PDF font name and current size, in points.", "_PDFX_Font")
    _G_ApiFn('_PDFX_TextWidth($doc, $text, $size=0)', "Exact width in points, from the AFM tables of the current font.", "_PDFX_TextWidth")
    _G_ApiFn('_PDFX_Text($doc, $x, $y, $text, $size=0)', "Writes one line; y is the top of the text. No wrapping.", "_PDFX_Text")
    _G_ApiFn('_PDFX_TextAlign($doc, $x, $y, $w, $text, $align="L", $size=0)', "Writes one line aligned in a box: L, C or R.", "_PDFX_TextAlign")
    _G_ApiFn('_PDFX_TextWrap($doc, $x, $y, $w, $text, $size=0, $lead=0, $align="L", $brk=False)', "Wraps a paragraph and returns the top of the next free line. $brk adds pages at the margin.", "_PDFX_TextWrap")

    _G_ApiGroup("Graphic state")
    _G_ApiFn('_PDFX_SetFill($doc, $colour)', "Fill colour for shapes and text: 0xRRGGBB, name, [r,g,b] or ""r,g,b"". @error = 1 when clamped.", "_PDFX_SetFill")
    _G_ApiFn('_PDFX_SetStroke($doc, $colour)', "Stroke colour, same accepted forms as _PDFX_SetFill.", "_PDFX_SetStroke")
    _G_ApiFn('_PDFX_SetLineWidth($doc, $width)', "Stroke width in points; 0 or less becomes 0.1.", "_PDFX_SetLineWidth")
    _G_ApiFn('_PDFX_SetDash($doc, $on, $off=0)', "Dash pattern in points; $on = 0 restores a solid line, $off = 0 reuses $on.", "_PDFX_SetDash")
    _G_ApiFn('_PDFX_SetAlpha($doc, $alpha, $stroke=-1)', "Fill and stroke opacity in 0..1, through an ExtGState; negative stroke = same as fill.", "_PDFX_SetAlpha")

    _G_ApiGroup("Shapes")
    _G_ApiFn('_PDFX_Line($doc, $x1, $y1, $x2, $y2)', "Straight segment, stroke only.", "_PDFX_Line")
    _G_ApiFn('_PDFX_Rect($doc, $x, $y, $w, $h, $style=$PDFX_STROKE)', "Rectangle; style is $PDFX_STROKE, $PDFX_FILL or $PDFX_BOTH.", "_PDFX_Rect")
    _G_ApiFn('_PDFX_RoundRect($doc, $x, $y, $w, $h, $r, $style=$PDFX_STROKE)', "Rectangle with rounded corners of radius $r.", "_PDFX_RoundRect")
    _G_ApiFn('_PDFX_Ellipse($doc, $cx, $cy, $rx, $ry, $style=$PDFX_STROKE)', "Ellipse from its centre and two radii.", "_PDFX_Ellipse")
    _G_ApiFn('_PDFX_Circle($doc, $cx, $cy, $r, $style=$PDFX_STROKE)', "Circle from its centre and radius.", "_PDFX_Circle")
    _G_ApiFn('_PDFX_Polyline($doc, $points, $close=False, $style=$PDFX_STROKE)', "Polyline or polygon from an [n][2] array of x, y pairs.", "_PDFX_Polyline")
    _G_ApiFn('_PDFX_Bezier($doc, $x1, $y1, $c1x, $c1y, $c2x, $c2y, $x2, $y2, $style)', "Cubic Bezier curve with two control points.", "_PDFX_Bezier")

    _G_ApiGroup("Images")
    _G_ApiFn('_PDFX_Image($doc, $path, $x, $y, $w=0, $h=0)', "Inserts a JPEG, PNG, BMP or GIF. One missing dimension is inferred; both missing = natural size at 96 dpi.", "_PDFX_Image")
    _G_ApiFn('_PDFX_ImageFit($doc, $path, $x, $y, $w, $h, $align="C")', "Scales an image down to fit a box without distortion; align C, or L/R/T/B.", "_PDFX_ImageFit")
    _G_ApiFn('_PDFX_ImageInfo($doc, $path)', "Returns [pxW, pxH, ptW, ptH, bytes, EXT] and registers the image in the document.", "_PDFX_ImageInfo")

    _G_ApiGroup("Tables")
    _G_ApiFn('_PDFX_Table($doc, $x, $y, $width, $columns, $rows, $options="")', "Paginated table with repeated header. Columns: [title, fraction, L/C/R]. Returns the bottom y.", "_PDFX_Table")

    _G_ApiGroup("Navigation")
    _G_ApiFn('_PDFX_Link($doc, $x, $y, $w, $h, $url)', "Clickable external URL over the given rectangle.", "_PDFX_Link")
    _G_ApiFn('_PDFX_LinkPage($doc, $x, $y, $w, $h, $page, $yTarget=-1)', "Internal link; the target page may not exist yet, it is resolved at save time.", "_PDFX_LinkPage")
    _G_ApiFn('_PDFX_AddBookmark($doc, $title, $level=0, $page=-1, $y=-1)', "Adds an outline entry; returns its ordinal, or -1 with @error = 1. Without y, /Fit; with y, /XYZ.", "_PDFX_AddBookmark")
    _G_ApiFn('_PDFX_SetPageMode($doc, $mode="UseOutlines")', "Opening pane: UseNone, UseOutlines, UseThumbs or FullScreen.", "_PDFX_SetPageMode")
    _G_ApiFn('_PDFX_SetPageLayout($doc, $layout)', "Page layout: SinglePage, OneColumn, TwoColumnLeft/Right, TwoPageLeft/Right.", "_PDFX_SetPageLayout")

    _G_ApiGroup("Metadata and page furniture")
    _G_ApiFn('_PDFX_SetMeta($doc, $title="", $author="", $subject="", $keywords="")', "Fills the /Info dictionary; non-ASCII text is written in UTF-16BE.", "_PDFX_SetMeta")
    _G_ApiFn('_PDFX_SetHeader($doc, $l="", $c="", $r="", $size=8, $font="", $style="", $col=-1)', "Header on every page, with {page}, {pages}, {date}; a thin rule is drawn below it.", "_PDFX_SetHeader")
    _G_ApiFn('_PDFX_SetFooter($doc, $l="", $c="", $r="", $size=8, $font="", $style="", $col=-1)', "Footer on every page; the size is shared with the header.", "_PDFX_SetFooter")

    _G_ApiGroup("Output")
    _G_ApiFn('_PDFX_SetCompression($doc, $level=6)', "FlateDecode for content streams, 0..9; 0 leaves them raw. Applied at save time.", "_PDFX_SetCompression")
    _G_ApiFn('_PDFX_Save($doc, $file)', "Writes the PDF 1.7 file. @error = 1 if the file cannot be created, 2 if already saved.", "_PDFX_Save")
    _G_ApiFn('_PDFX_Close($doc)', "Releases GDI+ if the engine started it. Call after the save.", "_PDFX_Close")
EndFunc

Func _G_ApiGroup($sTitle)
    _G_H2($sTitle)
EndFunc

Func _G_ApiFn($sSignature, $sDescription, $sName)
    Local $aLines = _G_WrapLines($sSignature, $g_W, 7.5, "Courier")
    Local $fHeight = UBound($aLines) * 10 + _PDFX_Mm(9)
    If $g_Y + $fHeight > $g_Bottom Then
        _G_NewPage()
        $g_Y = _PDFX_Mm(48)
    EndIf

    _PDFX_SetFill($g_Doc, 0x1D3F6B)
    _PDFX_SetFont($g_Doc, "Courier", 7.5)
    For $iLine = 0 To UBound($aLines) - 1
        _PDFX_Text($g_Doc, $g_X, $g_Y, $aLines[$iLine], 7.5)
        $g_Y += 10
    Next
    _PDFX_AddBookmark($g_Doc, $sName, 2, _PDFX_PageCount($g_Doc), $g_Y - UBound($aLines) * 10)

    $g_Y += _PDFX_Mm(1.6)
    _G_P($sDescription, 8.5, 11.8, "Helvetica", "", 0x4A5466)
EndFunc

Func _G_Ch17()
    _G_Chapter("17", "References and licence", "Where the conventions come from.")

    _G_P("PDFX is written from ISO 32000-1:2008, the specification of PDF 1.7, and from the public AFM " & _
        "metrics of the Core 14 fonts. The clauses that matter most to a reader of the source are listed below.")

    Local $aCols17[3][3] = [["Clause", 0.20, "L"], ["Subject", 0.56, "L"], ["Used in", 0.24, "L"]]
    Local $aRows17[7][3] = [ _
        ["7.5", "Objects, file structure, cross-reference table, trailer", "save pipeline"], _
        ["7.5.8", "Cross-reference table, 20-byte entries", "pdfcheck"], _
        ["8.2", "Graphic operators and state", "shapes, colour"], _
        ["8.6", "Images and image XObjects", "JPEG, GDI+ conversion"], _
        ["9.4", "Text objects, showing and positioning", "text emission"], _
        ["9.6", "Standard 14 fonts and encodings", "AFM metrics, WinAnsi"], _
        ["12.3 / 12.5", "Outlines, destinations, link annotations", "navigation"]]
    _G_Table($aCols17, $aRows17, 8, 65)

    _G_P("The WinAnsi encoding follows annex D of the specification. Font metrics follow the public AFM " & _
        "files distributed with the PDF reference. The implementation is original: no code, prose or comment " & _
        "is taken from another UDF; only the conventional AutoIt documentation layout is shared, as in every " & _
        "official include.")

    _G_H2("Version history")
    Local $aCols17b[2][3] = [["Version", 0.14, "C"], ["What changed", 0.86, "L"]]
    Local $aRows17b[4][2] = [ _
        ["1.1", "Colour, opacity and dash guards; save lifecycle; UTF-16 metadata, UTC dates, content-derived /ID; CMYK JPEG through APP14; header and footer styling"], _
        ["1.2", "DEFLATE compressor written in AutoIt; FlateDecode on every content stream; per-stream fallback for incompressible data"], _
        ["1.3", "Hierarchical bookmarks, internal links, opening mode and page layout; the three validation tools in Tools"], _
        ["1.4", "English edition of the UDF, examples and tests; this guide"]]
    _G_Table($aCols17b, $aRows17b, 8.5, 60)

    _G_H2("The package", True, 100)
    Local $aCols17c[2][3] = [["Path", 0.24, "L"], ["Contents", 0.76, "L"]]
    Local $aRows17c[5][2] = [ _
        ["PDFX.au3", "The engine: 42 public functions, no dependency, one #include"], _
        ["Examples", "Four complete scripts and the PDFs they produce"], _
        ["Tests", "Regression suites with reference outputs, one per subsystem"], _
        ["Tools", "pdfcheck.py, outline.py and regress.py, standard library only"], _
        ["Guide", "This document and the script that builds it"]]
    _G_Table($aCols17c, $aRows17c, 8.5, 55)

    _G_H2("Licence")
    _G_P("MIT licence or public domain, at your choice. Use PDFX in commercial software, modify it, " & _
        "redistribute it with or without this guide. Attribution is welcome, not required.")

    _G_H2("Author and support")
    _G_P("Numeric1 — https://www.autoitscript.com/forum/. Questions, bug reports and example documents " & _
        "belong in the AutoIt forum thread; a minimal script that reproduces the problem is the most useful " & _
        "attachment. Version 1.4.0 is the reference for this guide.")

    _G_Note("A last word", "The best way to learn the API is to take one of the four examples, change its data, " & _
        "and watch the PDF change with it. The engine is small enough to read end to end when a detail is " & _
        "unclear, and the tests describe the behaviour more precisely than any prose.")
EndFunc
