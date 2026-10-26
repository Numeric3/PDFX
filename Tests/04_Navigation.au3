#cs ----------------------------------------------------------------------------
    04_Navigation — signets hierarchiques, liens internes et mode d'ouverture.

    Ce script verifie des invariants mesurables et ecrit un PDF de reference :

        python Tools/regress.py Tests/Reference Examples Tests
        python Tools/pdfcheck.py Tests/04_Navigation.pdf
        python Tools/outline.py Tests/04_Navigation.pdf

    Couvert :
      - huit signets sur cinq pages, niveaux 0 a 2
      - niveau trop profond ramene a niveau precedent + 1
      - titres ASCII litteraux, titre accentue en UTF-16BE
      - /Count = nombre de descendants, chaines First/Last et Parent/Prev/Next
      - destinations /Fit et /XYZ (y converti pour chaque page)
      - lien interne vers une page creee plus tard, lien hors bornes ignore
      - /PageMode, /PageLayout, mode UseOutlines automatique avec signets
      - lifecycle : reglages refuses apres _PDFX_Save
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
		ConsoleWrite("ECHEC " & $sName & ($sDetail <> "" ? " (" & $sDetail & ")" : "") & @CRLF)
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
	_PDFX_SetMeta($oDocument, "Sans signet", "Numeric1", "", "")
	If $sMode <> "" Then _PDFX_SetPageMode($oDocument, $sMode)
	_PDFX_SetFont($oDocument, "Helvetica", 12)
	_PDFX_Text($oDocument, 40, 60, "Document sans navigation")
	_PDFX_Save($oDocument, $sPath)
	_PDFX_Close($oDocument)
EndFunc   ;==>_MinimalDocument

; ------------------------------------------------------------------ document
Global $oDocument = _PDFX_New("A4", "P", 18)
_PDFX_SetMeta($oDocument, "Manuel de navigation", "Numeric1", "Signets et liens internes", "pdfx;signets")
_PDFX_SetCompression($oDocument, 6)
_PDFX_SetHeader($oDocument, "Manuel", "Navigation", "{date}")
_PDFX_SetFooter($oDocument, "page {page}/{pages}", "", "")
_PDFX_SetFont($oDocument, "Helvetica", 24, "B")
_PDFX_Text($oDocument, 40, 60, "Manuel de navigation")

Global $aAdded[8]
$aAdded[0] = _PDFX_AddBookmark($oDocument, "Couverture", 0, 1)

_PDFX_AddPage($oDocument)
_PDFX_Text($oDocument, 40, 60, "Sommaire")
_Check("lien vers une page future accepte", _PDFX_LinkPage($oDocument, 40, 110, 300, 14, 3))
_Check("lien vers une page hors bornes accepte", _PDFX_LinkPage($oDocument, 40, 136, 300, 14, 99))

_PDFX_AddPage($oDocument)
_PDFX_Text($oDocument, 40, 60, "Chapitre 1")

_PDFX_AddPage($oDocument)
_PDFX_Text($oDocument, 40, 60, "Chapitre 2")

_PDFX_AddPage($oDocument)
_PDFX_Text($oDocument, 40, 60, "Annexe")

$aAdded[1] = _PDFX_AddBookmark($oDocument, "Sommaire", 0, 2, 40)
$aAdded[2] = _PDFX_AddBookmark($oDocument, "Chapitre 1", 1, 3)
$aAdded[3] = _PDFX_AddBookmark($oDocument, "Section 1.1", 2, 3, 60)
$aAdded[4] = _PDFX_AddBookmark($oDocument, "Section 1.2", 2, 4)
$aAdded[5] = _PDFX_AddBookmark($oDocument, "Chapitre 2", 1, 5)
$aAdded[6] = _PDFX_AddBookmark($oDocument, "Annexe", 0, 5)
$aAdded[7] = _PDFX_AddBookmark($oDocument, "R" & ChrW(233) & "sum" & ChrW(233), 5, 1)
_Check("huit signets numerotes", $aAdded[0] = 1 And $aAdded[7] = 8)

; ------------------------------------------------------------------ gardes
_Check("titre vide refuse", _PDFX_AddBookmark($oDocument, "  ", 0, 1) = -1 And @error = 1)
_Check("page zero refusee", _PDFX_AddBookmark($oDocument, "Hors page", 0, 0) = -1 And @error = 1)
_Check("page inexistante refusee", _PDFX_AddBookmark($oDocument, "Hors page", 0, 99) = -1 And @error = 1)
_Check("lien vers la page zero refuse", _PDFX_LinkPage($oDocument, 40, 162, 300, 14, 0) = False And @error = 1)

_Check("mode signets accepte", _PDFX_SetPageMode($oDocument, "useoutlines"))
_Check("mode inconnu refuse", _PDFX_SetPageMode($oDocument, "Sidebar") = False And @error = 1)
_Check("disposition acceptee", _PDFX_SetPageLayout($oDocument, "TwoColumnLeft"))
_Check("disposition inconnue refusee", _PDFX_SetPageLayout($oDocument, "Mosaic") = False And @error = 1)

; ------------------------------------------------------------------ ecriture
Global $sOut = @ScriptDir & "\04_Navigation.pdf"
Global $sSecond = @ScriptDir & "\04_Navigation_second.pdf"
FileDelete($sOut)
FileDelete($sSecond)
_Check("enregistrement", _PDFX_Save($oDocument, $sOut) And @error = 0)

