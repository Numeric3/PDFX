#cs ----------------------------------------------------------------------------
    01_Rapport — demonstration PDFX : mise en page, tableau pagine, formes.
#ce ----------------------------------------------------------------------------

#include "../PDFX.au3"

Local $sOut = @ScriptDir & "\01_Rapport.pdf"
Local $oDocument = _PDFX_New("A4", "P", 18)

_PDFX_SetMeta($oDocument, "Rapport de demonstration", "PDFX", "Exemple complet", "pdf;autoit;rapport")
_PDFX_SetCompression($oDocument, 6)
_PDFX_SetHeader($oDocument, "PDFX", "Rapport annuel", "{date}")
_PDFX_SetFooter($oDocument, "Genere par AutoIt", "", "Page {page} / {pages}")

; ------------------------------------------------------------------ couverture
_PDFX_SetFill($oDocument, 0x1F3864)
_PDFX_Rect($oDocument, 0, 0, _PDFX_PageWidth($oDocument), _PDFX_Mm(70), $PDFX_FILL)

_PDFX_SetFill($oDocument, "white")
_PDFX_SetFont($oDocument, "Helvetica", 30, "B")
_PDFX_Text($oDocument, _PDFX_Mm(18), _PDFX_Mm(26), "Rapport annuel")
_PDFX_SetFont($oDocument, "Helvetica", 13)
_PDFX_Text($oDocument, _PDFX_Mm(18), _PDFX_Mm(42), "Exercice 2026 — chiffres cles et perspectives")

_PDFX_SetFill($oDocument, 0x333333)
_PDFX_SetFont($oDocument, "Helvetica", 11)
_PDFX_TextWrap($oDocument, _PDFX_Mm(18), _PDFX_Mm(85), _PDFX_PageWidth($oDocument) - _PDFX_Mm(36), _
    "Ce document est produit sans bibliotheque externe : aucun pilote d'imprimante, aucun " & _
    "composant COM, aucun fichier temporaire. Les accents (éàçù), les guillemets « français » " & _
    "et les tirets — comme celui-ci — sont encodes en WinAnsi et s'affichent correctement. " & _
    "La largeur de chaque ligne est calculee avec les metriques AFM reelles des polices " & _
    "standard, ce qui permet une justification fiable.")

; ------------------------------------------------------------------ chiffres
Local $aKpi[3][3] = [ _
    ["Chiffre d'affaires", "4 281 000", "+12,4 %"], _
    ["Marge brute", "1 902 400", "+8,1 %"], _
    ["Effectif", "148", "+9"]]

Local $y = _PDFX_Mm(120)
_PDFX_SetFont($oDocument, "Helvetica", 12, "B")
_PDFX_SetFill($oDocument, 0x1F3864)
_PDFX_Text($oDocument, _PDFX_Mm(18), $y, "Indicateurs")
$y += _PDFX_Mm(8)

_PDFX_SetFont($oDocument, "Helvetica", 9)
_PDFX_SetLineWidth($oDocument, 0.8)
_PDFX_SetStroke($oDocument, 0xDDE3EF)

Local $fW = (_PDFX_PageWidth($oDocument) - _PDFX_Mm(36)) / 3
For $i = 0 To 2
    Local $x = _PDFX_Mm(18) + $i * $fW
    _PDFX_SetFill($oDocument, 0xF4F7FB)
    _PDFX_Rect($oDocument, $x, $y, $fW - 6, _PDFX_Mm(26), $PDFX_FILL)
    _PDFX_SetFill($oDocument, 0x6A7690)
    _PDFX_Text($oDocument, $x + 10, $y + 8, $aKpi[$i][0])
    _PDFX_SetFill($oDocument, 0x1F3864)
    _PDFX_SetFont($oDocument, "Helvetica", 17, "B")
    _PDFX_Text($oDocument, $x + 10, $y + 20, $aKpi[$i][1])
    _PDFX_SetFont($oDocument, "Helvetica", 9)
    _PDFX_SetFill($oDocument, 0x1E8A50)
    _PDFX_Text($oDocument, $x + 10, $y + 42, $aKpi[$i][2])
Next

; ------------------------------------------------------------------ graphique
$y = _PDFX_Mm(160)
_PDFX_SetFont($oDocument, "Helvetica", 12, "B")
_PDFX_SetFill($oDocument, 0x1F3864)
_PDFX_Text($oDocument, _PDFX_Mm(18), $y, "Repartition des ventes")
$y += _PDFX_Mm(10)

Local $aBar[5] = [62, 88, 54, 96, 73]
Local $aMois[5] = ["Jan", "Fev", "Mar", "Avr", "Mai"]
Local $x0 = _PDFX_Mm(18), $bx = _PDFX_Mm(34), $bw = _PDFX_Mm(18)
_PDFX_SetStroke($oDocument, 0xC9D2E3)
_PDFX_SetLineWidth($oDocument, 0.6)

