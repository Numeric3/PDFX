; #INDEX# =======================================================================================================================
; Title .........: PDFX
; AutoIt Version : 3.3.16.1
; Language ......: Francais
; Description ...: Moteur PDF autonome pour AutoIt : texte, formes, images,
;                  tableaux, liens, signets, en-tete et pied de page. Aucune
;                  dependance externe ; GDI+ (fourni avec AutoIt) sert
;                  uniquement a convertir PNG, BMP et GIF en JPEG, et un
;                  compresseur DEFLATE ecrit en AutoIt pur allege les flux de
;                  contenu.
; Author(s) .....: Numeric1
; Link ..........: https://www.autoitscript.com/forum/
; Version .......: 1.3.0
; Copyright .....: (c) 2026 Numeric1
; License .......: MIT ou domaine public, au choix.
;
; ------------------------------- DEMARRAGE RAPIDE -------------------------------
;
;   #include "PDFX.au3"
;
;   Local $oDocument = _PDFX_New()                       ; A4 portrait, marge 15 mm
;   _PDFX_SetCompression($oDocument, 6)                  ; flux de contenu en FlateDecode
;   _PDFX_SetFont($oDocument, "Helvetica", 24, "B")
;   _PDFX_Text($oDocument, 40, 40, "Rapport mensuel")    ; y = haut du texte
;   _PDFX_AddBookmark($oDocument, "Titre", 0, 1, 40)     ; signet vers la page 1
;   _PDFX_SetPageMode($oDocument, "UseOutlines")         ; volet des signets ouvert
;   _PDFX_SetFont($oDocument, "Helvetica", 11)
;   _PDFX_TextWrap($oDocument, 40, 80, 515, "Texte long ...")
;   _PDFX_Save($oDocument, @ScriptDir & "\rapport.pdf")
;   _PDFX_Close($oDocument)
;
; --------------------------------- PRINCIPES ----------------------------------
;
; * Un document est un handle (tableau) : aucun etat global, plusieurs PDF
;   peuvent etre construits en parallele dans le meme script.
; * Un document s'ecrit une seule fois : _PDFX_Save() gele le handle et
;   _PDFX_AddPage() renvoie ensuite @error = 2. Les dates sont en temps
;   universel et /ID est une empreinte MD5 deterministe du contenu.
; * Coordonnees en points (1 pt = 1/72 pouce), origine en HAUT et a GAUCHE.
;   _PDFX_Mm() convertit les millimetres ; le passage a l'espace PDF
;   (origine en bas a gauche) est interne.
; * Les largeurs de texte viennent des metriques AFM des polices standard :
;   alignements et retours a la ligne sont exacts, sans rendu GDI.
; * Encodage WinAnsi : les accents francais passent sans reglage.
; * Images : JPEG embarque octet pour octet ; PNG, BMP et GIF convertis en
;   JPEG sur fond blanc via GDI+, puis dedupliques par chemin.
; * Compression optionnelle : _PDFX_SetCompression() ecrit les flux de contenu
;   en FlateDecode (zlib), avec repli automatique sur le flux brut.
; * Navigation : _PDFX_AddBookmark() construit un arbre /Outlines hierarchique
;   et _PDFX_LinkPage() relie deux pages sans passer par une URL.
;
; ---------------------------------- LIMITES -----------------------------------
;
; * Compresseur en AutoIt pur : de l'ordre de 30 Ko/s et un taux proche de
;   zlib niveau 1. Les flux non compresses restent le defaut.
; * Pas de polices TrueType embarquees : seuls les caracteres couverts par
;   WinAnsi sont rendus, les autres deviennent '?'.
; * Pas de lecture ni de modification de PDF existants.
; * Signets et liens internes ne visent que des pages du document : pas de
;   destinations nommees, pas d'actions JavaScript ni de pieces jointes.
;
; -------------------------------- ORIGINALITE ---------------------------------
;
; Implementation ecrite pour ce projet d'apres la norme ISO 32000-1:2008
; (objets indirects, table xref, flux de contenu, annotations) et les
; metriques AFM publiques des polices Core 14 d'Adobe. Aucun code, texte ni
; commentaire n'est repris d'AutoItObject, de MPDF ou d'un autre UDF : seule
; la disposition conventionnelle des blocs de documentation AutoIt
; (#INDEX#, #CURRENT#, #FUNCTION#) est partagee, comme dans tout include
; officiel livre avec AutoIt.
;
; ===============================================================================================================================

#include-once
#AutoIt3Wrapper_Au3Check_Parameters=-d -w 1 -w 2 -w 3 -w 4 -w 5 -w 6
#include <GDIPlus.au3>
#include <Crypt.au3>

; #CURRENT# =====================================================================================================================
;_PDFX_AddBookmark
;_PDFX_AddPage
;_PDFX_Bezier
;_PDFX_Circle
;_PDFX_Close
;_PDFX_Ellipse
;_PDFX_Font
;_PDFX_FontSize
;_PDFX_Image
;_PDFX_ImageFit
;_PDFX_ImageInfo
;_PDFX_Line
;_PDFX_Link
;_PDFX_LinkPage
;_PDFX_Margin
;_PDFX_Mm
;_PDFX_New
;_PDFX_PageCount
;_PDFX_PageHeight
;_PDFX_PageWidth
;_PDFX_Polyline
;_PDFX_Rect
;_PDFX_RoundRect
;_PDFX_Save
;_PDFX_SavePage
;_PDFX_SetAlpha
;_PDFX_SetCompression
;_PDFX_SetDash
;_PDFX_SetFill
;_PDFX_SetFont
;_PDFX_SetFooter
;_PDFX_SetHeader
;_PDFX_SetLineWidth
;_PDFX_SetMeta
;_PDFX_SetPageLayout
;_PDFX_SetPageMode
;_PDFX_SetStroke
;_PDFX_Table
;_PDFX_Text
;_PDFX_TextAlign
;_PDFX_TextWidth
;_PDFX_TextWrap
; ===============================================================================================================================

; #INTERNAL_NO_DOC# =============================================================================================================
;_PDFX_AbsPath
;_PDFX_AddObject
;_PDFX_ApplyHeaderFooter
;_PDFX_ArrayPush
;_PDFX_BaseChar
;_PDFX_BaseFont
;_PDFX_BuildOutline
;_PDFX_ByteAt
;_PDFX_CharWidth
;_PDFX_ChunkAdd
;_PDFX_Clamp
;_PDFX_Color
;_PDFX_ColorName
;_PDFX_ColorStr
;_PDFX_ConvertToJpeg
;_PDFX_CurveTo
;_PDFX_EmitText
;_PDFX_EnsureFont
;_PDFX_EnsureImage
;_PDFX_Escape
;_PDFX_Ext
;_PDFX_F
;_PDFX_FlushPage
;_PDFX_HashHex
;_PDFX_HfLine
;_PDFX_ImageRow
;_PDFX_IsAscii
;_PDFX_JpegInfo
;_PDFX_Measure
;_PDFX_Oct3
;_PDFX_Op
;_PDFX_Opt
;_PDFX_PackContent
;_PDFX_PageDestination
;_PDFX_PaintOp
;_PDFX_PaperSize
;_PDFX_PatchPageLinks
;_PDFX_PreparePageLinks
;_PDFX_ReadBinary
;_PDFX_ResourceDict
;_PDFX_SpecialIndex
;_PDFX_StrokeOp
;_PDFX_StrokeState
;_PDFX_StyleState
;_PDFX_Sum
;_PDFX_TableDrawLines
;_PDFX_TableDrawRow
;_PDFX_TableRowHeight
;_PDFX_TextString
;_PDFX_Today
;_PDFX_UtcDate
;_PDFX_WinAnsi
;_PDFX_Wrap
;_PDFX_Y
;_PDFX_ZlibCompress
;_PDFX_ZlibFlush
;_PDFX_ZlibInit
;_PDFX_ZlibPut
;_PDFX_ZlibReverseBits
; ===============================================================================================================================

; Version du moteur, reprise dans les metadonnees /Creator et /Producer.
Global Const $PDFX_VERSION = "1.3.0"

#Region - Constantes internes ---------------------------------------------------------------------------------------------------
; Handle de document : chaque constante est un index du tableau renvoye par _PDFX_New().
Global Const $__PDFX_DOC_OBJECTS = 0         ; corps des objets indirects (index 1..N)
Global Const $__PDFX_DOC_OBJECTCOUNT = 1     ; nombre d'objets
Global Const $__PDFX_DOC_PAGES = 2           ; [n][4] = w, h, contenu, annotations
Global Const $__PDFX_DOC_FONTS = 3           ; [n][4] = baseFont, objNum, nomRessource, tableLargeur
Global Const $__PDFX_DOC_IMAGES = 4          ; [n][5] = chemin, objNum, largeur px, hauteur px, nomRessource
Global Const $__PDFX_DOC_STATES = 5          ; [n][3] = cle, objNum, nomRessource (ExtGState)
Global Const $__PDFX_DOC_WIDTH = 6           ; largeur page courante (pt)
Global Const $__PDFX_DOC_HEIGHT = 7          ; hauteur page courante (pt)
Global Const $__PDFX_DOC_CURRENTPAGE = 8     ; index de page courante (0-based, -1 = aucune)
Global Const $__PDFX_DOC_CONTENT = 9         ; flux de contenu de la page courante
Global Const $__PDFX_DOC_ANNOTS = 10         ; annotations de la page courante
Global Const $__PDFX_DOC_FONT = 11           ; index de police courante
Global Const $__PDFX_DOC_FONTSIZE = 12       ; taille courante
Global Const $__PDFX_DOC_FILL = 13           ; "r g b" courant
Global Const $__PDFX_DOC_STROKE = 14         ; "r g b" courant
Global Const $__PDFX_DOC_LINEWIDTH = 15      ; epaisseur de trait
Global Const $__PDFX_DOC_METADATA = 16       ; [titre, auteur, sujet, mots-cles]
Global Const $__PDFX_DOC_HEADERFOOTER = 17   ; [hG, hC, hD, fG, fC, fD, taille, coulH, policeH, styleH, coulF, policeF, styleF]
Global Const $__PDFX_DOC_MARGIN = 18         ; marge par defaut (pt)
Global Const $__PDFX_DOC_DEFAULTHEIGHT = 19  ; hauteur par defaut des nouvelles pages
Global Const $__PDFX_DOC_DEFAULTWIDTH = 20   ; largeur par defaut
Global Const $__PDFX_DOC_HFAPPLIED = 21      ; en-tete/pied deja insere dans les pages
Global Const $__PDFX_DOC_SAVED = 22          ; document deja ecrit : gele
Global Const $__PDFX_DOC_COMPRESSION = 23    ; niveau de compression des flux de contenu (0 = brut)
Global Const $__PDFX_DOC_BOOKMARKS = 24      ; [n][4] = titre, niveau, page (base 0), y haut (-1 = /Fit)
Global Const $__PDFX_DOC_PAGELINKS = 25      ; [n][7] = objet, page cible, y cible, rect (4 valeurs)
Global Const $__PDFX_DOC_PAGEMODE = 26       ; "" (auto) ou UseNone, UseOutlines, UseThumbs, FullScreen
Global Const $__PDFX_DOC_PAGELAYOUT = 27     ; "" ou SinglePage, OneColumn, TwoColumnLeft, ...
Global Const $__PDFX_DOC_SLOTS = 28          ; nombre total de slots

; Styles de peinture acceptes par les primitives et par _PDFX_Table().
Global Const $PDFX_STROKE = 0
Global Const $PDFX_FILL = 1
Global Const $PDFX_BOTH = 2

; Identifiants internes des tables de metriques AFM.
Global Const $PDFX_FONT_HELVETICA = 0
Global Const $PDFX_FONT_HELVETICA_BOLD = 1
Global Const $PDFX_FONT_TIMES = 2
Global Const $PDFX_FONT_TIMES_BOLD = 3
Global Const $PDFX_FONT_COURIER = 4

; Largeurs AFM (1/1000 em) pour les codes ASCII 32..126.
Global Const $PDFX_AFM_HELVETICA[95] = [278, 278, 355, 556, 556, 889, 667, 222, 333, 333, 389, 584, 278, 333, 278, 278, _
	556, 556, 556, 556, 556, 556, 556, 556, 556, 556, 278, 278, 584, 584, 584, 556, _
	1015, 667, 667, 722, 722, 667, 611, 778, 722, 278, 500, 667, 556, 833, 722, 778, _
	667, 778, 722, 667, 611, 722, 667, 944, 667, 667, 611, 278, 278, 278, 469, 556, _
	222, 556, 556, 500, 556, 556, 278, 556, 556, 222, 222, 500, 222, 833, 556, 556, _
	556, 556, 333, 500, 278, 556, 500, 722, 500, 500, 500, 334, 260, 334, 584]

Global Const $PDFX_AFM_HELVETICA_BOLD[95] = [278, 333, 474, 556, 556, 889, 722, 278, 333, 333, 389, 584, 278, 333, 278, 278, _
	556, 556, 556, 556, 556, 556, 556, 556, 556, 556, 333, 333, 584, 584, 584, 611, _
	975, 722, 722, 722, 722, 667, 611, 778, 722, 278, 556, 722, 611, 833, 722, 778, _
	667, 778, 722, 667, 611, 722, 667, 944, 667, 667, 611, 333, 278, 333, 584, 556, _
	278, 556, 611, 556, 611, 556, 333, 611, 611, 278, 278, 556, 278, 889, 611, 611, _
	611, 611, 389, 556, 333, 611, 556, 778, 556, 556, 500, 389, 280, 389, 584]

Global Const $PDFX_AFM_TIMES[95] = [250, 333, 408, 500, 500, 833, 778, 333, 333, 333, 500, 564, 250, 333, 250, 278, _
	500, 500, 500, 500, 500, 500, 500, 500, 500, 500, 278, 278, 564, 564, 564, 444, _
	921, 722, 667, 667, 722, 611, 556, 722, 722, 333, 389, 722, 611, 889, 722, 722, _
	556, 722, 667, 556, 611, 722, 722, 944, 722, 722, 611, 333, 278, 333, 469, 500, _
	333, 444, 500, 444, 500, 444, 333, 500, 500, 278, 278, 500, 278, 778, 500, 500, _
	500, 500, 333, 389, 278, 500, 500, 722, 500, 500, 444, 480, 200, 480, 541]

Global Const $PDFX_AFM_TIMES_BOLD[95] = [250, 333, 555, 500, 500, 1000, 833, 333, 333, 333, 500, 570, 250, 333, 250, 278, _
	500, 500, 500, 500, 500, 500, 500, 500, 500, 500, 333, 333, 570, 570, 570, 500, _
	930, 722, 667, 722, 722, 667, 611, 778, 778, 389, 500, 778, 667, 944, 722, 778, _
	611, 778, 722, 556, 667, 722, 722, 1000, 722, 722, 667, 333, 278, 333, 581, 500, _
	333, 500, 556, 444, 556, 444, 333, 500, 556, 278, 333, 556, 278, 833, 556, 500, _
	556, 556, 444, 389, 333, 556, 500, 722, 500, 500, 444, 394, 220, 394, 520]

; Caracteres speciaux WinAnsi : 0 Æ, 1 æ, 2 Ø, 3 ø, 4 ß, 5 ×, 6 ÷, 7 Ð, 8 ð, 9 Þ, 10 þ
Global Const $PDFX_AFM_SPECIAL[11][4] = [ _
	[1000, 1000, 889, 1000], _
	[889, 889, 444, 500], _
	[778, 778, 722, 778], _
	[611, 611, 500, 611], _
	[611, 556, 500, 556], _
	[584, 584, 564, 570], _
	[584, 584, 564, 570], _
	[722, 722, 722, 722], _
	[556, 556, 500, 556], _
	[667, 611, 556, 611], _
	[556, 556, 500, 556]]

; Etat global minimal : cycle de vie de GDI+ pour les images non JPEG.
Global $__PDFX_GdiPlusLoaded = False
Global $__PDFX_GdiPlusOwned = False

; Compresseur DEFLATE : tables figees, construites au premier usage, et profondeur de recherche
; LZ77 associee a chaque niveau de compression (0 = flux brut).
Global $__PDFX_ZLIB_READY = False
Global $__PDFX_ZLIB_LITCODE[288]
Global $__PDFX_ZLIB_LITBITS[288]
Global $__PDFX_ZLIB_LENCODE[259]
Global $__PDFX_ZLIB_LENEXTRA[259]
Global $__PDFX_ZLIB_LENBASE[259]
Global $__PDFX_ZLIB_DISTCODE[30]
Global $__PDFX_ZLIB_DISTEXTRA[30]
Global $__PDFX_ZLIB_DISTBASE[30]
Global $__PDFX_ZLIB_HEX[256]
Global Const $__PDFX_ZLIB_DEPTH[10] = [0, 1, 2, 3, 4, 6, 8, 12, 16, 24]
#EndRegion

#Region - Cycle de vie et pages -------------------------------------------------------------------------------------------------
; Creation du document, ajout de pages, dimensions et marges.

; #FUNCTION# ====================================================================================================================
; Name...........: _PDFX_New
; Description ...: Cree un document PDF en memoire et ouvre sa premiere page.
; Syntax.........: _PDFX_New($sFormat = "A4", $sOrient = "P", $iMarginMm = 15)
; Parameters ....: $sFormat   - format de page : A4 (defaut), A3, A5, Letter, Legal, ou LARGEURxHAUTEUR en
;                               millimetres.
;                  $sOrient   - orientation : P portrait (defaut) ou L paysage.
;                  $iMarginMm - marge par defaut, en millimetres (15 par defaut).
; Return values .: Success      - handle du document, a transmettre a toutes les autres fonctions.
; Author ........: Numeric1
; Modified.......:
; Remarks .......: Le handle est un tableau autonome : plusieurs documents peuvent etre construits en parallele. Un
;                  format inconnu retombe sur A4 portrait.
; Related .......: _PDFX_AddPage, _PDFX_SetFont, _PDFX_Save, _PDFX_Close
; Link ..........: https://www.autoitscript.com/forum/
; Example .......: Yes
; ===============================================================================================================================
Func _PDFX_New($sFormat = "A4", $sOrient = "P", $iMarginMm = 15)
	Local $oDocument[$__PDFX_DOC_SLOTS]

	Local $aPageSize = _PDFX_PaperSize($sFormat)
	Local $fPageWidth = $aPageSize[0], $fPageHeight = $aPageSize[1]
	If StringUpper($sOrient) = "L" Then
		Local $fSwap = $fPageWidth
		$fPageWidth = $fPageHeight
		$fPageHeight = $fSwap
	EndIf

	Local $aPages[0][4]
	Local $aObjects[3]
	$aObjects[1] = "<< /Type /Catalog /Pages 2 0 R >>"
	$aObjects[2] = ""
	Local $aFonts[0][4]
	Local $aImages[0][5]
	Local $aStates[0][3]
	Local $aMetadata[4] = ["", "", "", ""]
	Local $aHeaderFooter[13] = ["", "", "", "", "", "", 8, "0.4 0.4 0.4", "Helvetica", "", "0.4 0.4 0.4", "Helvetica", ""]
	Local $aBookmarks[0][4]
	Local $aPageLinks[0][7]

	$oDocument[$__PDFX_DOC_OBJECTS] = $aObjects
	$oDocument[$__PDFX_DOC_OBJECTCOUNT] = 2
	$oDocument[$__PDFX_DOC_PAGES] = $aPages
	$oDocument[$__PDFX_DOC_FONTS] = $aFonts
	$oDocument[$__PDFX_DOC_IMAGES] = $aImages
	$oDocument[$__PDFX_DOC_STATES] = $aStates
	$oDocument[$__PDFX_DOC_WIDTH] = $fPageWidth
	$oDocument[$__PDFX_DOC_HEIGHT] = $fPageHeight
	$oDocument[$__PDFX_DOC_CURRENTPAGE] = -1
	$oDocument[$__PDFX_DOC_CONTENT] = ""
	$oDocument[$__PDFX_DOC_ANNOTS] = ""
	$oDocument[$__PDFX_DOC_FONT] = 0
	$oDocument[$__PDFX_DOC_FONTSIZE] = 10
	$oDocument[$__PDFX_DOC_FILL] = "0 0 0"
	$oDocument[$__PDFX_DOC_STROKE] = "0 0 0"
	$oDocument[$__PDFX_DOC_LINEWIDTH] = 1
	$oDocument[$__PDFX_DOC_METADATA] = $aMetadata
	$oDocument[$__PDFX_DOC_HEADERFOOTER] = $aHeaderFooter
	$oDocument[$__PDFX_DOC_MARGIN] = _PDFX_Mm($iMarginMm)
	$oDocument[$__PDFX_DOC_DEFAULTWIDTH] = $fPageWidth
	$oDocument[$__PDFX_DOC_DEFAULTHEIGHT] = $fPageHeight
	$oDocument[$__PDFX_DOC_HFAPPLIED] = False
	$oDocument[$__PDFX_DOC_SAVED] = False
	$oDocument[$__PDFX_DOC_COMPRESSION] = 0
	$oDocument[$__PDFX_DOC_BOOKMARKS] = $aBookmarks
	$oDocument[$__PDFX_DOC_PAGELINKS] = $aPageLinks
	$oDocument[$__PDFX_DOC_PAGEMODE] = ""
	$oDocument[$__PDFX_DOC_PAGELAYOUT] = ""

	_PDFX_SetFont($oDocument, "Helvetica", 10)
	_PDFX_AddPage($oDocument)
	Return $oDocument
EndFunc   ;==>_PDFX_New

Func _PDFX_PaperSize($sFormat)
	Local $aPageSize[2]
	Switch StringUpper(StringStripWS($sFormat, 8))
		Case "A3"
			$aPageSize[0] = _PDFX_Mm(297)
			$aPageSize[1] = _PDFX_Mm(420)
		Case "A5"
			$aPageSize[0] = _PDFX_Mm(148)
			$aPageSize[1] = _PDFX_Mm(210)
		Case "LETTER", "US LETTER"
			$aPageSize[0] = _PDFX_Mm(215.9)
			$aPageSize[1] = _PDFX_Mm(279.4)
		Case "LEGAL"
			$aPageSize[0] = _PDFX_Mm(215.9)
			$aPageSize[1] = _PDFX_Mm(355.6)
		Case "A4", ""
			$aPageSize[0] = _PDFX_Mm(210)
			$aPageSize[1] = _PDFX_Mm(297)
		Case Else
			Local $aDimensions = StringSplit(StringUpper($sFormat), "X")
			If $aDimensions[0] = 2 Then
				$aPageSize[0] = _PDFX_Mm(Number($aDimensions[1]))
				$aPageSize[1] = _PDFX_Mm(Number($aDimensions[2]))
				If $aPageSize[0] <= 0 Or $aPageSize[1] <= 0 Then
					$aPageSize[0] = _PDFX_Mm(210)
					$aPageSize[1] = _PDFX_Mm(297)
				EndIf
			Else
				$aPageSize[0] = _PDFX_Mm(210)
				$aPageSize[1] = _PDFX_Mm(297)
			EndIf
	EndSwitch
	Return $aPageSize
EndFunc   ;==>_PDFX_PaperSize

; #FUNCTION# ====================================================================================================================
; Name...........: _PDFX_Mm
; Description ...: Convertit une longueur en millimetres vers l'unite interne, le point PDF.
; Syntax.........: _PDFX_Mm($fMillimetres)
; Parameters ....: $fMillimetres - longueur en millimetres.
; Return values .: Success      - valeur en points (1 pt = 1/72 pouce).
; Author ........: Numeric1
; Modified.......:
; Remarks .......: Le moteur travaille exclusivement en points ; cette fonction evite les conversions dispersees dans
;                  le code appelant.
; Related .......: _PDFX_New, _PDFX_Margin
; Link ..........: https://www.autoitscript.com/forum/
; Example .......: Yes
; ===============================================================================================================================
Func _PDFX_Mm($fMillimetres)
	Return $fMillimetres * 72 / 25.4
EndFunc   ;==>_PDFX_Mm

; #FUNCTION# ====================================================================================================================
; Name...........: _PDFX_AddPage
; Description ...: Ajoute une page au document et la rend courante.
; Syntax.........: _PDFX_AddPage(ByRef $oDocument, $fWidth = 0, $fHeight = 0)
; Parameters ....: $oDocument - handle du document.
;                  $fWidth    - largeur en points ; 0 = largeur par defaut du document.
;                  $fHeight   - hauteur en points ; 0 = hauteur par defaut du document.
; Return values .: Success      - index de la nouvelle page (base 0).
;                  Failure      - -1 et @error = 2 si le document a deja ete enregistre.
; Author ........: Numeric1
; Modified.......:
; Remarks .......: Le contenu de la page precedente est fige avant l'ajout. Un document enregistre par _PDFX_Save()
;                  est gele : plus aucune page ne peut y etre ajoutee.
; Related .......: _PDFX_New, _PDFX_SavePage, _PDFX_PageCount
; Link ..........: https://www.autoitscript.com/forum/
; Example .......: Yes
; ===============================================================================================================================
Func _PDFX_AddPage(ByRef $oDocument, $fWidth = 0, $fHeight = 0)
	If $oDocument[$__PDFX_DOC_SAVED] Then Return SetError(2, 0, -1)
	_PDFX_FlushPage($oDocument)

	Local $aPages = $oDocument[$__PDFX_DOC_PAGES]
	Local $iPageIndex = UBound($aPages)
	ReDim $aPages[$iPageIndex + 1][4]
	$aPages[$iPageIndex][0] = $fWidth > 0 ? $fWidth : $oDocument[$__PDFX_DOC_DEFAULTWIDTH]
	$aPages[$iPageIndex][1] = $fHeight > 0 ? $fHeight : $oDocument[$__PDFX_DOC_DEFAULTHEIGHT]
	$aPages[$iPageIndex][2] = ""
	$aPages[$iPageIndex][3] = ""
	$oDocument[$__PDFX_DOC_PAGES] = $aPages
	$oDocument[$__PDFX_DOC_CURRENTPAGE] = $iPageIndex
	$oDocument[$__PDFX_DOC_WIDTH] = $aPages[$iPageIndex][0]
	$oDocument[$__PDFX_DOC_HEIGHT] = $aPages[$iPageIndex][1]
	$oDocument[$__PDFX_DOC_CONTENT] = ""
	$oDocument[$__PDFX_DOC_ANNOTS] = ""
	Return $iPageIndex
EndFunc   ;==>_PDFX_AddPage

; #FUNCTION# ====================================================================================================================
; Name...........: _PDFX_PageCount
; Description ...: Renvoie le nombre de pages du document.
; Syntax.........: _PDFX_PageCount($oDocument)
; Parameters ....: $oDocument - handle du document.
; Return values .: Success      - nombre de pages (entier).
; Author ........: Numeric1
; Modified.......:
; Remarks .......:
; Related .......: _PDFX_AddPage
; Link ..........: https://www.autoitscript.com/forum/
; Example .......: Yes
; ===============================================================================================================================
Func _PDFX_PageCount($oDocument)
	Return UBound($oDocument[$__PDFX_DOC_PAGES])
EndFunc   ;==>_PDFX_PageCount

; #FUNCTION# ====================================================================================================================
; Name...........: _PDFX_PageWidth
; Description ...: Renvoie la largeur de la page courante.
; Syntax.........: _PDFX_PageWidth($oDocument)
; Parameters ....: $oDocument - handle du document.
; Return values .: Success      - largeur en points.
; Author ........: Numeric1
; Modified.......:
; Remarks .......:
; Related .......: _PDFX_PageHeight, _PDFX_Mm
; Link ..........: https://www.autoitscript.com/forum/
; Example .......: Yes
; ===============================================================================================================================
Func _PDFX_PageWidth($oDocument)
	Return $oDocument[$__PDFX_DOC_WIDTH]
EndFunc   ;==>_PDFX_PageWidth

; #FUNCTION# ====================================================================================================================
; Name...........: _PDFX_PageHeight
; Description ...: Renvoie la hauteur de la page courante.
; Syntax.........: _PDFX_PageHeight($oDocument)
; Parameters ....: $oDocument - handle du document.
; Return values .: Success      - hauteur en points.
; Author ........: Numeric1
; Modified.......:
; Remarks .......:
; Related .......: _PDFX_PageWidth, _PDFX_Mm
; Link ..........: https://www.autoitscript.com/forum/
; Example .......: Yes
; ===============================================================================================================================
Func _PDFX_PageHeight($oDocument)
	Return $oDocument[$__PDFX_DOC_HEIGHT]
EndFunc   ;==>_PDFX_PageHeight

; #FUNCTION# ====================================================================================================================
; Name...........: _PDFX_Margin
; Description ...: Renvoie la marge par defaut du document.
; Syntax.........: _PDFX_Margin($oDocument)
; Parameters ....: $oDocument - handle du document.
; Return values .: Success      - marge en points.
; Author ........: Numeric1
; Modified.......:
; Remarks .......:
; Related .......: _PDFX_New, _PDFX_Mm
; Link ..........: https://www.autoitscript.com/forum/
; Example .......: Yes
; ===============================================================================================================================
Func _PDFX_Margin($oDocument)
	Return $oDocument[$__PDFX_DOC_MARGIN]
EndFunc   ;==>_PDFX_Margin

; #FUNCTION# ====================================================================================================================
; Name...........: _PDFX_SavePage
; Description ...: Fige le contenu de la page courante dans le document.
; Syntax.........: _PDFX_SavePage(ByRef $oDocument)
; Parameters ....: $oDocument - handle du document.
; Return values .: Success      - None.
; Author ........: Numeric1
; Modified.......:
; Remarks .......: Normalement inutile : _PDFX_AddPage() et _PDFX_Save() figent la page automatiquement.
; Related .......: _PDFX_AddPage, _PDFX_Save
; Link ..........: https://www.autoitscript.com/forum/
; Example .......: No
; ===============================================================================================================================
Func _PDFX_SavePage(ByRef $oDocument)
	_PDFX_FlushPage($oDocument)
EndFunc   ;==>_PDFX_SavePage

Func _PDFX_FlushPage(ByRef $oDocument)
	If $oDocument[$__PDFX_DOC_SAVED] Then Return
	Local $iPage = $oDocument[$__PDFX_DOC_CURRENTPAGE]
	If $iPage < 0 Then Return
	Local $aPages = $oDocument[$__PDFX_DOC_PAGES]
	If $iPage >= UBound($aPages) Then Return
	$aPages[$iPage][2] = $oDocument[$__PDFX_DOC_CONTENT]
	$aPages[$iPage][3] = $oDocument[$__PDFX_DOC_ANNOTS]
	$oDocument[$__PDFX_DOC_PAGES] = $aPages
	$oDocument[$__PDFX_DOC_CONTENT] = ""
	$oDocument[$__PDFX_DOC_ANNOTS] = ""
EndFunc   ;==>_PDFX_FlushPage

#EndRegion

#Region - Objets indirects ------------------------------------------------------------------------------------------------------
; Allocation des objets numerotes qui composent le fichier PDF.

Func _PDFX_AddObject(ByRef $oDocument, $vBody)
	Local $iObjectNumber = $oDocument[$__PDFX_DOC_OBJECTCOUNT] + 1
	Local $aObjects = $oDocument[$__PDFX_DOC_OBJECTS]
	If $iObjectNumber >= UBound($aObjects) Then ReDim $aObjects[$iObjectNumber + 32]
	$aObjects[$iObjectNumber] = $vBody
	$oDocument[$__PDFX_DOC_OBJECTS] = $aObjects
	$oDocument[$__PDFX_DOC_OBJECTCOUNT] = $iObjectNumber
	Return $iObjectNumber
EndFunc   ;==>_PDFX_AddObject

#EndRegion

#Region - Polices et metriques --------------------------------------------------------------------------------------------------
; Selection des polices standard et calcul exact des largeurs AFM.

; #FUNCTION# ====================================================================================================================
; Name...........: _PDFX_SetFont
; Description ...: Selectionne la police et la taille utilisees par les fonctions de texte.
; Syntax.........: _PDFX_SetFont(ByRef $oDocument, $sFamily = "Helvetica", $iSize = 0, $sStyle = "")
; Parameters ....: $sFamily - famille : Helvetica (defaut), Times, Courier ; alias acceptes : serif, mono, courrier,
;                             georgia.
;                  $iSize   - taille en points ; 0 conserve la taille courante.
;                  $sStyle  - style : B gras, I italique, BI gras italique.
; Return values .: Success      - True.
;                  Failure      - False et @error = 1 si la police ne peut pas etre creee.
; Author ........: Numeric1
; Modified.......:
; Remarks .......: Les 14 polices standard PDF sont disponibles sans fichier de police ni embarquement.
; Related .......: _PDFX_Font, _PDFX_FontSize, _PDFX_TextWidth
; Link ..........: https://www.autoitscript.com/forum/
; Example .......: Yes
; ===============================================================================================================================
Func _PDFX_SetFont(ByRef $oDocument, $sFamily = "Helvetica", $iSize = 0, $sStyle = "")
	Local $iFont = _PDFX_EnsureFont($oDocument, $sFamily, $sStyle)
	If $iFont < 0 Then Return SetError(1, 0, False)
	$oDocument[$__PDFX_DOC_FONT] = $iFont
	If $iSize > 0 Then $oDocument[$__PDFX_DOC_FONTSIZE] = $iSize
	Return True
EndFunc   ;==>_PDFX_SetFont

; #FUNCTION# ====================================================================================================================
; Name...........: _PDFX_Font
; Description ...: Renvoie le nom PDF de la police courante.
; Syntax.........: _PDFX_Font($oDocument)
; Parameters ....: $oDocument - handle du document.
; Return values .: Success      - nom de base, par exemple Helvetica-Bold.
; Author ........: Numeric1
; Modified.......:
; Remarks .......:
; Related .......: _PDFX_SetFont, _PDFX_FontSize
; Link ..........: https://www.autoitscript.com/forum/
; Example .......: Yes
; ===============================================================================================================================
Func _PDFX_Font($oDocument)
	Local $aFonts = $oDocument[$__PDFX_DOC_FONTS]
	Return $aFonts[$oDocument[$__PDFX_DOC_FONT]][0]
EndFunc   ;==>_PDFX_Font

; #FUNCTION# ====================================================================================================================
; Name...........: _PDFX_FontSize
; Description ...: Renvoie la taille de police courante.
; Syntax.........: _PDFX_FontSize($oDocument)
; Parameters ....: $oDocument - handle du document.
; Return values .: Success      - taille en points.
; Author ........: Numeric1
; Modified.......:
; Remarks .......:
; Related .......: _PDFX_SetFont, _PDFX_Font
; Link ..........: https://www.autoitscript.com/forum/
; Example .......: Yes
; ===============================================================================================================================
Func _PDFX_FontSize($oDocument)
	Return $oDocument[$__PDFX_DOC_FONTSIZE]
EndFunc   ;==>_PDFX_FontSize

Func _PDFX_EnsureFont(ByRef $oDocument, $sFamily, $sStyle)
	Local $aBaseFont = _PDFX_BaseFont($sFamily, $sStyle)
	Local $aFonts = $oDocument[$__PDFX_DOC_FONTS]
	For $iFontIndex = 0 To UBound($aFonts) - 1
		If $aFonts[$iFontIndex][0] = $aBaseFont[0] Then Return $iFontIndex
	Next

	Local $iObject = _PDFX_AddObject($oDocument, "<< /Type /Font /Subtype /Type1 /BaseFont /" & $aBaseFont[0] & " /Encoding /WinAnsiEncoding >>")
	Local $iNewIndex = UBound($aFonts)
	ReDim $aFonts[$iNewIndex + 1][4]
	$aFonts[$iNewIndex][0] = $aBaseFont[0]
	$aFonts[$iNewIndex][1] = $iObject
	$aFonts[$iNewIndex][2] = "F" & ($iNewIndex + 1)
	$aFonts[$iNewIndex][3] = $aBaseFont[1]
	$oDocument[$__PDFX_DOC_FONTS] = $aFonts
	Return $iNewIndex
EndFunc   ;==>_PDFX_EnsureFont

; [nom PDF de la police, table de largeur]
Func _PDFX_BaseFont($sFamily, $sStyle)
	Local $sFlags = StringUpper(StringStripWS($sStyle, 8))
	Local $bBold = StringInStr($sFlags, "B") > 0
	Local $bItalic = StringInStr($sFlags, "I") > 0
	Local $aFont[2]
	Local $sFamilyKey = StringLower(StringStripWS($sFamily, 8))

	If StringInStr($sFamilyKey, "courier") Or StringInStr($sFamilyKey, "mono") Or $sFamilyKey = "courrier" Then
		If $bBold And $bItalic Then
			$aFont[0] = "Courier-BoldOblique"
		ElseIf $bBold Then
			$aFont[0] = "Courier-Bold"
		ElseIf $bItalic Then
			$aFont[0] = "Courier-Oblique"
		Else
			$aFont[0] = "Courier"
		EndIf
		$aFont[1] = $PDFX_FONT_COURIER
		Return $aFont
	EndIf

	If StringInStr($sFamilyKey, "times") Or StringInStr($sFamilyKey, "serif") Or StringInStr($sFamilyKey, "georgia") Then
		If $bBold And $bItalic Then
			$aFont[0] = "Times-BoldItalic"
			$aFont[1] = $PDFX_FONT_TIMES_BOLD
		ElseIf $bBold Then
			$aFont[0] = "Times-Bold"
			$aFont[1] = $PDFX_FONT_TIMES_BOLD
		ElseIf $bItalic Then
			$aFont[0] = "Times-Italic"
			$aFont[1] = $PDFX_FONT_TIMES
		Else
			$aFont[0] = "Times-Roman"
			$aFont[1] = $PDFX_FONT_TIMES
		EndIf
		Return $aFont
	EndIf

	If $bBold And $bItalic Then
		$aFont[0] = "Helvetica-BoldOblique"
		$aFont[1] = $PDFX_FONT_HELVETICA_BOLD
	ElseIf $bBold Then
		$aFont[0] = "Helvetica-Bold"
		$aFont[1] = $PDFX_FONT_HELVETICA_BOLD
	ElseIf $bItalic Then
		$aFont[0] = "Helvetica-Oblique"
		$aFont[1] = $PDFX_FONT_HELVETICA
	Else
		$aFont[0] = "Helvetica"
		$aFont[1] = $PDFX_FONT_HELVETICA
	EndIf
	Return $aFont
EndFunc   ;==>_PDFX_BaseFont

; #FUNCTION# ====================================================================================================================
; Name...........: _PDFX_TextWidth
; Description ...: Calcule la largeur d'un texte avec la police courante.
; Syntax.........: _PDFX_TextWidth($oDocument, $sText, $iSize = 0)
; Parameters ....: $oDocument - handle du document.
;                  $sText     - texte a mesurer.
;                  $iSize     - taille en points ; 0 = taille courante.
; Return values .: Success      - largeur en points.
; Author ........: Numeric1
; Modified.......:
; Remarks .......: Le calcul utilise les metriques AFM : le resultat est exact pour les polices standard, sans rendu
;                  GDI.
; Related .......: _PDFX_SetFont, _PDFX_TextAlign
; Link ..........: https://www.autoitscript.com/forum/
; Example .......: Yes
; ===============================================================================================================================
Func _PDFX_TextWidth($oDocument, $sText, $iSize = 0)
	Return _PDFX_Measure($oDocument, $sText, $iSize > 0 ? $iSize : $oDocument[$__PDFX_DOC_FONTSIZE], $oDocument[$__PDFX_DOC_FONT])
EndFunc   ;==>_PDFX_TextWidth

Func _PDFX_Measure($oDocument, $sText, $iSize, $iFont = -1)
	If $iFont < 0 Then $iFont = $oDocument[$__PDFX_DOC_FONT]
	Local $aFonts = $oDocument[$__PDFX_DOC_FONTS]
	Local $iWidthTable = $aFonts[$iFont][3]
	Local $iLength = StringLen($sText)
	If $iLength = 0 Then Return 0

	Local $iTotalWidth = 0
	For $iChar = 1 To $iLength
		$iTotalWidth += _PDFX_CharWidth($iWidthTable, AscW(StringMid($sText, $iChar, 1)))
	Next
	Return $iTotalWidth * $iSize / 1000
EndFunc   ;==>_PDFX_Measure

Func _PDFX_CharWidth($iTable, $iCode)
	If $iTable = $PDFX_FONT_COURIER Then Return 600
	If $iCode < 32 Then Return 0
	If $iCode <= 126 Then
		Switch $iTable
			Case $PDFX_FONT_HELVETICA
				Return $PDFX_AFM_HELVETICA[$iCode - 32]
			Case $PDFX_FONT_HELVETICA_BOLD
				Return $PDFX_AFM_HELVETICA_BOLD[$iCode - 32]
			Case $PDFX_FONT_TIMES
				Return $PDFX_AFM_TIMES[$iCode - 32]
			Case $PDFX_FONT_TIMES_BOLD
				Return $PDFX_AFM_TIMES_BOLD[$iCode - 32]
		EndSwitch
		Return 500
	EndIf

	Local $iSpecialIndex = _PDFX_SpecialIndex($iCode)
	If $iSpecialIndex >= 0 Then Return $PDFX_AFM_SPECIAL[$iSpecialIndex][$iTable]

	Local $iBaseCode = _PDFX_BaseChar($iCode)
	If $iBaseCode >= 32 And $iBaseCode <= 126 Then Return _PDFX_CharWidth($iTable, $iBaseCode)
	Return 500
EndFunc   ;==>_PDFX_CharWidth

; Index dans $PDFX_AFM_SPECIAL, ou -1.
Func _PDFX_SpecialIndex($iCode)
	Switch $iCode
		Case 0xC6
			Return 0
		Case 0xE6
			Return 1
		Case 0xD8
			Return 2
		Case 0xF8
			Return 3
		Case 0xDF
			Return 4
		Case 0xD7
			Return 5
		Case 0xF7
			Return 6
		Case 0xD0
			Return 7
		Case 0xF0
			Return 8
		Case 0xDE
			Return 9
		Case 0xFE
			Return 10
	EndSwitch
	Return -1
EndFunc   ;==>_PDFX_SpecialIndex

; Pour un caractere latin accentue, renvoie la lettre de base (pour la largeur).
Func _PDFX_BaseChar($iCode)
	Switch $iCode
		Case 0xC0 To 0xC5, 0xE0 To 0xE5
			Return ($iCode >= 0xE0) ? 97 : 65
		Case 0xC7, 0xE7
			Return ($iCode = 0xE7) ? 99 : 67
		Case 0xC8 To 0xCB, 0xE8 To 0xEB
			Return ($iCode >= 0xE8) ? 101 : 69
		Case 0xCC To 0xCF, 0xEC To 0xEF
			Return ($iCode >= 0xEC) ? 105 : 73
		Case 0xD1, 0xF1
			Return ($iCode = 0xF1) ? 110 : 78
		Case 0xD2 To 0xD6, 0xF2 To 0xF6
			Return ($iCode >= 0xF2) ? 111 : 79
		Case 0xD9 To 0xDC, 0xF9 To 0xFC
			Return ($iCode >= 0xF9) ? 117 : 85
		Case 0xDD, 0xFD, 0xFF
			Return 121
	EndSwitch
	; Caracteres typographiques WinAnsi -> largeur approximative
	Switch $iCode
		Case 0x80
			Return 32
		Case 0x85
			Return 46
		Case 0x91, 0x92, 0x98
			Return 39
		Case 0x93, 0x94
			Return 34
		Case 0x96
			Return 45
		Case 0x97
			Return 45
	EndSwitch
	Return -1
EndFunc   ;==>_PDFX_BaseChar

#EndRegion

#Region - Etat graphique --------------------------------------------------------------------------------------------------------
; Couleurs, epaisseur de trait, tirets et opacite.

; #FUNCTION# ====================================================================================================================
; Name...........: _PDFX_SetFill
; Description ...: Definit la couleur de remplissage des formes et du texte.
; Syntax.........: _PDFX_SetFill(ByRef $oDocument, $vColor)
; Parameters ....: $oDocument - handle du document.
;                  $vColor    - 0xRRGGBB, tableau [rouge, vert, bleu], chaine de trois nombres separes par des
;                               virgules, ou nom (red, navy, gris...).
; Return values .: Success      - True.
;                  Failure      - True et @error = 1 si une composante a ete ramenee dans l'intervalle [0, 255].
; Author ........: Numeric1
; Modified.......:
; Remarks .......: La couleur reste active jusqu'au prochain appel ; chaque primitive capture la couleur au moment de
;                  son emission.
; Related .......: _PDFX_SetStroke, _PDFX_Rect, _PDFX_Text
; Link ..........: https://www.autoitscript.com/forum/
; Example .......: Yes
; ===============================================================================================================================
Func _PDFX_SetFill(ByRef $oDocument, $vColor)
	$oDocument[$__PDFX_DOC_FILL] = _PDFX_Color($vColor)
	Return SetError(@error, 0, True)
EndFunc   ;==>_PDFX_SetFill

; #FUNCTION# ====================================================================================================================
; Name...........: _PDFX_SetStroke
; Description ...: Definit la couleur du trait des formes.
; Syntax.........: _PDFX_SetStroke(ByRef $oDocument, $vColor)
; Parameters ....: $oDocument - handle du document.
;                  $vColor    - meme syntaxe que _PDFX_SetFill().
; Return values .: Success      - True.
;                  Failure      - True et @error = 1 si une composante a ete ramenee dans l'intervalle [0, 255].
; Author ........: Numeric1
; Modified.......:
; Remarks .......:
; Related .......: _PDFX_SetFill, _PDFX_SetLineWidth, _PDFX_Line
; Link ..........: https://www.autoitscript.com/forum/
; Example .......: Yes
; ===============================================================================================================================
Func _PDFX_SetStroke(ByRef $oDocument, $vColor)
	$oDocument[$__PDFX_DOC_STROKE] = _PDFX_Color($vColor)
	Return SetError(@error, 0, True)
EndFunc   ;==>_PDFX_SetStroke

; #FUNCTION# ====================================================================================================================
; Name...........: _PDFX_SetLineWidth
; Description ...: Definit l'epaisseur du trait.
; Syntax.........: _PDFX_SetLineWidth(ByRef $oDocument, $fWidth)
; Parameters ....: $oDocument - handle du document.
;                  $fWidth    - epaisseur en points ; une valeur inferieure ou egale a 0 est ramenee a 0.1.
; Return values .: Success      - True.
; Author ........: Numeric1
; Modified.......:
; Remarks .......:
; Related .......: _PDFX_SetStroke, _PDFX_SetDash
; Link ..........: https://www.autoitscript.com/forum/
; Example .......: Yes
; ===============================================================================================================================
Func _PDFX_SetLineWidth(ByRef $oDocument, $fWidth)
	If $fWidth <= 0 Then $fWidth = 0.1
	$oDocument[$__PDFX_DOC_LINEWIDTH] = $fWidth
	Return True
EndFunc   ;==>_PDFX_SetLineWidth

; #FUNCTION# ====================================================================================================================
; Name...........: _PDFX_SetDash
; Description ...: Definit un motif de tirets pour les traits suivants.
; Syntax.........: _PDFX_SetDash(ByRef $oDocument, $fOn, $fOff = 0)
; Parameters ....: $oDocument - handle du document.
;                  $fOn       - longueur du trait, en points ; 0 ou moins retablit un trait plein.
;                  $fOff      - longueur de l'espace, en points ; 0 = meme valeur que le trait.
; Return values .: Success      - True.
; Author ........: Numeric1
; Modified.......:
; Remarks .......: Le motif s'applique a tous les traits suivants, y compris les bordures de tableaux, jusqu'au
;                  prochain changement. _PDFX_SetDash($oDocument, 0) emet le motif vide [] et revient au trait continu.
; Related .......: _PDFX_SetLineWidth, _PDFX_Line
; Link ..........: https://www.autoitscript.com/forum/
; Example .......: Yes
; ===============================================================================================================================
Func _PDFX_SetDash(ByRef $oDocument, $fOn, $fOff = 0)
	If $fOn <= 0 Then
		_PDFX_Op($oDocument, "[] 0 d")
		Return True
	EndIf
	If $fOff <= 0 Then $fOff = $fOn
	_PDFX_Op($oDocument, "[" & _PDFX_F($fOn) & " " & _PDFX_F($fOff) & "] 0 d")
	Return True
EndFunc   ;==>_PDFX_SetDash

; #FUNCTION# ====================================================================================================================
; Name...........: _PDFX_SetAlpha
; Description ...: Definit l'opacite des remplissages et des traits.
; Syntax.........: _PDFX_SetAlpha(ByRef $oDocument, $fAlpha, $fStroke = -1)
; Parameters ....: $oDocument - handle du document.
;                  $fAlpha    - opacite de remplissage, de 0 (transparent) a 1 (opaque).
;                  $fStroke   - opacite du trait ; valeur negative = identique au remplissage.
; Return values .: Success      - True.
;                  Failure      - True et @error = 1 si une opacite a ete ramenee dans l'intervalle [0, 1].
; Author ........: Numeric1
; Modified.......:
; Remarks .......: Implemente par un ExtGState /ca /CA, cree une seule fois par couple de valeurs puis reutilise.
;                  Les valeurs negatives sont ramenees a 0, celles superieures a 1 a 1.
; Related .......: _PDFX_SetFill, _PDFX_SetStroke
; Link ..........: https://www.autoitscript.com/forum/
; Example .......: Yes
; ===============================================================================================================================
Func _PDFX_SetAlpha(ByRef $oDocument, $fAlpha, $fStroke = -1)
	If $fStroke < 0 Then $fStroke = $fAlpha

	Local $fFillAlpha = _PDFX_Clamp($fAlpha, 0, 1)
	Local $iFillError = @error
	Local $fStrokeAlpha = _PDFX_Clamp($fStroke, 0, 1)
	Local $iError = ($iFillError Or @error) ? 1 : 0

	Local $sStateKey = _PDFX_F($fFillAlpha) & "|" & _PDFX_F($fStrokeAlpha)
	Local $aStates = $oDocument[$__PDFX_DOC_STATES]
	Local $iObject = 0, $sResourceName = ""
	For $iState = 0 To UBound($aStates) - 1
		If $aStates[$iState][0] = $sStateKey Then
			$iObject = $aStates[$iState][1]
			$sResourceName = $aStates[$iState][2]
			ExitLoop
		EndIf
	Next
	If $iObject = 0 Then
		$iObject = _PDFX_AddObject($oDocument, "<< /Type /ExtGState /ca " & _PDFX_F($fFillAlpha) & " /CA " & _PDFX_F($fStrokeAlpha) & " >>")
		Local $iNewState = UBound($aStates)
		ReDim $aStates[$iNewState + 1][3]
		$aStates[$iNewState][0] = $sStateKey
		$aStates[$iNewState][1] = $iObject
		$aStates[$iNewState][2] = "GS" & ($iNewState + 1)
		$oDocument[$__PDFX_DOC_STATES] = $aStates
		$sResourceName = $aStates[$iNewState][2]
	EndIf
	_PDFX_Op($oDocument, "/" & $sResourceName & " gs")
	Return SetError($iError, 0, True)
EndFunc   ;==>_PDFX_SetAlpha

Func _PDFX_Color($vColor)
	Local $iRed = 0, $iGreen = 0, $iBlue = 0

	If IsArray($vColor) Then
		If UBound($vColor) >= 3 Then
			$iRed = $vColor[0]
			$iGreen = $vColor[1]
			$iBlue = $vColor[2]
		EndIf
	ElseIf IsString($vColor) Then
		Local $sValue = StringStripWS($vColor, 8)
		Local $vNamed = _PDFX_ColorName($sValue)
		If $vNamed >= 0 Then
			$vColor = $vNamed
		ElseIf StringInStr($sValue, ",") Then
			Local $aParts = StringSplit($sValue, ",", 2)
			If UBound($aParts) >= 3 Then
				$iRed = Number($aParts[0])
				$iGreen = Number($aParts[1])
				$iBlue = Number($aParts[2])
				Local $sClamped = _PDFX_ColorStr($iRed, $iGreen, $iBlue)
				Return SetError(@error, 0, $sClamped)
			EndIf
			Return "0 0 0"
		Else
			$vColor = Number($sValue)
		EndIf
	EndIf

	If Not IsArray($vColor) Then
		Local $iColor = Number($vColor)
		$iRed = BitAND(BitShift($iColor, 16), 0xFF)
		$iGreen = BitAND(BitShift($iColor, 8), 0xFF)
		$iBlue = BitAND($iColor, 0xFF)
	EndIf
	; Return _PDFX_ColorStr() perdrait @error : on l'intercepte avant de le propager.
	Local $sRgb = _PDFX_ColorStr($iRed, $iGreen, $iBlue)
	Return SetError(@error, 0, $sRgb)
EndFunc   ;==>_PDFX_Color

Func _PDFX_ColorStr($iRed, $iGreen, $iBlue)
	Local $iError = 0
	$iRed = _PDFX_Clamp($iRed, 0, 255)
	If @error Then $iError = 1
	$iGreen = _PDFX_Clamp($iGreen, 0, 255)
	If @error Then $iError = 1
	$iBlue = _PDFX_Clamp($iBlue, 0, 255)
	If @error Then $iError = 1
	Return SetError($iError, 0, _PDFX_F($iRed / 255) & " " & _PDFX_F($iGreen / 255) & " " & _PDFX_F($iBlue / 255))
EndFunc   ;==>_PDFX_ColorStr

Func _PDFX_ColorName($sColorName)
	Switch StringLower($sColorName)
		Case "black", "noir"
			Return 0x000000
		Case "white", "blanc"
			Return 0xFFFFFF
		Case "red", "rouge"
			Return 0xFF0000
		Case "green", "vert"
			Return 0x008000
		Case "blue", "bleu"
			Return 0x0000FF
		Case "gray", "grey", "gris"
			Return 0x808080
		Case "lightgray", "lightgrey"
			Return 0xD3D3D3
		Case "navy", "marine"
			Return 0x000080
		Case "teal"
			Return 0x008080
		Case "orange"
			Return 0xFFA500
		Case "purple", "violet"
			Return 0x800080
		Case "yellow", "jaune"
			Return 0xFFFF00
		Case "silver"
			Return 0xC0C0C0
		Case "maroon", "bordeaux"
			Return 0x800000
		Case "olive"
			Return 0x808000
		Case "lime"
			Return 0x00FF00
		Case "aqua", "cyan"
			Return 0x00FFFF
		Case "fuchsia", "magenta"
			Return 0xFF00FF
	EndSwitch
	Return -1
EndFunc   ;==>_PDFX_ColorName

#EndRegion

#Region - Texte et encodage -----------------------------------------------------------------------------------------------------
; Emission du texte, alignement, retour a la ligne et conversion WinAnsi.

; #FUNCTION# ====================================================================================================================
; Name...........: _PDFX_Text
; Description ...: Ecrit une ligne de texte.
; Syntax.........: _PDFX_Text(ByRef $oDocument, $fX, $fY, $sText, $iSize = 0)
; Parameters ....: $oDocument - handle du document.
;                  $fX        - abscisse du debut du texte, en points.
;                  $fY        - ordonnee du HAUT du texte, et non de la ligne de base.
;                  $sText     - texte a ecrire.
;                  $iSize     - taille en points ; 0 = taille courante.
; Return values .: Success      - ordonnee du haut de la ligne suivante (interligne 1.2).
; Author ........: Numeric1
; Modified.......:
; Remarks .......: Le texte est encode en WinAnsi ; les caracteres non representables deviennent '?'.
; Related .......: _PDFX_TextAlign, _PDFX_TextWrap, _PDFX_SetFont
; Link ..........: https://www.autoitscript.com/forum/
; Example .......: Yes
; ===============================================================================================================================
Func _PDFX_Text(ByRef $oDocument, $fX, $fY, $sText, $iSize = 0)
	_PDFX_EmitText($oDocument, $fX, $fY, $sText, $iSize)
	Return $fY + ($iSize > 0 ? $iSize : $oDocument[$__PDFX_DOC_FONTSIZE]) * 1.2
EndFunc   ;==>_PDFX_Text

; #FUNCTION# ====================================================================================================================
; Name...........: _PDFX_TextAlign
; Description ...: Ecrit une ligne de texte alignee dans une boite horizontale.
; Syntax.........: _PDFX_TextAlign(ByRef $oDocument, $fX, $fY, $fWidth, $sText, $sAlign = "L", $iSize = 0)
; Parameters ....: $oDocument - handle du document.
;                  $fX        - bord gauche de la boite d'alignement.
;                  $fY        - ordonnee du haut du texte.
;                  $fWidth    - largeur de la boite d'alignement, en points.
;                  $sText     - texte a ecrire.
;                  $sAlign    - L gauche (defaut), C centre, R droite.
;                  $iSize     - taille en points ; 0 = taille courante.
; Return values .: Success      - ordonnee du haut de la ligne suivante (interligne 1.2).
; Author ........: Numeric1
; Modified.......:
; Remarks .......: Pour C et R, la largeur reelle du texte est mesuree avec les metriques AFM avant placement.
; Related .......: _PDFX_Text, _PDFX_TextWidth
; Link ..........: https://www.autoitscript.com/forum/
; Example .......: Yes
; ===============================================================================================================================
Func _PDFX_TextAlign(ByRef $oDocument, $fX, $fY, $fWidth, $sText, $sAlign = "L", $iSize = 0)
	_PDFX_EmitText($oDocument, $fX, $fY, $sText, $iSize, $sAlign, $fWidth)
	Return $fY + ($iSize > 0 ? $iSize : $oDocument[$__PDFX_DOC_FONTSIZE]) * 1.2
EndFunc   ;==>_PDFX_TextAlign

; #FUNCTION# ====================================================================================================================
; Name...........: _PDFX_TextWrap
; Description ...: Ecrit un texte sur plusieurs lignes, avec retour a la ligne automatique.
; Syntax.........: _PDFX_TextWrap(ByRef $oDocument, $fX, $fY, $fWidth, $sText, $iSize = 0, $fLeading = 0, $sAlign = "L", $bPageBreak = False)
; Parameters ....: $oDocument  - handle du document.
;                  $fX         - bord gauche de la colonne.
;                  $fY         - ordonnee du haut de la premiere ligne.
;                  $fWidth     - largeur utile de la colonne, en points.
;                  $sText      - texte a ecrire ; les retours chariot sont respectes.
;                  $iSize      - taille en points ; 0 = taille courante.
;                  $fLeading   - interligne en points ; 0 = 1.2 fois la taille.
;                  $sAlign     - L gauche (defaut), C centre, R droite.
;                  $bPageBreak - True : ajoute une page des que la marge basse est atteinte.
; Return values .: Success      - ordonnee du haut de la premiere ligne libre.
; Author ........: Numeric1
; Modified.......:
; Remarks .......: Les mots plus larges que la colonne sont coupes caractere par caractere ; les paragraphes vides
;                  sont conserves.
; Related .......: _PDFX_Text, _PDFX_TextAlign, _PDFX_Wrap
; Link ..........: https://www.autoitscript.com/forum/
; Example .......: Yes
; ===============================================================================================================================
Func _PDFX_TextWrap(ByRef $oDocument, $fX, $fY, $fWidth, $sText, $iSize = 0, $fLeading = 0, $sAlign = "L", $bPageBreak = False)
	Local $fFontSize = $iSize > 0 ? $iSize : $oDocument[$__PDFX_DOC_FONTSIZE]
	Local $fLineHeight = $fLeading > 0 ? $fLeading : $fFontSize * 1.2
	Local $aLines = _PDFX_Wrap($oDocument, $sText, $fWidth, $fFontSize)

	For $iLine = 0 To UBound($aLines) - 1
		If $bPageBreak And $fY + $fFontSize > $oDocument[$__PDFX_DOC_HEIGHT] - $oDocument[$__PDFX_DOC_MARGIN] Then
			_PDFX_AddPage($oDocument)
			$fY = $oDocument[$__PDFX_DOC_MARGIN]
		EndIf
		_PDFX_EmitText($oDocument, $fX, $fY, $aLines[$iLine], $fFontSize, $sAlign, $fWidth)
		$fY += $fLineHeight
	Next
	Return $fY
EndFunc   ;==>_PDFX_TextWrap

; Decoupe un texte en lignes tenant dans $fWidth (respecte les retours chariot).
Func _PDFX_Wrap($oDocument, $sText, $fWidth, $iSize = 0)
	Local $fFontSize = $iSize > 0 ? $iSize : $oDocument[$__PDFX_DOC_FONTSIZE]
	Local $aLines[0]

	Local $sNormalized = StringReplace($sText, @CRLF, @LF)
	$sNormalized = StringReplace($sNormalized, @CR, @LF)
	Local $aParagraphs = StringSplit($sNormalized, @LF, 3)

	For $iParagraph = 0 To UBound($aParagraphs) - 1
		Local $sParagraph = $aParagraphs[$iParagraph]
		If $sParagraph = "" Then
			_PDFX_ArrayPush($aLines, "")
			ContinueLoop
		EndIf

		Local $aWords = StringSplit($sParagraph, " ", 3)
		Local $sLine = ""
		For $iWord = 0 To UBound($aWords) - 1
			Local $sWord = $aWords[$iWord]
			If $sWord = "" Then ContinueLoop

			; Mot plus large que la colonne : on le coupe caractere par caractere.
			If _PDFX_Measure($oDocument, $sWord, $fFontSize) > $fWidth Then
				If $sLine <> "" Then
					_PDFX_ArrayPush($aLines, $sLine)
					$sLine = ""
				EndIf
				Local $sChunk = ""
				For $iChar = 1 To StringLen($sWord)
					Local $sCandidate = $sChunk & StringMid($sWord, $iChar, 1)
					If _PDFX_Measure($oDocument, $sCandidate, $fFontSize) > $fWidth And $sChunk <> "" Then
						_PDFX_ArrayPush($aLines, $sChunk)
						$sChunk = StringMid($sWord, $iChar, 1)
					Else
						$sChunk = $sCandidate
					EndIf
				Next
				$sLine = $sChunk
				ContinueLoop
			EndIf

			If $sLine = "" Then
				$sLine = $sWord
			Else
				Local $sJoined = $sLine & " " & $sWord
				If _PDFX_Measure($oDocument, $sJoined, $fFontSize) <= $fWidth Then
					$sLine = $sJoined
				Else
					_PDFX_ArrayPush($aLines, $sLine)
					$sLine = $sWord
				EndIf
			EndIf
		Next
		_PDFX_ArrayPush($aLines, $sLine)
	Next
	Return $aLines
EndFunc   ;==>_PDFX_Wrap

Func _PDFX_EmitText(ByRef $oDocument, $fX, $fY, $sText, $iSize, $sAlign = "L", $fWidth = 0)
	Local $fFontSize = $iSize > 0 ? $iSize : $oDocument[$__PDFX_DOC_FONTSIZE]
	Local $sEscaped = _PDFX_Escape($sText)
	If $sEscaped = "" Then Return

	Local $aFonts = $oDocument[$__PDFX_DOC_FONTS]
	Local $sResourceName = $aFonts[$oDocument[$__PDFX_DOC_FONT]][2]

	If $fWidth > 0 And $sAlign <> "L" Then
		Local $fTextWidth = _PDFX_Measure($oDocument, $sText, $fFontSize)
		If $sAlign = "C" Then
			$fX += ($fWidth - $fTextWidth) / 2
		ElseIf $sAlign = "R" Then
			$fX += $fWidth - $fTextWidth
		EndIf
	EndIf

	Local $fBaseline = $oDocument[$__PDFX_DOC_HEIGHT] - $fY - $fFontSize * 0.8
	Local $sStream = "BT" & @LF & "/" & $sResourceName & " " & _PDFX_F($fFontSize) & " Tf" & @LF
	$sStream &= $oDocument[$__PDFX_DOC_FILL] & " rg" & @LF
	$sStream &= "1 0 0 1 " & _PDFX_F($fX) & " " & _PDFX_F($fBaseline) & " Tm" & @LF
	$sStream &= "(" & $sEscaped & ") Tj" & @LF & "ET" & @LF
	_PDFX_Op($oDocument, $sStream)
EndFunc   ;==>_PDFX_EmitText

; Chaine PDF : echappe ( ) \ et encode en WinAnsi (octal pour > 126).
Func _PDFX_Escape($sText)
	Local $iLength = StringLen($sText)
	If $iLength = 0 Then Return ""
	Local $sEscaped = ""
	For $iChar = 1 To $iLength
		Local $iCode = AscW(StringMid($sText, $iChar, 1))
		Local $iByte = _PDFX_WinAnsi($iCode)
		If $iByte = 0x28 Or $iByte = 0x29 Or $iByte = 0x5C Then
			$sEscaped &= "\" & Chr($iByte)
		ElseIf $iByte >= 32 And $iByte <= 126 Then
			$sEscaped &= Chr($iByte)
		Else
			$sEscaped &= "\" & _PDFX_Oct3($iByte)
		EndIf
	Next
	Return $sEscaped
EndFunc   ;==>_PDFX_Escape

; Octet en notation octale sur 3 chiffres (AutoIt n'a pas de Oct()).
Func _PDFX_Oct3($iByte)
	Return Chr(48 + Int($iByte / 64)) & Chr(48 + Int(Mod($iByte, 64) / 8)) & Chr(48 + Mod($iByte, 8))
EndFunc   ;==>_PDFX_Oct3

; Point de code Unicode -> octet WinAnsi.
Func _PDFX_WinAnsi($iCode)
	If ($iCode >= 32 And $iCode <= 126) Or ($iCode >= 160 And $iCode <= 255) Then Return $iCode
	Switch $iCode
		Case 0x20AC
			Return 0x80
		Case 0x201A
			Return 0x82
		Case 0x0192
			Return 0x83
		Case 0x201E
			Return 0x84
		Case 0x2026
			Return 0x85
		Case 0x2020
			Return 0x86
		Case 0x2021
			Return 0x87
		Case 0x02C6
			Return 0x88
		Case 0x2030
			Return 0x89
		Case 0x0160
			Return 0x8A
		Case 0x2039
			Return 0x8B
		Case 0x0152
			Return 0x8C
		Case 0x017D
			Return 0x8E
		Case 0x2018
			Return 0x91
		Case 0x2019
			Return 0x92
		Case 0x201C
			Return 0x93
		Case 0x201D
			Return 0x94
		Case 0x2022
			Return 0x95
		Case 0x2013
			Return 0x96
		Case 0x2014
			Return 0x97
		Case 0x02DC
			Return 0x98
		Case 0x2122
			Return 0x99
		Case 0x0161
			Return 0x9A
		Case 0x203A
			Return 0x9B
		Case 0x0153
			Return 0x9C
		Case 0x017E
			Return 0x9E
		Case 0x0178
			Return 0x9F
		Case 0x0A, 0x0D, 0x09
			Return 32
	EndSwitch
	Return 63 ; '?'
EndFunc   ;==>_PDFX_WinAnsi

#EndRegion

#Region - Formes vectorielles ---------------------------------------------------------------------------------------------------
; Segments, rectangles, ellipses, polygones et courbes de Bezier.

; #FUNCTION# ====================================================================================================================
; Name...........: _PDFX_Line
; Description ...: Trace un segment de droite.
; Syntax.........: _PDFX_Line(ByRef $oDocument, $fX1, $fY1, $fX2, $fY2)
; Parameters ....: $oDocument - handle du document.
;                  $fX1       - abscisse du point de depart.
;                  $fY1       - ordonnee du point de depart.
;                  $fX2       - abscisse du point d'arrivee.
;                  $fY2       - ordonnee du point d'arrivee.
; Return values .: Success      - True.
; Author ........: Numeric1
; Modified.......:
; Remarks .......: Utilise la couleur de trait et l'epaisseur courantes.
; Related .......: _PDFX_SetStroke, _PDFX_SetLineWidth, _PDFX_SetDash
; Link ..........: https://www.autoitscript.com/forum/
; Example .......: Yes
; ===============================================================================================================================
Func _PDFX_Line(ByRef $oDocument, $fX1, $fY1, $fX2, $fY2)
	_PDFX_Op($oDocument, _PDFX_StrokeState($oDocument) & _PDFX_F($fX1) & " " & _PDFX_F(_PDFX_Y($oDocument, $fY1)) & " m " & _
			_PDFX_F($fX2) & " " & _PDFX_F(_PDFX_Y($oDocument, $fY2)) & " l S")
	Return True
EndFunc   ;==>_PDFX_Line

; #FUNCTION# ====================================================================================================================
; Name...........: _PDFX_Rect
; Description ...: Trace un rectangle.
; Syntax.........: _PDFX_Rect(ByRef $oDocument, $fX, $fY, $fWidth, $fHeight, $iStyle = $PDFX_STROKE)
; Parameters ....: $oDocument - handle du document.
;                  $fX        - abscisse du coin superieur gauche.
;                  $fY        - ordonnee du coin superieur gauche.
;                  $fWidth    - largeur, en points.
;                  $fHeight   - hauteur, en points.
;                  $iStyle    - $PDFX_STROKE (defaut), $PDFX_FILL ou $PDFX_BOTH.
; Return values .: Success      - True.
; Author ........: Numeric1
; Modified.......:
; Remarks .......:
; Related .......: _PDFX_Fill, _PDFX_RoundRect, _PDFX_SetFill, _PDFX_SetStroke
; Link ..........: https://www.autoitscript.com/forum/
; Example .......: Yes
; ===============================================================================================================================
Func _PDFX_Rect(ByRef $oDocument, $fX, $fY, $fWidth, $fHeight, $iStyle = $PDFX_STROKE)
	Local $sStream = _PDFX_StyleState($oDocument, $iStyle)
	$sStream &= _PDFX_F($fX) & " " & _PDFX_F(_PDFX_Y($oDocument, $fY + $fHeight)) & " " & _PDFX_F($fWidth) & " " & _PDFX_F($fHeight) & " re " & _PDFX_PaintOp($iStyle)
	_PDFX_Op($oDocument, $sStream)
	Return True
EndFunc   ;==>_PDFX_Rect

; #FUNCTION# ====================================================================================================================
; Name...........: _PDFX_RoundRect
; Description ...: Trace un rectangle a coins arrondis.
; Syntax.........: _PDFX_RoundRect(ByRef $oDocument, $fX, $fY, $fWidth, $fHeight, $fRadius, $iStyle = $PDFX_STROKE)
; Parameters ....: $oDocument - handle du document.
;                  $fX        - abscisse du coin superieur gauche.
;                  $fY        - ordonnee du coin superieur gauche.
;                  $fWidth    - largeur, en points.
;                  $fHeight   - hauteur, en points.
;                  $fRadius   - rayon des coins ; borne a la moitie du plus petit cote.
;                  $iStyle    - $PDFX_STROKE (defaut), $PDFX_FILL ou $PDFX_BOTH.
; Return values .: Success      - True.
; Author ........: Numeric1
; Modified.......:
; Remarks .......: Un rayon nul ou negatif produit un rectangle ordinaire.
; Related .......: _PDFX_Rect, _PDFX_Circle
; Link ..........: https://www.autoitscript.com/forum/
; Example .......: Yes
; ===============================================================================================================================
Func _PDFX_RoundRect(ByRef $oDocument, $fX, $fY, $fWidth, $fHeight, $fRadius, $iStyle = $PDFX_STROKE)
	If $fRadius <= 0 Then Return _PDFX_Rect($oDocument, $fX, $fY, $fWidth, $fHeight, $iStyle)
	If $fRadius > $fWidth / 2 Then $fRadius = $fWidth / 2
	If $fRadius > $fHeight / 2 Then $fRadius = $fHeight / 2

	Local $fTop = $fY, $fBottom = $fY + $fHeight
	Local $fKappa = 0.5523 * $fRadius
	Local $sStream = _PDFX_StyleState($oDocument, $iStyle)

	$sStream &= _PDFX_F($fX + $fRadius) & " " & _PDFX_F(_PDFX_Y($oDocument, $fTop)) & " m" & @LF
	$sStream &= _PDFX_F($fX + $fWidth - $fRadius) & " " & _PDFX_F(_PDFX_Y($oDocument, $fTop)) & " l" & @LF
	$sStream &= _PDFX_CurveTo($oDocument, $fX + $fWidth - $fRadius + $fKappa, $fTop, $fX + $fWidth, $fTop + $fRadius - $fKappa, $fX + $fWidth, $fTop + $fRadius)
	$sStream &= _PDFX_F($fX + $fWidth) & " " & _PDFX_F(_PDFX_Y($oDocument, $fBottom - $fRadius)) & " l" & @LF
	$sStream &= _PDFX_CurveTo($oDocument, $fX + $fWidth, $fBottom - $fRadius + $fKappa, $fX + $fWidth - $fRadius + $fKappa, $fBottom, $fX + $fWidth - $fRadius, $fBottom)
	$sStream &= _PDFX_F($fX + $fRadius) & " " & _PDFX_F(_PDFX_Y($oDocument, $fBottom)) & " l" & @LF
	$sStream &= _PDFX_CurveTo($oDocument, $fX + $fRadius - $fKappa, $fBottom, $fX, $fBottom - $fRadius + $fKappa, $fX, $fBottom - $fRadius)
	$sStream &= _PDFX_F($fX) & " " & _PDFX_F(_PDFX_Y($oDocument, $fTop + $fRadius)) & " l" & @LF
	$sStream &= _PDFX_CurveTo($oDocument, $fX, $fTop + $fRadius - $fKappa, $fX + $fRadius - $fKappa, $fTop, $fX + $fRadius, $fTop)
	$sStream &= _PDFX_PaintOp($iStyle)

	_PDFX_Op($oDocument, $sStream)
	Return True
EndFunc   ;==>_PDFX_RoundRect

; #FUNCTION# ====================================================================================================================
; Name...........: _PDFX_Ellipse
; Description ...: Trace une ellipse definie par son centre et ses deux rayons.
; Syntax.........: _PDFX_Ellipse(ByRef $oDocument, $fCenterX, $fCenterY, $fRadiusX, $fRadiusY, $iStyle = $PDFX_STROKE)
; Parameters ....: $oDocument - handle du document.
;                  $fCenterX  - abscisse du centre.
;                  $fCenterY  - ordonnee du centre.
;                  $fRadiusX  - rayon horizontal, en points.
;                  $fRadiusY  - rayon vertical, en points.
;                  $iStyle    - $PDFX_STROKE (defaut), $PDFX_FILL ou $PDFX_BOTH.
; Return values .: Success      - True.
; Author ........: Numeric1
; Modified.......:
; Remarks .......: Quatre courbes de Bezier cubiques, avec la constante kappa 0.5523.
; Related .......: _PDFX_Circle, _PDFX_Bezier
; Link ..........: https://www.autoitscript.com/forum/
; Example .......: Yes
; ===============================================================================================================================
Func _PDFX_Ellipse(ByRef $oDocument, $fCenterX, $fCenterY, $fRadiusX, $fRadiusY, $iStyle = $PDFX_STROKE)
	Local $fKappa = 0.5523
	Local $sStream = _PDFX_StyleState($oDocument, $iStyle)

	$sStream &= _PDFX_F($fCenterX + $fRadiusX) & " " & _PDFX_F(_PDFX_Y($oDocument, $fCenterY)) & " m" & @LF
	$sStream &= _PDFX_CurveTo($oDocument, $fCenterX + $fRadiusX, $fCenterY - $fKappa * $fRadiusY, $fCenterX + $fKappa * $fRadiusX, $fCenterY - $fRadiusY, $fCenterX, $fCenterY - $fRadiusY)
	$sStream &= _PDFX_CurveTo($oDocument, $fCenterX - $fKappa * $fRadiusX, $fCenterY - $fRadiusY, $fCenterX - $fRadiusX, $fCenterY - $fKappa * $fRadiusY, $fCenterX - $fRadiusX, $fCenterY)
	$sStream &= _PDFX_CurveTo($oDocument, $fCenterX - $fRadiusX, $fCenterY + $fKappa * $fRadiusY, $fCenterX - $fKappa * $fRadiusX, $fCenterY + $fRadiusY, $fCenterX, $fCenterY + $fRadiusY)
	$sStream &= _PDFX_CurveTo($oDocument, $fCenterX + $fKappa * $fRadiusX, $fCenterY + $fRadiusY, $fCenterX + $fRadiusX, $fCenterY + $fKappa * $fRadiusY, $fCenterX + $fRadiusX, $fCenterY)
	$sStream &= _PDFX_PaintOp($iStyle)

	_PDFX_Op($oDocument, $sStream)
	Return True
EndFunc   ;==>_PDFX_Ellipse

; #FUNCTION# ====================================================================================================================
; Name...........: _PDFX_Circle
; Description ...: Trace un cercle.
; Syntax.........: _PDFX_Circle(ByRef $oDocument, $fCenterX, $fCenterY, $fRadius, $iStyle = $PDFX_STROKE)
; Parameters ....: $oDocument - handle du document.
;                  $fCenterX  - abscisse du centre.
;                  $fCenterY  - ordonnee du centre.
;                  $fRadius   - rayon, en points.
;                  $iStyle    - $PDFX_STROKE (defaut), $PDFX_FILL ou $PDFX_BOTH.
; Return values .: Success      - True.
; Author ........: Numeric1
; Modified.......:
; Remarks .......:
; Related .......: _PDFX_Ellipse
; Link ..........: https://www.autoitscript.com/forum/
; Example .......: Yes
; ===============================================================================================================================
Func _PDFX_Circle(ByRef $oDocument, $fCenterX, $fCenterY, $fRadius, $iStyle = $PDFX_STROKE)
	Return _PDFX_Ellipse($oDocument, $fCenterX, $fCenterY, $fRadius, $fRadius, $iStyle)
EndFunc   ;==>_PDFX_Circle

; #FUNCTION# ====================================================================================================================
; Name...........: _PDFX_Polyline
; Description ...: Trace une ligne brisee ou un polygone.
; Syntax.........: _PDFX_Polyline(ByRef $oDocument, $aPoints, $bClose = False, $iStyle = $PDFX_STROKE)
; Parameters ....: $oDocument - handle du document.
;                  $aPoints   - tableau [n][2] de sommets : $aPoints[i][0] = x, $aPoints[i][1] = y.
;                  $bClose    - True ferme le trace (polygone).
;                  $iStyle    - $PDFX_STROKE (defaut), $PDFX_FILL ou $PDFX_BOTH.
; Return values .: Success      - True.
;                  Failure      - False si le tableau contient moins de deux sommets.
; Author ........: Numeric1
; Modified.......:
; Remarks .......:
; Related .......: _PDFX_Line, _PDFX_Bezier
; Link ..........: https://www.autoitscript.com/forum/
; Example .......: Yes
; ===============================================================================================================================
Func _PDFX_Polyline(ByRef $oDocument, $aPoints, $bClose = False, $iStyle = $PDFX_STROKE)
	Local $iCount = UBound($aPoints)
	If $iCount < 2 Then Return False
	Local $sStream = _PDFX_StyleState($oDocument, $iStyle)
	$sStream &= _PDFX_F($aPoints[0][0]) & " " & _PDFX_F(_PDFX_Y($oDocument, $aPoints[0][1])) & " m" & @LF
	For $iPoint = 1 To $iCount - 1
		$sStream &= _PDFX_F($aPoints[$iPoint][0]) & " " & _PDFX_F(_PDFX_Y($oDocument, $aPoints[$iPoint][1])) & " l" & @LF
	Next
	If $bClose Then $sStream &= "h" & @LF
	$sStream &= _PDFX_PaintOp($iStyle)
	_PDFX_Op($oDocument, $sStream)
	Return True
EndFunc   ;==>_PDFX_Polyline

; #FUNCTION# ====================================================================================================================
; Name...........: _PDFX_Bezier
; Description ...: Trace une courbe de Bezier cubique.
; Syntax.........: _PDFX_Bezier(ByRef $oDocument, $fX1, $fY1, $fControl1X, $fControl1Y, $fControl2X, $fControl2Y, $fX2, $fY2, $iStyle = $PDFX_STROKE)
; Parameters ....: $oDocument  - handle du document.
;                  $fX1        - abscisse du point de depart.
;                  $fY1        - ordonnee du point de depart.
;                  $fControl1X - abscisse du premier point de controle.
;                  $fControl1Y - ordonnee du premier point de controle.
;                  $fControl2X - abscisse du second point de controle.
;                  $fControl2Y - ordonnee du second point de controle.
;                  $fX2        - abscisse du point d'arrivee.
;                  $fY2        - ordonnee du point d'arrivee.
;                  $iStyle     - $PDFX_STROKE (defaut), $PDFX_FILL ou $PDFX_BOTH.
; Return values .: Success      - True.
; Author ........: Numeric1
; Modified.......:
; Remarks .......:
; Related .......: _PDFX_Polyline, _PDFX_Ellipse
; Link ..........: https://www.autoitscript.com/forum/
; Example .......: Yes
; ===============================================================================================================================
Func _PDFX_Bezier(ByRef $oDocument, $fX1, $fY1, $fControl1X, $fControl1Y, $fControl2X, $fControl2Y, $fX2, $fY2, $iStyle = $PDFX_STROKE)
	Local $sStream = _PDFX_StyleState($oDocument, $iStyle)
	$sStream &= _PDFX_F($fX1) & " " & _PDFX_F(_PDFX_Y($oDocument, $fY1)) & " m" & @LF
	$sStream &= _PDFX_CurveTo($oDocument, $fControl1X, $fControl1Y, $fControl2X, $fControl2Y, $fX2, $fY2)
	$sStream &= _PDFX_PaintOp($iStyle)
	_PDFX_Op($oDocument, $sStream)
	Return True
EndFunc   ;==>_PDFX_Bezier

Func _PDFX_CurveTo($oDocument, $fControl1X, $fControl1Y, $fControl2X, $fControl2Y, $fX, $fY)
	Return _PDFX_F($fControl1X) & " " & _PDFX_F(_PDFX_Y($oDocument, $fControl1Y)) & " " & _
		   _PDFX_F($fControl2X) & " " & _PDFX_F(_PDFX_Y($oDocument, $fControl2Y)) & " " & _
		   _PDFX_F($fX) & " " & _PDFX_F(_PDFX_Y($oDocument, $fY)) & " c" & @LF
EndFunc   ;==>_PDFX_CurveTo

; Couleur + epaisseur de trait.
Func _PDFX_StrokeState($oDocument)
	Return $oDocument[$__PDFX_DOC_STROKE] & " RG" & @LF & _PDFX_F($oDocument[$__PDFX_DOC_LINEWIDTH]) & " w" & @LF
EndFunc   ;==>_PDFX_StrokeState

Func _PDFX_StyleState($oDocument, $iStyle)
	Local $sStream = ""
	If $iStyle <> $PDFX_FILL Then $sStream &= _PDFX_StrokeState($oDocument)
	$sStream &= $oDocument[$__PDFX_DOC_FILL] & " rg" & @LF
	Return $sStream & "q" & @LF
EndFunc   ;==>_PDFX_StyleState

Func _PDFX_PaintOp($iStyle)
	Switch $iStyle
		Case $PDFX_FILL
			Return "f" & @LF & "Q"
		Case $PDFX_BOTH
			Return "B" & @LF & "Q"
		Case Else
			Return "S" & @LF & "Q"
	EndSwitch
EndFunc   ;==>_PDFX_PaintOp

; Coordonnee y (haut -> bas) vers l'espace PDF (bas -> haut).
Func _PDFX_Y($oDocument, $fY)
	Return $oDocument[$__PDFX_DOC_HEIGHT] - $fY
EndFunc   ;==>_PDFX_Y

#EndRegion

#Region - Images ----------------------------------------------------------------------------------------------------------------
; Insertion, mise a l'echelle et conversion des images.

; #FUNCTION# ====================================================================================================================
; Name...........: _PDFX_Image
; Description ...: Insere une image JPEG, PNG, BMP ou GIF.
; Syntax.........: _PDFX_Image(ByRef $oDocument, $sPath, $fX, $fY, $fWidth = 0, $fHeight = 0)
; Parameters ....: $oDocument - handle du document.
;                  $sPath     - chemin du fichier image.
;                  $fX        - abscisse du coin superieur gauche.
;                  $fY        - ordonnee du coin superieur gauche.
;                  $fWidth    - largeur en points ; 0 = taille naturelle a 96 dpi.
;                  $fHeight   - hauteur en points ; 0 = proportions conservees.
; Return values .: Success      - True.
;                  Failure      - False et @error = 1 si le fichier est absent, 2 si l'image ne peut pas etre lue.
; Author ........: Numeric1
; Modified.......:
; Remarks .......: Les JPEG sont embarques octet pour octet, sans recompression. Les autres formats passent par GDI+
;                  et sont aplatis sur blanc. Une image deja utilisee n'est stockee qu'une fois par document.
; Related .......: _PDFX_ImageFit, _PDFX_ImageInfo
; Link ..........: https://www.autoitscript.com/forum/
; Example .......: Yes
; ===============================================================================================================================
Func _PDFX_Image(ByRef $oDocument, $sPath, $fX, $fY, $fWidth = 0, $fHeight = 0)
	If Not FileExists($sPath) Then Return SetError(1, 0, False)

	Local $aImage = _PDFX_EnsureImage($oDocument, $sPath)
	If Not IsArray($aImage) Then Return SetError(2, 0, False)

	Local $iPixelWidth = $aImage[2], $iPixelHeight = $aImage[3]
	Local $fNaturalWidth = $iPixelWidth * 72 / 96, $fNaturalHeight = $iPixelHeight * 72 / 96

	If $fWidth <= 0 And $fHeight <= 0 Then
		$fWidth = $fNaturalWidth
		$fHeight = $fNaturalHeight
	ElseIf $fWidth <= 0 Then
		$fWidth = $fHeight * $iPixelWidth / $iPixelHeight
	ElseIf $fHeight <= 0 Then
		$fHeight = $fWidth * $iPixelHeight / $iPixelWidth
	EndIf

	Local $sStream = "q" & @LF
	$sStream &= _PDFX_F($fWidth) & " 0 0 " & _PDFX_F($fHeight) & " " & _PDFX_F($fX) & " " & _PDFX_F(_PDFX_Y($oDocument, $fY + $fHeight)) & " cm" & @LF
	$sStream &= "/" & $aImage[4] & " Do" & @LF & "Q"
	_PDFX_Op($oDocument, $sStream)
	Return True
EndFunc   ;==>_PDFX_Image

; #FUNCTION# ====================================================================================================================
; Name...........: _PDFX_ImageFit
; Description ...: Insere une image reduite pour tenir entierement dans une boite, proportions conservees.
; Syntax.........: _PDFX_ImageFit(ByRef $oDocument, $sPath, $fX, $fY, $fWidth, $fHeight, $sAlign = "C")
; Parameters ....: $oDocument - handle du document.
;                  $sPath     - chemin du fichier image.
;                  $fX        - abscisse de la boite d'accueil.
;                  $fY        - ordonnee de la boite d'accueil.
;                  $fWidth    - largeur de la boite, en points.
;                  $fHeight   - hauteur de la boite, en points.
;                  $sAlign    - C centre (defaut), ou combinaison de L, R, T, B.
; Return values .: Success      - True.
;                  Failure      - False et @error = 2 ou 3 si l'image est illisible ou vide.
; Author ........: Numeric1
; Modified.......:
; Remarks .......: Aucune deformation : l'image est mise a l'echelle du cote limitant, puis positionnee dans la boite.
; Related .......: _PDFX_Image, _PDFX_ImageInfo
; Link ..........: https://www.autoitscript.com/forum/
; Example .......: Yes
; ===============================================================================================================================
Func _PDFX_ImageFit(ByRef $oDocument, $sPath, $fX, $fY, $fWidth, $fHeight, $sAlign = "C")
	Local $aImage = _PDFX_EnsureImage($oDocument, $sPath)
	If Not IsArray($aImage) Then Return SetError(2, 0, False)
	Local $iPixelWidth = $aImage[2], $iPixelHeight = $aImage[3]
	If $iPixelWidth < 1 Or $iPixelHeight < 1 Then Return SetError(3, 0, False)

	Local $fAspect = $iPixelWidth / $iPixelHeight
	Local $fDrawWidth = $fWidth, $fDrawHeight = $fWidth / $fAspect
	If $fDrawHeight > $fHeight Then
		$fDrawHeight = $fHeight
		$fDrawWidth = $fHeight * $fAspect
	EndIf

	Local $fOffsetX = ($fWidth - $fDrawWidth) / 2, $fOffsetY = ($fHeight - $fDrawHeight) / 2
	Local $sAlignCode = StringUpper($sAlign)
	If StringInStr($sAlignCode, "L") Then
		$fOffsetX = 0
	ElseIf StringInStr($sAlignCode, "R") Then
		$fOffsetX = $fWidth - $fDrawWidth
	EndIf
	If StringInStr($sAlignCode, "T") Then
		$fOffsetY = 0
	ElseIf StringInStr($sAlignCode, "B") Then
		$fOffsetY = $fHeight - $fDrawHeight
	EndIf

	Local $bDrawn = _PDFX_Image($oDocument, $sPath, $fX + $fOffsetX, $fY + $fOffsetY, $fDrawWidth, $fDrawHeight)
	Return SetError(@error, 0, $bDrawn)
EndFunc   ;==>_PDFX_ImageFit

; #FUNCTION# ====================================================================================================================
; Name...........: _PDFX_ImageInfo
; Description ...: Renvoie les caracteristiques d'une image et l'inscrit dans le document.
; Syntax.........: _PDFX_ImageInfo(ByRef $oDocument, $sPath)
; Parameters ....: $oDocument - handle du document.
;                  $sPath     - chemin du fichier image.
; Return values .: Success      - tableau de 6 elements : 0 largeur en pixels, 1 hauteur en pixels, 2 largeur en
;                                  points a 96 dpi, 3 hauteur en points, 4 taille du fichier en octets, 5 extension en
;                                  majuscules.
;                  Failure      - 0 et @error = 1 ou 2.
; Author ........: Numeric1
; Modified.......:
; Remarks .......: L'image est ajoutee aux ressources du PDF, qu'elle soit dessinee ensuite ou non.
; Related .......: _PDFX_Image, _PDFX_ImageFit
; Link ..........: https://www.autoitscript.com/forum/
; Example .......: Yes
; ===============================================================================================================================
Func _PDFX_ImageInfo(ByRef $oDocument, $sPath)
	If Not FileExists($sPath) Then Return SetError(1, 0, 0)
	Local $aImage = _PDFX_EnsureImage($oDocument, $sPath)
	If Not IsArray($aImage) Then Return SetError(2, 0, 0)
	Local $aInfo[6]
	$aInfo[0] = $aImage[2]
	$aInfo[1] = $aImage[3]
	$aInfo[2] = $aImage[2] * 72 / 96
	$aInfo[3] = $aImage[3] * 72 / 96
	$aInfo[4] = FileGetSize($sPath)
	$aInfo[5] = StringUpper(_PDFX_Ext($sPath))
	Return $aInfo
EndFunc   ;==>_PDFX_ImageInfo

Func _PDFX_EnsureImage(ByRef $oDocument, $sPath)
	Local $sFullPath = _PDFX_AbsPath($sPath)
	Local $aImages = $oDocument[$__PDFX_DOC_IMAGES]
	For $iIndex = 0 To UBound($aImages) - 1
		If $aImages[$iIndex][0] = $sFullPath Then Return _PDFX_ImageRow($aImages, $iIndex)
	Next

	Local $iPixelWidth = 0, $iPixelHeight = 0, $iComponents = 0, $bAdobe = False
	Local $bImageData = 0

	Local $sExtension = StringLower(_PDFX_Ext($sFullPath))
	If $sExtension = "jpg" Or $sExtension = "jpeg" Then
		$bImageData = _PDFX_ReadBinary($sFullPath)
		If Not IsBinary($bImageData) Then Return 0
		If Not _PDFX_JpegInfo($bImageData, $iPixelWidth, $iPixelHeight, $iComponents, $bAdobe) Then Return 0
	Else
		$bImageData = _PDFX_ConvertToJpeg($sFullPath, $iPixelWidth, $iPixelHeight)
		If Not IsBinary($bImageData) Then Return 0
		$iComponents = 3
	EndIf

	Local $sColorSpace = "/DeviceRGB"
	Local $sDecode = ""
	If $iComponents = 1 Then
		$sColorSpace = "/DeviceGray"
	ElseIf $iComponents = 4 Then
		$sColorSpace = "/DeviceCMYK"
		; Adobe ecrit les valeurs CMJN inversees ; sans APP14, on respecte l'ordre PDF.
		If $bAdobe Then $sDecode = " /Decode [1 0 1 0 1 0 1 0]"
	EndIf

	Local $sDictionary = "<< /Type /XObject /Subtype /Image /Width " & $iPixelWidth & " /Height " & $iPixelHeight & _
			" /ColorSpace " & $sColorSpace & " /BitsPerComponent 8" & $sDecode & _
			" /Filter /DCTDecode /Length " & BinaryLen($bImageData) & " >>"
	Local $aObjectBody[3]
	$aObjectBody[0] = $sDictionary & @LF & "stream" & @LF
	$aObjectBody[1] = $bImageData
	$aObjectBody[2] = @LF & "endstream"

	Local $iObject = _PDFX_AddObject($oDocument, $aObjectBody)
	Local $iNewIndex = UBound($aImages)
	ReDim $aImages[$iNewIndex + 1][5]
	$aImages[$iNewIndex][0] = $sFullPath
	$aImages[$iNewIndex][1] = $iObject
	$aImages[$iNewIndex][2] = $iPixelWidth
	$aImages[$iNewIndex][3] = $iPixelHeight
	$aImages[$iNewIndex][4] = "Im" & ($iNewIndex + 1)
	$oDocument[$__PDFX_DOC_IMAGES] = $aImages
	Return _PDFX_ImageRow($aImages, $iNewIndex)
EndFunc   ;==>_PDFX_EnsureImage

; Retourner directement une ligne de tableau 2D provoque une erreur fatale AutoIt :
; on renvoie une copie 1D.
Func _PDFX_ImageRow($aImages, $iIndex)
	Local $aRow[5] = [$aImages[$iIndex][0], $aImages[$iIndex][1], $aImages[$iIndex][2], $aImages[$iIndex][3], $aImages[$iIndex][4]]
	Return $aRow
EndFunc   ;==>_PDFX_ImageRow

; Asc() sur un binaire lit la chaine "0x..", pas l'octet : Number() est requis.
Func _PDFX_ByteAt($bData, $iPos)
	Return Number(BinaryMid($bData, $iPos, 1))
EndFunc   ;==>_PDFX_ByteAt

; Lit la geometrie JPEG et signale les fichiers CMJN ecrits par Adobe (marqueur APP14).
Func _PDFX_JpegInfo($bData, ByRef $iWidth, ByRef $iHeight, ByRef $iComponents, ByRef $bAdobe)
	Local $iLength = BinaryLen($bData)
	$bAdobe = False
	If $iLength < 8 Then Return False
	If BinaryMid($bData, 1, 2) <> Binary("0xFFD8") Then Return False

	Local $iPosition = 3
	While $iPosition < $iLength - 8
		If _PDFX_ByteAt($bData, $iPosition) <> 0xFF Then
			$iPosition += 1
			ContinueLoop
		EndIf
		Local $iMarker = _PDFX_ByteAt($bData, $iPosition + 1)
		If $iMarker = 0xD8 Or $iMarker = 0x01 Or ($iMarker >= 0xD0 And $iMarker <= 0xD7) Then
			$iPosition += 2
		ElseIf $iMarker = 0xD9 Or $iMarker = 0xDA Then
			Return False
		Else
			Local $iSegmentLength = _PDFX_ByteAt($bData, $iPosition + 2) * 256 + _PDFX_ByteAt($bData, $iPosition + 3)
			If $iMarker = 0xEE And $iSegmentLength >= 14 Then
				If _PDFX_ByteAt($bData, $iPosition + 4) = 0x41 And _PDFX_ByteAt($bData, $iPosition + 5) = 0x64 And _
						_PDFX_ByteAt($bData, $iPosition + 6) = 0x6F And _PDFX_ByteAt($bData, $iPosition + 7) = 0x62 And _
						_PDFX_ByteAt($bData, $iPosition + 8) = 0x65 Then $bAdobe = True
			EndIf
			If ($iMarker >= 0xC0 And $iMarker <= 0xCF) And $iMarker <> 0xC4 And $iMarker <> 0xC8 And $iMarker <> 0xCC Then
				$iHeight = _PDFX_ByteAt($bData, $iPosition + 5) * 256 + _PDFX_ByteAt($bData, $iPosition + 6)
				$iWidth = _PDFX_ByteAt($bData, $iPosition + 7) * 256 + _PDFX_ByteAt($bData, $iPosition + 8)
				$iComponents = _PDFX_ByteAt($bData, $iPosition + 9)
				Return ($iWidth > 0 And $iHeight > 0)
			EndIf
			$iPosition += 2 + $iSegmentLength
		EndIf
	WEnd
	Return False
EndFunc   ;==>_PDFX_JpegInfo

; Convertit tout format GDI+ (PNG, BMP, GIF, TIFF...) en JPEG sur fond blanc.
Func _PDFX_ConvertToJpeg($sPath, ByRef $iWidth, ByRef $iHeight)
	If Not $__PDFX_GdiPlusLoaded Then
		_GDIPlus_Startup()
		$__PDFX_GdiPlusLoaded = True
		$__PDFX_GdiPlusOwned = True
	EndIf

	Local $hImage = _GDIPlus_ImageLoadFromFile($sPath)
	If Not $hImage Then Return 0
	$iWidth = _GDIPlus_ImageGetWidth($hImage)
	$iHeight = _GDIPlus_ImageGetHeight($hImage)
	If $iWidth < 1 Or $iHeight < 1 Then
		_GDIPlus_ImageDispose($hImage)
		Return 0
	EndIf

	Local $hBitmap = _GDIPlus_BitmapCreateFromScan0($iWidth, $iHeight)
	Local $hGraphics = _GDIPlus_ImageGetGraphicsContext($hBitmap)
	_GDIPlus_GraphicsClear($hGraphics, 0xFFFFFFFF)
	_GDIPlus_GraphicsDrawImage($hGraphics, $hImage, 0, 0)

	Local $sTempFile = @TempDir & "\pdfx_" & Random(100000, 999999, 1) & ".jpg"
	_GDIPlus_ImageSaveToFileEx($hBitmap, $sTempFile, _GDIPlus_EncodersGetCLSID("JPG"))

	_GDIPlus_GraphicsDispose($hGraphics)
	_GDIPlus_BitmapDispose($hBitmap)
	_GDIPlus_ImageDispose($hImage)

	Local $bJpeg = _PDFX_ReadBinary($sTempFile)
	FileDelete($sTempFile)
	If Not IsBinary($bJpeg) Then Return 0

	Local $iJpegWidth = 0, $iJpegHeight = 0, $iJpegComponents = 0, $bJpegAdobe = False
	If Not _PDFX_JpegInfo($bJpeg, $iJpegWidth, $iJpegHeight, $iJpegComponents, $bJpegAdobe) Then Return 0
	Return $bJpeg
EndFunc   ;==>_PDFX_ConvertToJpeg

#EndRegion

#Region - Tableaux --------------------------------------------------------------------------------------------------------------
; Tableaux pagines avec en-tete repete, zebrures et grille.

; #FUNCTION# ====================================================================================================================
; Name...........: _PDFX_Table
; Description ...: Dessine un tableau pagine, avec en-tete repete et grille.
; Syntax.........: _PDFX_Table(ByRef $oDocument, $fX, $fY, $fWidth, $aColumns, $aRows, $sOptions = "")
; Parameters ....: $oDocument - handle du document.
;                  $fX        - abscisse du coin superieur gauche.
;                  $fY        - ordonnee du coin superieur gauche.
;                  $fWidth    - largeur totale du tableau, en points.
;                  $aColumns  - tableau [n][2 ou 3] : 0 titre, 1 fraction de largeur, 2 alignement L/C/R.
;                  $aRows     - tableau [n][m] de cellules ; toute valeur est convertie en chaine.
;                  $sOptions  - options separees par des points-virgules, detaillees dans Remarques.
; Return values .: Success      - ordonnee du bas du tableau, prete pour la suite du contenu.
; Author ........: Numeric1
; Modified.......:
; Remarks .......: Options : padding=4, fontsize=0 (taille courante), border=0.5, bordercolor=0xBFC9D9,
;                  headfill=0xE8EEF7, headcolor=0x1F3864, zebra=0, zebracolor=0xF7F9FC,
;                  textcolor=0x000000, pagebreak=1. headfill=-1 supprime le fond de la ligne d'en-tete.
;                  Avec pagebreak=1, l'en-tete est reaffiche en haut de chaque nouvelle page.
; Related .......: _PDFX_TextWrap, _PDFX_Line, _PDFX_AddPage
; Link ..........: https://www.autoitscript.com/forum/
; Example .......: Yes
; ===============================================================================================================================
Func _PDFX_Table(ByRef $oDocument, $fX, $fY, $fWidth, $aColumns, $aRows, $sOptions = "")
	Local $iColumnCount = UBound($aColumns, 1)
	If $iColumnCount < 1 Then Return $fY

	Local $fPadding = Number(_PDFX_Opt($sOptions, "padding", 4))
	Local $fBorder = Number(_PDFX_Opt($sOptions, "border", 0.5))
	Local $fFontSize = Number(_PDFX_Opt($sOptions, "fontsize", 0))
	Local $bZebra = Number(_PDFX_Opt($sOptions, "zebra", 0))
	Local $bPageBreak = Number(_PDFX_Opt($sOptions, "pagebreak", 1)) <> 0
	Local $vHeadFill = _PDFX_Opt($sOptions, "headfill", 0xE8EEF7)
	Local $vHeadColor = _PDFX_Opt($sOptions, "headcolor", 0x1F3864)
	Local $vZebraColor = _PDFX_Opt($sOptions, "zebracolor", 0xF7F9FC)
	Local $vBorderColor = _PDFX_Opt($sOptions, "bordercolor", 0xBFC9D9)

	If $fFontSize <= 0 Then $fFontSize = $oDocument[$__PDFX_DOC_FONTSIZE]
	Local $fLineHeight = $fFontSize * 1.2

	; Largeurs et alignements de colonnes
	Local $aColumnWidths[$iColumnCount]
	Local $aAlignments[$iColumnCount]
	Local $fFractionTotal = 0
	For $iColumn = 0 To $iColumnCount - 1
		Local $fFraction = (UBound($aColumns, 2) >= 2) ? Number($aColumns[$iColumn][1]) : 1 / $iColumnCount
		If $fFraction <= 0 Then $fFraction = 1 / $iColumnCount
		$aColumnWidths[$iColumn] = $fFraction
		$fFractionTotal += $fFraction
		$aAlignments[$iColumn] = "L"
		If UBound($aColumns, 2) >= 3 Then
			Local $sAlign = StringUpper(StringStripWS($aColumns[$iColumn][2], 8))
			If $sAlign = "C" Or $sAlign = "R" Then $aAlignments[$iColumn] = $sAlign
		EndIf
	Next
	For $iColumn = 0 To $iColumnCount - 1
		$aColumnWidths[$iColumn] = $aColumnWidths[$iColumn] / $fFractionTotal * $fWidth
	Next

	; Ligne d'en-tete au meme format qu'une ligne de donnees
	Local $aHeaderRow[1][$iColumnCount]
	For $iColumn = 0 To $iColumnCount - 1
		$aHeaderRow[0][$iColumn] = String($aColumns[$iColumn][0])
	Next

	; Sauvegarde de l'etat typographique
	Local $iPreviousFont = $oDocument[$__PDFX_DOC_FONT]
	Local $fPreviousSize = $oDocument[$__PDFX_DOC_FONTSIZE]
	Local $sPreviousFill = $oDocument[$__PDFX_DOC_FILL]
	Local $sPreviousStroke = $oDocument[$__PDFX_DOC_STROKE]
	Local $fPreviousLineWidth = $oDocument[$__PDFX_DOC_LINEWIDTH]

	Local $iHeaderFont = _PDFX_EnsureFont($oDocument, _PDFX_Font($oDocument), "B")

	Local $iRowCount = UBound($aRows, 1)

	; En-tete
	Local $fHeaderHeight = _PDFX_TableRowHeight($oDocument, $aHeaderRow, $aColumnWidths, $fPadding, $fLineHeight, $fFontSize, $iHeaderFont)
	$fY = _PDFX_TableDrawRow($oDocument, $fX, $fY, $aColumnWidths, $aHeaderRow, $aAlignments, $fPadding, $fLineHeight, $fFontSize, $iHeaderFont, $vHeadFill, $vHeadColor)
	$fY = _PDFX_TableDrawLines($oDocument, $fX, $fY - $fHeaderHeight, $fWidth, $aColumnWidths, $fHeaderHeight, $fBorder, $vBorderColor)

	; Lignes
	For $iRow = 0 To $iRowCount - 1
		Local $aRow[1][$iColumnCount]
		For $iColumn = 0 To $iColumnCount - 1
			$aRow[0][$iColumn] = ($iColumn < UBound($aRows, 2)) ? String($aRows[$iRow][$iColumn]) : ""
		Next

		Local $fRowHeight = _PDFX_TableRowHeight($oDocument, $aRow, $aColumnWidths, $fPadding, $fLineHeight, $fFontSize, $iPreviousFont)

		If $bPageBreak And $fY + $fRowHeight > $oDocument[$__PDFX_DOC_HEIGHT] - $oDocument[$__PDFX_DOC_MARGIN] Then
			_PDFX_AddPage($oDocument)
			$fY = $oDocument[$__PDFX_DOC_MARGIN]
			Local $fRepeatedHeaderHeight = _PDFX_TableRowHeight($oDocument, $aHeaderRow, $aColumnWidths, $fPadding, $fLineHeight, $fFontSize, $iHeaderFont)
			$fY = _PDFX_TableDrawRow($oDocument, $fX, $fY, $aColumnWidths, $aHeaderRow, $aAlignments, $fPadding, $fLineHeight, $fFontSize, $iHeaderFont, $vHeadFill, $vHeadColor)
			$fY = _PDFX_TableDrawLines($oDocument, $fX, $fY - $fRepeatedHeaderHeight, $fWidth, $aColumnWidths, $fRepeatedHeaderHeight, $fBorder, $vBorderColor)
		EndIf

		Local $vFillColor = ($bZebra And Mod($iRow, 2) = 1) ? $vZebraColor : -1
		Local $vTextColor = _PDFX_Opt($sOptions, "textcolor", 0x000000)
		$fY = _PDFX_TableDrawRow($oDocument, $fX, $fY, $aColumnWidths, $aRow, $aAlignments, $fPadding, $fLineHeight, $fFontSize, $iPreviousFont, $vFillColor, $vTextColor)
		$fY = _PDFX_TableDrawLines($oDocument, $fX, $fY - $fRowHeight, $fWidth, $aColumnWidths, $fRowHeight, $fBorder, $vBorderColor)
	Next

	; Restauration
	$oDocument[$__PDFX_DOC_FONT] = $iPreviousFont
	$oDocument[$__PDFX_DOC_FONTSIZE] = $fPreviousSize
	$oDocument[$__PDFX_DOC_FILL] = $sPreviousFill
	$oDocument[$__PDFX_DOC_STROKE] = $sPreviousStroke
	$oDocument[$__PDFX_DOC_LINEWIDTH] = $fPreviousLineWidth

	Return $fY
EndFunc   ;==>_PDFX_Table

Func _PDFX_TableRowHeight($oDocument, $aRow, $aColumnWidths, $fPadding, $fLineHeight, $fFontSize, $iFont)
	Local $iMaxLines = 1
	Local $iColumnCount = UBound($aRow, 2)
	Local $iPreviousFont = $oDocument[$__PDFX_DOC_FONT]
	$oDocument[$__PDFX_DOC_FONT] = $iFont
	For $iColumn = 0 To $iColumnCount - 1
		Local $fAvailableWidth = $aColumnWidths[$iColumn] - 2 * $fPadding
		If $fAvailableWidth < 1 Then $fAvailableWidth = 1
		Local $aLines = _PDFX_Wrap($oDocument, String($aRow[0][$iColumn]), $fAvailableWidth, $fFontSize)
		If UBound($aLines) > $iMaxLines Then $iMaxLines = UBound($aLines)
	Next
	$oDocument[$__PDFX_DOC_FONT] = $iPreviousFont
	Return $iMaxLines * $fLineHeight + 2 * $fPadding
EndFunc   ;==>_PDFX_TableRowHeight

; Dessine une ligne (fond + textes) et renvoie le bas de la ligne.
Func _PDFX_TableDrawRow(ByRef $oDocument, $fX, $fY, $aColumnWidths, $aRow, $aAlignments, $fPadding, $fLineHeight, $fFontSize, $iFont, $vFillColor, $vTextColor)
	Local $iColumnCount = UBound($aRow, 2)
	Local $fRowHeight = _PDFX_TableRowHeight($oDocument, $aRow, $aColumnWidths, $fPadding, $fLineHeight, $fFontSize, $iFont)

	If Not IsString($vFillColor) Then
		If $vFillColor <> -1 Then
			_PDFX_SetFill($oDocument, $vFillColor)
			_PDFX_Rect($oDocument, $fX, $fY, _PDFX_Sum($aColumnWidths), $fRowHeight, $PDFX_FILL)
		EndIf
	ElseIf $vFillColor <> "" And $vFillColor <> "-1" Then
		_PDFX_SetFill($oDocument, $vFillColor)
		_PDFX_Rect($oDocument, $fX, $fY, _PDFX_Sum($aColumnWidths), $fRowHeight, $PDFX_FILL)
	EndIf

	Local $iPreviousFont = $oDocument[$__PDFX_DOC_FONT]
	Local $fPreviousSize = $oDocument[$__PDFX_DOC_FONTSIZE]
	Local $sPreviousFill = $oDocument[$__PDFX_DOC_FILL]

	$oDocument[$__PDFX_DOC_FONT] = $iFont
	$oDocument[$__PDFX_DOC_FONTSIZE] = $fFontSize
	_PDFX_SetFill($oDocument, $vTextColor)

	Local $fColumnX = $fX
	For $iColumn = 0 To $iColumnCount - 1
		Local $fAvailableWidth = $aColumnWidths[$iColumn] - 2 * $fPadding
		Local $aLines = _PDFX_Wrap($oDocument, String($aRow[0][$iColumn]), $fAvailableWidth, $fFontSize)
		Local $fTextY = $fY + $fPadding
		For $iLine = 0 To UBound($aLines) - 1
			_PDFX_EmitText($oDocument, $fColumnX + $fPadding, $fTextY, $aLines[$iLine], $fFontSize, $aAlignments[$iColumn], $fAvailableWidth)
			$fTextY += $fLineHeight
		Next
		$fColumnX += $aColumnWidths[$iColumn]
	Next

	$oDocument[$__PDFX_DOC_FONT] = $iPreviousFont
	$oDocument[$__PDFX_DOC_FONTSIZE] = $fPreviousSize
	$oDocument[$__PDFX_DOC_FILL] = $sPreviousFill
	Return $fY + $fRowHeight
EndFunc   ;==>_PDFX_TableDrawRow

Func _PDFX_TableDrawLines(ByRef $oDocument, $fX, $fTop, $fWidth, $aColumnWidths, $fRowHeight, $fBorderWidth, $vBorderColor)
	_PDFX_SetStroke($oDocument, $vBorderColor)
	_PDFX_SetLineWidth($oDocument, $fBorderWidth)
	Local $fBottom = $fTop + $fRowHeight
	_PDFX_Line($oDocument, $fX, $fTop, $fX + $fWidth, $fTop)
	_PDFX_Line($oDocument, $fX, $fBottom, $fX + $fWidth, $fBottom)
	_PDFX_Line($oDocument, $fX, $fTop, $fX, $fBottom)
	Local $fColumnX = $fX
	For $iColumn = 0 To UBound($aColumnWidths) - 1
		$fColumnX += $aColumnWidths[$iColumn]
		_PDFX_Line($oDocument, $fColumnX, $fTop, $fColumnX, $fBottom)
	Next
	Return $fBottom
EndFunc   ;==>_PDFX_TableDrawLines

#EndRegion

#Region - Liens, metadonnees, en-tete et pied -----------------------------------------------------------------------------------
; Annotations de lien, dictionnaire /Info et habillage des pages.

; #FUNCTION# ====================================================================================================================
; Name...........: _PDFX_Link
; Description ...: Ajoute un lien hypertexte cliquable.
; Syntax.........: _PDFX_Link(ByRef $oDocument, $fX, $fY, $fWidth, $fHeight, $sUrl)
; Parameters ....: $oDocument - handle du document.
;                  $fX        - abscisse du coin superieur gauche de la zone.
;                  $fY        - ordonnee du coin superieur gauche de la zone.
;                  $fWidth    - largeur de la zone cliquable, en points.
;                  $fHeight   - hauteur de la zone cliquable, en points.
;                  $sUrl      - adresse complete, par exemple https://www.autoitscript.com/forum/.
; Return values .: Success      - True.
;                  Failure      - False si aucune page n'est ouverte.
; Author ........: Numeric1
; Modified.......:
; Remarks .......: Le lien est une annotation /Link invisible (/Border [0 0 0]) : il ne modifie pas le rendu.
; Related .......: _PDFX_Text, _PDFX_Save
; Link ..........: https://www.autoitscript.com/forum/
; Example .......: Yes
; ===============================================================================================================================
Func _PDFX_Link(ByRef $oDocument, $fX, $fY, $fW, $fH, $sUrl)
	Local $iCurrentPage = $oDocument[$__PDFX_DOC_CURRENTPAGE]
	If $iCurrentPage < 0 Then Return False
	Local $fTop = _PDFX_Y($oDocument, $fY + $fH)
	Local $fBottom = _PDFX_Y($oDocument, $fY)
	Local $sAnnotation = "<< /Type /Annot /Subtype /Link /Rect [" & _PDFX_F($fX) & " " & _PDFX_F($fTop) & " " & _
			_PDFX_F($fX + $fW) & " " & _PDFX_F($fBottom) & "] /Border [0 0 0] " & _
			"/A << /S /URI /URI (" & _PDFX_Escape($sUrl) & ") >> >>"
	Local $iObject = _PDFX_AddObject($oDocument, $sAnnotation)
	$oDocument[$__PDFX_DOC_ANNOTS] &= $iObject & " 0 R "
	Return True
EndFunc   ;==>_PDFX_Link

; #FUNCTION# ====================================================================================================================
; Name...........: _PDFX_LinkPage
; Description ...: Ajoute un lien interne vers une autre page du document.
; Syntax.........: _PDFX_LinkPage(ByRef $oDocument, $fX, $fY, $fWidth, $fHeight, $iPage, $fYTarget = -1)
; Parameters ....: $oDocument - handle du document.
;                  $fX        - abscisse du coin superieur gauche de la zone cliquable.
;                  $fY        - ordonnee du coin superieur gauche de la zone.
;                  $fWidth    - largeur de la zone, en points.
;                  $fHeight   - hauteur de la zone, en points.
;                  $iPage     - page cible, numerotee a partir de 1. Elle peut ne pas encore
;                               exister : le lien est resolu a l'enregistrement et ignore si la
;                               page n'a jamais ete creee.
;                  $fYTarget  - ordonnee d'arrivee, en points depuis le haut de la page cible ;
;                               -1 (defaut) cadre la page entiere (/Fit).
; Return values .: Success      - True.
;                  Failure      - False et @error = 1 si aucune page n'est ouverte ou si $iPage
;                                 vaut moins de 1, 2 si le document a deja ete enregistre.
; Author ........: Numeric1
; Modified.......:
; Remarks .......: L'annotation /Link est invisible (/Border [0 0 0]). La destination est ecrite en
;                  /Dest et non en action /URI : le lien reste valable hors ligne et apres
;                  reorganisation du document par un lecteur. L'annotation n'est creee qu'a
;                  l'enregistrement, ce qui permet de relier un sommaire a des chapitres ecrits
;                  plus tard.
; Related .......: _PDFX_Link, _PDFX_AddBookmark, _PDFX_Save
; Link ..........: https://www.autoitscript.com/forum/
; Example .......: Yes
; ===============================================================================================================================
Func _PDFX_LinkPage(ByRef $oDocument, $fX, $fY, $fW, $fH, $iPage, $fYTarget = -1)
	If $oDocument[$__PDFX_DOC_SAVED] Then Return SetError(2, 0, False)
	Local $iCurrentPage = $oDocument[$__PDFX_DOC_CURRENTPAGE]
	If $iCurrentPage < 0 Then Return SetError(1, 0, False)
	Local $iTarget = Int(Number($iPage)) - 1
	If $iTarget < 0 Then Return SetError(1, 1, False)

	Local $aLinks = $oDocument[$__PDFX_DOC_PAGELINKS]
	Local $iCount = UBound($aLinks)
	ReDim $aLinks[$iCount + 1][7]
	$aLinks[$iCount][0] = $iCurrentPage
	$aLinks[$iCount][1] = $iTarget
	$aLinks[$iCount][2] = Number($fYTarget)
	$aLinks[$iCount][3] = $fX
	$aLinks[$iCount][4] = _PDFX_Y($oDocument, $fY + $fH)
	$aLinks[$iCount][5] = $fX + $fW
	$aLinks[$iCount][6] = _PDFX_Y($oDocument, $fY)
	$oDocument[$__PDFX_DOC_PAGELINKS] = $aLinks
	Return True
EndFunc   ;==>_PDFX_LinkPage

; #FUNCTION# ====================================================================================================================
; Name...........: _PDFX_AddBookmark
; Description ...: Ajoute une entree au sommaire du document (arbre /Outlines).
; Syntax.........: _PDFX_AddBookmark(ByRef $oDocument, $sTitle, $iLevel = 0, $iPage = -1, $fY = -1)
; Parameters ....: $oDocument - handle du document.
;                  $sTitle    - libelle affiche dans le volet de navigation.
;                  $iLevel    - profondeur, 0 pour une entree racine. Un niveau ne peut descendre que
;                               d'un cran a la fois : toute valeur plus profonde est ramenee a
;                               niveau precedent + 1, une valeur negative a 0.
;                  $iPage     - page cible, numerotee a partir de 1 ; -1 (defaut) = page courante.
;                  $fY        - ordonnee d'arrivee, en points depuis le haut de la page cible ;
;                               -1 (defaut) cadre la page entiere (/Fit).
; Return values .: Success      - numero du signet (a partir de 1).
;                  Failure      - -1 et @error = 1 si le titre est vide ou la page inexistante,
;                                 2 si le document a deja ete enregistre.
; Author ........: Numeric1
; Modified.......:
; Remarks .......: Les signets sont assembles a l'enregistrement : l'ordre d'ajout devient l'ordre
;                  de lecture, chaque entree recoit /Parent, /Prev, /Next, /First, /Last et un
;                  /Count (nombre de descendants). Le volet s'ouvre par defaut des qu'un signet
;                  existe, sauf si _PDFX_SetPageMode() impose un autre mode. Les titres non ASCII
;                  sont ecrits en UTF-16BE, comme les metadonnees.
; Related .......: _PDFX_SetPageMode, _PDFX_LinkPage, _PDFX_Save
; Link ..........: https://www.autoitscript.com/forum/
; Example .......: Yes
; ===============================================================================================================================
Func _PDFX_AddBookmark(ByRef $oDocument, $sTitle, $iLevel = 0, $iPage = -1, $fY = -1)
	If $oDocument[$__PDFX_DOC_SAVED] Then Return SetError(2, 0, -1)
	$sTitle = StringStripWS($sTitle, 3)
	If $sTitle = "" Then Return SetError(1, 0, -1)

	Local $iPageCount = UBound($oDocument[$__PDFX_DOC_PAGES])
	If $iPageCount = 0 Then Return SetError(1, 1, -1)
	Local $iPageIndex = $iPage = -1 ? $oDocument[$__PDFX_DOC_CURRENTPAGE] : Int(Number($iPage)) - 1
	If $iPageIndex < 0 Or $iPageIndex >= $iPageCount Then Return SetError(1, 1, -1)

	Local $aBookmarks = $oDocument[$__PDFX_DOC_BOOKMARKS]
	Local $iCount = UBound($aBookmarks)
	Local $iPreviousLevel = $iCount > 0 ? $aBookmarks[$iCount - 1][1] : -1
	$iLevel = Int(Number($iLevel))
	If $iLevel < 0 Then $iLevel = 0
	If $iLevel > $iPreviousLevel + 1 Then $iLevel = $iPreviousLevel + 1

	ReDim $aBookmarks[$iCount + 1][4]
	$aBookmarks[$iCount][0] = $sTitle
	$aBookmarks[$iCount][1] = $iLevel
	$aBookmarks[$iCount][2] = $iPageIndex
	$aBookmarks[$iCount][3] = Number($fY)
	$oDocument[$__PDFX_DOC_BOOKMARKS] = $aBookmarks
	Return $iCount + 1
EndFunc   ;==>_PDFX_AddBookmark

; #FUNCTION# ====================================================================================================================
; Name...........: _PDFX_SetPageMode
; Description ...: Choisit le panneau affiche a l'ouverture du document.
; Syntax.........: _PDFX_SetPageMode(ByRef $oDocument, $sMode = "UseOutlines")
; Parameters ....: $oDocument - handle du document.
;                  $sMode     - UseNone, UseOutlines (signets), UseThumbs (vignettes), FullScreen, ou
;                               une chaine vide pour revenir au comportement automatique (signets
;                               ouverts si le document en contient). La casse est ignoree.
; Return values .: Success      - True.
;                  Failure      - False et @error = 1 si le mode est inconnu, 2 si le document a
;                                 deja ete enregistre.
; Author ........: Numeric1
; Modified.......:
; Remarks .......: Le choix est ecrit dans la cle /PageMode du catalogue. Les lecteurs restent
;                  libres de l'ignorer (par exemple en mode plein ecran).
; Related .......: _PDFX_AddBookmark, _PDFX_SetPageLayout
; Link ..........: https://www.autoitscript.com/forum/
; Example .......: Yes
; ===============================================================================================================================
Func _PDFX_SetPageMode(ByRef $oDocument, $sMode = "UseOutlines")
	If $oDocument[$__PDFX_DOC_SAVED] Then Return SetError(2, 0, False)
	Local $sCanonical
	Switch StringUpper(StringStripWS($sMode, 8))
		Case ""
			$sCanonical = ""
		Case "USENONE"
			$sCanonical = "UseNone"
		Case "USEOUTLINES"
			$sCanonical = "UseOutlines"
		Case "USETHUMBS"
			$sCanonical = "UseThumbs"
		Case "FULLSCREEN"
			$sCanonical = "FullScreen"
		Case Else
			Return SetError(1, 0, False)
	EndSwitch
	$oDocument[$__PDFX_DOC_PAGEMODE] = $sCanonical
	Return True
EndFunc   ;==>_PDFX_SetPageMode

; #FUNCTION# ====================================================================================================================
; Name...........: _PDFX_SetPageLayout
; Description ...: Choisit la disposition des pages a l'ouverture du document.
; Syntax.........: _PDFX_SetPageLayout(ByRef $oDocument, $sLayout)
; Parameters ....: $oDocument - handle du document.
;                  $sLayout   - SinglePage, OneColumn, TwoColumnLeft, TwoColumnRight, TwoPageLeft,
;                               TwoPageRight, ou une chaine vide pour ne rien imposer. La casse est
;                               ignoree.
; Return values .: Success      - True.
;                  Failure      - False et @error = 1 si la disposition est inconnue, 2 si le
;                                 document a deja ete enregistre.
; Author ........: Numeric1
; Modified.......:
; Remarks .......: Le choix est ecrit dans la cle /PageLayout du catalogue. Il reste indicatif :
;                  le lecteur peut appliquer sa propre preference.
; Related .......: _PDFX_SetPageMode
; Link ..........: https://www.autoitscript.com/forum/
; Example .......: Yes
; ===============================================================================================================================
Func _PDFX_SetPageLayout(ByRef $oDocument, $sLayout)
	If $oDocument[$__PDFX_DOC_SAVED] Then Return SetError(2, 0, False)
	Local $sCanonical
	Switch StringUpper(StringStripWS($sLayout, 8))
		Case ""
			$sCanonical = ""
		Case "SINGLEPAGE"
			$sCanonical = "SinglePage"
		Case "ONECOLUMN"
			$sCanonical = "OneColumn"
		Case "TWOCOLUMNLEFT"
			$sCanonical = "TwoColumnLeft"
		Case "TWOCOLUMNRIGHT"
			$sCanonical = "TwoColumnRight"
		Case "TWOPAGELEFT"
			$sCanonical = "TwoPageLeft"
		Case "TWOPAGERIGHT"
			$sCanonical = "TwoPageRight"
		Case Else
			Return SetError(1, 0, False)
	EndSwitch
	$oDocument[$__PDFX_DOC_PAGELAYOUT] = $sCanonical
	Return True
EndFunc   ;==>_PDFX_SetPageLayout

; #FUNCTION# ====================================================================================================================
; Name...........: _PDFX_SetMeta
; Description ...: Renseigne les metadonnees du document.
; Syntax.........: _PDFX_SetMeta(ByRef $oDocument, $sTitle = "", $sAuthor = "", $sSubject = "", $sKeywords = "")
; Parameters ....: $oDocument - handle du document.
;                  $sTitle    - titre du document.
;                  $sAuthor   - auteur.
;                  $sSubject  - sujet.
;                  $sKeywords - mots-cles, separes par des virgules.
; Return values .: Success      - True.
; Author ........: Numeric1
; Modified.......:
; Remarks .......: Les valeurs sont ecrites dans le dictionnaire /Info lors de _PDFX_Save(). Une chaine vide conserve
;                  la valeur precedente ; le producteur et la date de creation sont ajoutes automatiquement.
; Related .......: _PDFX_Save
; Link ..........: https://www.autoitscript.com/forum/
; Example .......: Yes
; ===============================================================================================================================
Func _PDFX_SetMeta(ByRef $oDocument, $sTitle = "", $sAuthor = "", $sSubject = "", $sKeywords = "")
	Local $aMetadata = $oDocument[$__PDFX_DOC_METADATA]
	If $sTitle <> "" Then $aMetadata[0] = $sTitle
	If $sAuthor <> "" Then $aMetadata[1] = $sAuthor
	If $sSubject <> "" Then $aMetadata[2] = $sSubject
	If $sKeywords <> "" Then $aMetadata[3] = $sKeywords
	$oDocument[$__PDFX_DOC_METADATA] = $aMetadata
	Return True
EndFunc   ;==>_PDFX_SetMeta

; #FUNCTION# ====================================================================================================================
; Name...........: _PDFX_SetHeader
; Description ...: Definit l'en-tete applique a toutes les pages.
; Syntax.........: _PDFX_SetHeader(ByRef $oDocument, $sLeft = "", $sCenter = "", $sRight = "", $iSize = 8, _
;                  $sFont = "", $sStyle = "", $vColor = -1)
; Parameters ....: $oDocument - handle du document.
;                  $sLeft     - texte de la zone gauche ; jetons {page}, {pages} et {date} acceptes.
;                  $sCenter   - texte de la zone centrale.
;                  $sRight    - texte de la zone droite.
;                  $iSize     - taille de police ; une valeur inferieure ou egale a 0 conserve la valeur courante.
;                               La taille est commune a l'en-tete et au pied.
;                  $sFont     - famille de police ; une chaine vide conserve la valeur courante (Helvetica).
;                  $sStyle    - style : combinaison de B (gras) et I (italique) ; une chaine vide revient au style normal.
;                  $vColor    - couleur du texte et du filet : 0xRRGGBB, "nom" ou tableau [R, G, B] ; -1 conserve la
;                               couleur courante.
; Return values .: Success      - True.
;                  Failure      - True et @error = 1 si une composante de couleur a ete ramenee dans [0, 255].
; Author ........: Numeric1
; Modified.......:
; Remarks .......: L'en-tete est insere au moment de _PDFX_Save(), sur chaque page, suivi d'un filet de separation.
;                  Une zone vide est ignoree ; trois zones vides suppriment l'en-tete.
; Related .......: _PDFX_SetFooter, _PDFX_Save
; Link ..........: https://www.autoitscript.com/forum/
; Example .......: Yes
; ===============================================================================================================================
Func _PDFX_SetHeader(ByRef $oDocument, $sLeft = "", $sCenter = "", $sRight = "", $iSize = 8, $sFont = "", $sStyle = "", $vColor = -1)
	Local $aHeaderFooter = $oDocument[$__PDFX_DOC_HEADERFOOTER]
	$aHeaderFooter[0] = $sLeft
	$aHeaderFooter[1] = $sCenter
	$aHeaderFooter[2] = $sRight
	If $iSize > 0 Then $aHeaderFooter[6] = $iSize
	If $sFont <> "" Then $aHeaderFooter[8] = $sFont
	$aHeaderFooter[9] = $sStyle
	Local $iError = 0
	If $vColor <> -1 Then
		$aHeaderFooter[7] = _PDFX_Color($vColor)
		$iError = @error
	EndIf
	$oDocument[$__PDFX_DOC_HEADERFOOTER] = $aHeaderFooter
	Return SetError($iError, 0, True)
EndFunc   ;==>_PDFX_SetHeader

; #FUNCTION# ====================================================================================================================
; Name...........: _PDFX_SetFooter
; Description ...: Definit le pied de page applique a toutes les pages.
; Syntax.........: _PDFX_SetFooter(ByRef $oDocument, $sLeft = "", $sCenter = "", $sRight = "", $iSize = 8, _
;                  $sFont = "", $sStyle = "", $vColor = -1)
; Parameters ....: $oDocument - handle du document.
;                  $sLeft     - texte de la zone gauche ; jetons {page}, {pages} et {date} acceptes.
;                  $sCenter   - texte de la zone centrale.
;                  $sRight    - texte de la zone droite.
;                  $iSize     - taille de police ; une valeur inferieure ou egale a 0 conserve la valeur courante.
;                               La taille est commune a l'en-tete et au pied.
;                  $sFont     - famille de police ; une chaine vide conserve la valeur courante (Helvetica).
;                  $sStyle    - style : combinaison de B (gras) et I (italique) ; une chaine vide revient au style normal.
;                  $vColor    - couleur du texte : 0xRRGGBB, "nom" ou tableau [R, G, B] ; -1 conserve la couleur courante.
; Return values .: Success      - True.
;                  Failure      - True et @error = 1 si une composante de couleur a ete ramenee dans [0, 255].
; Author ........: Numeric1
; Modified.......:
; Remarks .......: Le pied est cale sur la marge basse du document. Exemple de pagination :
;                  _PDFX_SetFooter($oDocument, '', 'Page {page} / {pages}', '{date}').
; Related .......: _PDFX_SetHeader, _PDFX_Save
; Link ..........: https://www.autoitscript.com/forum/
; Example .......: Yes
; ===============================================================================================================================
Func _PDFX_SetFooter(ByRef $oDocument, $sLeft = "", $sCenter = "", $sRight = "", $iSize = 8, $sFont = "", $sStyle = "", $vColor = -1)
	Local $aHeaderFooter = $oDocument[$__PDFX_DOC_HEADERFOOTER]
	$aHeaderFooter[3] = $sLeft
	$aHeaderFooter[4] = $sCenter
	$aHeaderFooter[5] = $sRight
	If $iSize > 0 Then $aHeaderFooter[6] = $iSize
	If $sFont <> "" Then $aHeaderFooter[11] = $sFont
	$aHeaderFooter[12] = $sStyle
	Local $iError = 0
	If $vColor <> -1 Then
		$aHeaderFooter[10] = _PDFX_Color($vColor)
		$iError = @error
	EndIf
	$oDocument[$__PDFX_DOC_HEADERFOOTER] = $aHeaderFooter
	Return SetError($iError, 0, True)
EndFunc   ;==>_PDFX_SetFooter

Func _PDFX_ApplyHeaderFooter(ByRef $oDocument)
	If $oDocument[$__PDFX_DOC_HFAPPLIED] Then Return
	Local $aHeaderFooter = $oDocument[$__PDFX_DOC_HEADERFOOTER]
	Local $bHasText = ($aHeaderFooter[0] <> "" Or $aHeaderFooter[1] <> "" Or $aHeaderFooter[2] <> "" Or $aHeaderFooter[3] <> "" Or $aHeaderFooter[4] <> "" Or $aHeaderFooter[5] <> "")
	If Not $bHasText Then Return
	$oDocument[$__PDFX_DOC_HFAPPLIED] = True

	Local $aPages = $oDocument[$__PDFX_DOC_PAGES]
	Local $iPageCount = UBound($aPages)
	Local $fFontSize = $aHeaderFooter[6]
	Local $fLineHeight = $fFontSize * 1.2
	Local $sHeaderFont = $aHeaderFooter[8]
	If $sHeaderFont = "" Then $sHeaderFont = "Helvetica"
	Local $sFooterFont = $aHeaderFooter[11]
	If $sFooterFont = "" Then $sFooterFont = "Helvetica"
	Local $iHeaderFont = _PDFX_EnsureFont($oDocument, $sHeaderFont, $aHeaderFooter[9])
	Local $iFooterFont = _PDFX_EnsureFont($oDocument, $sFooterFont, $aHeaderFooter[12])
	Local $iPreviousFont = $oDocument[$__PDFX_DOC_FONT]
	Local $fPreviousSize = $oDocument[$__PDFX_DOC_FONTSIZE]
	Local $sPreviousFill = $oDocument[$__PDFX_DOC_FILL]
	Local $sPreviousStroke = $oDocument[$__PDFX_DOC_STROKE]
	Local $fPreviousLineWidth = $oDocument[$__PDFX_DOC_LINEWIDTH]
	Local $fDocumentMargin = $oDocument[$__PDFX_DOC_MARGIN]

	For $iPage = 0 To $iPageCount - 1
		Local $fPageWidth = $aPages[$iPage][0]
		Local $fPageHeight = $aPages[$iPage][1]
		Local $sAddition = ""

		; En-tete
		If $aHeaderFooter[0] <> "" Or $aHeaderFooter[1] <> "" Or $aHeaderFooter[2] <> "" Then
			$sAddition &= _PDFX_HfLine($oDocument, $aHeaderFooter, 0, $fDocumentMargin, $fPageWidth, $fPageHeight, $fFontSize, $iHeaderFont, $aHeaderFooter[7], $iPage + 1, $iPageCount)
			$sAddition &= _PDFX_StrokeOp($aHeaderFooter[7], 0.5, $fDocumentMargin, $fPageHeight - $fDocumentMargin - $fLineHeight - 3, $fPageWidth - $fDocumentMargin, $fPageHeight - $fDocumentMargin - $fLineHeight - 3, $fPageHeight)
		EndIf

		; Pied (le texte est cale a $fDocumentMargin du bas)
		If $aHeaderFooter[3] <> "" Or $aHeaderFooter[4] <> "" Or $aHeaderFooter[5] <> "" Then
			Local $fFooterTopY = $fPageHeight - $fDocumentMargin + 4
			$sAddition &= _PDFX_HfLine($oDocument, $aHeaderFooter, 3, $fFooterTopY, $fPageWidth, $fPageHeight, $fFontSize, $iFooterFont, $aHeaderFooter[10], $iPage + 1, $iPageCount)
		EndIf

		$aPages[$iPage][2] = $aPages[$iPage][2] & $sAddition
	Next

	$oDocument[$__PDFX_DOC_PAGES] = $aPages
	$oDocument[$__PDFX_DOC_FONT] = $iPreviousFont
	$oDocument[$__PDFX_DOC_FONTSIZE] = $fPreviousSize
	$oDocument[$__PDFX_DOC_FILL] = $sPreviousFill
	$oDocument[$__PDFX_DOC_STROKE] = $sPreviousStroke
	$oDocument[$__PDFX_DOC_LINEWIDTH] = $fPreviousLineWidth
EndFunc   ;==>_PDFX_ApplyHeaderFooter

Func _PDFX_StrokeOp($sColor, $fLineWidth, $fX1, $fY1, $fX2, $fY2, $fPageHeight)
	Return $sColor & " RG" & @LF & _PDFX_F($fLineWidth) & " w" & @LF & "q" & @LF & _
			_PDFX_F($fX1) & " " & _PDFX_F($fPageHeight - $fY1) & " m " & _PDFX_F($fX2) & " " & _PDFX_F($fPageHeight - $fY2) & " l S" & @LF & "Q" & @LF
EndFunc   ;==>_PDFX_StrokeOp

; $iSlotBase : 0 = en-tete, 3 = pied
Func _PDFX_HfLine($oDocument, $aHeaderFooter, $iSlotBase, $fTopY, $fPageWidth, $fPageHeight, $fFontSize, $iFont, $sColor, $iPageNumber, $iPageCount)
	Local $aFonts = $oDocument[$__PDFX_DOC_FONTS]
	Local $sResourceName = $aFonts[$iFont][2]
	Local $fMargin = $oDocument[$__PDFX_DOC_MARGIN]
	Local $sStream = ""

	Local $aText[3] = [$aHeaderFooter[$iSlotBase], $aHeaderFooter[$iSlotBase + 1], $aHeaderFooter[$iSlotBase + 2]]
	Local $aPositions[3] = [$fMargin, $fMargin, $fMargin]
	Local $aFullWidths[3] = [$fPageWidth - 2 * $fMargin, $fPageWidth - 2 * $fMargin, $fPageWidth - 2 * $fMargin]
	Local $fBaseline = $fPageHeight - $fTopY - $fFontSize * 0.8
	Local $iPreviousFont = $oDocument[$__PDFX_DOC_FONT]
	Local $fPreviousSize = $oDocument[$__PDFX_DOC_FONTSIZE]
	Local $sPreviousFill = $oDocument[$__PDFX_DOC_FILL]
	$oDocument[$__PDFX_DOC_FONT] = $iFont
	$oDocument[$__PDFX_DOC_FONTSIZE] = $fFontSize

	For $iSlot = 0 To 2
		If $aText[$iSlot] = "" Then ContinueLoop
		Local $sText = $aText[$iSlot]
		$sText = StringReplace($sText, "{page}", String($iPageNumber))
		$sText = StringReplace($sText, "{pages}", String($iPageCount))
		$sText = StringReplace($sText, "{date}", _PDFX_Today())

		Local $sEscaped = _PDFX_Escape($sText)
		Local $fTextWidth = _PDFX_Measure($oDocument, $sText, $fFontSize, $iFont)
		Local $fX = $aPositions[$iSlot]
		If $iSlot = 1 Then
			$fX = $fMargin + ($aFullWidths[$iSlot] - $fTextWidth) / 2
		ElseIf $iSlot = 2 Then
			$fX = $fMargin + $aFullWidths[$iSlot] - $fTextWidth
		EndIf

		$sStream &= "BT" & @LF & "/" & $sResourceName & " " & _PDFX_F($fFontSize) & " Tf" & @LF & _
			  $sColor & " rg" & @LF & "1 0 0 1 " & _PDFX_F($fX) & " " & _PDFX_F($fBaseline) & " Tm" & @LF & _
			  "(" & $sEscaped & ") Tj" & @LF & "ET" & @LF
	Next

	$oDocument[$__PDFX_DOC_FONT] = $iPreviousFont
	$oDocument[$__PDFX_DOC_FONTSIZE] = $fPreviousSize
	$oDocument[$__PDFX_DOC_FILL] = $sPreviousFill
	Return $sStream
EndFunc   ;==>_PDFX_HfLine

Func _PDFX_Today()
	Return @YEAR & "-" & @MON & "-" & @MDAY
EndFunc   ;==>_PDFX_Today

#EndRegion

#Region - Ecriture du fichier PDF -----------------------------------------------------------------------------------------------
; Serialisation des objets, table xref, trailer et startxref.

; #FUNCTION# ====================================================================================================================
; Name...........: _PDFX_SetCompression
; Description ...: Active la compression FlateDecode des flux de contenu.
; Syntax.........: _PDFX_SetCompression(ByRef $oDocument, $iLevel = 6)
; Parameters ....: $oDocument - handle du document.
;                  $iLevel    - niveau de 0 a 9 : 0 laisse les flux en clair (defaut), 1 compresse le plus vite,
;                               9 cherche les repetitions les plus lointaines. 6 est un bon compromis.
; Return values .: Success      - True.
;                  Failure      - True et @error = 1 si le niveau a ete ramene dans l'intervalle [0, 9] ;
;                                 False et @error = 2 si le document a deja ete enregistre.
; Author ........: Numeric1
; Modified.......:
; Remarks .......: La compression est appliquee a l'enregistrement, page par page : chaque flux de contenu est
;                  compresse en zlib (RFC 1950) sur DEFLATE (RFC 1951) et precede de /Filter /FlateDecode. Un flux
;                  qui ne gagne rien (tres court, ou deja dense) est ecrit en clair : le choix est automatique.
;                  Le code est autonome, sans DLL ni COM ; comptez de l'ordre de 30 Ko/s, contre plusieurs Mo/s pour
;                  zlib en C. Le rendu des pages est identique, seul le poids du fichier change.
; Related .......: _PDFX_Save
; Link ..........: https://www.autoitscript.com/forum/
; Example .......: Yes
; ===============================================================================================================================
Func _PDFX_SetCompression(ByRef $oDocument, $iLevel = 6)
	If $oDocument[$__PDFX_DOC_SAVED] Then Return SetError(2, 0, False)
	$iLevel = Int(Number($iLevel))
	Local $iError = 0
	If $iLevel < 0 Then
		$iLevel = 0
		$iError = 1
	ElseIf $iLevel > 9 Then
		$iLevel = 9
		$iError = 1
	EndIf
	$oDocument[$__PDFX_DOC_COMPRESSION] = $iLevel
	Return SetError($iError, 0, True)
EndFunc   ;==>_PDFX_SetCompression

; #FUNCTION# ====================================================================================================================
; Name...........: _PDFX_Save
; Description ...: Ecrit le document au format PDF 1.7.
; Syntax.........: _PDFX_Save(ByRef $oDocument, $sFile)
; Parameters ....: $oDocument - handle du document.
;                  $sFile     - chemin du fichier de destination.
; Return values .: Success      - True.
;                  Failure      - False et @error = 1 si le fichier ne peut pas etre cree ;
;                                 False et @error = 2 si le document a deja ete enregistre.
; Author ........: Numeric1
; Modified.......:
; Remarks .......: Fige la page courante, applique l'en-tete et le pied, puis serialise les objets, la table xref, le
;                  trailer et startxref. Le fichier produit est autonome et conforme a ISO 32000-1.
;                  Un document ne s'ecrit qu'une fois : apres un enregistrement reussi, _PDFX_AddPage() et un second
;                  _PDFX_Save() renvoient @error = 2. Les dates sont en temps universel (suffixe Z), les chaines non
;                  ASCII de /Info sont ecrites en UTF-16BE, et /ID est une empreinte MD5 deterministe du contenu.
; Related .......: _PDFX_New, _PDFX_SetMeta, _PDFX_Close
; Link ..........: https://www.autoitscript.com/forum/
; Example .......: Yes
; ===============================================================================================================================
Func _PDFX_Save(ByRef $oDocument, $sFile)
	If $oDocument[$__PDFX_DOC_SAVED] Then Return SetError(2, 0, False)
	If UBound($oDocument[$__PDFX_DOC_PAGES]) = 0 Then _PDFX_AddPage($oDocument)
	_PDFX_FlushPage($oDocument)
	_PDFX_ApplyHeaderFooter($oDocument)

	Local $aPages = $oDocument[$__PDFX_DOC_PAGES]
	Local $iPageCount = UBound($aPages)
	_PDFX_PreparePageLinks($oDocument, $aPages, $iPageCount)
	Local $sResources = _PDFX_ResourceDict($oDocument)
	Local $sPageReferences = ""
	Local $aPageObjects[$iPageCount]

	For $iIndex = 0 To $iPageCount - 1
		Local $sContent = $aPages[$iIndex][2]
		If $sContent = "" Then $sContent = " "

		Local $iContentObject
		Local $vPacked = _PDFX_PackContent($oDocument, $sContent)
		If IsBinary($vPacked) Then
			Local $aStream[3] = ["<< /Length " & BinaryLen($vPacked) & " /Filter /FlateDecode >>" & @LF & "stream" & @LF, _
					$vPacked, @LF & "endstream"]
			$iContentObject = _PDFX_AddObject($oDocument, $aStream)
		Else
			$iContentObject = _PDFX_AddObject($oDocument, "<< /Length " & StringLen($sContent) & " >>" & @LF & _
					"stream" & @LF & $sContent & @LF & "endstream")
		EndIf

		Local $sPage = "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 " & _PDFX_F($aPages[$iIndex][0]) & " " & _PDFX_F($aPages[$iIndex][1]) & "]"
		If $sResources <> "" Then $sPage &= " /Resources << " & $sResources & " >>"
		$sPage &= " /Contents " & $iContentObject & " 0 R"
		If StringStripWS($aPages[$iIndex][3], 8) <> "" Then $sPage &= " /Annots [" & StringStripWS($aPages[$iIndex][3], 7) & "]"
		$sPage &= " >>"

		Local $iPageObject = _PDFX_AddObject($oDocument, $sPage)
		$aPageObjects[$iIndex] = $iPageObject
		$sPageReferences &= $iPageObject & " 0 R "
	Next

	; Arbre de pages (objet 2)
	Local $aPageTreeObjects = $oDocument[$__PDFX_DOC_OBJECTS]
	$aPageTreeObjects[2] = "<< /Type /Pages /Count " & $iPageCount & " /Kids [" & StringStripWS($sPageReferences, 2) & "] >>"
	$oDocument[$__PDFX_DOC_OBJECTS] = $aPageTreeObjects

	; Navigation : destinations des liens internes, sommaire, mode d'ouverture.
	_PDFX_PatchPageLinks($oDocument, $aPages, $aPageObjects)
	Local $iOutlineObject = _PDFX_BuildOutline($oDocument, $aPages, $aPageObjects)
	Local $sPageMode = $oDocument[$__PDFX_DOC_PAGEMODE]
	If $sPageMode = "" And $iOutlineObject > 0 Then $sPageMode = "UseOutlines"
	Local $sPageLayout = $oDocument[$__PDFX_DOC_PAGELAYOUT]

	Local $aCatalogObjects = $oDocument[$__PDFX_DOC_OBJECTS]
	Local $sCatalog = "<< /Type /Catalog /Pages 2 0 R"
	If $iOutlineObject > 0 Then $sCatalog &= " /Outlines " & $iOutlineObject & " 0 R"
	If $sPageMode <> "" Then $sCatalog &= " /PageMode /" & $sPageMode
	If $sPageLayout <> "" Then $sCatalog &= " /PageLayout /" & $sPageLayout
	$aCatalogObjects[1] = $sCatalog & " >>"
	$oDocument[$__PDFX_DOC_OBJECTS] = $aCatalogObjects

	; Info
	Local $aMetadata = $oDocument[$__PDFX_DOC_METADATA]
	Local $sInfoBody = "<<"
	If $aMetadata[0] <> "" Then $sInfoBody &= " /Title " & _PDFX_TextString($aMetadata[0])
	If $aMetadata[1] <> "" Then $sInfoBody &= " /Author " & _PDFX_TextString($aMetadata[1])
	If $aMetadata[2] <> "" Then $sInfoBody &= " /Subject " & _PDFX_TextString($aMetadata[2])
	If $aMetadata[3] <> "" Then $sInfoBody &= " /Keywords " & _PDFX_TextString($aMetadata[3])
	Local $sUtcDate = _PDFX_UtcDate()
	$sInfoBody &= " /Creator " & _PDFX_TextString("PDFX " & $PDFX_VERSION)
	$sInfoBody &= " /Producer " & _PDFX_TextString("PDFX " & $PDFX_VERSION & " pour AutoIt")
	$sInfoBody &= " /CreationDate (D:" & $sUtcDate & ") /ModDate (D:" & $sUtcDate & ") >>"
	Local $iInfoObject = _PDFX_AddObject($oDocument, $sInfoBody)

	; Identifiant de document : empreinte du contenu et des metadonnees, donc reproductible.
	Local $sIdSeed = "PDFX " & $PDFX_VERSION & "|" & $aMetadata[0] & "|" & $aMetadata[1] & "|" & $aMetadata[2] & "|" & $aMetadata[3]
	For $iIndex = 0 To $iPageCount - 1
		$sIdSeed &= "|" & $aPages[$iIndex][2]
	Next
	Local $aIdBookmarks = $oDocument[$__PDFX_DOC_BOOKMARKS]
	For $iIndex = 0 To UBound($aIdBookmarks) - 1
		$sIdSeed &= "|B" & $aIdBookmarks[$iIndex][0] & "|" & $aIdBookmarks[$iIndex][1] & "|" & $aIdBookmarks[$iIndex][2] & "|" & $aIdBookmarks[$iIndex][3]
	Next
	Local $aIdLinks = $oDocument[$__PDFX_DOC_PAGELINKS]
	For $iIndex = 0 To UBound($aIdLinks) - 1
		$sIdSeed &= "|K" & $aIdLinks[$iIndex][1] & "|" & $aIdLinks[$iIndex][2] & "|" & $aIdLinks[$iIndex][3] & "|" & $aIdLinks[$iIndex][4]
	Next
	If $sPageMode <> "" Then $sIdSeed &= "|M" & $sPageMode
	If $sPageLayout <> "" Then $sIdSeed &= "|L" & $sPageLayout
	Local $sDocumentId = _PDFX_HashHex($sIdSeed)
	If $sDocumentId = "" Then $sDocumentId = "00000000000000000000000000000000"

	; Assemblage : calcul des offsets puis ecriture
	Local $aChunks[1][2]
	Local $iChunkCount = 0
	Local $iPosition = 0
	Local $aObjectOffsets[$oDocument[$__PDFX_DOC_OBJECTCOUNT] + 1]

	Local $sPdfHeader = "%PDF-1.7" & @LF
	_PDFX_ChunkAdd($aChunks, $iChunkCount, "t", $sPdfHeader)
	$iPosition += StringLen($sPdfHeader)
	Local $bBinaryMarker = Binary("0x25E2E3CFD30A")
	_PDFX_ChunkAdd($aChunks, $iChunkCount, "b", $bBinaryMarker)
	$iPosition += BinaryLen($bBinaryMarker)

	Local $aObjectBodies = $oDocument[$__PDFX_DOC_OBJECTS]
	For $iIndex = 1 To $oDocument[$__PDFX_DOC_OBJECTCOUNT]
		$aObjectOffsets[$iIndex] = $iPosition

		Local $sObjectHeader = $iIndex & " 0 obj" & @LF
		_PDFX_ChunkAdd($aChunks, $iChunkCount, "t", $sObjectHeader)
		$iPosition += StringLen($sObjectHeader)

		Local $vObjectBody = $aObjectBodies[$iIndex]
		If IsArray($vObjectBody) Then
			For $iPart = 0 To UBound($vObjectBody) - 1
				If IsBinary($vObjectBody[$iPart]) Then
					_PDFX_ChunkAdd($aChunks, $iChunkCount, "b", $vObjectBody[$iPart])
					$iPosition += BinaryLen($vObjectBody[$iPart])
				Else
					_PDFX_ChunkAdd($aChunks, $iChunkCount, "t", $vObjectBody[$iPart])
					$iPosition += StringLen($vObjectBody[$iPart])
				EndIf
			Next
		Else
			_PDFX_ChunkAdd($aChunks, $iChunkCount, "t", $vObjectBody)
			$iPosition += StringLen($vObjectBody)
		EndIf

		_PDFX_ChunkAdd($aChunks, $iChunkCount, "t", @LF & "endobj" & @LF)
		$iPosition += StringLen(@LF & "endobj" & @LF)
	Next

	; Table xref
	Local $iXrefPosition = $iPosition
	Local $sXref = "xref" & @LF & "0 " & ($oDocument[$__PDFX_DOC_OBJECTCOUNT] + 1) & @LF & "0000000000 65535 f" & @CRLF
	For $iIndex = 1 To $oDocument[$__PDFX_DOC_OBJECTCOUNT]
		$sXref &= StringFormat("%010d 00000 n", $aObjectOffsets[$iIndex]) & @CRLF
	Next
	_PDFX_ChunkAdd($aChunks, $iChunkCount, "t", $sXref)
	$iPosition += StringLen($sXref)

	Local $sTrailer = "trailer" & @LF & "<< /Size " & ($oDocument[$__PDFX_DOC_OBJECTCOUNT] + 1) & " /Root 1 0 R /Info " & $iInfoObject & _
			" 0 R /ID [<" & $sDocumentId & "><" & $sDocumentId & ">] >>" & @LF
	_PDFX_ChunkAdd($aChunks, $iChunkCount, "t", $sTrailer)
	$iPosition += StringLen($sTrailer)

	Local $sStartXref = "startxref" & @LF & $iXrefPosition & @LF & "%%EOF" & @LF
	_PDFX_ChunkAdd($aChunks, $iChunkCount, "t", $sStartXref)

	Local $hFile = FileOpen($sFile, 0x12)
	If $hFile = -1 Then Return SetError(1, 0, False)
	For $iIndex = 0 To $iChunkCount - 1
		FileWrite($hFile, $aChunks[$iIndex][1])
	Next
	FileClose($hFile)
	$oDocument[$__PDFX_DOC_SAVED] = True
	Return True
EndFunc   ;==>_PDFX_Save

Func _PDFX_PackContent(ByRef $oDocument, $sContent)
	Local $iLevel = $oDocument[$__PDFX_DOC_COMPRESSION]
	If $iLevel <= 0 Then Return 0
	If StringLen($sContent) < 16 Then Return 0
	Local $bPacked = _PDFX_ZlibCompress($sContent, $__PDFX_ZLIB_DEPTH[$iLevel])
	If Not IsBinary($bPacked) Then Return 0
	If BinaryLen($bPacked) >= StringLen($sContent) Then Return 0
	Return $bPacked
EndFunc   ;==>_PDFX_PackContent

; Destination PDF vers une page : page entiere (/Fit) ou point precis (/XYZ).
Func _PDFX_PageDestination($fPageHeight, $iPageObject, $fYTop)
	If $fYTop < 0 Then Return "[" & $iPageObject & " 0 R /Fit]"
	Local $fY = $fPageHeight - $fYTop
	If $fY < 0 Then $fY = 0
	If $fY > $fPageHeight Then $fY = $fPageHeight
	Return "[" & $iPageObject & " 0 R /XYZ 0 " & _PDFX_F($fY) & " null]"
EndFunc   ;==>_PDFX_PageDestination

; Cree les annotations internes avant les pages, pour que /Annots les reference des leur ecriture.
Func _PDFX_PreparePageLinks(ByRef $oDocument, ByRef $aPages, $iPageCount)
	Local $aLinks = $oDocument[$__PDFX_DOC_PAGELINKS]
	If UBound($aLinks) = 0 Then Return
	Local $aObjects = $aLinks
	For $iIndex = 0 To UBound($aLinks) - 1
		; Colonne 0 : page source avant preparation, objet de l'annotation ensuite.
		; La valeur 0 marque un lien abandonne, que _PDFX_PatchPageLinks ignorera.
		Local $iSource = $aLinks[$iIndex][0]
		$aObjects[$iIndex][0] = 0
		If $aLinks[$iIndex][1] >= $iPageCount Then ContinueLoop
		Local $sAnnotation = "<< /Type /Annot /Subtype /Link /Rect [" & _PDFX_F($aLinks[$iIndex][3]) & " " & _
				_PDFX_F($aLinks[$iIndex][4]) & " " & _PDFX_F($aLinks[$iIndex][5]) & " " & _PDFX_F($aLinks[$iIndex][6]) & _
				"] /Border [0 0 0] /Dest [0 0 R /Fit] >>"
		Local $iObject = _PDFX_AddObject($oDocument, $sAnnotation)
		$aPages[$iSource][3] &= $iObject & " 0 R "
		$aObjects[$iIndex][0] = $iObject
	Next
	$oDocument[$__PDFX_DOC_PAGELINKS] = $aObjects
EndFunc   ;==>_PDFX_PreparePageLinks

; Complete les annotations internes : leur page cible n'est connue qu'apres la creation des pages.
Func _PDFX_PatchPageLinks(ByRef $oDocument, $aPages, $aPageObjects)
	Local $aLinks = $oDocument[$__PDFX_DOC_PAGELINKS]
	If UBound($aLinks) = 0 Then Return
	Local $aBodies = $oDocument[$__PDFX_DOC_OBJECTS]
	For $iIndex = 0 To UBound($aLinks) - 1
		If $aLinks[$iIndex][0] = 0 Then ContinueLoop
		Local $iTarget = $aLinks[$iIndex][1]
		Local $sDestination = _PDFX_PageDestination($aPages[$iTarget][1], $aPageObjects[$iTarget], $aLinks[$iIndex][2])
		$aBodies[$aLinks[$iIndex][0]] = "<< /Type /Annot /Subtype /Link /Rect [" & _PDFX_F($aLinks[$iIndex][3]) & " " & _
				_PDFX_F($aLinks[$iIndex][4]) & " " & _PDFX_F($aLinks[$iIndex][5]) & " " & _PDFX_F($aLinks[$iIndex][6]) & _
				"] /Border [0 0 0] /Dest " & $sDestination & " >>"
	Next
	$oDocument[$__PDFX_DOC_OBJECTS] = $aBodies
EndFunc   ;==>_PDFX_PatchPageLinks

; Arbre /Outlines : chaines First/Last, liens Parent/Prev/Next et /Count des descendants.
Func _PDFX_BuildOutline(ByRef $oDocument, $aPages, $aPageObjects)
	Local $aBookmarks = $oDocument[$__PDFX_DOC_BOOKMARKS]
	Local $iTotal = UBound($aBookmarks)
	If $iTotal = 0 Then Return 0

	Local $aParent[$iTotal], $aFirst[$iTotal], $aLast[$iTotal]
	Local $aPrev[$iTotal], $aNext[$iTotal], $aCount[$iTotal]
	Local $aLastAtLevel[$iTotal]
	Local $iRootFirst = 0, $iRootLast = 0
	Local $iIndex, $iLevel, $iParent, $iDepth

	For $iIndex = 0 To $iTotal - 1
		$iLevel = $aBookmarks[$iIndex][1]
		$iParent = $iLevel = 0 ? -1 : $aLastAtLevel[$iLevel - 1] - 1
		$aParent[$iIndex] = $iParent
		If $iParent < 0 Then
			If $iRootFirst = 0 Then
				$iRootFirst = $iIndex + 1
			Else
				$aNext[$iRootLast - 1] = $iIndex + 1
				$aPrev[$iIndex] = $iRootLast
			EndIf
			$iRootLast = $iIndex + 1
		Else
			If $aFirst[$iParent] = 0 Then
				$aFirst[$iParent] = $iIndex + 1
			Else
				$aNext[$aLast[$iParent] - 1] = $iIndex + 1
				$aPrev[$iIndex] = $aLast[$iParent]
			EndIf
			$aLast[$iParent] = $iIndex + 1
		EndIf
		$aLastAtLevel[$iLevel] = $iIndex + 1
		For $iDepth = $iLevel + 1 To $iTotal - 1
			$aLastAtLevel[$iDepth] = 0
		Next
	Next

	For $iIndex = 0 To $iTotal - 1
		Local $iDescendants = 0
		For $iDepth = $iIndex + 1 To $iTotal - 1
			If $aBookmarks[$iDepth][1] <= $aBookmarks[$iIndex][1] Then ExitLoop
			$iDescendants += 1
		Next
		$aCount[$iIndex] = $iDescendants
	Next

	Local $aObjects[$iTotal]
	For $iIndex = 0 To $iTotal - 1
		$aObjects[$iIndex] = _PDFX_AddObject($oDocument, "")
	Next
	Local $iOutlineObject = _PDFX_AddObject($oDocument, "")
	Local $aBodies = $oDocument[$__PDFX_DOC_OBJECTS]

	For $iIndex = 0 To $iTotal - 1
		Local $iPage = $aBookmarks[$iIndex][2]
		Local $sItem = "<< /Title " & _PDFX_TextString($aBookmarks[$iIndex][0])
		$sItem &= " /Parent " & ($aParent[$iIndex] >= 0 ? $aObjects[$aParent[$iIndex]] : $iOutlineObject) & " 0 R"
		If $aPrev[$iIndex] > 0 Then $sItem &= " /Prev " & $aObjects[$aPrev[$iIndex] - 1] & " 0 R"
		If $aNext[$iIndex] > 0 Then $sItem &= " /Next " & $aObjects[$aNext[$iIndex] - 1] & " 0 R"
		If $aFirst[$iIndex] > 0 Then
			$sItem &= " /First " & $aObjects[$aFirst[$iIndex] - 1] & " 0 R"
			$sItem &= " /Last " & $aObjects[$aLast[$iIndex] - 1] & " 0 R"
		EndIf
		If $aCount[$iIndex] > 0 Then $sItem &= " /Count " & $aCount[$iIndex]
		$sItem &= " /Dest " & _PDFX_PageDestination($aPages[$iPage][1], $aPageObjects[$iPage], $aBookmarks[$iIndex][3]) & " >>"
		$aBodies[$aObjects[$iIndex]] = $sItem
	Next

	$aBodies[$iOutlineObject] = "<< /Type /Outlines /First " & $aObjects[$iRootFirst - 1] & " 0 R /Last " & _
			$aObjects[$iRootLast - 1] & " 0 R /Count " & $iTotal & " >>"
	$oDocument[$__PDFX_DOC_OBJECTS] = $aBodies
	Return $iOutlineObject
EndFunc   ;==>_PDFX_BuildOutline

Func _PDFX_ChunkAdd(ByRef $aChunks, ByRef $iChunkCount, $sKind, $vData)
	If $iChunkCount >= UBound($aChunks) Then ReDim $aChunks[$iChunkCount + 64][2]
	$aChunks[$iChunkCount][0] = $sKind
	$aChunks[$iChunkCount][1] = $vData
	$iChunkCount += 1
EndFunc   ;==>_PDFX_ChunkAdd

Func _PDFX_ResourceDict($oDocument)
	Local $sResources = ""

	Local $aFonts = $oDocument[$__PDFX_DOC_FONTS]
	If UBound($aFonts) > 0 Then
		$sResources &= "/Font << "
		For $iIndex = 0 To UBound($aFonts) - 1
			$sResources &= "/" & $aFonts[$iIndex][2] & " " & $aFonts[$iIndex][1] & " 0 R "
		Next
		$sResources &= ">> "
	EndIf

	Local $aImages = $oDocument[$__PDFX_DOC_IMAGES]
	If UBound($aImages) > 0 Then
		$sResources &= "/XObject << "
		For $iIndex = 0 To UBound($aImages) - 1
			$sResources &= "/" & $aImages[$iIndex][4] & " " & $aImages[$iIndex][1] & " 0 R "
		Next
		$sResources &= ">> "
	EndIf

	Local $aStates = $oDocument[$__PDFX_DOC_STATES]
	If UBound($aStates) > 0 Then
		$sResources &= "/ExtGState << "
		For $iIndex = 0 To UBound($aStates) - 1
			$sResources &= "/" & $aStates[$iIndex][2] & " " & $aStates[$iIndex][1] & " 0 R "
		Next
		$sResources &= ">> "
	EndIf

	Return StringStripWS($sResources, 2)
EndFunc   ;==>_PDFX_ResourceDict

; #FUNCTION# ====================================================================================================================
; Name...........: _PDFX_Close
; Description ...: Libere les ressources du moteur pour ce document.
; Syntax.........: _PDFX_Close(ByRef $oDocument)
; Parameters ....: $oDocument - handle du document.
; Return values .: Success      - True.
; Author ........: Numeric1
; Modified.......:
; Remarks .......: Arrete GDI+ si le moteur l'a demarre. A appeler apres _PDFX_Save() ; le handle n'est plus utilise
;                  ensuite.
; Related .......: _PDFX_Save
; Link ..........: https://www.autoitscript.com/forum/
; Example .......: Yes
; ===============================================================================================================================
Func _PDFX_Close(ByRef $oDocument)
#forceref $oDocument
	If $__PDFX_GdiPlusLoaded And $__PDFX_GdiPlusOwned Then _GDIPlus_Shutdown()
	$__PDFX_GdiPlusLoaded = False
	$__PDFX_GdiPlusOwned = False
	Return True
EndFunc   ;==>_PDFX_Close

#EndRegion

#Region - Utilitaires internes --------------------------------------------------------------------------------------------------
; Helpers de bas niveau partages par le moteur.

Func _PDFX_Op(ByRef $oDocument, $sOp)
	$oDocument[$__PDFX_DOC_CONTENT] &= $sOp & @LF
EndFunc   ;==>_PDFX_Op

Func _PDFX_ArrayPush(ByRef $aArray, $vValue)
	Local $iCount = UBound($aArray)
	ReDim $aArray[$iCount + 1]
	$aArray[$iCount] = $vValue
EndFunc   ;==>_PDFX_ArrayPush

Func _PDFX_Sum($aValues)
	Local $fTotal = 0
	For $iIndex = 0 To UBound($aValues) - 1
		$fTotal += $aValues[$iIndex]
	Next
	Return $fTotal
EndFunc   ;==>_PDFX_Sum

; Borne une valeur numerique et signale par @error = 1 tout depassement.
Func _PDFX_Clamp($vValue, $fMinimum, $fMaximum)
	Local $fValue = Number($vValue)
	If $fValue < $fMinimum Then Return SetError(1, 0, $fMinimum)
	If $fValue > $fMaximum Then Return SetError(1, 0, $fMaximum)
	Return $fValue
EndFunc   ;==>_PDFX_Clamp

; Format compact d'un nombre reel pour le flux PDF.
Func _PDFX_F($vNumber)
	Local $sNumber = StringFormat("%.3f", $vNumber)
	While StringRight($sNumber, 1) = "0" And StringLen($sNumber) > 1
		$sNumber = StringLeft($sNumber, StringLen($sNumber) - 1)
	WEnd
	If StringRight($sNumber, 1) = "." Then $sNumber = StringLeft($sNumber, StringLen($sNumber) - 1)
	If $sNumber = "-0" Then $sNumber = "0"
	Return $sNumber
EndFunc   ;==>_PDFX_F

; Empreinte MD5 d'une chaine, en hexadecimal majuscule (32 caracteres).
Func _PDFX_HashHex($sData)
	Local $bHash = _Crypt_HashData($sData, $CALG_MD5)
	If Not IsBinary($bHash) Then Return ""
	Local $sHex = ""
	For $iByte = 1 To BinaryLen($bHash)
		$sHex &= StringUpper(Hex(_PDFX_ByteAt($bHash, $iByte), 2))
	Next
	Return $sHex
EndFunc   ;==>_PDFX_HashHex

; Vrai si tous les caracteres tiennent dans l'ASCII imprimable.
Func _PDFX_IsAscii($sText)
	For $iChar = 1 To StringLen($sText)
		Local $iCode = AscW(StringMid($sText, $iChar, 1))
		If $iCode < 32 Or $iCode > 126 Then Return False
	Next
	Return True
EndFunc   ;==>_PDFX_IsAscii

; Valeur de texte PDF : chaine litterale si ASCII, hexadecimale UTF-16BE sinon.
Func _PDFX_TextString($sText)
	If $sText = "" Then Return "<>"
	If _PDFX_IsAscii($sText) Then Return "(" & _PDFX_Escape($sText) & ")"
	Local $sHex = "FEFF"
	For $iChar = 1 To StringLen($sText)
		Local $iCode = AscW(StringMid($sText, $iChar, 1))
		If $iCode < 0 Then $iCode += 65536
		$sHex &= StringUpper(Hex($iCode, 4))
	Next
	Return "<" & $sHex & ">"
EndFunc   ;==>_PDFX_TextString

; Horodatage PDF en temps universel : D:AAAAMMJJHHMMSSZ.
Func _PDFX_UtcDate()
	Local $tSystem = DllStructCreate("ushort wYear; ushort wMonth; ushort wDayOfWeek; ushort wDay; ushort wHour; ushort wMinute; ushort wSecond; ushort wMilliseconds")
	DllCall("kernel32.dll", "none", "GetSystemTime", "struct*", $tSystem)
	Return StringFormat("%04d%02d%02d%02d%02d%02dZ", DllStructGetData($tSystem, "wYear"), _
			DllStructGetData($tSystem, "wMonth"), DllStructGetData($tSystem, "wDay"), _
			DllStructGetData($tSystem, "wHour"), DllStructGetData($tSystem, "wMinute"), _
			DllStructGetData($tSystem, "wSecond"))
EndFunc   ;==>_PDFX_UtcDate

Func _PDFX_Ext($sPath)
	Local $iDot = StringInStr($sPath, ".", 0, -1)
	If $iDot = 0 Then Return ""
	Return StringMid($sPath, $iDot + 1)
EndFunc   ;==>_PDFX_Ext

Func _PDFX_AbsPath($sPath)
	Local $sFullPath = StringReplace($sPath, "/", "\")
	If StringLen($sFullPath) > 1 And StringMid($sFullPath, 2, 1) = ":" Then Return $sFullPath
	Return @WorkingDir & "\" & $sFullPath
EndFunc   ;==>_PDFX_AbsPath

Func _PDFX_ReadBinary($sPath)
	Local $hFile = FileOpen($sPath, 16)
	If $hFile = -1 Then Return 0
	Local $bData = FileRead($hFile)
	FileClose($hFile)
	Return $bData
EndFunc   ;==>_PDFX_ReadBinary

; Lit "cle=valeur;cle=valeur" ; renvoie $vDefault si absent.
Func _PDFX_Opt($sOpts, $sKey, $vDefault)
	If $sOpts = "" Then Return $vDefault
	Local $aPairs = StringSplit($sOpts, ";", 2)
	For $i = 0 To UBound($aPairs) - 1
		Local $sPair = StringStripWS($aPairs[$i], 8)
		Local $iEqual = StringInStr($sPair, "=")
		If $iEqual > 0 Then
			If StringLower(StringStripWS(StringLeft($sPair, $iEqual - 1), 8)) = $sKey Then
				Local $vValue = StringStripWS(StringMid($sPair, $iEqual + 1), 8)
				If StringLeft($vValue, 2) = "0x" Then Return Number($vValue)
				Return $vValue
			EndIf
		EndIf
	Next
	Return $vDefault
EndFunc   ;==>_PDFX_Opt

; -------------------------------------------------------------------------------------------------------------------------------
; Compresseur DEFLATE (RFC 1951) et enveloppe zlib (RFC 1950).
;
; Codage Huffman fixe : le bloc ne transporte que les codes du bloc 01, ce qui evite d'ecrire un arbre dynamique
; et rend la sortie strictement deterministe. La recherche de repetitions est un hachage a trois octets avec
; chainage borne par le niveau demande. L'ecrivain de bits produit directement la chaine hexadecimale qui sera
; convertie en binaire une fois le flux termine.

Func _PDFX_ZlibInit()
	If $__PDFX_ZLIB_READY Then Return
	Local $iCode, $iBits, $iValue
	For $iCode = 0 To 287
		If $iCode <= 143 Then
			$iBits = 8
			$iValue = 0x30 + $iCode
		ElseIf $iCode <= 255 Then
			$iBits = 9
			$iValue = 0x190 + ($iCode - 144)
		ElseIf $iCode <= 279 Then
			$iBits = 7
			$iValue = $iCode - 256
		Else
			$iBits = 8
			$iValue = 0xC0 + ($iCode - 280)
		EndIf
		$__PDFX_ZLIB_LITCODE[$iCode] = _PDFX_ZlibReverseBits($iValue, $iBits)
		$__PDFX_ZLIB_LITBITS[$iCode] = $iBits
	Next

	Local $aLenBase[29] = [3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258]
	Local $aLenExtra[29] = [0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0]
	Local $j, $k, $iBase, $iExtra, $iCount, $iLength
	For $j = 0 To 28
		$iBase = $aLenBase[$j]
		$iExtra = $aLenExtra[$j]
		$iCount = ($j = 28) ? 1 : BitShift(1, -$iExtra)
		For $k = 0 To $iCount - 1
			$iLength = $iBase + $k
			$__PDFX_ZLIB_LENCODE[$iLength] = 257 + $j
			$__PDFX_ZLIB_LENEXTRA[$iLength] = $iExtra
			$__PDFX_ZLIB_LENBASE[$iLength] = $iBase
		Next
	Next

	Local $aDistBase[30] = [1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577]
	Local $aDistExtra[30] = [0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13]
	For $j = 0 To 29
		$__PDFX_ZLIB_DISTCODE[$j] = _PDFX_ZlibReverseBits($j, 5)
		$__PDFX_ZLIB_DISTBASE[$j] = $aDistBase[$j]
		$__PDFX_ZLIB_DISTEXTRA[$j] = $aDistExtra[$j]
	Next

	For $iCode = 0 To 255
		$__PDFX_ZLIB_HEX[$iCode] = Hex($iCode, 2)
	Next
	$__PDFX_ZLIB_READY = True
EndFunc   ;==>_PDFX_ZlibInit

; Les codes Huffman se lisent du bit de poids fort vers le bit de poids faible, alors que _PDFX_ZlibPut()
; ecrit du poids faible vers le poids fort : chaque code est donc retourne une fois pour toutes.
Func _PDFX_ZlibReverseBits($iValue, $iBits)
	Local $iResult = 0, $iBit
	For $iBit = 0 To $iBits - 1
		$iResult = BitShift($iResult, -1)
		If BitAND($iValue, BitShift(1, -$iBit)) Then $iResult = BitOR($iResult, 1)
	Next
	Return $iResult
EndFunc   ;==>_PDFX_ZlibReverseBits

; Etat de l'ecrivain : [0] bits en attente, [1] nombre de bits en attente, [2] octets deja produits en hexadecimal.
Func _PDFX_ZlibPut(ByRef $aState, $iValue, $iBits)
	$aState[0] = BitOR($aState[0], BitShift($iValue, -$aState[1]))
	$aState[1] += $iBits
	While $aState[1] >= 8
		$aState[2] &= $__PDFX_ZLIB_HEX[BitAND($aState[0], 0xFF)]
		$aState[0] = BitShift($aState[0], 8)
		$aState[1] -= 8
	WEnd
EndFunc   ;==>_PDFX_ZlibPut

Func _PDFX_ZlibFlush(ByRef $aState)
	If $aState[1] > 0 Then
		$aState[2] &= $__PDFX_ZLIB_HEX[BitAND($aState[0], 0xFF)]
		$aState[0] = 0
		$aState[1] = 0
	EndIf
EndFunc   ;==>_PDFX_ZlibFlush

; Compresse une chaine ASCII en zlib et renvoie un binaire pret pour /FlateDecode.
; $iDepth borne le nombre de candidats examines par position ; 0 est reserve au flux brut et n'arrive pas ici.
Func _PDFX_ZlibCompress($sData, $iDepth)
	_PDFX_ZlibInit()
	Local $iLength = StringLen($sData)
	If $iLength < 16 Then Return 0
	If $iDepth < 1 Then $iDepth = 1

	Local $aData[$iLength]
	Local $i
	For $i = 0 To $iLength - 1
		$aData[$i] = BitAND(AscW(StringMid($sData, $i + 1, 1)), 0xFF)
	Next

	Local $aLitCode = $__PDFX_ZLIB_LITCODE, $aLitBits = $__PDFX_ZLIB_LITBITS
	Local $aLenCode = $__PDFX_ZLIB_LENCODE, $aLenExtra = $__PDFX_ZLIB_LENEXTRA
	Local $aLenBase = $__PDFX_ZLIB_LENBASE
	Local $aDistCode = $__PDFX_ZLIB_DISTCODE, $aDistExtra = $__PDFX_ZLIB_DISTEXTRA
	Local $aDistBase = $__PDFX_ZLIB_DISTBASE

	; En-tete zlib : deflate, fenetre 32 Ko, niveau par defaut ; 0x789C est le couple recommande.
	Local $aState[3] = [0, 0, "789C"]
	_PDFX_ZlibPut($aState, 1, 1)
	_PDFX_ZlibPut($aState, 1, 2)

	Local $aHead[65536], $aPrev[$iLength]
	Local $iPosition = 0, $iHash, $iCandidate, $iCandidatePosition, $iDistance
	Local $iBestLength, $iBestDistance, $iMaxLength, $iSearched, $iMatch
	Local $iCode, $iExtra, $iSkip, $iSkipPos, $iSkipHash, $iA, $iB

	While $iPosition < $iLength
		$iBestLength = 0
		$iBestDistance = 0
		If $iPosition + 2 < $iLength Then
			$iHash = BitAND(($aData[$iPosition] * 31 + $aData[$iPosition + 1]) * 31 + $aData[$iPosition + 2], 0xFFFF)
			$iCandidate = $aHead[$iHash]
			$iMaxLength = $iLength - $iPosition
			If $iMaxLength > 258 Then $iMaxLength = 258
			$iSearched = 0
			While $iCandidate <> 0 And $iSearched < $iDepth
				$iCandidatePosition = $iCandidate - 1
				$iDistance = $iPosition - $iCandidatePosition
				If $iDistance > 32768 Then ExitLoop
				If $aData[$iCandidatePosition + $iBestLength] = $aData[$iPosition + $iBestLength] Then
					$iMatch = 0
					While $iMatch < $iMaxLength And $aData[$iCandidatePosition + $iMatch] = $aData[$iPosition + $iMatch]
						$iMatch += 1
					WEnd
					If $iMatch > $iBestLength Then
						$iBestLength = $iMatch
						$iBestDistance = $iDistance
						If $iBestLength >= $iMaxLength Then ExitLoop
					EndIf
				EndIf
				$iCandidate = $aPrev[$iCandidatePosition]
				$iSearched += 1
			WEnd
			$aPrev[$iPosition] = $aHead[$iHash]
			$aHead[$iHash] = $iPosition + 1
		EndIf

		If $iBestLength >= 3 Then
			$iCode = $aLenCode[$iBestLength]
			_PDFX_ZlibPut($aState, $aLitCode[$iCode], $aLitBits[$iCode])
			$iExtra = $aLenExtra[$iBestLength]
			If $iExtra > 0 Then _PDFX_ZlibPut($aState, $iBestLength - $aLenBase[$iBestLength], $iExtra)

			$iCode = 29
			While $iBestDistance < $aDistBase[$iCode]
				$iCode -= 1
			WEnd
			_PDFX_ZlibPut($aState, $aDistCode[$iCode], 5)
			$iExtra = $aDistExtra[$iCode]
			If $iExtra > 0 Then _PDFX_ZlibPut($aState, $iBestDistance - $aDistBase[$iCode], $iExtra)

			For $iSkip = 1 To $iBestLength - 1
				$iSkipPos = $iPosition + $iSkip
				If $iSkipPos + 2 < $iLength Then
					$iSkipHash = BitAND(($aData[$iSkipPos] * 31 + $aData[$iSkipPos + 1]) * 31 + $aData[$iSkipPos + 2], 0xFFFF)
					$aPrev[$iSkipPos] = $aHead[$iSkipHash]
					$aHead[$iSkipHash] = $iSkipPos + 1
				EndIf
			Next
			$iPosition += $iBestLength
		Else
			_PDFX_ZlibPut($aState, $aLitCode[$aData[$iPosition]], $aLitBits[$aData[$iPosition]])
			$iPosition += 1
		EndIf
	WEnd

	_PDFX_ZlibPut($aState, $aLitCode[256], $aLitBits[256])
	_PDFX_ZlibFlush($aState)

	; Adler-32 des octets d'origine, en complement de la somme de controle de zlib.
	$iA = 1
	$iB = 0
	For $i = 0 To $iLength - 1
		$iA += $aData[$i]
		If $iA >= 65521 Then $iA -= 65521
		$iB += $iA
		If $iB >= 65521 Then $iB -= 65521
	Next
	Return Binary("0x" & $aState[2] & Hex($iB, 4) & Hex($iA, 4))
EndFunc   ;==>_PDFX_ZlibCompress

#EndRegion
