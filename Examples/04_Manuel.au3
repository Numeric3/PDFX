#cs ----------------------------------------------------------------------------
    04_Manuel — demonstration PDFX : signets, sommaire cliquable, mode d'ouverture.

    Le sommaire est ecrit avant les chapitres : ses liens visent des pages qui
    n'existent pas encore. PDFX resout ces destinations au moment de
    l'enregistrement, quand les numeros d'objets des pages sont connus.
#ce ----------------------------------------------------------------------------

#include "../PDFX.au3"

Global $sOut = @ScriptDir & "\04_Manuel.pdf"
Global $oDocument = _PDFX_New("A4", "P", 18)

_PDFX_SetMeta($oDocument, "Manuel PDFX — navigation", "Numeric1", _
    "Signets hierarchiques, liens internes et mode d'ouverture", "pdf;autoit;signets")
_PDFX_SetCompression($oDocument, 6)
_PDFX_SetHeader($oDocument, "PDFX", "Manuel de navigation", "{date}")
_PDFX_SetFooter($oDocument, "Genere par AutoIt", "", "{page} / {pages}")
_PDFX_SetPageMode($oDocument, "UseOutlines")
_PDFX_SetPageLayout($oDocument, "SinglePage")

Global Const $COLOR_DARK = 0x1F3864
Global Const $COLOR_ACCENT = 0x2E75B6
Global Const $COLOR_TEXT = 0x333333
Global Const $COLOR_MUTED = 0x6A7690
Global Const $COLOR_RULE = 0xDDE3EF

; ================================================================== couverture
_PDFX_SetFill($oDocument, $COLOR_DARK)
_PDFX_Rect($oDocument, 0, 0, _PDFX_PageWidth($oDocument), _PDFX_Mm(80), $PDFX_FILL)

_PDFX_SetFill($oDocument, "white")
_PDFX_SetFont($oDocument, "Helvetica", 34, "B")
_PDFX_Text($oDocument, _PDFX_Mm(18), _PDFX_Mm(30), "Manuel PDFX")
_PDFX_SetFont($oDocument, "Helvetica", 14)
_PDFX_Text($oDocument, _PDFX_Mm(18), _PDFX_Mm(46), "Navigation : signets, liens internes et mode d'ouverture")

_PDFX_SetFill($oDocument, $COLOR_TEXT)
_PDFX_SetFont($oDocument, "Helvetica", 11)
_PDFX_TextWrap($oDocument, _PDFX_Mm(18), _PDFX_Mm(100), _PDFX_PageWidth($oDocument) - _PDFX_Mm(36), _
    "Un PDF ne se contente pas d'afficher des pages : il porte aussi sa propre table des matieres. " & _
    "Les signets apparaissent dans le volet de navigation du lecteur, et les liens internes " & _
    "permettent d'aller d'un sommaire a un chapitre sans quitter le document. " & _
    "Ce manuel est produit par le moteur qu'il decrit : chaque titre ci-dessous existe " & _
    "aussi comme signet, et chaque ligne du sommaire est une zone cliquable.")

_PDFX_SetFill($oDocument, $COLOR_MUTED)
_PDFX_SetFont($oDocument, "Helvetica", 9)
_PDFX_Text($oDocument, _PDFX_Mm(18), _PDFX_Mm(150), "Auteur : Numeric1 — https://www.autoitscript.com/forum/")
_PDFX_Text($oDocument, _PDFX_Mm(18), _PDFX_Mm(156), "Aucune dependance : ni COM, ni DLL tierce, ni fichier temporaire.")

_PDFX_AddBookmark($oDocument, "Couverture", 0, 1)

; ================================================================== sommaire
_PDFX_AddPage($oDocument)
_PDFX_SetFill($oDocument, $COLOR_DARK)
_PDFX_SetFont($oDocument, "Helvetica", 24, "B")
_PDFX_Text($oDocument, _PDFX_Mm(18), _PDFX_Mm(24), "Sommaire")

_PDFX_SetStroke($oDocument, $COLOR_RULE)
_PDFX_SetLineWidth($oDocument, 0.5)

