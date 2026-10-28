#cs ----------------------------------------------------------------------------
    03_Images — gallery: direct JPEG (DCTDecode), converted PNG (GDI+),
    sizing and automatic deduplication.
#ce ----------------------------------------------------------------------------

#include "../PDFX.au3"

Global Const $INK = 0x101828
Global Const $BLUE = 0x1F3864
Global Const $GREY = 0x6B7280
Global Const $RULE = 0xD8DFE8

Global $g_Jpg = @ScriptDir & "\Assets\mandrill.jpg"
Global $g_Png = @ScriptDir & "\Assets\png.png"

Global $oDocument = _PDFX_New("A4", "P", 20)
_PDFX_SetMeta($oDocument, "Image gallery", "PDFX", "Images and sizing", "pdf, image, jpeg, png")
_PDFX_SetCompression($oDocument, 6)

; ------------------------------------------------------------------ banner
_PDFX_SetFill($oDocument, 0x0F1B33)
_PDFX_Rect($oDocument, 0, 0, _PDFX_PageWidth($oDocument), _PDFX_Mm(34), $PDFX_FILL)
_PDFX_SetFill($oDocument, $BLUE)
_PDFX_Rect($oDocument, 0, _PDFX_Mm(34), _PDFX_PageWidth($oDocument), _PDFX_Mm(1.2), $PDFX_FILL)

_PDFX_SetFill($oDocument, 0xFFFFFF)
_PDFX_SetFont($oDocument, "Helvetica", 22, "B")
_PDFX_Text($oDocument, _PDFX_Mm(20), _PDFX_Mm(11), "IMAGE GALLERY")

_PDFX_SetFill($oDocument, 0x9FB2CC)
_PDFX_SetFont($oDocument, "Helvetica", 9)
_PDFX_Text($oDocument, _PDFX_Mm(20), _PDFX_Mm(24), "Direct JPEG, converted PNG, sizing — PDFX " & $PDFX_VERSION)

_PDFX_SetFill($oDocument, 0x9FB2CC)
_PDFX_SetFont($oDocument, "Helvetica", 8, "B")
_PDFX_TextAlign($oDocument, _PDFX_PageWidth($oDocument) - _PDFX_Mm(60), _PDFX_Mm(13), _PDFX_Mm(40), "EXAMPLE 03", "R")

; ------------------------------------------------------------------ cards
Global $aJpg = 0, $aPng = 0
If FileExists($g_Jpg) Then $aJpg = _PDFX_ImageInfo($oDocument, $g_Jpg)
If FileExists($g_Png) Then $aPng = _PDFX_ImageInfo($oDocument, $g_Png)

Global $fCardW = _PDFX_Mm(82), $fCardH = _PDFX_Mm(100)
Global $fTop = _PDFX_Mm(44)

If IsArray($aJpg) Then
    _ImgCard($oDocument, $g_Jpg, _PDFX_Mm(20), $fTop, $fCardW, $fCardH, "JPEG", _
        "Embedded directly", "DCTDecode stream copied as is, without recompression.", _
        _ImgLine($aJpg, "px"))
EndIf

If IsArray($aPng) Then
    _ImgCard($oDocument, $g_Png, _PDFX_Mm(108), $fTop, $fCardW, $fCardH, "PNG", _
        "GDI+ conversion", "Alpha channel flattened onto white, then encoded as JPEG.", _
        _ImgLine($aPng, "px"))
EndIf

; ------------------------------------------------------------------ section
_PDFX_SetStroke($oDocument, $RULE)
_PDFX_SetLineWidth($oDocument, 0.5)
_PDFX_Line($oDocument, _PDFX_Mm(20), _PDFX_Mm(156), _PDFX_Mm(190), _PDFX_Mm(156))

_PDFX_SetFill($oDocument, $INK)
_PDFX_SetFont($oDocument, "Helvetica", 12, "B")
_PDFX_Text($oDocument, _PDFX_Mm(20), _PDFX_Mm(161), "Three ways to size an image")

Global $fTitleW = _PDFX_TextWidth($oDocument, "Three ways to size an image", 12)
_PDFX_SetFill($oDocument, $GREY)
_PDFX_SetFont($oDocument, "Helvetica", 8)
_PDFX_Text($oDocument, _PDFX_Mm(20) + $fTitleW + _PDFX_Mm(5), _PDFX_Mm(164.2), _
    "width only, height only, or both")

; _PDFX_Image($oDocument, path, x, y, width, height) — 0 = inferred from the proportions.
Global $fBoxW = _PDFX_Mm(54), $fBoxH = _PDFX_Mm(72)
Global $fY2 = _PDFX_Mm(172)

If FileExists($g_Jpg) Then
    ; 1) width set, height inferred
    _ImgFrame($oDocument, _PDFX_Mm(20), $fY2, $fBoxW, $fBoxH)
    _PDFX_Image($oDocument, $g_Jpg, _PDFX_Mm(23), $fY2 + _PDFX_Mm(3), _PDFX_Mm(48), 0)
    _Cap($oDocument, _PDFX_Mm(23), $fY2 + _PDFX_Mm(56), "Width only", "48 x 48 mm · height inferred")

    ; 2) height set, width inferred
    _ImgFrame($oDocument, _PDFX_Mm(78), $fY2, $fBoxW, $fBoxH)
    _PDFX_Image($oDocument, $g_Jpg, _PDFX_Mm(90), $fY2 + _PDFX_Mm(21), 0, _PDFX_Mm(30))
    _Cap($oDocument, _PDFX_Mm(81), $fY2 + _PDFX_Mm(56), "Height only", "30 x 30 mm · width inferred")

    ; 3) both set: deliberate stretch
    _ImgFrame($oDocument, _PDFX_Mm(136), $fY2, $fBoxW, $fBoxH)
    _PDFX_Image($oDocument, $g_Jpg, _PDFX_Mm(139), $fY2 + _PDFX_Mm(14), _PDFX_Mm(48), _PDFX_Mm(24))
    _Cap($oDocument, _PDFX_Mm(139), $fY2 + _PDFX_Mm(56), "Both set", "48 x 24 mm · proportions free")
