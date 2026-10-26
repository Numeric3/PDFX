#cs ----------------------------------------------------------------------------
    03_Compression — FlateDecode optionnel des flux de contenu.

    Ce script verifie les invariants observables sans decompresseur :

        python Tools/pdfcheck.py Tests/03_Compression.pdf

    Couvert :
      - niveau 0 (defaut) : aucun /Filter /FlateDecode
      - niveau 6 : un filtre par page, PDF plus petit que la version brute
      - /Length compresse strictement inferieur au flux en clair
      - petit flux : repli automatique sur le flux brut
      - niveau hors bornes ramene dans [0, 9] avec @error = 1
      - reglage refuse apres enregistrement : @error = 2
      - /ID identique avec et sans compression (empreinte du contenu, pas du fichier)
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

; Deux pages de texte identique ; $iLevel < 0 laisse la compression au defaut du document.
Func _Build($iLevel, $sPath, $iLines = 40)
	Local $oDocument = _PDFX_New("A4", "P", 18)
	_PDFX_SetMeta($oDocument, "Compression", "Numeric1", "FlateDecode", "pdfx;zlib")
	If $iLevel >= 0 Then _PDFX_SetCompression($oDocument, $iLevel)
	_PDFX_SetFont($oDocument, "Helvetica", 10)
	For $iPage = 1 To 2
		If $iPage = 2 Then _PDFX_AddPage($oDocument)
		For $iLine = 0 To $iLines - 1
			_PDFX_Text($oDocument, 40, 40 + $iLine * 16, _
				"Page " & $iPage & ", ligne " & $iLine & " : Portez ce vieux whisky au juge blond qui fume.")
		Next
	Next
	Local $bSaved = _PDFX_Save($oDocument, $sPath)
	_PDFX_Close($oDocument)
	Return $bSaved
EndFunc   ;==>_Build

; Longueurs /Length des flux dont l'en-tete se termine par $sSuffix.
Func _Lengths($sText, $sSuffix)
	Local $aFound[0]
	Local $iPos = 1
	While True
		Local $iHit = StringInStr($sText, "/Length ", 0, 1, $iPos)
		If $iHit = 0 Then ExitLoop
		Local $iEnd = StringInStr($sText, $sSuffix, 0, 1, $iHit)
		If $iEnd = 0 Then ExitLoop
		Local $sDigits = StringStripWS(StringMid($sText, $iHit + 8, $iEnd - ($iHit + 8)), 8)
		If StringIsDigit($sDigits) Then
			ReDim $aFound[UBound($aFound) + 1]
			$aFound[UBound($aFound) - 1] = Int($sDigits)
		EndIf
		$iPos = $iHit + 8
	WEnd
	Return $aFound
EndFunc   ;==>_Lengths

; ------------------------------------------------------------------ documents
Global $sPlain = @TempDir & "\pdfx_comp_plain.pdf"
Global $sFlate = @ScriptDir & "\03_Compression.pdf"
Global $sOff = @TempDir & "\pdfx_comp_off.pdf"
Global $sTiny = @TempDir & "\pdfx_comp_tiny.pdf"
Global $sLevel9 = @TempDir & "\pdfx_comp_level9.pdf"

Global $bPlain = _Build(-1, $sPlain)
Global $bFlate = _Build(6, $sFlate)
Global $bOff = _Build(0, $sOff)
_Check("enregistrements", $bPlain And $bFlate And $bOff)

Global $iSizePlain = FileGetSize($sPlain)
Global $iSizeFlate = FileGetSize($sFlate)
Global $sTextPlain = _ReadText($sPlain)
Global $sTextFlate = _ReadText($sFlate)
Global $sTextOff = _ReadText($sOff)

; ------------------------------------------------------------------ presence du filtre
_Check("defaut : aucun filtre", StringInStr($sTextPlain, "/FlateDecode") = 0)
_Check("niveau 0 : aucun filtre", StringInStr($sTextOff, "/FlateDecode") = 0)
_Check("niveau 6 : un filtre par page", UBound(StringRegExp($sTextFlate, "/Filter /FlateDecode", 3)) = 2)

; ------------------------------------------------------------------ poids et longueurs
_Check("PDF compresse plus petit", $iSizeFlate < $iSizePlain, $iSizeFlate & " / " & $iSizePlain)

Global $aPlainLength = _Lengths($sTextPlain, " >>")
Global $aFlateLength = _Lengths($sTextFlate, " /Filter /FlateDecode")
_Check("deux longueurs de part et d'autre", UBound($aPlainLength) = 2 And UBound($aFlateLength) = 2)
If UBound($aPlainLength) = 2 And UBound($aFlateLength) = 2 Then
	Global $iPlainSum = Int($aPlainLength[0]) + Int($aPlainLength[1])
	Global $iFlateSum = Int($aFlateLength[0]) + Int($aFlateLength[1])
	_Check("flux compresses plus courts", $iFlateSum < $iPlainSum, $iFlateSum & " / " & $iPlainSum)
	_Check("gain d'au moins 3:1", $iPlainSum >= 3 * $iFlateSum, $iPlainSum & " / " & $iFlateSum)
EndIf

; ------------------------------------------------------------------ petits flux et identifiant
Global $oTiny = _PDFX_New("A4", "P", 18)
_PDFX_SetCompression($oTiny, 6)
_PDFX_Save($oTiny, $sTiny)
_PDFX_Close($oTiny)
_Check("flux trop court laisse en clair", StringInStr(_ReadText($sTiny), "/FlateDecode") = 0)

_Check("/ID identique avec et sans compression", _DocumentId($sPlain) = _DocumentId($sFlate) And _DocumentId($sPlain) <> "")

; ------------------------------------------------------------------ gardes
Global $oGuard = _PDFX_New("A4", "P", 18)
_PDFX_SetCompression($oGuard, 42)
_Check("niveau > 9 signale et borne", @error = 1)
_PDFX_SetCompression($oGuard, -3)
_Check("niveau < 0 signale et borne", @error = 1)
_PDFX_SetCompression($oGuard, 9)
_Check("niveau 9 accepte", @error = 0)
_PDFX_SetFont($oGuard, "Helvetica", 10)
For $iLine = 0 To 24
	_PDFX_Text($oGuard, 40, 40 + $iLine * 16, "Ligne " & $iLine & " : Portez ce vieux whisky au juge blond qui fume.")
Next
_Check("enregistrement au niveau 9", _PDFX_Save($oGuard, $sLevel9))
_Check("niveau 9 compresse", StringInStr(_ReadText($sLevel9), "/FlateDecode") > 0)
_Check("reglage refuse apres enregistrement", _PDFX_SetCompression($oGuard, 0) = False And @error = 2)
_PDFX_Close($oGuard)

; ------------------------------------------------------------------ bilan
FileDelete($sPlain)
FileDelete($sOff)
FileDelete($sTiny)
FileDelete($sLevel9)
ConsoleWrite("---- " & ($g_Checks - $g_Failures) & "/" & $g_Checks & " verifications reussies" & @CRLF)
If $g_Failures > 0 Then Exit 1
