#cs ----------------------------------------------------------------------------
    02_Robustesse — gardes des entrees, cycle de vie et metadonnees.

    Ce script verifie des invariants mesurables et ecrit un PDF de reference :

        python Tools/regress.py Tests/Reference Examples Tests

    Couvert :
      - alpha et couleurs hors bornes : @error = 1, valeurs ramenees dans l'intervalle
      - tirets annules : "[] 0 d"
      - titre non ASCII : chaine hexadecimale UTF-16BE
      - dates UTC (suffixe Z) et /ID MD5 deterministe
      - second _PDFX_Save() et _PDFX_AddPage() apres enregistrement : @error = 2
      - police, style et couleur propres a l'en-tete et au pied
      - JPEG CMJN Adobe : /DeviceCMYK et /Decode inverse
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

Func _DocumentId($sPath)
	Local $aMatch = StringRegExp(_ReadText($sPath), "/ID \[<([0-9A-F]{32})><", 1)
	If UBound($aMatch) = 1 Then Return $aMatch[0]
	Return ""
EndFunc   ;==>_DocumentId

Func _MiniDocument($sPath)
	Local $oDocument = _PDFX_New("A4", "P", 18)
	_PDFX_SetMeta($oDocument, "Identifiant deterministe", "Numeric1", "", "")
	_PDFX_SetFont($oDocument, "Helvetica", 10)
	_PDFX_Text($oDocument, 40, 60, "Contenu identique")
	_PDFX_Save($oDocument, $sPath)
	_PDFX_Close($oDocument)
EndFunc   ;==>_MiniDocument

; ------------------------------------------------------------------ document
Global $oDocument = _PDFX_New("A4", "P", 18)
_PDFX_SetMeta($oDocument, "Rapport " & ChrW(233) & "t" & ChrW(233) & " " & ChrW(339) & " " & ChrW(8364), _
		"Numeric1", "Robustesse", "pdfx;test")
_PDFX_SetHeader($oDocument, "PDFX", "Robustesse", "{date}", 8, "Courier", "B", 0xFF0000)
_PDFX_SetFooter($oDocument, "page {page}/{pages}", "", "", 7, "Times", "I", 0x1F3864)

_PDFX_SetFont($oDocument, "Helvetica", 11)

; ------------------------------------------------------------------ gardes
_PDFX_SetAlpha($oDocument, 1.5)
_Check("alpha > 1 signale", @error = 1)

_PDFX_SetAlpha($oDocument, -0.5)
_Check("alpha < 0 signale", @error = 1)

_PDFX_SetAlpha($oDocument, 1)

_PDFX_SetFill($oDocument, "300,-5,100")
_Check("couleur hors bornes signalee", @error = 1)
_PDFX_Rect($oDocument, 40, 160, 20, 20, $PDFX_FILL)

_PDFX_SetDash($oDocument, 0)

; ------------------------------------------------------------------ contenu
_PDFX_SetFont($oDocument, "Helvetica", 12, "B")
_PDFX_SetFill($oDocument, 0x101828)
_PDFX_Text($oDocument, 40, 80, "Robustesse des entrees")
_PDFX_SetFont($oDocument, "Helvetica", 10)
_PDFX_SetFill($oDocument, 0x333333)
_PDFX_Text($oDocument, 40, 100, "Alpha, couleurs et tirets sont bornes silencieusement, avec @error = 1.")

Global $sCmyk = @ScriptDir & "\Assets\cmyk_adobe.jpg"
If FileExists($sCmyk) Then
	_Check("image CMJN acceptee", _PDFX_Image($oDocument, $sCmyk, 40, 130, 40))
Else
	ConsoleWrite("SKIP  image CMJN absente (" & $sCmyk & ")" & @CRLF)
EndIf

; ------------------------------------------------------------------ ecriture
Global $sOut = @ScriptDir & "\02_Robustesse.pdf"
Global $sSecond = @ScriptDir & "\02_Robustesse_second.pdf"
FileDelete($sSecond)
_Check("enregistrement", _PDFX_Save($oDocument, $sOut) And @error = 0)

Global $bAgain = _PDFX_Save($oDocument, $sSecond)
_Check("second enregistrement refuse", $bAgain = False And @error = 2)
_Check("second fichier absent", Not FileExists($sSecond))

Global $iPage = _PDFX_AddPage($oDocument)
_Check("page ajoutee apres enregistrement refusee", $iPage = -1 And @error = 2)

; ------------------------------------------------------------------ metadonnees
Global $sPdf = _ReadText($sOut)
_Check("alpha > 1 borne a 1", StringInStr($sPdf, "/ca 1 /CA 1") > 0)
_Check("alpha < 0 borne a 0", StringInStr($sPdf, "/ca 0 /CA 0") > 0)
_Check("couleur ramenee dans [0, 255]", StringInStr($sPdf, "1 0 0.392 rg") > 0)
_Check("tiret nul annule le style", StringInStr($sPdf, "[] 0 d") > 0)
_Check("titre non ASCII en UTF-16BE", StringInStr($sPdf, "/Title <FEFF") > 0)
_Check("date de creation UTC", StringRegExp($sPdf, "D:\d{14}Z") = 1)
_Check("date de modification presente", StringInStr($sPdf, "/ModDate (D:") > 0)
_Check("identifiant /ID de 32 octets", StringRegExp($sPdf, "/ID \[<([0-9A-F]{32})><\1>\]") = 1)
_Check("police d'en-tete Courier-Bold", StringInStr($sPdf, "/BaseFont /Courier-Bold") > 0)
_Check("police de pied Times-Italic", StringInStr($sPdf, "/BaseFont /Times-Italic") > 0)
_Check("couleur d'en-tete rouge", StringInStr($sPdf, "1 0 0 rg") > 0)
_Check("filet d'en-tete rouge", StringInStr($sPdf, "1 0 0 RG") > 0)

If FileExists($sCmyk) Then
	_Check("espace colorimetrique CMJN", StringInStr($sPdf, "/DeviceCMYK") > 0)
	_Check("decode inverse Adobe", StringInStr($sPdf, "/Decode [1 0 1 0 1 0 1 0]") > 0)
EndIf

; ------------------------------------------------------------------ determinisme
Global $sIdPath1 = @TempDir & "\pdfx_id1.pdf"
Global $sIdPath2 = @TempDir & "\pdfx_id2.pdf"
_MiniDocument($sIdPath1)
_MiniDocument($sIdPath2)
Global $sId1 = _DocumentId($sIdPath1)
Global $sId2 = _DocumentId($sIdPath2)
_Check("identifiant identique pour un contenu identique", $sId1 <> "" And $sId1 = $sId2, $sId1 & " / " & $sId2)
FileDelete($sIdPath1)
FileDelete($sIdPath2)

; ------------------------------------------------------------------ bilan
_PDFX_Close($oDocument)
ConsoleWrite("---- " & ($g_Checks - $g_Failures) & "/" & $g_Checks & " verifications reussies" & @CRLF)
If $g_Failures > 0 Then Exit 1
