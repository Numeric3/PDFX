#cs ----------------------------------------------------------------------------
    03_Images — galerie : JPEG direct (DCTDecode), PNG converti (GDI+),
    dimensionnement et deduplication automatique.
#ce ----------------------------------------------------------------------------

#include "../PDFX.au3"

Global Const $ENCRE = 0x101828
Global Const $BLEU = 0x1F3864
Global Const $GRIS = 0x6B7280
Global Const $TRAIT = 0xD8DFE8

Global $g_Jpg = @ScriptDir & "\..\..\Direct2D\examples\mandrill.jpg"
Global $g_Png = @ScriptDir & "\..\..\MIPDF\png.png"

Local $oDocument = _PDFX_New("A4", "P", 20)
_PDFX_SetMeta($oDocument, "Galerie d'images", "PDFX", "Images et dimensionnement", "pdf, image, jpeg, png")
_PDFX_SetCompression($oDocument, 6)

; ------------------------------------------------------------------ bandeau
_PDFX_SetFill($oDocument, 0x0F1B33)
_PDFX_Rect($oDocument, 0, 0, _PDFX_PageWidth($oDocument), _PDFX_Mm(34), $PDFX_FILL)
_PDFX_SetFill($oDocument, $BLEU)
_PDFX_Rect($oDocument, 0, _PDFX_Mm(34), _PDFX_PageWidth($oDocument), _PDFX_Mm(1.2), $PDFX_FILL)

_PDFX_SetFill($oDocument, 0xFFFFFF)
_PDFX_SetFont($oDocument, "Helvetica", 22, "B")
_PDFX_Text($oDocument, _PDFX_Mm(20), _PDFX_Mm(11), "GALERIE D'IMAGES")

_PDFX_SetFill($oDocument, 0x9FB2CC)
_PDFX_SetFont($oDocument, "Helvetica", 9)
_PDFX_Text($oDocument, _PDFX_Mm(20), _PDFX_Mm(24), "JPEG direct, PNG converti, dimensionnement — PDFX 1.0")

_PDFX_SetFill($oDocument, 0x9FB2CC)
_PDFX_SetFont($oDocument, "Helvetica", 8, "B")
_PDFX_TextAlign($oDocument, _PDFX_PageWidth($oDocument) - _PDFX_Mm(60), _PDFX_Mm(13), _PDFX_Mm(40), "EXEMPLE 03", "R")

; ------------------------------------------------------------------ cartes
Local $aJpg = 0, $aPng = 0
If FileExists($g_Jpg) Then $aJpg = _PDFX_ImageInfo($oDocument, $g_Jpg)
If FileExists($g_Png) Then $aPng = _PDFX_ImageInfo($oDocument, $g_Png)

Local $fCardW = _PDFX_Mm(82), $fCardH = _PDFX_Mm(100)
Local $fTop = _PDFX_Mm(44)

If IsArray($aJpg) Then
    _ImgCard($oDocument, $g_Jpg, _PDFX_Mm(20), $fTop, $fCardW, $fCardH, "JPEG", _
        "Inclusion directe", "Flux DCTDecode recopie tel quel, sans recompression.", _
        _ImgLine($aJpg, "px"))
EndIf

If IsArray($aPng) Then
    _ImgCard($oDocument, $g_Png, _PDFX_Mm(108), $fTop, $fCardW, $fCardH, "PNG", _
        "Conversion GDI+", "Canal alpha aplati sur blanc puis encode en JPEG.", _
        _ImgLine($aPng, "px"))
EndIf

; ------------------------------------------------------------------ section
_PDFX_SetStroke($oDocument, $TRAIT)
_PDFX_SetLineWidth($oDocument, 0.5)
_PDFX_Line($oDocument, _PDFX_Mm(20), _PDFX_Mm(156), _PDFX_Mm(190), _PDFX_Mm(156))

_PDFX_SetFill($oDocument, $ENCRE)
_PDFX_SetFont($oDocument, "Helvetica", 12, "B")
_PDFX_Text($oDocument, _PDFX_Mm(20), _PDFX_Mm(161), "Trois facons de dimensionner")