Global $aToc[5][3] = [ _
    ["Prise en main", 3, "Creer un document, choisir le format, ajouter du texte"], _
    ["Premier document", 4, "En-tete, pied de page et premier enregistrement"], _
    ["Signets", 5, "Hierarchie, niveaux et destinations"], _
    ["Liens internes", 6, "Sommaire cliquable et liens vers une page future"], _
    ["Colophon", 7, "Version du moteur et references"]]

Global $fTocX = _PDFX_Mm(18)
Global $fTocWidth = _PDFX_PageWidth($oDocument) - _PDFX_Mm(36)
Global $fTocY = _PDFX_Mm(48)

For $iIndex = 0 To UBound($aToc) - 1
    _PDFX_SetFill($oDocument, $COLOR_DARK)
    _PDFX_SetFont($oDocument, "Helvetica", 12, "B")
    _PDFX_Text($oDocument, $fTocX, $fTocY, $aToc[$iIndex][0])
    _PDFX_SetFill($oDocument, $COLOR_ACCENT)
    _PDFX_SetFont($oDocument, "Helvetica", 12)
    _PDFX_TextAlign($oDocument, $fTocX, $fTocY, $fTocWidth, String($aToc[$iIndex][1]), "R")
    _PDFX_SetFill($oDocument, $COLOR_MUTED)
    _PDFX_SetFont($oDocument, "Helvetica", 9)
    _PDFX_Text($oDocument, $fTocX, $fTocY + 14, $aToc[$iIndex][2])

    ; Ligne de conduite et zone cliquable sur toute la largeur utile.
    _PDFX_Line($oDocument, $fTocX, $fTocY + 26, $fTocX + $fTocWidth, $fTocY + 26)
    _PDFX_LinkPage($oDocument, $fTocX, $fTocY - 2, $fTocWidth, 28, $aToc[$iIndex][1], _PDFX_Mm(24))

    $fTocY += _PDFX_Mm(28)
Next

_PDFX_AddBookmark($oDocument, "Sommaire", 0, 2, _PDFX_Mm(24))

; ================================================================== prise en main
_PDFX_AddPage($oDocument)
_PDFX_SetFill($oDocument, $COLOR_ACCENT)
_PDFX_SetFont($oDocument, "Helvetica", 9, "B")
_PDFX_Text($oDocument, _PDFX_Mm(18), _PDFX_Mm(24), "CHAPITRE 1")
_PDFX_SetFill($oDocument, $COLOR_DARK)
_PDFX_SetFont($oDocument, "Helvetica", 20, "B")
_PDFX_Text($oDocument, _PDFX_Mm(18), _PDFX_Mm(32), "Prise en main")

_PDFX_SetFill($oDocument, $COLOR_TEXT)
_PDFX_SetFont($oDocument, "Helvetica", 10)
_PDFX_TextWrap($oDocument, _PDFX_Mm(18), _PDFX_Mm(50), $fTocWidth, _
    "Trois appels suffisent pour obtenir un PDF valide : _PDFX_New cree le document, " & _
    "les fonctions de dessin remplissent les pages, _PDFX_Save ecrit le fichier. " & _
    "Le handle renvoye par _PDFX_New porte tout l'etat : polices, couleurs, marges, " & _
    "signets et liens. Aucune variable globale n'est necessaire dans le script appelant.")

_PDFX_SetFill($oDocument, $COLOR_DARK)
_PDFX_SetFont($oDocument, "Helvetica", 14, "B")
_PDFX_Text($oDocument, _PDFX_Mm(18), _PDFX_Mm(120), "Installation")

_PDFX_SetFill($oDocument, $COLOR_TEXT)
_PDFX_SetFont($oDocument, "Helvetica", 10)
_PDFX_TextWrap($oDocument, _PDFX_Mm(18), _PDFX_Mm(130), $fTocWidth, _
    "1. Copier PDFX.au3 a cote de votre script." & @CRLF & _
    "2. Ajouter #include ""PDFX.au3"" en tete." & @CRLF & _
    "3. Appeler _PDFX_New, dessiner, puis _PDFX_Save." & @CRLF & _
    "4. Verifier le fichier avec Tools/pdfcheck.py si besoin.")