For $i = 0 To 4
    Local $h = $aBar[$i]
    Local $bx1 = $x0 + 24 + $i * ($bw + _PDFX_Mm(6))
    _PDFX_SetFill($oDocument, $i = 3 ? 0x2E75B6 : 0x9DC3E6)
    _PDFX_Rect($oDocument, $bx1, $y + 90 - $h, $bw, $h, $PDFX_FILL)
    _PDFX_SetFill($oDocument, 0x444444)
    _PDFX_SetFont($oDocument, "Helvetica", 8)
    _PDFX_TextAlign($oDocument, $bx1, $y + 94, $bw, $aMois[$i], "C")
    _PDFX_TextAlign($oDocument, $bx1, $y + 90 - $h - 10, $bw, String($aBar[$i]), "C")
Next

_PDFX_Line($oDocument, $x0 + 20, $y + 90, $x0 + 20 + 5 * ($bw + _PDFX_Mm(6)), $y + 90)

; ------------------------------------------------------------------ tableau
_PDFX_AddPage($oDocument)
_PDFX_SetFill($oDocument, 0x1F3864)
_PDFX_SetFont($oDocument, "Helvetica", 16, "B")
_PDFX_Text($oDocument, _PDFX_Mm(18), _PDFX_Mm(22), "Detail par agence")

Local $aCols[4][3] = [ _
    ["Agence", 0.34, "L"], _
    ["Ventes", 0.18, "R"], _
    ["Evolution", 0.16, "R"], _
    ["Commentaire", 0.32, "L"]]

Local $aRows[14][4]
Local $aSites[14] = ["Paris", "Lyon", "Marseille", "Bordeaux", "Lille", "Toulouse", "Nantes", _
    "Strasbourg", "Nice", "Rennes", "Montpellier", "Grenoble", "Dijon", "Rouen"]
For $i = 0 To 13
    $aRows[$i][0] = $aSites[$i]
    $aRows[$i][1] = StringFormat("%d %03d", 120 + $i * 7, 450 + $i * 31)
    $aRows[$i][2] = StringFormat("%+.1f %%", ($i - 5) * 1.7)
    If Mod($i, 4) = 0 Then
        $aRows[$i][3] = "Objectif depasse, equipe renforcee au printemps"
    Else
        $aRows[$i][3] = "Conforme au budget"
    EndIf
Next

_PDFX_SetFont($oDocument, "Helvetica", 9)
_PDFX_Table($oDocument, _PDFX_Mm(18), _PDFX_Mm(32), _PDFX_PageWidth($oDocument) - _PDFX_Mm(36), $aCols, $aRows, _
    "padding=5;fontsize=9;zebra=1;headfill=0x1F3864;headcolor=0xFFFFFF;border=0.4")

; ------------------------------------------------------------------ formes
Local $y2 = _PDFX_PageHeight($oDocument) - _PDFX_Mm(55)
_PDFX_SetStroke($oDocument, 0x1F3864)
_PDFX_SetLineWidth($oDocument, 1.2)
_PDFX_RoundRect($oDocument, _PDFX_Mm(18), $y2, _PDFX_Mm(55), _PDFX_Mm(22), _PDFX_Mm(4), $PDFX_STROKE)
_PDFX_SetFill($oDocument, 0xE8EEF7)
_PDFX_Circle($oDocument, _PDFX_Mm(92), $y2 + _PDFX_Mm(11), _PDFX_Mm(9), $PDFX_FILL)
_PDFX_SetFill($oDocument, 0x1E8A50)
_PDFX_Ellipse($oDocument, _PDFX_Mm(120), $y2 + _PDFX_Mm(11), _PDFX_Mm(14), _PDFX_Mm(7), $PDFX_FILL)

; Transparence
_PDFX_SetAlpha($oDocument, 0.35)
_PDFX_SetFill($oDocument, 0x2E75B6)
_PDFX_Rect($oDocument, _PDFX_Mm(145), $y2, _PDFX_mm(30), _PDFX_Mm(22), $PDFX_FILL)
_PDFX_SetAlpha($oDocument, 1)

_PDFX_SetFill($oDocument, 0x1F3864)
_PDFX_SetFont($oDocument, "Times", 11, "I")
_PDFX_Text($oDocument, _PDFX_Mm(18), $y2 + _PDFX_Mm(28), "Polices Times en italique — 1234567890")
_PDFX_SetFont($oDocument, "Courier", 9)
_PDFX_Text($oDocument, _PDFX_Mm(18), $y2 + _PDFX_Mm(36), "Courier 9pt : code et colonnes alignees")

_PDFX_Link($oDocument, _PDFX_Mm(18), $y2, _PDFX_Mm(55), _PDFX_Mm(22), "https://www.autoitscript.com/forum/")

If _PDFX_Save($oDocument, $sOut) Then
    ConsoleWrite("OK " & $sOut & " (" & FileGetSize($sOut) & " octets, " & _PDFX_PageCount($oDocument) & " pages)" & @CRLF)
Else
    ConsoleWrite("! ECHEC @error=" & @error & @CRLF)
EndIf

_PDFX_Close($oDocument)