Local $fTitreW = _PDFX_TextWidth($oDocument, "Trois facons de dimensionner", 12)
_PDFX_SetFill($oDocument, $GRIS)
_PDFX_SetFont($oDocument, "Helvetica", 8)
_PDFX_Text($oDocument, _PDFX_Mm(20) + $fTitreW + _PDFX_Mm(5), _PDFX_Mm(164.2), _
    "largeur seule, hauteur seule, ou les deux")

; $PDFX_Image($oDocument, chemin, x, y, largeur, hauteur) — 0 = deduit des proportions.
Local $fBoxW = _PDFX_Mm(54), $fBoxH = _PDFX_Mm(72), $fImgH = _PDFX_Mm(48)
Local $fY2 = _PDFX_Mm(172)

If FileExists($g_Jpg) Then
    ; 1) largeur imposee, hauteur deduite
    _ImgFrame($oDocument, _PDFX_Mm(20), $fY2, $fBoxW, $fBoxH)
    _PDFX_ImageFit($oDocument, $g_Jpg, _PDFX_Mm(23), $fY2 + _PDFX_Mm(3), _PDFX_Mm(48), $fImgH, "LT")
    _Cap($oDocument, _PDFX_Mm(23), $fY2 + _PDFX_Mm(56), "Largeur seule", "48 x 48 mm · hauteur deduite")

    ; 2) hauteur imposee, largeur deduite (centre dans la boite)
    _ImgFrame($oDocument, _PDFX_Mm(78), $fY2, $fBoxW, $fBoxH)
    _PDFX_ImageFit($oDocument, $g_Jpg, _PDFX_Mm(81), $fY2 + _PDFX_Mm(3), _PDFX_Mm(48), $fImgH, "C")
    _Cap($oDocument, _PDFX_Mm(81), $fY2 + _PDFX_Mm(56), "Hauteur seule", "30 x 30 mm · largeur deduite")

    ; 3) les deux imposes : etirement volontaire
    _ImgFrame($oDocument, _PDFX_Mm(136), $fY2, $fBoxW, $fBoxH)
    _PDFX_Image($oDocument, $g_Jpg, _PDFX_Mm(139), $fY2 + _PDFX_Mm(14), _PDFX_Mm(48), _PDFX_Mm(24))
    _Cap($oDocument, _PDFX_Mm(139), $fY2 + _PDFX_Mm(56), "Les deux imposes", "48 x 24 mm · proportions libres")
EndIf

; ------------------------------------------------------------------ note
_PDFX_SetFill($oDocument, 0xF2F5F9)
_PDFX_RoundRect($oDocument, _PDFX_Mm(20), _PDFX_Mm(254), _PDFX_Mm(170), _PDFX_Mm(18), _PDFX_Mm(2), $PDFX_FILL)

_PDFX_SetFill($oDocument, $BLEU)
_PDFX_SetFont($oDocument, "Helvetica", 8, "B")
_PDFX_Text($oDocument, _PDFX_Mm(24), _PDFX_Mm(257), "DEDUPLICATION")

_PDFX_SetFill($oDocument, 0x374151)
_PDFX_SetFont($oDocument, "Helvetica", 8)
_PDFX_TextWrap($oDocument, _PDFX_Mm(24), _PDFX_Mm(262.5), _PDFX_Mm(162), _
    "La meme image inseree plusieurs fois n'est stockee qu'une seule fois dans le PDF : " & _
    "les objets XObject sont mis en cache par chemin absolu. Formats acceptes : " & _
    "JPEG (inclusion directe), PNG, BMP, GIF, TIFF (conversion GDI+ sur fond blanc).", 8, 9.5)

_PDFX_SetFooter($oDocument, "PDFX · Exemples", "Page {page} / {pages}", "{date}")
_PDFX_SetFont($oDocument, "Helvetica", 9)

If _PDFX_Save($oDocument, @ScriptDir & "\03_Images.pdf") Then
    ConsoleWrite("OK 03_Images.pdf (" & FileGetSize(@ScriptDir & "\03_Images.pdf") & " octets)" & @CRLF)