_PDFX_SetFill($oDocument, $COLOR_MUTED)
_PDFX_SetFont($oDocument, "Helvetica", 9)
_PDFX_Text($oDocument, _PDFX_Mm(18), _PDFX_Mm(210), _
    "Aucun enregistrement n'est necessaire : le moteur ecrit directement le PDF.")

_PDFX_AddBookmark($oDocument, "Prise en main", 0, 3, _PDFX_Mm(32))
_PDFX_AddBookmark($oDocument, "Installation", 1, 3, _PDFX_Mm(120))

; ================================================================== premier document
_PDFX_AddPage($oDocument)
_PDFX_SetFill($oDocument, $COLOR_ACCENT)
_PDFX_SetFont($oDocument, "Helvetica", 9, "B")
_PDFX_Text($oDocument, _PDFX_Mm(18), _PDFX_Mm(24), "CHAPITRE 2")
_PDFX_SetFill($oDocument, $COLOR_DARK)
_PDFX_SetFont($oDocument, "Helvetica", 20, "B")
_PDFX_Text($oDocument, _PDFX_Mm(18), _PDFX_Mm(32), "Premier document")

_PDFX_SetFill($oDocument, $COLOR_TEXT)
_PDFX_SetFont($oDocument, "Helvetica", 10)
_PDFX_TextWrap($oDocument, _PDFX_Mm(18), _PDFX_Mm(50), $fTocWidth, _
    "Un document minimal tient en quelques lignes. L'en-tete et le pied de page sont " & _
    "poses une seule fois, puis repetes sur chaque page avec les jetons {page}, {pages} " & _
    "et {date}. Le pied de page de ce manuel les utilise deja.")

_PDFX_SetFill($oDocument, 0xF4F7FB)
_PDFX_Rect($oDocument, _PDFX_Mm(18), _PDFX_Mm(82), $fTocWidth, _PDFX_Mm(44), $PDFX_FILL)
_PDFX_SetFill($oDocument, 0x0B3D2E)
_PDFX_SetFont($oDocument, "Courier", 9)
_PDFX_Text($oDocument, _PDFX_Mm(22), _PDFX_Mm(88), '#include "PDFX.au3"')
_PDFX_Text($oDocument, _PDFX_Mm(22), _PDFX_Mm(95), 'Local $d = _PDFX_New("A4", "P", 18)')
_PDFX_Text($oDocument, _PDFX_Mm(22), _PDFX_Mm(102), '_PDFX_SetFont($d, "Helvetica", 12)')
_PDFX_Text($oDocument, _PDFX_Mm(22), _PDFX_Mm(109), '_PDFX_Text($d, 40, 60, "Bonjour")')
_PDFX_Text($oDocument, _PDFX_Mm(22), _PDFX_Mm(116), '_PDFX_Save($d, "bonjour.pdf")')

_PDFX_SetFill($oDocument, $COLOR_DARK)
_PDFX_SetFont($oDocument, "Helvetica", 14, "B")
_PDFX_Text($oDocument, _PDFX_Mm(18), _PDFX_Mm(150), "En-tete et pied de page")

_PDFX_SetFill($oDocument, $COLOR_TEXT)
_PDFX_SetFont($oDocument, "Helvetica", 10)
_PDFX_TextWrap($oDocument, _PDFX_Mm(18), _PDFX_Mm(160), $fTocWidth, _
    "L'en-tete occupe la marge haute, le pied la marge basse ; le corps du texte " & _
    "commence sous les deux. Les appels _PDFX_SetHeader et _PDFX_SetFooter prennent " & _
    "trois zones chacune : gauche, centre et droite. Une chaine vide masque la zone " & _
    "correspondante, ce qui permet de composer une pagination sobre.")

_PDFX_AddBookmark($oDocument, "Premier document", 0, 4, _PDFX_Mm(32))
_PDFX_AddBookmark($oDocument, "En-tete et pied de page", 1, 4, _PDFX_Mm(150))

