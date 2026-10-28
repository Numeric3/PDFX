; #INDEX# =======================================================================================================================
; Title .........: PDFX
; AutoIt Version : 3.3.16.1
; Language ......: English
; Description ...: Self-contained PDF engine for AutoIt: text, shapes, images,
;                  tables, links, bookmarks, header and footer. No external
;                  dependency; GDI+ (shipped with AutoIt) is only used to convert
;                  PNG, BMP and GIF to JPEG, and a DEFLATE compressor written in
;                  pure AutoIt shrinks the content streams.
; Author(s) .....: Numeric1
; Link ..........: https://www.autoitscript.com/forum/topic/213930-udf-pdfx/
; Version .......: 1.4.0
; Copyright .....: (c) 2026 Numeric1
; License .......: MIT or public domain, at your choice.
;
; ---------------------------------QUICK START----------------------------------
;
;   #include "PDFX.au3"
;
;   Local $oDocument = _PDFX_New()                       ; A4 portrait, 15 mm margin
;   _PDFX_SetCompression($oDocument, 6)                  ; content streams in FlateDecode
;   _PDFX_SetFont($oDocument, "Helvetica", 24, "B")
;   _PDFX_Text($oDocument, 40, 40, "Monthly report")      ; y = top of the text
;   _PDFX_AddBookmark($oDocument, "Title", 0, 1, 40)     ; bookmark to page 1
;   _PDFX_SetPageMode($oDocument, "UseOutlines")         ; bookmark pane open
;   _PDFX_SetFont($oDocument, "Helvetica", 11)
;   _PDFX_TextWrap($oDocument, 40, 80, 515, "Long text ...")
;   _PDFX_Save($oDocument, @ScriptDir & "\report.pdf")
;   _PDFX_Close($oDocument)
;
; ----------------------------------PRINCIPLES----------------------------------
;
; * A document is a handle (array): no global state, several PDFs can be
;   built in parallel in the same script.
; * A document is written only once: _PDFX_Save() freezes the handle and
;   _PDFX_AddPage() then returns @error = 2. Dates are in universal time and
;   /ID is a deterministic MD5 fingerprint of the content.
; * Coordinates in points (1 pt = 1/72 inch), origin at the TOP LEFT.
;   _PDFX_Mm() converts millimetres; the switch to PDF space (origin at the
;   bottom left) is internal.
; * Text widths come from the AFM metrics of the standard fonts:
;   alignment and word wrapping are exact, with no GDI rendering.
; * WinAnsi encoding: Western European accents pass without any setting.
; * Images: JPEG embedded byte for byte; PNG, BMP and GIF converted to
;   JPEG on white via GDI+, then deduplicated by path.
; * Optional compression: _PDFX_SetCompression() writes content streams
;   with FlateDecode (zlib), with automatic fallback to the raw stream.
; * Navigation: _PDFX_AddBookmark() builds a hierarchical /Outlines tree
;   and _PDFX_LinkPage() links two pages without going through a URL.
;
; ------------------------------------LIMITS------------------------------------
;
; * Pure AutoIt compressor: about 30 KB/s and a ratio close to zlib level 1.
;   Uncompressed streams remain the default.
; * No embedded TrueType fonts: only characters covered by WinAnsi are
;   rendered, the others become '?'.
; * No reading or modifying existing PDFs.
; * Bookmarks and internal links only target pages of the document: no
;   named destinations, no JavaScript actions and no attachments.
;
; ---------------------------------ORIGINALITY----------------------------------
;
; Implementation written for this project from ISO 32000-1:2008 (indirect
; objects, xref table, content streams, annotations) and the public AFM
; metrics of Adobe's Core 14 fonts.
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

; Engine version, echoed in the /Creator and /Producer metadata.
Global Const $PDFX_VERSION = "1.4.0"

#Region - Internal constants ----------------------------------------------------------------------------------------------------
; Document handle: each constant is an index in the array returned by _PDFX_New().
Global Const $__PDFX_DOC_OBJECTS = 0         ; bodies of the indirect objects (index 1..N)
Global Const $__PDFX_DOC_OBJECTCOUNT = 1     ; number of objects
Global Const $__PDFX_DOC_PAGES = 2           ; [n][4] = w, h, content, annotations
Global Const $__PDFX_DOC_FONTS = 3           ; [n][4] = baseFont, objNum, resourceName, widthTable
Global Const $__PDFX_DOC_IMAGES = 4          ; [n][5] = path, objNum, width px, height px, resourceName
Global Const $__PDFX_DOC_STATES = 5          ; [n][3] = key, objNum, resourceName (ExtGState)
Global Const $__PDFX_DOC_WIDTH = 6           ; current page width (pt)
Global Const $__PDFX_DOC_HEIGHT = 7          ; current page height (pt)
Global Const $__PDFX_DOC_CURRENTPAGE = 8     ; current page index (0-based, -1 = none)
Global Const $__PDFX_DOC_CONTENT = 9         ; content stream of the current page
Global Const $__PDFX_DOC_ANNOTS = 10         ; annotations of the current page
Global Const $__PDFX_DOC_FONT = 11           ; current font index
Global Const $__PDFX_DOC_FONTSIZE = 12       ; current size
Global Const $__PDFX_DOC_FILL = 13           ; current "r g b"
Global Const $__PDFX_DOC_STROKE = 14         ; current "r g b"
Global Const $__PDFX_DOC_LINEWIDTH = 15      ; line width
Global Const $__PDFX_DOC_METADATA = 16       ; [title, author, subject, keywords]
Global Const $__PDFX_DOC_HEADERFOOTER = 17   ; [hL, hC, hR, fL, fC, fR, size, hColour, hFont, hStyle, fColour, fFont, fStyle]
Global Const $__PDFX_DOC_MARGIN = 18         ; default margin (pt)
Global Const $__PDFX_DOC_DEFAULTHEIGHT = 19  ; default height of new pages
Global Const $__PDFX_DOC_DEFAULTWIDTH = 20   ; default width
Global Const $__PDFX_DOC_HFAPPLIED = 21      ; header/footer already inserted into the pages
Global Const $__PDFX_DOC_SAVED = 22          ; document already written: frozen
Global Const $__PDFX_DOC_COMPRESSION = 23    ; content stream compression level (0 = raw)
Global Const $__PDFX_DOC_BOOKMARKS = 24      ; [n][4] = title, level, page (0-based), top y (-1 = /Fit)
Global Const $__PDFX_DOC_PAGELINKS = 25      ; [n][7] = object, target page, target y, rect (4 values)
Global Const $__PDFX_DOC_PAGEMODE = 26       ; "" (auto) or UseNone, UseOutlines, UseThumbs, FullScreen
Global Const $__PDFX_DOC_PAGELAYOUT = 27     ; "" or SinglePage, OneColumn, TwoColumnLeft, ...
Global Const $__PDFX_DOC_SLOTS = 28          ; total number of slots

; Paint styles accepted by the primitives and by _PDFX_Table().
Global Const $PDFX_STROKE = 0
Global Const $PDFX_FILL = 1
Global Const $PDFX_BOTH = 2

; Internal identifiers of the AFM metric tables.
Global Const $PDFX_FONT_HELVETICA = 0
Global Const $PDFX_FONT_HELVETICA_BOLD = 1
Global Const $PDFX_FONT_TIMES = 2
Global Const $PDFX_FONT_TIMES_BOLD = 3
Global Const $PDFX_FONT_COURIER = 4

; AFM widths (1/1000 em) for ASCII codes 32..126.
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

; WinAnsi special characters: 0 AE, 1 ae, 2 Oslash, 3 oslash, 4 sharp s, 5 multiply, 6 divide, 7 Eth, 8 eth, 9 Thorn, 10 thorn
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

; Minimal global state: GDI+ lifecycle for non-JPEG images.
Global $__PDFX_GdiPlusLoaded = False
Global $__PDFX_GdiPlusOwned = False

; DEFLATE compressor: fixed tables, built on first use, and the LZ77 search depth
; associated with each compression level (0 = raw stream).
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
#EndRegion - Internal constants ----------------------------------------------------------------------------------------------------

#Region - Lifecycle and pages ---------------------------------------------------------------------------------------------------
; Document creation, page addition, dimensions and margins.