Else
    ConsoleWrite("! ECHEC @error=" & @error & @CRLF)
EndIf
_PDFX_Close($oDocument)

; ---------------------------------------------------------------- helpers

; Cadre de carte avec l'image ajustee a la zone utile et une legende.
Func _ImgCard(ByRef $oDocument, $sPath, $fX, $fY, $fW, $fH, $sBadge, $sTitle, $sDesc, $sInfo)
    _ImgFrame($oDocument, $fX, $fY, $fW, $fH)

    Local $fPad = _PDFX_Mm(3)
    _PDFX_ImageFit($oDocument, $sPath, $fX + $fPad, $fY + $fPad, $fW - 2 * $fPad, $fH - _PDFX_Mm(27), "C")

    ; pastille de format, posee sur le coin de l'image
    _PDFX_SetFill($oDocument, $BLEU)
    _PDFX_RoundRect($oDocument, $fX + $fPad + _PDFX_Mm(1), $fY + $fPad + _PDFX_Mm(1), _PDFX_Mm(17), _PDFX_Mm(6.5), _PDFX_Mm(1.5), $PDFX_FILL)
    _PDFX_SetFill($oDocument, 0xFFFFFF)
    _PDFX_SetFont($oDocument, "Helvetica", 7, "B")
    _PDFX_Text($oDocument, $fX + $fPad + _PDFX_Mm(2.8), $fY + $fPad + _PDFX_Mm(2.7), $sBadge)

    _PDFX_SetFill($oDocument, $ENCRE)
    _PDFX_SetFont($oDocument, "Helvetica", 9, "B")
    _PDFX_Text($oDocument, $fX + $fPad, $fY + $fH - _PDFX_Mm(20), $sTitle)

    _PDFX_SetFill($oDocument, $GRIS)
    _PDFX_SetFont($oDocument, "Helvetica", 7.5)
    _PDFX_TextWrap($oDocument, $fX + $fPad, $fY + $fH - _PDFX_Mm(14), $fW - 2 * $fPad - _PDFX_Mm(2), $sDesc, 7.5, 9)

    _PDFX_SetFill($oDocument, 0x8A94A6)
    _PDFX_SetFont($oDocument, "Courier", 7)
    _PDFX_Text($oDocument, $fX + $fPad, $fY + $fH - _PDFX_Mm(7), $sInfo)
EndFunc

Func _ImgFrame(ByRef $oDocument, $fX, $fY, $fW, $fH)
    _PDFX_SetFill($oDocument, 0xF7F9FC)
    _PDFX_RoundRect($oDocument, $fX, $fY, $fW, $fH, _PDFX_Mm(2.5), $PDFX_FILL)
    _PDFX_SetStroke($oDocument, $TRAIT)
    _PDFX_SetLineWidth($oDocument, 0.5)
    _PDFX_RoundRect($oDocument, $fX, $fY, $fW, $fH, _PDFX_Mm(2.5), $PDFX_STROKE)
EndFunc

Func _Cap(ByRef $oDocument, $fX, $fY, $sTitle, $sInfo)
    _PDFX_SetFill($oDocument, $ENCRE)
    _PDFX_SetFont($oDocument, "Helvetica", 8, "B")
    _PDFX_Text($oDocument, $fX, $fY, $sTitle)
    _PDFX_SetFill($oDocument, $GRIS)
    _PDFX_SetFont($oDocument, "Helvetica", 7)
    _PDFX_Text($oDocument, $fX, $fY + _PDFX_Mm(4.5), $sInfo)
EndFunc

; "256 x 256 px · 41 Ko"
Func _ImgLine($a, $sUnit)
    Local $fKo = $a[4] / 1024
    Local $sKo = $fKo >= 10 ? String(Round($fKo, 0)) : String(Round($fKo, 1))
    Return $a[0] & " x " & $a[1] & " " & $sUnit & " · " & $sKo & " Ko · " & $a[5]
EndFunc
