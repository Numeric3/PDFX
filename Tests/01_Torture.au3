#cs ----------------------------------------------------------------------------
    01_Torture — exercice complet du moteur.

    Ce script ne verifie pas un rendu : il traverse volontairement toutes les
    branches (formats, polices, encodage, primitives, images, tableaux,
    pagination, liens, en-tetes). Il sert de reference de non-regression :

        python Tools/pdfcheck.py Tests/01_Torture.pdf
        ./Tests/compare.sh          (compare au PDF temoin, dates neutralisees)
#ce ----------------------------------------------------------------------------

#include "../PDFX.au3"

Global $g_Jpeg = @ScriptDir & "\..\..\Direct2D\examples\mandrill.jpg"
Global $g_Png = @ScriptDir & "\..\..\MIPDF\png.png"

Local $oDocument = _PDFX_New("A5", "L", 12)
_PDFX_SetMeta($oDocument, "Torture", "Numeric1", "Non-regression", "pdfx;test")
_PDFX_SetHeader($oDocument, "PDFX · torture", "", "{date}", 7)
_PDFX_SetFooter($oDocument, "page {page}/{pages}", "", "n", 7)

; ---------------------------------------------------------------- page 1 : polices
_PDFX_SetFont($oDocument, "Helvetica", 16, "B")
_PDFX_SetFill($oDocument, 0x101828)
_PDFX_Text($oDocument, 24, 24, "Polices et encodage")

Local $aStyles[4] = ["", "B", "I", "BI"]
Local $aFamilies[3] = ["Helvetica", "Times", "Courier"]
Local $fY = 42
For $iFamily = 0 To UBound($aFamilies) - 1
    For $iStyle = 0 To UBound($aStyles) - 1
        _PDFX_SetFont($oDocument, $aFamilies[$iFamily], 10, $aStyles[$iStyle])
        _PDFX_SetFill($oDocument, 0x374151)
        _PDFX_Text($oDocument, 24, $fY, $aFamilies[$iFamily] & " " & $aStyles[$iStyle] & _
            " — Portez ce vieux whisky au juge blond qui fume.")
        $fY += 12
    Next
Next

_PDFX_SetFont($oDocument, "Helvetica", 10)
_PDFX_SetFill($oDocument, 0x1F3864)
_PDFX_Text($oDocument, 24, $fY + 4, "Accents : é è ê ë à â ä ù û ü ô ö î ï ç œ Œ æ Æ ß")
_PDFX_Text($oDocument, 24, $fY + 16, "Typo : « guillemets » — tiret € 12,50 ° 45 ± 2 · 3 … 4")

; mesure et alignements
Local $fBoxW = 200
_PDFX_SetFill($oDocument, 0x6B7280)
_PDFX_Text($oDocument, 24, $fY + 32, "Largeur mesuree : " & Round(_PDFX_TextWidth($oDocument, "Portez ce vieux whisky", 10), 2) & " pt")

_PDFX_TextAlign($oDocument, 24, $fY + 46, $fBoxW, "aligne a gauche", "L")
_PDFX_TextAlign($oDocument, 24, $fY + 58, $fBoxW, "centre", "C")
_PDFX_TextAlign($oDocument, 24, $fY + 70, $fBoxW, "aligne a droite", "R")

; ---------------------------------------------------------------- page 2 : texte long
_PDFX_AddPage($oDocument)
_PDFX_SetFont($oDocument, "Times", 10)
_PDFX_SetFill($oDocument, 0x101828)
_PDFX_Text($oDocument, 24, 24, "Retour a la ligne et pagination")

Local $sLong = "Un paragraphe assez long pour occuper plusieurs lignes dans une colonne etroite, " & _
    "avec des accents (éléphant, naïf, côté) et un mot tres long a couper : " & _
    "anticonstitutionnellement. " & @CRLF & @CRLF & _
    "Deuxieme paragraphe apres un saut de ligne explicite, pour verifier que le decoupage " & _
    "respecte les retours chariot du texte source."