; #FUNCTION# ====================================================================================================================
; Name...........: _PDFX_New
; Description ...: Creates a PDF document in memory and opens its first page.
; Syntax.........: _PDFX_New($sFormat = "A4", $sOrient = "P", $iMarginMm = 15)
; Parameters ....: $sFormat   - page format: A4 (default), A3, A5, Letter, Legal, or WIDTHxHEIGHT in
;                               millimetres.
;                  $sOrient   - orientation: P portrait (default) or L landscape.
;                  $iMarginMm - default margin, in millimetres (15 by default).
; Return values .: Success      - document handle, to pass to every other function.
; Author ........: Numeric1
; Modified.......:
; Remarks .......: The handle is a self-contained array: several documents can be built in parallel. An
;                  unknown format falls back to A4 portrait.
; Related .......: _PDFX_AddPage, _PDFX_SetFont, _PDFX_Save, _PDFX_Close
; Link ..........: https://www.autoitscript.com/forum/topic/213930-udf-pdfx/
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
; Description ...: Converts a length in millimetres to the internal unit, the PDF point.
; Syntax.........: _PDFX_Mm($fMillimetres)
; Parameters ....: $fMillimetres - length in millimetres.
; Return values .: Success      - value in points (1 pt = 1/72 inch).
; Author ........: Numeric1
; Modified.......:
; Remarks .......: The engine works exclusively in points; this function avoids scattered conversions in
;                  the calling code.
; Related .......: _PDFX_New, _PDFX_Margin
; Link ..........: https://www.autoitscript.com/forum/topic/213930-udf-pdfx/
; Example .......: Yes
; ===============================================================================================================================
Func _PDFX_Mm($fMillimetres)
	Return $fMillimetres * 72 / 25.4
EndFunc   ;==>_PDFX_Mm

; #FUNCTION# ====================================================================================================================
; Name...........: _PDFX_AddPage
; Description ...: Adds a page to the document and makes it current.
; Syntax.........: _PDFX_AddPage(ByRef $oDocument, $fWidth = 0, $fHeight = 0)
; Parameters ....: $oDocument - document handle.
;                  $fWidth    - width in points; 0 = default document width.
;                  $fHeight   - height in points; 0 = default document height.
; Return values .: Success      - index of the new page (0-based).
;                  Failure      - -1 with @error = 2 if the document has already been saved.
; Author ........: Numeric1
; Modified.......:
; Remarks .......: The content of the previous page is frozen before the addition. A document saved by
;                  _PDFX_Save() is frozen: no further page can be added to it.
; Related .......: _PDFX_New, _PDFX_SavePage, _PDFX_PageCount
; Link ..........: https://www.autoitscript.com/forum/topic/213930-udf-pdfx/
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
; Description ...: Returns the number of pages in the document.
; Syntax.........: _PDFX_PageCount($oDocument)
; Parameters ....: $oDocument - document handle.
; Return values .: Success      - number of pages (integer).
; Author ........: Numeric1
; Modified.......:
; Remarks .......:
; Related .......: _PDFX_AddPage
; Link ..........: https://www.autoitscript.com/forum/topic/213930-udf-pdfx/
; Example .......: Yes
; ===============================================================================================================================
Func _PDFX_PageCount($oDocument)
	Return UBound($oDocument[$__PDFX_DOC_PAGES])
EndFunc   ;==>_PDFX_PageCount

; #FUNCTION# ====================================================================================================================
; Name...........: _PDFX_PageWidth
; Description ...: Returns the width of the current page.
; Syntax.........: _PDFX_PageWidth($oDocument)
; Parameters ....: $oDocument - document handle.
; Return values .: Success      - width in points.
; Author ........: Numeric1
; Modified.......:
; Remarks .......:
; Related .......: _PDFX_PageHeight, _PDFX_Mm
; Link ..........: https://www.autoitscript.com/forum/topic/213930-udf-pdfx/
; Example .......: Yes
; ===============================================================================================================================
Func _PDFX_PageWidth($oDocument)
	Return $oDocument[$__PDFX_DOC_WIDTH]
EndFunc   ;==>_PDFX_PageWidth

; #FUNCTION# ====================================================================================================================
; Name...........: _PDFX_PageHeight
; Description ...: Returns the height of the current page.
; Syntax.........: _PDFX_PageHeight($oDocument)
; Parameters ....: $oDocument - document handle.
; Return values .: Success      - height in points.
; Author ........: Numeric1
; Modified.......:
; Remarks .......:
; Related .......: _PDFX_PageWidth, _PDFX_Mm
; Link ..........: https://www.autoitscript.com/forum/topic/213930-udf-pdfx/
; Example .......: Yes
; ===============================================================================================================================
Func _PDFX_PageHeight($oDocument)
	Return $oDocument[$__PDFX_DOC_HEIGHT]
EndFunc   ;==>_PDFX_PageHeight

; #FUNCTION# ====================================================================================================================
; Name...........: _PDFX_Margin
; Description ...: Returns the default margin of the document.
; Syntax.........: _PDFX_Margin($oDocument)
; Parameters ....: $oDocument - document handle.
; Return values .: Success      - margin in points.
; Author ........: Numeric1
; Modified.......:
; Remarks .......:
; Related .......: _PDFX_New, _PDFX_Mm
; Link ..........: https://www.autoitscript.com/forum/topic/213930-udf-pdfx/
; Example .......: Yes
; ===============================================================================================================================
Func _PDFX_Margin($oDocument)
	Return $oDocument[$__PDFX_DOC_MARGIN]
EndFunc   ;==>_PDFX_Margin

; #FUNCTION# ====================================================================================================================
; Name...........: _PDFX_SavePage
; Description ...: Freezes the content of the current page into the document.
; Syntax.........: _PDFX_SavePage(ByRef $oDocument)
; Parameters ....: $oDocument - document handle.
; Return values .: Success      - None.
; Author ........: Numeric1
; Modified.......:
; Remarks .......: Normally unnecessary: _PDFX_AddPage() and _PDFX_Save() freeze the page automatically.
; Related .......: _PDFX_AddPage, _PDFX_Save
; Link ..........: https://www.autoitscript.com/forum/topic/213930-udf-pdfx/
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

#EndRegion - Lifecycle and pages ---------------------------------------------------------------------------------------------------

#Region - Indirect objects ------------------------------------------------------------------------------------------------------
; Allocation of the numbered objects that make up the PDF file.

Func _PDFX_AddObject(ByRef $oDocument, $vBody)
	Local $iObjectNumber = $oDocument[$__PDFX_DOC_OBJECTCOUNT] + 1
	Local $aObjects = $oDocument[$__PDFX_DOC_OBJECTS]
	If $iObjectNumber >= UBound($aObjects) Then ReDim $aObjects[$iObjectNumber + 32]
	$aObjects[$iObjectNumber] = $vBody
	$oDocument[$__PDFX_DOC_OBJECTS] = $aObjects
	$oDocument[$__PDFX_DOC_OBJECTCOUNT] = $iObjectNumber
	Return $iObjectNumber
EndFunc   ;==>_PDFX_AddObject

#EndRegion - Indirect objects ------------------------------------------------------------------------------------------------------

#Region - Fonts and metrics -----------------------------------------------------------------------------------------------------
; Selection of the standard fonts and exact AFM width computation.

; #FUNCTION# ====================================================================================================================
; Name...........: _PDFX_SetFont
; Description ...: Selects the font and size used by the text functions.
; Syntax.........: _PDFX_SetFont(ByRef $oDocument, $sFamily = "Helvetica", $iSize = 0, $sStyle = "")
; Parameters ....: $sFamily - family: Helvetica (default), Times, Courier; accepted aliases: serif, mono, courrier,
;                             georgia.
;                  $iSize   - size in points; 0 keeps the current size.
;                  $sStyle  - style: B bold, I italic, BI bold italic.
; Return values .: Success      - True.
;                  Failure      - False with @error = 1 if the font cannot be created.
; Author ........: Numeric1
; Modified.......:
; Remarks .......: The 14 PDF standard fonts are available with no font file and no embedding.
; Related .......: _PDFX_Font, _PDFX_FontSize, _PDFX_TextWidth
; Link ..........: https://www.autoitscript.com/forum/topic/213930-udf-pdfx/
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
; Description ...: Returns the PDF name of the current font.
; Syntax.........: _PDFX_Font($oDocument)
; Parameters ....: $oDocument - document handle.
; Return values .: Success      - base name, for example Helvetica-Bold.
; Author ........: Numeric1
; Modified.......:
; Remarks .......:
; Related .......: _PDFX_SetFont, _PDFX_FontSize
; Link ..........: https://www.autoitscript.com/forum/topic/213930-udf-pdfx/
; Example .......: Yes
; ===============================================================================================================================
Func _PDFX_Font($oDocument)
	Local $aFonts = $oDocument[$__PDFX_DOC_FONTS]
	Return $aFonts[$oDocument[$__PDFX_DOC_FONT]][0]