; ================================================================== signets
_PDFX_AddPage($oDocument)
_PDFX_SetFill($oDocument, $COLOR_ACCENT)
_PDFX_SetFont($oDocument, "Helvetica", 9, "B")
_PDFX_Text($oDocument, _PDFX_Mm(18), _PDFX_Mm(24), "CHAPITRE 3")
_PDFX_SetFill($oDocument, $COLOR_DARK)
_PDFX_SetFont($oDocument, "Helvetica", 20, "B")
_PDFX_Text($oDocument, _PDFX_Mm(18), _PDFX_Mm(32), "Reference")

_PDFX_SetFill($oDocument, $COLOR_TEXT)
_PDFX_SetFont($oDocument, "Helvetica", 10)
_PDFX_TextWrap($oDocument, _PDFX_Mm(18), _PDFX_Mm(50), $fTocWidth, _
    "Ce chapitre rassemble les deux mecanismes de navigation : les signets, qui " & _
    "structurent le document dans le volet du lecteur, et les destinations, qui " & _
    "definissent le point exact ou s'ouvre chaque signet ou lien.")

_PDFX_SetFill($oDocument, $COLOR_DARK)
_PDFX_SetFont($oDocument, "Helvetica", 14, "B")
_PDFX_Text($oDocument, _PDFX_Mm(18), _PDFX_Mm(90), "Signets")

_PDFX_SetFill($oDocument, $COLOR_TEXT)
_PDFX_SetFont($oDocument, "Helvetica", 10)
_PDFX_TextWrap($oDocument, _PDFX_Mm(18), _PDFX_Mm(100), $fTocWidth, _
    "Un signet est un titre, un niveau et une destination. _PDFX_AddBookmark rend son " & _
    "numero d'ordre, ce qui permet de verifier un sommaire. Le niveau 0 est la racine ; " & _
    "un signet ne peut pas descendre de plus d'un niveau sous le precedent. " & _
    "Une demande trop profonde est ramenee a ce maximum, sans erreur : " & _
    "un sommaire reste toujours valide.")

_PDFX_SetFill($oDocument, $COLOR_DARK)
_PDFX_SetFont($oDocument, "Helvetica", 14, "B")
_PDFX_Text($oDocument, _PDFX_Mm(18), _PDFX_Mm(150), "Destinations")

_PDFX_SetFill($oDocument, $COLOR_TEXT)
_PDFX_SetFont($oDocument, "Helvetica", 10)
_PDFX_TextWrap($oDocument, _PDFX_Mm(18), _PDFX_Mm(160), $fTocWidth, _
    "Sans ordonnee, la destination est /Fit : la page entiere s'affiche. " & _
    "Avec une ordonnee, elle devient /XYZ et le lecteur place ce point en haut de " & _
    "la fenetre. C'est ce qui permet d'ouvrir un signet sur un paragraphe precis " & _
    "plutot que sur le debut du chapitre.")

_PDFX_AddBookmark($oDocument, "Reference", 0, 5, _PDFX_Mm(32))
_PDFX_AddBookmark($oDocument, "Signets", 1, 5, _PDFX_Mm(90))
_PDFX_AddBookmark($oDocument, "Destinations", 2, 5, _PDFX_Mm(150))

; ================================================================== liens internes
_PDFX_AddPage($oDocument)
_PDFX_SetFill($oDocument, $COLOR_ACCENT)
_PDFX_SetFont($oDocument, "Helvetica", 9, "B")
_PDFX_Text($oDocument, _PDFX_Mm(18), _PDFX_Mm(24), "REFERENCE (SUITE)")
_PDFX_SetFill($oDocument, $COLOR_DARK)
_PDFX_SetFont($oDocument, "Helvetica", 20, "B")
_PDFX_Text($oDocument, _PDFX_Mm(18), _PDFX_Mm(32), "Liens internes")