Local $fY2 = _PDFX_TextWrap($oDocument, 24, 42, 300, $sLong, 10, 13)

For $iParagraph = 1 To 12
    $fY2 = _PDFX_TextWrap($oDocument, 24, $fY2 + 6, 300, _
        "Paragraphe de remplissage " & $iParagraph & " : la pagination automatique doit " & _
        "passer a la page suivante quand la marge basse est atteinte, sans perdre de ligne.", 10, 13, "L", True)
Next

; ---------------------------------------------------------------- page 3 : formes
_PDFX_AddPage($oDocument)
_PDFX_SetFont($oDocument, "Helvetica", 12, "B")
_PDFX_SetFill($oDocument, 0x101828)
_PDFX_Text($oDocument, 24, 24, "Primitives")

_PDFX_SetStroke($oDocument, 0x1F3864)
_PDFX_SetLineWidth($oDocument, 1.2)
_PDFX_Line($oDocument, 24, 46, 300, 46)

_PDFX_SetFill($oDocument, 0xE8EEF7)
_PDFX_Rect($oDocument, 24, 56, 60, 30, $PDFX_FILL)
_PDFX_SetStroke($oDocument, 0x1F3864)
_PDFX_Rect($oDocument, 94, 56, 60, 30, $PDFX_BOTH)

_PDFX_SetFill($oDocument, 0xFDE68A)
_PDFX_RoundRect($oDocument, 164, 56, 60, 30, 6, $PDFX_FILL)
_PDFX_SetFill($oDocument, 0xBBF7D0)
_PDFX_Ellipse($oDocument, 254, 71, 30, 15, $PDFX_FILL)
_PDFX_SetFill($oDocument, 0xFECACA)
_PDFX_Circle($oDocument, 320, 71, 15, $PDFX_FILL)

Local $aPoints[4][2] = [[24, 100], [60, 130], [96, 100], [132, 130]]
_PDFX_SetStroke($oDocument, 0x7C3AED)
_PDFX_SetLineWidth($oDocument, 1)
_PDFX_Polyline($oDocument, $aPoints, False, $PDFX_STROKE)
_PDFX_SetFill($oDocument, 0xDDD6FE)
_PDFX_Polyline($oDocument, $aPoints, True, $PDFX_BOTH)

_PDFX_SetStroke($oDocument, 0x0F766E)
_PDFX_Bezier($oDocument, 160, 100, 190, 80, 220, 150, 250, 115, $PDFX_STROKE)

_PDFX_SetDash($oDocument, 4, 2)
_PDFX_SetStroke($oDocument, 0x6B7280)
_PDFX_Line($oDocument, 280, 100, 380, 100)
_PDFX_SetDash($oDocument, 1000, 0)

_PDFX_SetFill($oDocument, 0x1F3864)
_PDFX_SetAlpha($oDocument, 0.35)
_PDFX_Rect($oDocument, 24, 145, 80, 40, $PDFX_FILL)
_PDFX_SetFill($oDocument, 0xDC2626)
_PDFX_Rect($oDocument, 54, 155, 80, 40, $PDFX_FILL)
_PDFX_SetAlpha($oDocument, 1)

; ---------------------------------------------------------------- page 4 : images
_PDFX_AddPage($oDocument)
_PDFX_SetFont($oDocument, "Helvetica", 12, "B")
_PDFX_SetFill($oDocument, 0x101828)
_PDFX_Text($oDocument, 24, 24, "Images")

If FileExists($g_Jpeg) Then
    _PDFX_Image($oDocument, $g_Jpeg, 24, 42, 0, 40)
    _PDFX_Image($oDocument, $g_Jpeg, 100, 42, 40, 0)
    _PDFX_ImageFit($oDocument, $g_Jpeg, 150, 42, 60, 40, "LT")
    _PDFX_ImageFit($oDocument, $g_Jpeg, 216, 42, 60, 40, "RB")

    Local $aInfo = _PDFX_ImageInfo($oDocument, $g_Jpeg)
    _PDFX_SetFont($oDocument, "Courier", 7)
    _PDFX_SetFill($oDocument, 0x6B7280)
    _PDFX_Text($oDocument, 24, 92, $aInfo[0] & "x" & $aInfo[1] & " px · " & $aInfo[5] & " · " & $aInfo[4] & " octets")