EndFunc   ;==>_PDFX_Font

; #FUNCTION# ====================================================================================================================
; Name...........: _PDFX_FontSize
; Description ...: Returns the current font size.
; Syntax.........: _PDFX_FontSize($oDocument)
; Parameters ....: $oDocument - document handle.
; Return values .: Success      - size in points.
; Author ........: Numeric1
; Modified.......:
; Remarks .......:
; Related .......: _PDFX_SetFont, _PDFX_Font
; Link ..........: https://www.autoitscript.com/forum/topic/213930-udf-pdfx/
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

; [PDF name of the font, width table]
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
; Description ...: Computes the width of a text with the current font.
; Syntax.........: _PDFX_TextWidth($oDocument, $sText, $iSize = 0)
; Parameters ....: $oDocument - document handle.
;                  $sText     - text to measure.
;                  $iSize     - size in points; 0 = current size.
; Return values .: Success      - width in points.
; Author ........: Numeric1
; Modified.......:
; Remarks .......: The computation uses the AFM metrics: the result is exact for the standard fonts, with no GDI
;                  rendering.
; Related .......: _PDFX_SetFont, _PDFX_TextAlign
; Link ..........: https://www.autoitscript.com/forum/topic/213930-udf-pdfx/
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

; Index in $PDFX_AFM_SPECIAL, or -1.
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

; For an accented Latin character, returns the base letter (for width).
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
; WinAnsi typographic characters -> approximate width
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

#EndRegion - Fonts and metrics -----------------------------------------------------------------------------------------------------

#Region - Graphic state ---------------------------------------------------------------------------------------------------------
; Colours, line width, dashes and opacity.

; #FUNCTION# ====================================================================================================================
; Name...........: _PDFX_SetFill
; Description ...: Sets the fill colour used by shapes and text.
; Syntax.........: _PDFX_SetFill(ByRef $oDocument, $vColor)
; Parameters ....: $oDocument - document handle.
;                  $vColor    - 0xRRGGBB, [red, green, blue] array, a string of three comma-separated
;                               numbers, or a name (red, navy, gray...).
; Return values .: Success      - True.
;                  Failure      - True with @error = 1 if a component was clamped into [0, 255].
; Author ........: Numeric1
; Modified.......:
; Remarks .......: The colour stays active until the next call; every primitive captures the colour when
;                  it is emitted.
; Related .......: _PDFX_SetStroke, _PDFX_Rect, _PDFX_Text
; Link ..........: https://www.autoitscript.com/forum/topic/213930-udf-pdfx/
; Example .......: Yes
; ===============================================================================================================================
Func _PDFX_SetFill(ByRef $oDocument, $vColor)
	$oDocument[$__PDFX_DOC_FILL] = _PDFX_Color($vColor)
	Return SetError(@error, 0, True)
EndFunc   ;==>_PDFX_SetFill

; #FUNCTION# ====================================================================================================================
; Name...........: _PDFX_SetStroke
; Description ...: Sets the stroke colour used by shapes.
; Syntax.........: _PDFX_SetStroke(ByRef $oDocument, $vColor)
; Parameters ....: $oDocument - document handle.
;                  $vColor    - same syntax as _PDFX_SetFill().
; Return values .: Success      - True.
;                  Failure      - True with @error = 1 if a component was clamped into [0, 255].
; Author ........: Numeric1
; Modified.......:
; Remarks .......:
; Related .......: _PDFX_SetFill, _PDFX_SetLineWidth, _PDFX_Line
; Link ..........: https://www.autoitscript.com/forum/topic/213930-udf-pdfx/
; Example .......: Yes
; ===============================================================================================================================
Func _PDFX_SetStroke(ByRef $oDocument, $vColor)
	$oDocument[$__PDFX_DOC_STROKE] = _PDFX_Color($vColor)
	Return SetError(@error, 0, True)
EndFunc   ;==>_PDFX_SetStroke

; #FUNCTION# ====================================================================================================================
; Name...........: _PDFX_SetLineWidth
; Description ...: Sets the stroke width.
; Syntax.........: _PDFX_SetLineWidth(ByRef $oDocument, $fWidth)
; Parameters ....: $oDocument - document handle.
;                  $fWidth    - width in points; a value less than or equal to 0 is clamped to 0.1.
; Return values .: Success      - True.
; Author ........: Numeric1
; Modified.......:
; Remarks .......:
; Related .......: _PDFX_SetStroke, _PDFX_SetDash
; Link ..........: https://www.autoitscript.com/forum/topic/213930-udf-pdfx/
; Example .......: Yes
; ===============================================================================================================================
Func _PDFX_SetLineWidth(ByRef $oDocument, $fWidth)
	If $fWidth <= 0 Then $fWidth = 0.1
	$oDocument[$__PDFX_DOC_LINEWIDTH] = $fWidth
	Return True
EndFunc   ;==>_PDFX_SetLineWidth

; #FUNCTION# ====================================================================================================================
; Name...........: _PDFX_SetDash
; Description ...: Sets a dash pattern for the following strokes.
; Syntax.........: _PDFX_SetDash(ByRef $oDocument, $fOn, $fOff = 0)
; Parameters ....: $oDocument - document handle.
;                  $fOn       - length of the dash, in points; 0 or less restores a solid line.
;                  $fOff      - length of the gap, in points; 0 = same value as the dash.
; Return values .: Success      - True.
; Author ........: Numeric1
; Modified.......:
; Remarks .......: The pattern applies to all following strokes, including table borders, until the
;                  next change. _PDFX_SetDash($oDocument, 0) emits the empty pattern [] and restores a solid line.
; Related .......: _PDFX_SetLineWidth, _PDFX_Line
; Link ..........: https://www.autoitscript.com/forum/topic/213930-udf-pdfx/
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
; Description ...: Sets the opacity of fills and strokes.
; Syntax.........: _PDFX_SetAlpha(ByRef $oDocument, $fAlpha, $fStroke = -1)
; Parameters ....: $oDocument - document handle.
;                  $fAlpha    - fill opacity, from 0 (transparent) to 1 (opaque).
;                  $fStroke   - stroke opacity; a negative value = same as the fill.
; Return values .: Success      - True.
;                  Failure      - True with @error = 1 if an opacity was clamped into [0, 1].
; Author ........: Numeric1
; Modified.......:
; Remarks .......: Implemented with an ExtGState /ca /CA, created once per pair of values then reused.
;                  Negative values are clamped to 0, values above 1 to 1.
; Related .......: _PDFX_SetFill, _PDFX_SetStroke
; Link ..........: https://www.autoitscript.com/forum/topic/213930-udf-pdfx/
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
; Return _PDFX_ColorStr() would lose @error: it is intercepted before being propagated.
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
		Case "black"
			Return 0x000000
		Case "white"
			Return 0xFFFFFF
		Case "red"
			Return 0xFF0000
		Case "green"
			Return 0x008000
		Case "blue"
			Return 0x0000FF
		Case "gray", "grey"
			Return 0x808080
		Case "lightgray", "lightgrey"
			Return 0xD3D3D3
		Case "navy"
			Return 0x000080
		Case "teal"
			Return 0x008080
		Case "orange"
			Return 0xFFA500
		Case "purple", "violet"
			Return 0x800080
		Case "yellow"
			Return 0xFFFF00
		Case "silver"
			Return 0xC0C0C0
		Case "maroon"
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

#EndRegion - Graphic state ---------------------------------------------------------------------------------------------------------

