#cs ----------------------------------------------------------------------------
    02_Invoice — business example: header, multi-line table, totals.
#ce ----------------------------------------------------------------------------

#include "../PDFX.au3"

Global Const $BLUE = 0x1F3864
Global Const $GREY = 0x59616E

Global $oDocument = _PDFX_New("A4", "P", 20)
_PDFX_SetMeta($oDocument, "Invoice INV-2026-0142", "Duval Studio", "", "")
_PDFX_SetCompression($oDocument, 6)

; ------------------------------------------------------------------ header
_PDFX_SetFont($oDocument, "Helvetica", 22, "B")
_PDFX_SetFill($oDocument, $BLUE)
_PDFX_Text($oDocument, _PDFX_Mm(20), _PDFX_Mm(18), "INVOICE")

_PDFX_SetFont($oDocument, "Helvetica", 9)
_PDFX_SetFill($oDocument, $GREY)
_PDFX_Text($oDocument, _PDFX_Mm(20), _PDFX_Mm(28), "Duval Studio — 14 Lilac Street, Bristol BS1 4HD")
_PDFX_Text($oDocument, _PDFX_Mm(20), _PDFX_Mm(33), "VAT GB 812 4567 89 — Reg. 8124567")

_PDFX_SetFont($oDocument, "Helvetica", 9, "B")
_PDFX_SetFill($oDocument, $BLUE)
_PDFX_TextAlign($oDocument, _PDFX_PageWidth($oDocument) - _PDFX_Mm(80), _PDFX_Mm(18), _PDFX_Mm(60), "Invoice INV-2026-0142", "R")
_PDFX_SetFont($oDocument, "Helvetica", 9)
_PDFX_SetFill($oDocument, $GREY)
_PDFX_TextAlign($oDocument, _PDFX_PageWidth($oDocument) - _PDFX_Mm(80), _PDFX_Mm(24), _PDFX_Mm(60), "Date: 25/10/2026", "R")
_PDFX_TextAlign($oDocument, _PDFX_PageWidth($oDocument) - _PDFX_Mm(80), _PDFX_Mm(29), _PDFX_Mm(60), "Due: 24/11/2026", "R")

; ------------------------------------------------------------------ customer
_PDFX_SetFill($oDocument, 0xF4F7FB)
_PDFX_Rect($oDocument, _PDFX_Mm(20), _PDFX_Mm(48), _PDFX_Mm(85), _PDFX_Mm(30), $PDFX_FILL)
_PDFX_SetFill($oDocument, $BLUE)
_PDFX_SetFont($oDocument, "Helvetica", 8, "B")
_PDFX_Text($oDocument, _PDFX_Mm(24), _PDFX_Mm(52), "BILLED TO")
_PDFX_SetFill($oDocument, 0x101828)
_PDFX_SetFont($oDocument, "Helvetica", 10, "B")
_PDFX_Text($oDocument, _PDFX_Mm(24), _PDFX_Mm(58), "Lumiere Ltd")
_PDFX_SetFont($oDocument, "Helvetica", 9)
_PDFX_Text($oDocument, _PDFX_Mm(24), _PDFX_Mm(64), "8 Victor Hugo Avenue")
_PDFX_Text($oDocument, _PDFX_Mm(24), _PDFX_Mm(69), "Manchester M2 5DB")

; ------------------------------------------------------------------ table
Global $aCols[5][3] = [ _
    ["Description", 0.42, "L"], _
    ["Qty", 0.10, "C"], _
    ["Unit price", 0.16, "R"], _
    ["VAT", 0.10, "C"], _
    ["Line total", 0.22, "R"]]