EndIf

If FileExists($g_Png) Then
    _PDFX_Image($oDocument, $g_Png, 290, 42, 50, 0)
    _PDFX_Image($oDocument, $g_Png, 290, 105, 50, 50)
    _PDFX_SetFont($oDocument, "Helvetica", 8)
    _PDFX_SetFill($oDocument, 0x6B7280)
    _PDFX_Text($oDocument, 290, 96, "PNG aplati sur blanc")
EndIf

; ---------------------------------------------------------------- page 5 : tableaux
_PDFX_AddPage($oDocument)
_PDFX_SetFont($oDocument, "Helvetica", 12, "B")
_PDFX_SetFill($oDocument, 0x101828)
_PDFX_Text($oDocument, 24, 24, "Tableaux")

Local $aCols[4][3] = [ _
    ["Reference", 0.40, "L"], _
    ["Quantite", 0.15, "C"], _
    ["Prix unitaire", 0.20, "R"], _
    ["Total", 0.25, "R"]]

Local $aRows[26][4]
For $iRow = 0 To 25
    $aRows[$iRow][0] = "Article " & StringFormat("%02d", $iRow + 1) & " — libelle qui peut passer sur deux lignes"
    $aRows[$iRow][1] = String($iRow + 1)
    $aRows[$iRow][2] = StringFormat("%d,%02d EUR", 10 + $iRow, $iRow * 7)
    $aRows[$iRow][3] = StringFormat("%d,%02d EUR", 100 + $iRow * 3, $iRow)
Next

_PDFX_SetFont($oDocument, "Helvetica", 8)
Local $fY3 = _PDFX_Table($oDocument, 24, 42, 380, $aCols, $aRows, _
    "padding=4;fontsize=8;zebra=1;headfill=0x1F3864;headcolor=0xFFFFFF;border=0.4;pagebreak=1")

_PDFX_SetFont($oDocument, "Helvetica", 9, "B")
_PDFX_SetFill($oDocument, 0x101828)
_PDFX_Text($oDocument, 24, $fY3 + 10, "Sans filets ni fond d'en-tete")

Local $aCols2[2][3] = [["Cle", 0.5, "L"], ["Valeur", 0.5, "R"]]
Local $aRows2[3][2] = [["alpha", "1"], ["beta", "2"], ["gamma", "3"]]
_PDFX_SetFont($oDocument, "Times", 9)
_PDFX_Table($oDocument, 24, $fY3 + 22, 380, $aCols2, $aRows2, _
    "border=0;headfill=-1;fontsize=9;padding=3")

; ---------------------------------------------------------------- liens + fin
_PDFX_Link($oDocument, 24, 24, 120, 16, "https://www.autoitscript.com/forum/")

_PDFX_AddPage($oDocument, _PDFX_Mm(210), _PDFX_Mm(297))
_PDFX_SetFont($oDocument, "Helvetica", 10)
_PDFX_SetFill($oDocument, 0x101828)
_PDFX_Text($oDocument, _PDFX_Mm(20), _PDFX_Mm(20), _
    "Derniere page A4 inseree par _PDFX_AddPage avec une taille explicite.")

; ---------------------------------------------------------------- sortie
Local $sOut = @ScriptDir & "\01_Torture.pdf"
If _PDFX_Save($oDocument, $sOut) Then
    ConsoleWrite("OK 01_Torture.pdf (" & FileGetSize($sOut) & " octets, " & _PDFX_PageCount($oDocument) & " pages)" & @CRLF)
Else
    ConsoleWrite("! ECHEC @error=" & @error & @CRLF)
EndIf
_PDFX_Close($oDocument)