#Region - Text and encoding -----------------------------------------------------------------------------------------------------
; Text emission, alignment, word wrapping and WinAnsi conversion.

; #FUNCTION# ====================================================================================================================
; Name...........: _PDFX_Text
; Description ...: Writes a line of text.
; Syntax.........: _PDFX_Text(ByRef $oDocument, $fX, $fY, $sText, $iSize = 0)
; Parameters ....: $oDocument - document handle.
;                  $fX        - x coordinate of the start of the text, in points.
;                  $fY        - y coordinate of the TOP of the text, not of the baseline.
;                  $sText     - text to write.
;                  $iSize     - size in points; 0 = current size.
; Return values .: Success      - y coordinate of the top of the next line (1.2 line spacing).
; Author ........: Numeric1
; Modified.......:
; Remarks .......: The text is encoded in WinAnsi; unrepresentable characters become '?'.
; Related .......: _PDFX_TextAlign, _PDFX_TextWrap, _PDFX_SetFont
; Link ..........: https://www.autoitscript.com/forum/topic/213930-udf-pdfx/
; Example .......: Yes
; ===============================================================================================================================
Func _PDFX_Text(ByRef $oDocument, $fX, $fY, $sText, $iSize = 0)
	_PDFX_EmitText($oDocument, $fX, $fY, $sText, $iSize)
	Return $fY + ($iSize > 0 ? $iSize : $oDocument[$__PDFX_DOC_FONTSIZE]) * 1.2
EndFunc   ;==>_PDFX_Text

; #FUNCTION# ====================================================================================================================
; Name...........: _PDFX_TextAlign
; Description ...: Writes a line of text aligned inside a horizontal box.
; Syntax.........: _PDFX_TextAlign(ByRef $oDocument, $fX, $fY, $fWidth, $sText, $sAlign = "L", $iSize = 0)
; Parameters ....: $oDocument - document handle.
;                  $fX        - left edge of the alignment box.
;                  $fY        - y coordinate of the top of the text.
;                  $fWidth    - width of the alignment box, in points.
;                  $sText     - text to write.
;                  $sAlign    - L left (default), C centre, R right.
;                  $iSize     - size in points; 0 = current size.
; Return values .: Success      - y coordinate of the top of the next line (1.2 line spacing).
; Author ........: Numeric1
; Modified.......:
; Remarks .......: For C and R, the real text width is measured from the AFM metrics before placement.
; Related .......: _PDFX_Text, _PDFX_TextWidth
; Link ..........: https://www.autoitscript.com/forum/topic/213930-udf-pdfx/
; Example .......: Yes
; ===============================================================================================================================
Func _PDFX_TextAlign(ByRef $oDocument, $fX, $fY, $fWidth, $sText, $sAlign = "L", $iSize = 0)
	_PDFX_EmitText($oDocument, $fX, $fY, $sText, $iSize, $sAlign, $fWidth)
	Return $fY + ($iSize > 0 ? $iSize : $oDocument[$__PDFX_DOC_FONTSIZE]) * 1.2
EndFunc   ;==>_PDFX_TextAlign

; #FUNCTION# ====================================================================================================================
; Name...........: _PDFX_TextWrap
; Description ...: Writes text over several lines, with automatic word wrapping.
; Syntax.........: _PDFX_TextWrap(ByRef $oDocument, $fX, $fY, $fWidth, $sText, $iSize = 0, $fLeading = 0, $sAlign = "L", $bPageBreak = False)
; Parameters ....: $oDocument  - document handle.
;                  $fX         - left edge of the column.
;                  $fY         - y coordinate of the top of the first line.
;                  $fWidth     - usable width of the column, in points.
;                  $sText      - text to write; carriage returns are honoured.
;                  $iSize      - size in points; 0 = current size.
;                  $fLeading   - line spacing in points; 0 = 1.2 times the size.
;                  $sAlign     - L left (default), C centre, R right.
;                  $bPageBreak - True: adds a page as soon as the bottom margin is reached.
; Return values .: Success      - y coordinate of the top of the first free line.
; Author ........: Numeric1
; Modified.......:
; Remarks .......: Words wider than the column are split character by character; empty paragraphs
;                  are preserved.
; Related .......: _PDFX_Text, _PDFX_TextAlign, _PDFX_Wrap
; Link ..........: https://www.autoitscript.com/forum/topic/213930-udf-pdfx/
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

; Splits text into lines that fit inside $fWidth (honours carriage returns).
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

; Word wider than the column: split it character by character.
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

; PDF string: escape ( ) \ and encode in WinAnsi (octal above 126).
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

; Byte in 3-digit octal notation (AutoIt has no Oct()).
Func _PDFX_Oct3($iByte)
	Return Chr(48 + Int($iByte / 64)) & Chr(48 + Int(Mod($iByte, 64) / 8)) & Chr(48 + Mod($iByte, 8))
EndFunc   ;==>_PDFX_Oct3

; Unicode code point -> WinAnsi byte.
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

#EndRegion - Text and encoding -----------------------------------------------------------------------------------------------------

#Region - Vector shapes ---------------------------------------------------------------------------------------------------------
; Lines, rectangles, ellipses, polygons and Bezier curves.

; #FUNCTION# ====================================================================================================================
; Name...........: _PDFX_Line
; Description ...: Draws a straight line segment.
; Syntax.........: _PDFX_Line(ByRef $oDocument, $fX1, $fY1, $fX2, $fY2)
; Parameters ....: $oDocument - document handle.
;                  $fX1       - x coordinate of the start point.
;                  $fY1       - y coordinate of the start point.
;                  $fX2       - x coordinate of the end point.
;                  $fY2       - y coordinate of the end point.
; Return values .: Success      - True.
; Author ........: Numeric1
; Modified.......:
; Remarks .......: Uses the current stroke colour and line width.
; Related .......: _PDFX_SetStroke, _PDFX_SetLineWidth, _PDFX_SetDash
; Link ..........: https://www.autoitscript.com/forum/topic/213930-udf-pdfx/
; Example .......: Yes
; ===============================================================================================================================
Func _PDFX_Line(ByRef $oDocument, $fX1, $fY1, $fX2, $fY2)
	_PDFX_Op($oDocument, _PDFX_StrokeState($oDocument) & _PDFX_F($fX1) & " " & _PDFX_F(_PDFX_Y($oDocument, $fY1)) & " m " & _
			_PDFX_F($fX2) & " " & _PDFX_F(_PDFX_Y($oDocument, $fY2)) & " l S")
	Return True
EndFunc   ;==>_PDFX_Line

