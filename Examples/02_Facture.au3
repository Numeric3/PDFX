#cs ----------------------------------------------------------------------------
    02_Facture — exemple metier : en-tete, tableau multi-lignes, totaux.
#ce ----------------------------------------------------------------------------

#include "../PDFX.au3"

Global Const $BLEU = 0x1F3864
Global Const $GRIS = 0x59616E

Local $oDocument = _PDFX_New("A4", "P", 20)
_PDFX_SetMeta($oDocument, "Facture F-2026-0142", "Atelier Duval", "", "")
_PDFX_SetCompression($oDocument, 6)

; ------------------------------------------------------------------ en-tete
_PDFX_SetFont($oDocument, "Helvetica", 22, "B")
_PDFX_SetFill($oDocument, $BLEU)
_PDFX_Text($oDocument, _PDFX_Mm(20), _PDFX_Mm(18), "FACTURE")

_PDFX_SetFont($oDocument, "Helvetica", 9)
_PDFX_SetFill($oDocument, $GRIS)
_PDFX_Text($oDocument, _PDFX_Mm(20), _PDFX_Mm(28), "Atelier Duval — 14 rue des Lilas, 75011 Paris")
_PDFX_Text($oDocument, _PDFX_Mm(20), _PDFX_Mm(33), "SIRET 812 456 789 00021 — TVA FR58 812456789")

_PDFX_SetFont($oDocument, "Helvetica", 9, "B")
_PDFX_SetFill($oDocument, $BLEU)
_PDFX_TextAlign($oDocument, _PDFX_PageWidth($oDocument) - _PDFX_Mm(80), _PDFX_Mm(18), _PDFX_Mm(60), "Facture F-2026-0142", "R")
_PDFX_SetFont($oDocument, "Helvetica", 9)
_PDFX_SetFill($oDocument, $GRIS)
_PDFX_TextAlign($oDocument, _PDFX_PageWidth($oDocument) - _PDFX_Mm(80), _PDFX_Mm(24), _PDFX_Mm(60), "Date : 25/10/2026", "R")
_PDFX_TextAlign($oDocument, _PDFX_PageWidth($oDocument) - _PDFX_Mm(80), _PDFX_Mm(29), _PDFX_Mm(60), "Echeance : 24/11/2026", "R")

; ------------------------------------------------------------------ client
_PDFX_SetFill($oDocument, 0xF4F7FB)
_PDFX_Rect($oDocument, _PDFX_Mm(20), _PDFX_Mm(48), _PDFX_Mm(85), _PDFX_Mm(30), $PDFX_FILL)
_PDFX_SetFill($oDocument, $BLEU)
_PDFX_SetFont($oDocument, "Helvetica", 8, "B")
_PDFX_Text($oDocument, _PDFX_Mm(24), _PDFX_Mm(52), "FACTURE A")
_PDFX_SetFill($oDocument, 0x101828)
_PDFX_SetFont($oDocument, "Helvetica", 10, "B")
_PDFX_Text($oDocument, _PDFX_Mm(24), _PDFX_Mm(58), "Societe Lumiere SARL")
_PDFX_SetFont($oDocument, "Helvetica", 9)
_PDFX_Text($oDocument, _PDFX_Mm(24), _PDFX_Mm(64), "8 avenue Victor Hugo")
_PDFX_Text($oDocument, _PDFX_Mm(24), _PDFX_Mm(69), "69006 Lyon")

; ------------------------------------------------------------------ tableau
Local $aCols[5][3] = [ _
    ["Designation", 0.42, "L"], _
    ["Qte", 0.10, "C"], _
    ["P.U. HT", 0.16, "R"], _
    ["TVA", 0.10, "C"], _
    ["Total HT", 0.22, "R"]]