Global $aRows[8][5] = [ _
    ["Graphic design — complete brand guidelines", "1", "1,450.00", "20 %", "1,450.00"], _
    ["Print assets (A2 poster, tri-fold flyer)", "2", "320.00", "20 %", "640.00"], _
    ["Product photography in studio", "1", "780.00", "20 %", "780.00"], _
    ["Retouching and colour grading (12 images)", "1", "540.00", "20 %", "540.00"], _
    ["Website mock-up — 6 screens", "1", "1,980.00", "20 %", "1,980.00"], _
    ["Responsive HTML/CSS integration", "1", "2,350.00", "20 %", "2,350.00"], _
    ["Tool training (half day)", "1", "450.00", "20 %", "450.00"], _
    ["Maintenance plan, 12 months", "1", "1,200.00", "20 %", "1,200.00"]]

_PDFX_SetFont($oDocument, "Helvetica", 9)
Global $y = _PDFX_Table($oDocument, _PDFX_Mm(20), _PDFX_Mm(88), _PDFX_PageWidth($oDocument) - _PDFX_Mm(40), $aCols, $aRows, _
    "padding=6;fontsize=9;zebra=1;headfill=0x1F3864;headcolor=0xFFFFFF;border=0.4;bordercolor=0xC9D2E3")

; ------------------------------------------------------------------ totals
$y += _PDFX_Mm(4)
Global $xr = _PDFX_PageWidth($oDocument) - _PDFX_Mm(90)
_PDFX_SetFont($oDocument, "Helvetica", 10)
_PDFX_SetFill($oDocument, $GREY)
_PDFX_TextAlign($oDocument, $xr, $y, _PDFX_Mm(40), "Subtotal", "R")
_PDFX_SetFill($oDocument, 0x101828)
_PDFX_TextAlign($oDocument, $xr + _PDFX_Mm(42), $y, _PDFX_Mm(48), "9,390.00 GBP", "R")

$y += _PDFX_Mm(7)
_PDFX_SetFill($oDocument, $GREY)
_PDFX_TextAlign($oDocument, $xr, $y, _PDFX_Mm(40), "VAT 20 %", "R")
_PDFX_SetFill($oDocument, 0x101828)
_PDFX_TextAlign($oDocument, $xr + _PDFX_Mm(42), $y, _PDFX_Mm(48), "1,878.00 GBP", "R")

$y += _PDFX_Mm(9)
_PDFX_SetFill($oDocument, $BLUE)
_PDFX_Rect($oDocument, $xr, $y - _PDFX_Mm(1), _PDFX_Mm(90), _PDFX_Mm(13), $PDFX_FILL)
_PDFX_SetFill($oDocument, 0xFFFFFF)
_PDFX_SetFont($oDocument, "Helvetica", 11, "B")
_PDFX_TextAlign($oDocument, $xr + _PDFX_Mm(3), $y + _PDFX_Mm(2), _PDFX_Mm(37), "TOTAL", "L")
_PDFX_TextAlign($oDocument, $xr + _PDFX_Mm(42), $y + _PDFX_Mm(2), _PDFX_Mm(45), "11,268.00 GBP", "R")

; ------------------------------------------------------------------ terms
$y += _PDFX_Mm(24)
_PDFX_SetFont($oDocument, "Helvetica", 8)
_PDFX_SetFill($oDocument, $GREY)
_PDFX_TextWrap($oDocument, _PDFX_Mm(20), $y, _PDFX_PageWidth($oDocument) - _PDFX_Mm(40), _
    "Payment by bank transfer — IBAN GB29 NWBK 6016 1331 9268 19. " & _
    "Late payment carries interest at three times the statutory rate, plus a fixed " & _
    "recovery fee of 40 GBP.", 8, 10)

_PDFX_Link($oDocument, _PDFX_Mm(20), _PDFX_Mm(18), _PDFX_Mm(70), _PDFX_Mm(8), "https://www.autoitscript.com/")

If _PDFX_Save($oDocument, @ScriptDir & "\02_Invoice.pdf") Then
    Global $sOut = @ScriptDir & "\02_Invoice.pdf"
    ConsoleWrite("OK 02_Invoice.pdf (" & FileGetSize($sOut) & " bytes)" & @CRLF)
Else
    ConsoleWrite("! FAILED @error=" & @error & @CRLF)
EndIf
_PDFX_Close($oDocument)