; #FUNCTION# ====================================================================================================================
; Name...........: _PDFX_Rect
; Description ...: Draws a rectangle.
; Syntax.........: _PDFX_Rect(ByRef $oDocument, $fX, $fY, $fWidth, $fHeight, $iStyle = $PDFX_STROKE)
; Parameters ....: $oDocument - document handle.
;                  $fX        - x coordinate of the top-left corner.
;                  $fY        - y coordinate of the top-left corner.
;                  $fWidth    - width, in points.
;                  $fHeight   - height, in points.
;                  $iStyle    - $PDFX_STROKE (default), $PDFX_FILL or $PDFX_BOTH.
; Return values .: Success      - True.
; Author ........: Numeric1
; Modified.......:
; Remarks .......:
; Related .......: _PDFX_Fill, _PDFX_RoundRect, _PDFX_SetFill, _PDFX_SetStroke
; Link ..........: https://www.autoitscript.com/forum/topic/213930-udf-pdfx/
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
; Description ...: Draws a rectangle with rounded corners.
; Syntax.........: _PDFX_RoundRect(ByRef $oDocument, $fX, $fY, $fWidth, $fHeight, $fRadius, $iStyle = $PDFX_STROKE)
; Parameters ....: $oDocument - document handle.
;                  $fX        - x coordinate of the top-left corner.
;                  $fY        - y coordinate of the top-left corner.
;                  $fWidth    - width, in points.
;                  $fHeight   - height, in points.
;                  $fRadius   - corner radius; clamped to half of the shortest side.
;                  $iStyle    - $PDFX_STROKE (default), $PDFX_FILL or $PDFX_BOTH.
; Return values .: Success      - True.
; Author ........: Numeric1
; Modified.......:
; Remarks .......: A zero or negative radius produces an ordinary rectangle.
; Related .......: _PDFX_Rect, _PDFX_Circle
; Link ..........: https://www.autoitscript.com/forum/topic/213930-udf-pdfx/
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
; Description ...: Draws an ellipse defined by its centre and two radii.
; Syntax.........: _PDFX_Ellipse(ByRef $oDocument, $fCenterX, $fCenterY, $fRadiusX, $fRadiusY, $iStyle = $PDFX_STROKE)
; Parameters ....: $oDocument - document handle.
;                  $fCenterX  - x coordinate of the centre.
;                  $fCenterY  - y coordinate of the centre.
;                  $fRadiusX  - horizontal radius, in points.
;                  $fRadiusY  - vertical radius, in points.
;                  $iStyle    - $PDFX_STROKE (default), $PDFX_FILL or $PDFX_BOTH.
; Return values .: Success      - True.
; Author ........: Numeric1
; Modified.......:
; Remarks .......: Four cubic Bezier curves, using the kappa constant 0.5523.
; Related .......: _PDFX_Circle, _PDFX_Bezier
; Link ..........: https://www.autoitscript.com/forum/topic/213930-udf-pdfx/
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
; Description ...: Draws a circle.
; Syntax.........: _PDFX_Circle(ByRef $oDocument, $fCenterX, $fCenterY, $fRadius, $iStyle = $PDFX_STROKE)
; Parameters ....: $oDocument - document handle.
;                  $fCenterX  - x coordinate of the centre.
;                  $fCenterY  - y coordinate of the centre.
;                  $fRadius   - radius, in points.
;                  $iStyle    - $PDFX_STROKE (default), $PDFX_FILL or $PDFX_BOTH.
; Return values .: Success      - True.
; Author ........: Numeric1
; Modified.......:
; Remarks .......:
; Related .......: _PDFX_Ellipse
; Link ..........: https://www.autoitscript.com/forum/topic/213930-udf-pdfx/
; Example .......: Yes
; ===============================================================================================================================
Func _PDFX_Circle(ByRef $oDocument, $fCenterX, $fCenterY, $fRadius, $iStyle = $PDFX_STROKE)
	Return _PDFX_Ellipse($oDocument, $fCenterX, $fCenterY, $fRadius, $fRadius, $iStyle)
EndFunc   ;==>_PDFX_Circle

; #FUNCTION# ====================================================================================================================
; Name...........: _PDFX_Polyline
; Description ...: Draws a polyline or a polygon.
; Syntax.........: _PDFX_Polyline(ByRef $oDocument, $aPoints, $bClose = False, $iStyle = $PDFX_STROKE)
; Parameters ....: $oDocument - document handle.
;                  $aPoints   - [n][2] array of vertices: $aPoints[i][0] = x, $aPoints[i][1] = y.
;                  $bClose    - True closes the path (polygon).
;                  $iStyle    - $PDFX_STROKE (default), $PDFX_FILL or $PDFX_BOTH.
; Return values .: Success      - True.
;                  Failure      - False if the array holds fewer than two vertices.
; Author ........: Numeric1
; Modified.......:
; Remarks .......:
; Related .......: _PDFX_Line, _PDFX_Bezier
; Link ..........: https://www.autoitscript.com/forum/topic/213930-udf-pdfx/
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
; Description ...: Draws a cubic Bezier curve.
; Syntax.........: _PDFX_Bezier(ByRef $oDocument, $fX1, $fY1, $fControl1X, $fControl1Y, $fControl2X, $fControl2Y, $fX2, $fY2, $iStyle = $PDFX_STROKE)
; Parameters ....: $oDocument  - document handle.
;                  $fX1        - x coordinate of the start point.
;                  $fY1        - y coordinate of the start point.
;                  $fControl1X - x coordinate of the first control point.
;                  $fControl1Y - y coordinate of the first control point.
;                  $fControl2X - x coordinate of the second control point.
;                  $fControl2Y - y coordinate of the second control point.
;                  $fX2        - x coordinate of the end point.
;                  $fY2        - y coordinate of the end point.
;                  $iStyle     - $PDFX_STROKE (default), $PDFX_FILL or $PDFX_BOTH.
; Return values .: Success      - True.
; Author ........: Numeric1
; Modified.......:
; Remarks .......:
; Related .......: _PDFX_Polyline, _PDFX_Ellipse
; Link ..........: https://www.autoitscript.com/forum/topic/213930-udf-pdfx/
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

; Stroke colour + line width.
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

; y coordinate (top -> bottom) to PDF space (bottom -> top).
Func _PDFX_Y($oDocument, $fY)
	Return $oDocument[$__PDFX_DOC_HEIGHT] - $fY
EndFunc   ;==>_PDFX_Y

#EndRegion - Vector shapes ---------------------------------------------------------------------------------------------------------

#Region - Images ----------------------------------------------------------------------------------------------------------------
; Insertion, scaling and conversion of images.

; #FUNCTION# ====================================================================================================================
; Name...........: _PDFX_Image
; Description ...: Inserts a JPEG, PNG, BMP or GIF image.
; Syntax.........: _PDFX_Image(ByRef $oDocument, $sPath, $fX, $fY, $fWidth = 0, $fHeight = 0)
; Parameters ....: $oDocument - document handle.
;                  $sPath     - path of the image file.
;                  $fX        - x coordinate of the top-left corner.
;                  $fY        - y coordinate of the top-left corner.
;                  $fWidth    - width in points; 0 = natural size at 96 dpi.
;                  $fHeight   - height in points; 0 = proportions preserved.
; Return values .: Success      - True.
;                  Failure      - False with @error = 1 if the file is missing, 2 if the image cannot be read.
; Author ........: Numeric1
; Modified.......:
; Remarks .......: JPEG files are embedded byte for byte, without recompression. Other formats go through GDI+
;                  and are flattened onto white. An image already used is stored only once per document.
; Related .......: _PDFX_ImageFit, _PDFX_ImageInfo
; Link ..........: https://www.autoitscript.com/forum/topic/213930-udf-pdfx/
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
; Description ...: Inserts an image scaled down to fit entirely inside a box, proportions preserved.
; Syntax.........: _PDFX_ImageFit(ByRef $oDocument, $sPath, $fX, $fY, $fWidth, $fHeight, $sAlign = "C")
; Parameters ....: $oDocument - document handle.
;                  $sPath     - path of the image file.
;                  $fX        - x coordinate of the containing box.
;                  $fY        - y coordinate of the containing box.
;                  $fWidth    - width of the box, in points.
;                  $fHeight   - height of the box, in points.
;                  $sAlign    - C centre (default), or a combination of L, R, T, B.
; Return values .: Success      - True.
;                  Failure      - False with @error = 2 or 3 if the image is unreadable or empty.
; Author ........: Numeric1
; Modified.......:
; Remarks .......: No distortion: the image is scaled by the limiting side, then positioned in the box.
; Related .......: _PDFX_Image, _PDFX_ImageInfo
; Link ..........: https://www.autoitscript.com/forum/topic/213930-udf-pdfx/
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
; Description ...: Returns the characteristics of an image and registers it in the document.
; Syntax.........: _PDFX_ImageInfo(ByRef $oDocument, $sPath)
; Parameters ....: $oDocument - document handle.
;                  $sPath     - path of the image file.
; Return values .: Success      - 6-element array: 0 width in pixels, 1 height in pixels, 2 width in
;                                  points at 96 dpi, 3 height in points, 4 file size in bytes, 5 extension in
;                                  upper case.
;                  Failure      - 0 with @error = 1 or 2.
; Author ........: Numeric1
; Modified.......:
; Remarks .......: The image is added to the PDF resources, whether it is drawn afterwards or not.
; Related .......: _PDFX_Image, _PDFX_ImageFit
; Link ..........: https://www.autoitscript.com/forum/topic/213930-udf-pdfx/
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
; Adobe stores CMYK values inverted; without APP14, the PDF order is respected.
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