Local $aRows[8][5] = [ _
    ["Conception graphique — charte complete", "1", "1 450,00", "20 %", "1 450,00"], _
    ["Declinaison print (affiche A2, flyer 3 volets)", "2", "320,00", "20 %", "640,00"], _
    ["Photographie produit en studio", "1", "780,00", "20 %", "780,00"], _
    ["Retouche et etalonnage (12 visuels)", "1", "540,00", "20 %", "540,00"], _
    ["Maquette site vitrine — 6 ecrans", "1", "1 980,00", "20 %", "1 980,00"], _
    ["Integration HTML/CSS responsive", "1", "2 350,00", "20 %", "2 350,00"], _
    ["Formation a l'outil (demi-journee)", "1", "450,00", "20 %", "450,00"], _
    ["Forfait maintenance 12 mois", "1", "1 200,00", "20 %", "1 200,00"]]

_PDFX_SetFont($oDocument, "Helvetica", 9)
Local $y = _PDFX_Table($oDocument, _PDFX_Mm(20), _PDFX_Mm(88), _PDFX_PageWidth($oDocument) - _PDFX_Mm(40), $aCols, $aRows, _
    "padding=6;fontsize=9;zebra=1;headfill=0x1F3864;headcolor=0xFFFFFF;border=0.4;bordercolor=0xC9D2E3")

; ------------------------------------------------------------------ totaux
$y += _PDFX_Mm(4)
Local $xr = _PDFX_PageWidth($oDocument) - _PDFX_Mm(90)
_PDFX_SetFont($oDocument, "Helvetica", 10)
_PDFX_SetFill($oDocument, $GRIS)
_PDFX_TextAlign($oDocument, $xr, $y, _PDFX_Mm(40), "Total HT", "R")
_PDFX_SetFill($oDocument, 0x101828)
_PDFX_TextAlign($oDocument, $xr + _PDFX_Mm(42), $y, _PDFX_Mm(48), "9 390,00 EUR", "R")

$y += _PDFX_Mm(7)
_PDFX_SetFill($oDocument, $GRIS)
_PDFX_TextAlign($oDocument, $xr, $y, _PDFX_Mm(40), "TVA 20 %", "R")
_PDFX_SetFill($oDocument, 0x101828)
_PDFX_TextAlign($oDocument, $xr + _PDFX_Mm(42), $y, _PDFX_Mm(48), "1 878,00 EUR", "R")

$y += _PDFX_Mm(9)
_PDFX_SetFill($oDocument, $BLEU)
_PDFX_Rect($oDocument, $xr, $y - _PDFX_Mm(1), _PDFX_Mm(90), _PDFX_Mm(13), $PDFX_FILL)
_PDFX_SetFill($oDocument, 0xFFFFFF)
_PDFX_SetFont($oDocument, "Helvetica", 11, "B")
_PDFX_TextAlign($oDocument, $xr + _PDFX_Mm(3), $y + _PDFX_Mm(2), _PDFX_Mm(37), "TOTAL TTC", "L")
_PDFX_TextAlign($oDocument, $xr + _PDFX_Mm(42), $y + _PDFX_Mm(2), _PDFX_Mm(45), "11 268,00 EUR", "R")

; ------------------------------------------------------------------ mentions
$y += _PDFX_Mm(24)
_PDFX_SetFont($oDocument, "Helvetica", 8)
_PDFX_SetFill($oDocument, $GRIS)
_PDFX_TextWrap($oDocument, _PDFX_Mm(20), $y, _PDFX_PageWidth($oDocument) - _PDFX_Mm(40), _
    "Reglement par virement bancaire — IBAN FR76 3000 4008 2800 0123 4567 890. " & _
    "Tout retard de paiement entraine une penalite de 3 fois le taux d'interet legal, " & _
    "ainsi qu'une indemnite forfaitaire de 40 EUR pour frais de recouvrement (art. L441-10 du Code de commerce).", 8, 10)

_PDFX_Link($oDocument, _PDFX_Mm(20), _PDFX_Mm(18), _PDFX_Mm(70), _PDFX_Mm(8), "https://www.autoitscript.com/")

If _PDFX_Save($oDocument, @ScriptDir & "\02_Facture.pdf") Then
    ConsoleWrite("OK 02_Facture.pdf (" & FileGetSize(@ScriptDir & "\02_Facture.pdf") & " octets)" & @CRLF)
Else
    ConsoleWrite("! ECHEC @error=" & @error & @CRLF)
EndIf
_PDFX_Close($oDocument)