EndIf

; ------------------------------------------------------------------ note
_PDFX_SetFill($oDocument, 0xF2F5F9)
_PDFX_RoundRect($oDocument, _PDFX_Mm(20), _PDFX_Mm(254), _PDFX_Mm(170), _PDFX_Mm(18), _PDFX_Mm(2), $PDFX_FILL)

_PDFX_SetFill($oDocument, $BLUE)
_PDFX_SetFont($oDocument, "Helvetica", 8, "B")
_PDFX_Text($oDocument, _PDFX_Mm(24), _PDFX_Mm(257), "DEDUPLICATION")

_PDFX_SetFill($oDocument, 0x374151)
_PDFX_SetFont($oDocument, "Helvetica", 8)
_PDFX_TextWrap($oDocument, _PDFX_Mm(24), _PDFX_Mm(262.5), _PDFX_Mm(162), _
    "The same image inserted several times is stored only once in the PDF: XObject " & _
    "objects are cached by absolute path. Accepted formats: JPEG (embedded directly), " & _
    "PNG, BMP and GIF (converted through GDI+ onto white).", 8, 9.5)

_PDFX_SetFooter($oDocument, "PDFX · Examples", "Page {page} / {pages}", "{date}")
_PDFX_SetFont($oDocument, "Helvetica", 9)

If _PDFX_Save($oDocument, @ScriptDir & "\03_Images.pdf") Then
    ConsoleWrite("OK 03_Images.pdf (" & FileGetSize(@ScriptDir & "\03_Images.pdf") & " bytes)" & @CRLF)
Else
    ConsoleWrite("! FAILED @error=" & @error & @CRLF)
EndIf
_PDFX_Close($oDocument)

; ---------------------------------------------------------------- helpers

; Card frame with the image fitted into the content area, plus a caption.
Func _ImgCard(ByRef $oDocument, $sPath, $fX, $fY, $fW, $fH, $sBadge, $sTitle, $sDesc, $sInfo)
    _ImgFrame($oDocument, $fX, $fY, $fW, $fH)

    Local $fPad = _PDFX_Mm(3)
    _PDFX_ImageFit($oDocument, $sPath, $fX + $fPad, $fY + $fPad, $fW - 2 * $fPad, $fH - _PDFX_Mm(27), "C")

    ; format badge, laid over the corner of the image
    _PDFX_SetFill($oDocument, $BLUE)
    _PDFX_RoundRect($oDocument, $fX + $fPad + _PDFX_Mm(1), $fY + $fPad + _PDFX_Mm(1), _PDFX_Mm(17), _PDFX_Mm(6.5), _PDFX_Mm(1.5), $PDFX_FILL)
    _PDFX_SetFill($oDocument, 0xFFFFFF)
    _PDFX_SetFont($oDocument, "Helvetica", 7, "B")
    _PDFX_Text($oDocument, $fX + $fPad + _PDFX_Mm(2.8), $fY + $fPad + _PDFX_Mm(2.7), $sBadge)

    _PDFX_SetFill($oDocument, $INK)
    _PDFX_SetFont($oDocument, "Helvetica", 9, "B")
    _PDFX_Text($oDocument, $fX + $fPad, $fY + $fH - _PDFX_Mm(20), $sTitle)

    _PDFX_SetFill($oDocument, $GREY)
    _PDFX_SetFont($oDocument, "Helvetica", 7.5)
    _PDFX_TextWrap($oDocument, $fX + $fPad, $fY + $fH - _PDFX_Mm(14), $fW - 2 * $fPad - _PDFX_Mm(2), $sDesc, 7.5, 9)

    _PDFX_SetFill($oDocument, 0x8A94A6)
    _PDFX_SetFont($oDocument, "Courier", 7)
    _PDFX_Text($oDocument, $fX + $fPad, $fY + $fH - _PDFX_Mm(7), $sInfo)
EndFunc

Func _ImgFrame(ByRef $oDocument, $fX, $fY, $fW, $fH)
    _PDFX_SetFill($oDocument, 0xF7F9FC)
    _PDFX_RoundRect($oDocument, $fX, $fY, $fW, $fH, _PDFX_Mm(2.5), $PDFX_FILL)
    _PDFX_SetStroke($oDocument, $RULE)
    _PDFX_SetLineWidth($oDocument, 0.5)
    _PDFX_RoundRect($oDocument, $fX, $fY, $fW, $fH, _PDFX_Mm(2.5), $PDFX_STROKE)
EndFunc

Func _Cap(ByRef $oDocument, $fX, $fY, $sTitle, $sInfo)
    _PDFX_SetFill($oDocument, $INK)
    _PDFX_SetFont($oDocument, "Helvetica", 8, "B")
    _PDFX_Text($oDocument, $fX, $fY, $sTitle)
    _PDFX_SetFill($oDocument, $GREY)
    _PDFX_SetFont($oDocument, "Helvetica", 7)
    _PDFX_Text($oDocument, $fX, $fY + _PDFX_Mm(4.5), $sInfo)
EndFunc

; "256 x 256 px · 41 KB"
Func _ImgLine($a, $sUnit)
    Local $fKb = $a[4] / 1024
    Local $sKb = $fKb >= 10 ? String(Round($fKb, 0)) : String(Round($fKb, 1))
    Return $a[0] & " x " & $a[1] & " " & $sUnit & " · " & $sKb & " KB · " & $a[5]
EndFunc