; Returning a row of a 2D array directly is a fatal AutoIt error:
; a 1D copy is returned instead.
Func _PDFX_ImageRow($aImages, $iIndex)
	Local $aRow[5] = [$aImages[$iIndex][0], $aImages[$iIndex][1], $aImages[$iIndex][2], $aImages[$iIndex][3], $aImages[$iIndex][4]]
	Return $aRow
EndFunc   ;==>_PDFX_ImageRow

; Asc() on binary reads the "0x.." string, not the byte: Number() is required.
Func _PDFX_ByteAt($bData, $iPos)
	Return Number(BinaryMid($bData, $iPos, 1))
EndFunc   ;==>_PDFX_ByteAt

; Reads the JPEG geometry and flags CMYK files written by Adobe (APP14 marker).
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

; Converts any GDI+ format (PNG, BMP, GIF, TIFF...) to JPEG on a white background.
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

#EndRegion - Images ----------------------------------------------------------------------------------------------------------------

#Region - Tables ----------------------------------------------------------------------------------------------------------------
; Paginated tables with repeated header, zebra stripes and grid.

; #FUNCTION# ====================================================================================================================
; Name...........: _PDFX_Table
; Description ...: Draws a paginated table with repeated header and grid.
; Syntax.........: _PDFX_Table(ByRef $oDocument, $fX, $fY, $fWidth, $aColumns, $aRows, $sOptions = "")
; Parameters ....: $oDocument - document handle.
;                  $fX        - x coordinate of the top-left corner.
;                  $fY        - y coordinate of the top-left corner.
;                  $fWidth    - total table width, in points.
;                  $aColumns  - [n][2 or 3] array: 0 title, 1 width fraction, 2 L/C/R alignment.
;                  $aRows     - [n][m] array of cells; any value is converted to a string.
;                  $sOptions  - semicolon-separated options, detailed under Remarks.
; Return values .: Success      - y coordinate of the bottom of the table, ready for the following content.
;                  Failure      - $fY unchanged, @error = 1 when the rows are narrower than the columns.
; Author ........: Numeric1
; Modified.......:
; Remarks .......: Options: padding=4, fontsize=0 (current size), border=0.5, bordercolor=0xBFC9D9,
;                  headfill=0xE8EEF7, headcolor=0x1F3864, zebra=0, zebracolor=0xF7F9FC,
;                  textcolor=0x000000, pagebreak=1. headfill=-1 removes the header row background.
;                  With pagebreak=1, the header is redrawn at the top of every new page.
; Related .......: _PDFX_TextWrap, _PDFX_Line, _PDFX_AddPage
; Link ..........: https://www.autoitscript.com/forum/topic/213930-udf-pdfx/
; Example .......: Yes
; ===============================================================================================================================
Func _PDFX_Table(ByRef $oDocument, $fX, $fY, $fWidth, $aColumns, $aRows, $sOptions = "")
	Local $iColumnCount = UBound($aColumns, 1)
	If $iColumnCount < 1 Then Return $fY
	If UBound($aRows, 2) > 0 And UBound($aRows, 2) < $iColumnCount Then Return SetError(1, 0, $fY)
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

; Column widths and alignments
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

; Header row in the same format as a data row
	Local $aHeaderRow[1][$iColumnCount]
	For $iColumn = 0 To $iColumnCount - 1
		$aHeaderRow[0][$iColumn] = String($aColumns[$iColumn][0])
	Next

; Save the typographic state
	Local $iPreviousFont = $oDocument[$__PDFX_DOC_FONT]
	Local $fPreviousSize = $oDocument[$__PDFX_DOC_FONTSIZE]
	Local $sPreviousFill = $oDocument[$__PDFX_DOC_FILL]
	Local $sPreviousStroke = $oDocument[$__PDFX_DOC_STROKE]
	Local $fPreviousLineWidth = $oDocument[$__PDFX_DOC_LINEWIDTH]

	Local $iHeaderFont = _PDFX_EnsureFont($oDocument, _PDFX_Font($oDocument), "B")

	Local $iRowCount = UBound($aRows, 1)

; Header
	Local $fHeaderHeight = _PDFX_TableRowHeight($oDocument, $aHeaderRow, $aColumnWidths, $fPadding, $fLineHeight, $fFontSize, $iHeaderFont)
	$fY = _PDFX_TableDrawRow($oDocument, $fX, $fY, $aColumnWidths, $aHeaderRow, $aAlignments, $fPadding, $fLineHeight, $fFontSize, $iHeaderFont, $vHeadFill, $vHeadColor)
	$fY = _PDFX_TableDrawLines($oDocument, $fX, $fY - $fHeaderHeight, $fWidth, $aColumnWidths, $fHeaderHeight, $fBorder, $vBorderColor)

; Rows
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

; Restore
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

; Draws one row (background + texts) and returns the bottom of the row.
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

#EndRegion - Tables ----------------------------------------------------------------------------------------------------------------

#Region - Links, metadata, header and footer ------------------------------------------------------------------------------------
; Link annotations, /Info dictionary, page header and footer.