_PDFX_SetFill($oDocument, $COLOR_TEXT)
_PDFX_SetFont($oDocument, "Helvetica", 10)
_PDFX_TextWrap($oDocument, _PDFX_Mm(18), _PDFX_Mm(50), $fTocWidth, _
    "_PDFX_LinkPage transforme un rectangle en zone cliquable. La page cible peut " & _
    "ne pas exister encore : c'est le cas du sommaire, ecrit avant les chapitres. " & _
    "Le moteur garde la demande en attente et l'ecrit a l'enregistrement, quand " & _
    "chaque page possede enfin son numero d'objet. Un lien vers une page qui n'a " & _
    "jamais ete creee est ignore sans erreur.")

_PDFX_SetFill($oDocument, 0xEAF1FB)
_PDFX_Rect($oDocument, _PDFX_Mm(18), _PDFX_Mm(105), $fTocWidth, _PDFX_Mm(18), $PDFX_FILL)
_PDFX_SetFill($oDocument, $COLOR_DARK)
_PDFX_SetFont($oDocument, "Helvetica", 12, "B")
_PDFX_Text($oDocument, _PDFX_Mm(24), _PDFX_Mm(111), "Retour au sommaire")
_PDFX_LinkPage($oDocument, _PDFX_Mm(18), _PDFX_Mm(105), $fTocWidth, _PDFX_Mm(18), 2, _PDFX_Mm(24))

_PDFX_SetFill($oDocument, $COLOR_TEXT)
_PDFX_SetFont($oDocument, "Helvetica", 10)
_PDFX_TextWrap($oDocument, _PDFX_Mm(18), _PDFX_Mm(140), $fTocWidth, _
    "Le rectangle ci-dessus vise la page 2, qui existe deja : c'est un lien arriere. " & _
    "Les entrees du sommaire, elles, visaient des pages futures : deux cas traites " & _
    "par le meme appel.")

_PDFX_AddBookmark($oDocument, "Liens internes", 1, 6, _PDFX_Mm(32))

; ================================================================== colophon
_PDFX_AddPage($oDocument)
_PDFX_SetFill($oDocument, $COLOR_DARK)
_PDFX_SetFont($oDocument, "Helvetica", 20, "B")
_PDFX_Text($oDocument, _PDFX_Mm(18), _PDFX_Mm(32), "Colophon")

_PDFX_SetFill($oDocument, $COLOR_TEXT)
_PDFX_SetFont($oDocument, "Helvetica", 10)
_PDFX_TextWrap($oDocument, _PDFX_Mm(18), _PDFX_Mm(52), $fTocWidth, _
    "Document produit par PDFX " & $PDFX_VERSION & " pour AutoIt, sans bibliotheque " & _
    "externe et sans composant COM. Les flux de contenu sont compresses en FlateDecode " & _
    "par un compresseur ecrit en AutoIt. L'identifiant du document est une empreinte " & _
    "deterministe : deux generations du meme contenu donnent le meme fichier, " & _
    "horodatage mis a part.")

_PDFX_SetFill($oDocument, $COLOR_MUTED)
_PDFX_SetFont($oDocument, "Helvetica", 9)
_PDFX_Text($oDocument, _PDFX_Mm(18), _PDFX_Mm(100), "Auteur : Numeric1")
_PDFX_Text($oDocument, _PDFX_Mm(18), _PDFX_Mm(106), "Forum : https://www.autoitscript.com/forum/")
_PDFX_Text($oDocument, _PDFX_Mm(18), _PDFX_Mm(112), "Reference : ISO 32000-1, section 12.3 (interactive features, outlines et annotations)")

_PDFX_AddBookmark($oDocument, "Colophon", 0, 7, _PDFX_Mm(32))

; ================================================================== ecriture
FileDelete($sOut)
If Not _PDFX_Save($oDocument, $sOut) Then
    ConsoleWrite("Echec de l'enregistrement : " & @error & @CRLF)
    Exit 1
EndIf
_PDFX_Close($oDocument)

ConsoleWrite("OK " & $sOut & " (" & FileGetSize($sOut) & " octets, " & _
    _PDFX_PageCount($oDocument) & " pages)" & @CRLF)