Global $bAgain = _PDFX_Save($oDocument, $sSecond)
_Check("second enregistrement refuse", $bAgain = False And @error = 2)
_Check("second fichier absent", Not FileExists($sSecond))
_Check("signet apres enregistrement refuse", _PDFX_AddBookmark($oDocument, "Tardif") = -1 And @error = 2)
_Check("lien apres enregistrement refuse", _PDFX_LinkPage($oDocument, 40, 188, 300, 14, 2) = False And @error = 2)
_Check("mode apres enregistrement refuse", _PDFX_SetPageMode($oDocument, "UseNone") = False And @error = 2)
_Check("disposition apres enregistrement refusee", _PDFX_SetPageLayout($oDocument, "SinglePage") = False And @error = 2)

; ------------------------------------------------------------------ structure
Global $sPdf = _ReadText($sOut)
Global $aPages = _PageRefs($sPdf)
_Check("cinq pages referencees", UBound($aPages) = 5)
_Check("catalogue reference le sommaire", StringRegExp($sPdf, "/Outlines \d+ 0 R") = 1)
_Check("mode et disposition du catalogue", StringInStr($sPdf, "/PageMode /UseOutlines") > 0 And _
		StringInStr($sPdf, "/PageLayout /TwoColumnLeft") > 0)
_Check("racine du sommaire", StringRegExp($sPdf, "/Type /Outlines /First \d+ 0 R /Last \d+ 0 R /Count 8") = 1)
_Check("titres ASCII", StringInStr($sPdf, "/Title (Couverture)") > 0 And StringInStr($sPdf, "/Title (Annexe)") > 0)
_Check("titre accentue en UTF-16BE", StringInStr($sPdf, "/Title <FEFF") > 0)
_Check("chapitre comptant deux sections", StringRegExp($sPdf, "(?s)/Title \(Chapitre 1\).*?/Count 2") = 1)
_Check("niveau profond ramene sous Annexe", StringRegExp($sPdf, "(?s)/Title \(Annexe\).*?/Count 1") = 1)
_Check("chaines Parent et Prev/Next", StringInStr(_Item($sPdf, "\(Chapitre 1\)"), "/Parent ") > 0 And _
		StringInStr(_Item($sPdf, "\(Section 1.1\)"), "/Next ") > 0 And _
		StringInStr(_Item($sPdf, "\(Section 1.1\)"), "/Prev ") = 0 And _
		StringInStr(_Item($sPdf, "\(Section 1.2\)"), "/Prev ") > 0 And _
		StringInStr(_Item($sPdf, "\(Section 1.2\)"), "/Next ") = 0)
_Check("destination /Fit de la couverture", StringInStr(_Item($sPdf, "\(Couverture\)"), "/Dest [" & $aPages[0] & " 0 R /Fit]") > 0, $aPages[0])
_Check("destination /XYZ de la section", StringRegExp(_Item($sPdf, "\(Section 1.1\)"), "/Dest \[" & $aPages[2] & " 0 R /XYZ 0 [0-9.]+ null\]") = 1)

; ------------------------------------------------------------------ liens
Global $aLink = StringRegExp($sPdf, "/Subtype /Link[^\r\n]*", 1)
_Check("une seule annotation de lien", UBound($aLink) = 1)
If UBound($aLink) = 1 Then
	_Check("lien interne vers la troisieme page", StringInStr($aLink[0], "/Dest [" & $aPages[2] & " 0 R /Fit]") > 0, $aLink[0])
	_Check("lien sans placeholder", StringInStr($aLink[0], "[0 0 R") = 0)
EndIf
_Check("page deux porte l'annotation", StringRegExp($sPdf, "/Annots \[\d+ 0 R\]") = 1)

; ------------------------------------------------------------------ mode auto
Global $sAuto = @TempDir & "\pdfx_nav_auto.pdf"
FileDelete($sAuto)
Global $oAuto = _PDFX_New("A4", "P", 18)
_PDFX_SetFont($oAuto, "Helvetica", 12)
_PDFX_Text($oAuto, 40, 60, "Mode automatique")
_PDFX_AddBookmark($oAuto, "Unique", 0, 1)
_PDFX_Save($oAuto, $sAuto)
_PDFX_Close($oAuto)
Global $sAutoPdf = _ReadText($sAuto)
_Check("mode signets automatique", StringInStr($sAutoPdf, "/PageMode /UseOutlines") > 0)
FileDelete($sAuto)

Global $sPlain = @TempDir & "\pdfx_nav_plain.pdf"
Global $sNone = @TempDir & "\pdfx_nav_none.pdf"
_MinimalDocument($sPlain)
_MinimalDocument($sNone, "UseNone")
Global $sPlainPdf = _ReadText($sPlain)
Global $sNonePdf = _ReadText($sNone)
_Check("document sans signet : pas de sommaire", StringInStr($sPlainPdf, "/Outlines") = 0 And _
		StringInStr($sPlainPdf, "/PageMode") = 0)
_Check("document sans signet : mode explicite", StringInStr($sNonePdf, "/Outlines") = 0 And _
		StringInStr($sNonePdf, "/PageMode /UseNone") > 0)
FileDelete($sPlain)
FileDelete($sNone)

; ------------------------------------------------------------------ bilan
_PDFX_Close($oDocument)
ConsoleWrite("---- " & ($g_Checks - $g_Failures) & "/" & $g_Checks & " verifications reussies" & @CRLF)
If $g_Failures > 0 Then Exit 1