; #FUNCTION# ====================================================================================================================
; Name...........: _PDFX_Link
; Description ...: Adds a clickable hypertext link.
; Syntax.........: _PDFX_Link(ByRef $oDocument, $fX, $fY, $fWidth, $fHeight, $sUrl)
; Parameters ....: $oDocument - document handle.
;                  $fX        - x coordinate of the top-left corner of the area.
;                  $fY        - y coordinate of the top-left corner of the area.
;                  $fWidth    - width of the clickable area, in points.
;                  $fHeight   - height of the clickable area, in points.
;                  $sUrl      - full address, for example https://www.autoitscript.com/forum/.
; Return values .: Success      - True.
;                  Failure      - False if no page is open.
; Author ........: Numeric1
; Modified.......:
; Remarks .......: The link is an invisible /Link annotation (/Border [0 0 0]): it does not alter the rendering.
; Related .......: _PDFX_Text, _PDFX_Save
; Link ..........: https://www.autoitscript.com/forum/topic/213930-udf-pdfx/
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
; Description ...: Adds an internal link to another page of the document.
; Syntax.........: _PDFX_LinkPage(ByRef $oDocument, $fX, $fY, $fWidth, $fHeight, $iPage, $fYTarget = -1)
; Parameters ....: $oDocument - document handle.
;                  $fX        - x coordinate of the top-left corner of the clickable area.
;                  $fY        - y coordinate of the top-left corner of the area.
;                  $fWidth    - width of the area, in points.
;                  $fHeight   - height of the area, in points.
;                  $iPage     - target page, numbered from 1. It may not exist yet:
;                               the link is resolved at save time and dropped if the page
;                               was never created.
;                  $fYTarget  - arrival y coordinate, in points from the top of the target page;
;                               -1 (default) frames the whole page (/Fit).
; Return values .: Success      - True.
;                  Failure      - False with @error = 1 if no page is open or if $iPage
;                                 is less than 1, 2 if the document has already been saved.
; Author ........: Numeric1
; Modified.......:
; Remarks .......: The /Link annotation is invisible (/Border [0 0 0]). The destination is written as
;                  /Dest rather than a /URI action: the link remains valid offline and after
;                  a reader reorganises the document. The annotation is created only at
;                  save time, which allows linking a table of contents to chapters written
;                  later.
; Related .......: _PDFX_Link, _PDFX_AddBookmark, _PDFX_Save
; Link ..........: https://www.autoitscript.com/forum/topic/213930-udf-pdfx/
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
; Description ...: Adds an entry to the document outline (/Outlines tree).
; Syntax.........: _PDFX_AddBookmark(ByRef $oDocument, $sTitle, $iLevel = 0, $iPage = -1, $fY = -1)
; Parameters ....: $oDocument - document handle.
;                  $sTitle    - label shown in the navigation pane.
;                  $iLevel    - depth, 0 for a root entry. A level can only go down
;                               one step at a time: any deeper value is clamped to
;                               previous level + 1, and a negative value to 0.
;                  $iPage     - target page, numbered from 1; -1 (default) = current page.
;                  $fY        - arrival y coordinate, in points from the top of the target page;
;                               -1 (default) frames the whole page (/Fit).
; Return values .: Success      - bookmark number (starting at 1).
;                  Failure      - -1 with @error = 1 if the title is empty or the page does not exist,
;                                 2 if the document has already been saved.
; Author ........: Numeric1
; Modified.......:
; Remarks .......: Bookmarks are assembled at save time: insertion order becomes reading
;                  order, each entry receives /Parent, /Prev, /Next, /First, /Last and a
;                  /Count (number of descendants). The pane opens by default as soon as a bookmark
;                  exists, unless _PDFX_SetPageMode() imposes another mode. Non-ASCII titles
;                  are written in UTF-16BE, like the metadata.
; Related .......: _PDFX_SetPageMode, _PDFX_LinkPage, _PDFX_Save
; Link ..........: https://www.autoitscript.com/forum/topic/213930-udf-pdfx/
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
; Description ...: Chooses the panel displayed when the document opens.
; Syntax.........: _PDFX_SetPageMode(ByRef $oDocument, $sMode = "UseOutlines")
; Parameters ....: $oDocument - document handle.
;                  $sMode     - UseNone, UseOutlines (bookmarks), UseThumbs (thumbnails), FullScreen, or
;                               an empty string to return to the automatic behaviour (bookmarks
;                               open if the document has any). Case is ignored.
; Return values .: Success      - True.
;                  Failure      - False with @error = 1 if the mode is unknown, 2 if the document
;                                 has already been saved.
; Author ........: Numeric1
; Modified.......:
; Remarks .......: The choice is written in the /PageMode key of the catalog. Readers remain
;                  free to ignore it (for example in full-screen mode).
; Related .......: _PDFX_AddBookmark, _PDFX_SetPageLayout
; Link ..........: https://www.autoitscript.com/forum/topic/213930-udf-pdfx/
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
; Description ...: Chooses the page layout when the document opens.
; Syntax.........: _PDFX_SetPageLayout(ByRef $oDocument, $sLayout)
; Parameters ....: $oDocument - document handle.
;                  $sLayout   - SinglePage, OneColumn, TwoColumnLeft, TwoColumnRight, TwoPageLeft,
;                               TwoPageRight, or an empty string to impose nothing. Case is
;                               ignored.
; Return values .: Success      - True.
;                  Failure      - False with @error = 1 if the layout is unknown, 2 if the
;                                 document has already been saved.
; Author ........: Numeric1
; Modified.......:
; Remarks .......: The choice is written in the /PageLayout key of the catalog. It remains a hint:
;                  the reader may apply its own preference.
; Related .......: _PDFX_SetPageMode
; Link ..........: https://www.autoitscript.com/forum/topic/213930-udf-pdfx/
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
; Description ...: Fills in the document metadata.
; Syntax.........: _PDFX_SetMeta(ByRef $oDocument, $sTitle = "", $sAuthor = "", $sSubject = "", $sKeywords = "")
; Parameters ....: $oDocument - document handle.
;                  $sTitle    - document title.
;                  $sAuthor   - author.
;                  $sSubject  - subject.
;                  $sKeywords - keywords, separated by commas.
; Return values .: Success      - True.
; Author ........: Numeric1
; Modified.......:
; Remarks .......: Values are written into the /Info dictionary during _PDFX_Save(). An empty string keeps
;                  the previous value; producer and creation date are added automatically.
; Related .......: _PDFX_Save
; Link ..........: https://www.autoitscript.com/forum/topic/213930-udf-pdfx/
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
; Description ...: Defines the header applied to every page.
; Syntax.........: _PDFX_SetHeader(ByRef $oDocument, $sLeft = "", $sCenter = "", $sRight = "", $iSize = 8, _
;                  $sFont = "", $sStyle = "", $vColor = -1)
; Parameters ....: $oDocument - document handle.
;                  $sLeft     - text of the left area; tokens {page}, {pages} and {date} accepted.
;                  $sCenter   - text of the centre area.
;                  $sRight    - text of the right area.
;                  $iSize     - font size; a value less than or equal to 0 keeps the current value.
;                               The size is shared by the header and the footer.
;                  $sFont     - font family; an empty string keeps the current value (Helvetica).
;                  $sStyle    - style: combination of B (bold) and I (italic); an empty string restores normal style.
;                  $vColor    - colour of the text and rule: 0xRRGGBB, "name" or array [R, G, B]; -1 keeps the
;                               current colour.
; Return values .: Success      - True.
;                  Failure      - True with @error = 1 if a colour component was clamped into [0, 255].
; Author ........: Numeric1
; Modified.......:
; Remarks .......: The header is inserted during _PDFX_Save(), on every page, followed by a separating rule.
;                  An empty area is ignored; three empty areas remove the header.
; Related .......: _PDFX_SetFooter, _PDFX_Save
; Link ..........: https://www.autoitscript.com/forum/topic/213930-udf-pdfx/
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
; Description ...: Defines the footer applied to every page.
; Syntax.........: _PDFX_SetFooter(ByRef $oDocument, $sLeft = "", $sCenter = "", $sRight = "", $iSize = 8, _
;                  $sFont = "", $sStyle = "", $vColor = -1)
; Parameters ....: $oDocument - document handle.
;                  $sLeft     - text of the left area; tokens {page}, {pages} and {date} accepted.
;                  $sCenter   - text of the centre area.
;                  $sRight    - text of the right area.
;                  $iSize     - font size; a value less than or equal to 0 keeps the current value.
;                               The size is shared by the header and the footer.
;                  $sFont     - font family; an empty string keeps the current value (Helvetica).
;                  $sStyle    - style: combination of B (bold) and I (italic); an empty string restores normal style.
;                  $vColor    - text colour: 0xRRGGBB, "name" or array [R, G, B]; -1 keeps the current colour.
; Return values .: Success      - True.
;                  Failure      - True with @error = 1 if a colour component was clamped into [0, 255].
; Author ........: Numeric1
; Modified.......:
; Remarks .......: The footer sits on the bottom margin of the document. Pagination example:
;                  _PDFX_SetFooter($oDocument, '', 'Page {page} / {pages}', '{date}').
; Related .......: _PDFX_SetHeader, _PDFX_Save
; Link ..........: https://www.autoitscript.com/forum/topic/213930-udf-pdfx/
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

; Header
		If $aHeaderFooter[0] <> "" Or $aHeaderFooter[1] <> "" Or $aHeaderFooter[2] <> "" Then
			$sAddition &= _PDFX_HfLine($oDocument, $aHeaderFooter, 0, $fDocumentMargin, $fPageWidth, $fPageHeight, $fFontSize, $iHeaderFont, $aHeaderFooter[7], $iPage + 1, $iPageCount)
			$sAddition &= _PDFX_StrokeOp($aHeaderFooter[7], 0.5, $fDocumentMargin, $fDocumentMargin + $fLineHeight + 3, $fPageWidth - $fDocumentMargin, $fDocumentMargin + $fLineHeight + 3, $fPageHeight)
		EndIf

; Footer (the text sits $fDocumentMargin above the bottom edge)
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

; $iSlotBase: 0 = header, 3 = footer
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

#EndRegion - Links, metadata, header and footer ------------------------------------------------------------------------------------

#Region - Writing the PDF file --------------------------------------------------------------------------------------------------
; Object serialisation, xref table, trailer and startxref.

; #FUNCTION# ====================================================================================================================
; Name...........: _PDFX_SetCompression
; Description ...: Enables FlateDecode compression for content streams.
; Syntax.........: _PDFX_SetCompression(ByRef $oDocument, $iLevel = 6)
; Parameters ....: $oDocument - document handle.
;                  $iLevel    - level from 0 to 9: 0 leaves streams uncompressed (default), 1 compresses fastest,
;                               9 searches the most distant repetitions. 6 is a good compromise.
; Return values .: Success      - True.
;                  Failure      - True with @error = 1 if the level was clamped into [0, 9];
;                                 False with @error = 2 if the document has already been saved.
; Author ........: Numeric1
; Modified.......:
; Remarks .......: Compression is applied at save time, page by page: each content stream is
;                  compressed with zlib (RFC 1950) over DEFLATE (RFC 1951) and prefixed with /Filter /FlateDecode.
;                  A stream that gains nothing (very short, or already dense) is written uncompressed: the
;                  choice is automatic. The code is self-contained, with no DLL and no COM; expect about
;                  30 KB/s, against several MB/s for zlib in C. Page rendering is identical; only the file size changes.
; Related .......: _PDFX_Save
; Link ..........: https://www.autoitscript.com/forum/topic/213930-udf-pdfx/
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
; Description ...: Writes the document as PDF 1.7.
; Syntax.........: _PDFX_Save(ByRef $oDocument, $sFile)
; Parameters ....: $oDocument - document handle.
;                  $sFile     - path of the destination file.
; Return values .: Success      - True.
;                  Failure      - False with @error = 1 if the file cannot be created;
;                                 False with @error = 2 if the document has already been saved.
; Author ........: Numeric1
; Modified.......:
; Remarks .......: Freezes the current page, applies the header and footer, then serialises the objects, the xref
;                  table, the trailer and startxref. The produced file is self-contained and conforms to ISO 32000-1.
;                  A document is written only once: after a successful save, _PDFX_AddPage() and a second
;                  _PDFX_Save() return @error = 2. Dates are in universal time (Z suffix), non-ASCII strings of
;                  /Info are written in UTF-16BE, and /ID is a deterministic MD5 fingerprint of the content.
; Related .......: _PDFX_New, _PDFX_SetMeta, _PDFX_Close
; Link ..........: https://www.autoitscript.com/forum/topic/213930-udf-pdfx/
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

; Page tree (object 2)
	Local $aPageTreeObjects = $oDocument[$__PDFX_DOC_OBJECTS]
	$aPageTreeObjects[2] = "<< /Type /Pages /Count " & $iPageCount & " /Kids [" & StringStripWS($sPageReferences, 2) & "] >>"
	$oDocument[$__PDFX_DOC_OBJECTS] = $aPageTreeObjects

; Navigation: internal link destinations, outline, opening mode.
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
$sInfoBody &= " /Producer " & _PDFX_TextString("PDFX " & $PDFX_VERSION & " for AutoIt")
	$sInfoBody &= " /CreationDate (D:" & $sUtcDate & ") /ModDate (D:" & $sUtcDate & ") >>"
	Local $iInfoObject = _PDFX_AddObject($oDocument, $sInfoBody)

; Document identifier: fingerprint of content and metadata, therefore reproducible.
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

; Assembly: compute offsets, then write
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

; PDF destination to a page: whole page (/Fit) or precise point (/XYZ).
Func _PDFX_PageDestination($fPageHeight, $iPageObject, $fYTop)
	If $fYTop < 0 Then Return "[" & $iPageObject & " 0 R /Fit]"
	Local $fY = $fPageHeight - $fYTop
	If $fY < 0 Then $fY = 0
	If $fY > $fPageHeight Then $fY = $fPageHeight
	Return "[" & $iPageObject & " 0 R /XYZ 0 " & _PDFX_F($fY) & " null]"
EndFunc   ;==>_PDFX_PageDestination

; Creates internal annotations before the pages, so /Annots can reference them as soon as they are written.
Func _PDFX_PreparePageLinks(ByRef $oDocument, ByRef $aPages, $iPageCount)
	Local $aLinks = $oDocument[$__PDFX_DOC_PAGELINKS]
	If UBound($aLinks) = 0 Then Return
	Local $aObjects = $aLinks
	For $iIndex = 0 To UBound($aLinks) - 1
; Column 0: source page before preparation, annotation object afterwards.
; The value 0 marks an abandoned link, which _PDFX_PatchPageLinks ignores.
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

; Completes the internal annotations: their target page is only known after the pages are created.
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

; /Outlines tree: First/Last chains, Parent/Prev/Next links and /Count of descendants.
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
; Description ...: Releases the engine resources for this document.
; Syntax.........: _PDFX_Close(ByRef $oDocument)
; Parameters ....: $oDocument - document handle.
; Return values .: Success      - True.
; Author ........: Numeric1
; Modified.......:
; Remarks .......: Shuts GDI+ down if the engine started it. Call it after _PDFX_Save(); the handle is not
;                  used afterwards.
; Related .......: _PDFX_Save
; Link ..........: https://www.autoitscript.com/forum/topic/213930-udf-pdfx/
; Example .......: Yes
; ===============================================================================================================================
Func _PDFX_Close(ByRef $oDocument)
	#forceref $oDocument
	If $__PDFX_GdiPlusLoaded And $__PDFX_GdiPlusOwned Then _GDIPlus_Shutdown()
	$__PDFX_GdiPlusLoaded = False
	$__PDFX_GdiPlusOwned = False
	Return True
EndFunc   ;==>_PDFX_Close

#EndRegion - Writing the PDF file --------------------------------------------------------------------------------------------------

#Region - Internal utilities --------------------------------------------------------------------------------------------------
; Low-level helpers shared by the engine.

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

; Clamps a numeric value and reports any overflow with @error = 1.
Func _PDFX_Clamp($vValue, $fMinimum, $fMaximum)
	Local $fValue = Number($vValue)
	If $fValue < $fMinimum Then Return SetError(1, 0, $fMinimum)
	If $fValue > $fMaximum Then Return SetError(1, 0, $fMaximum)
	Return $fValue
EndFunc   ;==>_PDFX_Clamp

; Compact real-number format for the PDF content stream.
Func _PDFX_F($vNumber)
	Local $sNumber = StringFormat("%.3f", $vNumber)
	While StringRight($sNumber, 1) = "0" And StringLen($sNumber) > 1
		$sNumber = StringLeft($sNumber, StringLen($sNumber) - 1)
	WEnd
	If StringRight($sNumber, 1) = "." Then $sNumber = StringLeft($sNumber, StringLen($sNumber) - 1)
	If $sNumber = "-0" Then $sNumber = "0"
	Return $sNumber
EndFunc   ;==>_PDFX_F

; MD5 fingerprint of a string, as 32 uppercase hex characters.
Func _PDFX_HashHex($sData)
	Local $bHash = _Crypt_HashData($sData, $CALG_MD5)
	If Not IsBinary($bHash) Then Return ""
	Local $sHex = ""
	For $iByte = 1 To BinaryLen($bHash)
		$sHex &= StringUpper(Hex(_PDFX_ByteAt($bHash, $iByte), 2))
	Next
	Return $sHex
EndFunc   ;==>_PDFX_HashHex

; True when every character is printable ASCII.
Func _PDFX_IsAscii($sText)
	For $iChar = 1 To StringLen($sText)
		Local $iCode = AscW(StringMid($sText, $iChar, 1))
		If $iCode < 32 Or $iCode > 126 Then Return False
	Next
	Return True
EndFunc   ;==>_PDFX_IsAscii

; PDF text value: literal string for ASCII, UTF-16BE hexadecimal otherwise.
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

; PDF timestamp in universal time: D:YYYYMMDDHHMMSSZ.
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

; Parses "key=value;key=value"; returns $vDefault when the key is absent.
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
; DEFLATE compressor (RFC 1951) and zlib wrapper (RFC 1950).
;
; Fixed Huffman coding: the block only carries type-01 codes, which avoids writing a dynamic tree and makes
; the output strictly deterministic. Match search is a three-byte hash with a chain bounded by the requested
; level. The bit writer produces the hexadecimal string directly; it is converted to binary once the stream
; is complete.

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

; Huffman codes are read from the most significant bit to the least significant, whereas _PDFX_ZlibPut()
; writes from the least significant to the most significant: every code is therefore reversed once and for all.
Func _PDFX_ZlibReverseBits($iValue, $iBits)
	Local $iResult = 0, $iBit
	For $iBit = 0 To $iBits - 1
		$iResult = BitShift($iResult, -1)
		If BitAND($iValue, BitShift(1, -$iBit)) Then $iResult = BitOR($iResult, 1)
	Next
	Return $iResult
EndFunc   ;==>_PDFX_ZlibReverseBits

; Writer state: [0] pending bits, [1] number of pending bits, [2] bytes already produced, in hexadecimal.
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

; Compresses an ASCII string with zlib and returns binary ready for /FlateDecode.
; $iDepth bounds the candidates examined per position; 0 is reserved for raw streams and never reaches here.
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

; zlib header: deflate, 32 KB window, default level; 0x789C is the recommended pair.
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

; Adler-32 of the original bytes, complementing the zlib checksum.
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

#EndRegion - Internal utilities --------------------------------------------------------------------------------------------------
