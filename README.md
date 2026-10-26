# PDFX 1.3 — écrire des PDF en AutoIt, sans dépendance

PDFX écrit des fichiers PDF 1.7 valides depuis AutoIt pur. Aucun COM, aucun
DLL externe, aucun binaire à côté du script : un seul `#include`.

```autoit
#include "PDFX.au3"

Local $pdf = _PDFX_New("A4", "P", 20)          ; A4 portrait, marges 20 mm
_PDFX_SetCompression($pdf, 6)                  ; flux de contenu en FlateDecode
_PDFX_SetFont($pdf, "Helvetica", 22, "B")
_PDFX_SetFill($pdf, 0x1F3864)
_PDFX_Text($pdf, _PDFX_Mm(20), _PDFX_Mm(20), "Bonjour")
_PDFX_AddBookmark($pdf, "Introduction", 0, 1)  ; signet vers la page 1
_PDFX_SetPageMode($pdf, "UseOutlines")         ; volet des signets ouvert
_PDFX_Save($pdf, @ScriptDir & "\demo.pdf")
_PDFX_Close($pdf)
```

Le fichier produit s'ouvre dans Acrobat, Chrome, Edge, Firefox, SumatraPDF,
Aperçu, et passe n'importe quel validateur strict.

**Auteur : Numeric1** — [forum AutoItScript](https://www.autoitscript.com/forum/).
Licence MIT ou domaine public, au choix.

PDFX est une implémentation originale, écrite d'après la norme ISO 32000-1 et
les métriques AFM publiques des polices Core 14. Aucun code, texte ni
commentaire n'est repris d'AutoItObject, de MPDF ou d'un autre UDF ; seule la
disposition conventionnelle des blocs de documentation AutoIt (`#INDEX#`,
`#CURRENT#`, `#FUNCTION#`) est partagée, comme dans tout include officiel.

---

## 1. Le modèle mental

Un document est un **tableau** (le handle). Chaque fonction le reçoit en premier
argument et le modifie. AutoIt passe les tableaux par référence : inutile
d'écrire `ByRef` à l'appel.

```autoit
Local $pdf = _PDFX_New("A4")        ; crée la page 1
_PDFX_AddPage($pdf)                 ; page 2
_PDFX_Text($pdf, 56, 56, "Page 2")
_PDFX_Save($pdf, "doc.pdf")         ; écrit tout d'un coup
_PDFX_Close($pdf)                   ; optionnel : libère GDI+ en fin de script
```

Rien n'est écrit avant `_PDFX_Save`. Le document se construit en mémoire sous
forme d'objets indirects ; l'xref et le trailer sont calculés à l'enregistrement.

## 2. Repère et unités

| | PDF natif | PDFX |
|---|---|---|
| Origine | coin **bas-gauche** | coin **haut-gauche** |
| Axe Y | monte | descend |
| Unité | point (1/72") | point (1/72") |
| A4 | 595,28 × 841,89 | idem |

`_PDFX_Mm(20)` convertit 20 mm en points. `_PDFX_Text($pdf, x, y, ...)` place le
**haut** du texte en `y` : la coordonnée que vous lisez est celle que vous voyez.

Formats : `A3`, `A4`, `A5`, `Letter`, `Legal`, ou `"120x200"` (mm).
Orientation : `"P"` ou `"L"`.

## 3. Remplissage, trait, opacité

```autoit
_PDFX_SetFill($pdf, 0x1F3864)        ; 0xRRGGBB
_PDFX_SetStroke($pdf, "navy")        ; nom, [r,g,b] ou "r,g,b"
_PDFX_SetLineWidth($pdf, 0.8)
_PDFX_SetDash($pdf, 3, 2)            ; 3 pt plein, 2 pt vide
_PDFX_SetAlpha($pdf, 0.25)           ; 25 % — s'applique aux dessins suivants
```

Les formes prennent `$PDFX_STROKE`, `$PDFX_FILL` ou `$PDFX_BOTH`.

Les entrées sont **bornées sans exception** : une composante de couleur hors de
`[0, 255]` ou une opacité hors de `[0, 1]` est ramenée dans l'intervalle, et
`@error` vaut `1` pour signaler la correction. `_PDFX_SetDash($pdf, 0)` remet le
trait plein (`[] 0 d`) ; `_PDFX_SetDash($pdf, 3)` utilise 3 pt plein / 3 pt vide.

## 4. Texte

```autoit
_PDFX_SetFont($pdf, "Helvetica", 10)        ; famille, taille, style
_PDFX_Text($pdf, x, y, "Texte", 0)           ; 0 = taille courante
_PDFX_TextAlign($pdf, x, y, largeur, "Texte", "C")   ; L, C, R
Local $ySuivant = _PDFX_TextWrap($pdf, x, y, largeur, $long, 10, 12)
```

`_PDFX_TextWrap` retourne l'ordonnée du prochain paragraphe, ce qui permet
d'enchaîner naturellement :

```autoit
Local $y = _PDFX_Mm(40)
$y = _PDFX_TextWrap($pdf, _PDFX_Mm(20), $y, _PDFX_Mm(170), $paragraphe1, 10)
$y = _PDFX_TextWrap($pdf, _PDFX_Mm(20), $y + _PDFX_Mm(3), _PDFX_Mm(170), $paragraphe2, 10)
```

`_PDFX_TextWidth($pdf, $texte, $taille)` renvoie la largeur exacte en points,
calculée sur les métriques AFM réelles de la police — pas une approximation.

### Polices

Trois familles, les quatorze polices standard du PDF (aucun fichier à embarquer,
aucune licence) :

| Famille | Styles |
|---|---|
| `Helvetica` (ou `Arial`, `sans`) | normal, `B`, `I`, `BI` |
| `Times` (ou `serif`) | normal, `B`, `I`, `BI` |
| `Courier` (ou `mono`) | normal, `B`, `I`, `BI` |

Encodage **WinAnsi** : le français passe intégralement — `é à ç ù ê ï ô œ Œ
« » € — ° ± · — …`. Les caractères hors WinAnsi (CJK, cyrillique, emoji) sont
remplacés par `?`.

## 5. Formes

```autoit
_PDFX_Line($pdf, x1, y1, x2, y2)
_PDFX_Rect($pdf, x, y, w, h, $PDFX_FILL)
_PDFX_RoundRect($pdf, x, y, w, h, rayon, $PDFX_BOTH)
_PDFX_Ellipse($pdf, cx, cy, rx, ry, $PDFX_FILL)
_PDFX_Circle($pdf, cx, cy, r, $PDFX_STROKE)
_PDFX_Polyline($pdf, $aPoints, $fermer, $PDFX_FILL)   ; [n][2] = [[x,y], ...]
_PDFX_Bezier($pdf, x1, y1, c1x, c1y, c2x, c2y, x2, y2, $style)
```

## 6. Images

```autoit
_PDFX_Image($pdf, "photo.jpg", x, y, largeur, hauteur)   ; 0 = déduit
_PDFX_ImageFit($pdf, "logo.png", x, y, boiteW, boiteH, "C")
Local $a = _PDFX_ImageInfo($pdf, "photo.jpg")            ; [pxW, pxH, ptW, ptH, octets, ext]
```

- **JPEG** : le flux est recopié tel quel (`/DCTDecode`). Zéro réencodage, zéro
  perte, taille du PDF = taille du JPEG. Composantes RGB, CMJN et niveaux de
  gris reconnues automatiquement. Un JPEG CMJN portant le marqueur APP14
  `Adobe` est déclaré avec `/Decode [1 0 1 0 1 0 1 0]`, car Adobe y stocke les
  valeurs inversées ; sans ce marqueur, l'ordre PDF est respecté.
- **PNG, BMP, GIF, TIFF** : conversion GDI+ en JPEG sur fond blanc (le canal
  alpha est aplati — c'est le comportement voulu pour la presse).
- **Dimensions** : `$fWidth` seule → hauteur déduite ; `$fHeight` seule → largeur
  déduite ; les deux → proportions imposées ; aucune → taille naturelle à 96 dpi.
- **Dédoublonnage** : une image insérée dix fois n'est stockée qu'une fois
  (cache par chemin absolu, un seul XObject).

## 7. Tableaux paginés

```autoit
Local $aColumns[3][3] = [ _
    ["Désignation", 0.60, "L"], _
    ["Qté",         0.15, "C"], _
    ["Total",       0.25, "R"]]

Local $aRows[2][3] = [ _
    ["Conception", "1", "1 450,00"], _
    ["Tirage",     "2",   "640,00"]]

Local $y = _PDFX_Table($pdf, x, y, largeur, $aColumns, $aRows, _
    "padding=6;fontsize=9;zebra=1;headfill=0x1F3864;headcolor=0xFFFFFF")
```

Les fractions de largeur sont normalisées : `0.6 / 0.15 / 0.25` ou `6 / 1.5 / 2.5`
donnent le même résultat. Le tableau ajoute automatiquement une page et répète
l'en-tête quand il déborde. Il retourne l'ordonnée libre sous la dernière ligne.

| Option | Défaut | Rôle |
|---|---|---|
| `padding` | 4 | marge intérieure des cellules, en points |
| `fontsize` | taille courante | taille du corps |
| `headfill` | `0xE8EEF7` | fond de l'en-tête (`-1` pour aucun) |
| `headcolor` | `0x1F3864` | couleur du texte d'en-tête |
| `zebra` | 0 | 1 = lignes alternées |
| `zebracolor` | `0xF7F9FC` | fond des lignes paires |
| `border` | 0.5 | épaisseur des filets (0 = aucun) |
| `bordercolor` | `0xBFC9D9` | couleur des filets |
| `pagebreak` | 1 | 0 = pas de saut de page automatique |

## 8. En-tête, pied de page, liens, métadonnées

```autoit
_PDFX_SetHeader($pdf, "Société", "", "Rapport 2026")
_PDFX_SetFooter($pdf, "", "Page {page} / {pages}", "{date}")
_PDFX_Link($pdf, x, y, w, h, "https://www.autoitscript.com/")
_PDFX_SetMeta($pdf, "Titre", "Auteur", "Sujet", "mots, clés")
```

Les deux fonctions acceptent trois réglages supplémentaires, propres à chaque
zone :

```autoit
_PDFX_SetHeader($pdf, "Interne", "", "Rapport", 8, "Courier", "B", 0x1F3864)
_PDFX_SetFooter($pdf, "", "Page {page} / {pages}", "", 7, "Times", "I", 0x6B7280)
```

| Paramètre | Défaut | Rôle |
|---|---|---|
| taille | 8 | taille du texte, commune à l'en-tête et au pied |
| famille | `Helvetica` | `Helvetica`, `Times` ou `Courier` |
| style | normal | combinaison de `B` et `I` |
| couleur | `0x666666` | couleur du texte, et du filet pour l'en-tête |

`{page}`, `{pages}` et `{date}` sont remplacés à l'enregistrement. L'en-tête et
le pied sont dessinés **après** le contenu : ils restent visibles sur les fonds
colorés.

## 9. Navigation : signets, liens internes, ouverture

Un PDF peut porter sa propre table des matières. PDFX écrit le volet des signets,
les zones cliquables qui y mènent, et le mode d'ouverture du document.

```autoit
_PDFX_AddBookmark($pdf, "Couverture", 0, 1)                  ; niveau 0, page 1
_PDFX_AddBookmark($pdf, "Chapitre 1", 1, 3)                  ; sous le précédent
_PDFX_AddBookmark($pdf, "Section 1.1", 2, 3, _PDFX_Mm(120))  ; page 3, à 120 mm du haut
_PDFX_LinkPage($pdf, x, y, w, h, 5)                          ; zone cliquable vers la page 5
_PDFX_SetPageMode($pdf, "UseOutlines")                       ; volet ouvert
_PDFX_SetPageLayout($pdf, "SinglePage")
```

### Signets

`_PDFX_AddBookmark($pdf, titre, niveau, page, y)` accepte une page en base 1 et
une ordonnée **en points depuis le haut**, comme le reste de l'API. Sans
ordonnée, la destination est `/Fit` : la page entière s'affiche. Avec une
ordonnée, elle devient `/XYZ` et le lecteur place ce point en haut de la fenêtre.

- Les niveaux sont en base 0. Un signet ne peut pas descendre de plus d'un
  niveau sous le précédent : une demande trop profonde est ramenée à ce maximum,
  sans erreur. Un sommaire reste donc toujours valide.
- La fonction renvoie le numéro d'ordre du signet (1, 2, …), ou `-1` avec
  `@error = 1` si le titre est vide ou la page hors du document.
- L'arbre est complet : `/Parent`, `/Prev`, `/Next`, `/First`, `/Last`, `/Count`.
  Le `/Count` d'un nœud est son nombre de descendants ; celui de la racine est le
  total. Les comptes sont positifs, donc tous les nœuds sont ouverts.
- Les titres ASCII sont écrits en chaîne littérale, les autres en hexadécimal
  **UTF-16BE** ; un titre accentué reste exact dans le volet du lecteur.
- Sans mode explicite, la présence de signets suffit : `/PageMode /UseOutlines`
  est ajouté au catalogue automatiquement.

### Liens internes

`_PDFX_LinkPage($pdf, x, y, largeur, hauteur, page, yCible)` transforme un
rectangle en annotation `/Subtype /Link`. Les coordonnées suivent le repère
habituel (haut-gauche, en points) ; la conversion PDF est faite par le moteur.

Le point important : **la page cible peut ne pas exister encore**. C'est le cas
d'un sommaire écrit avant les chapitres. Le moteur garde la demande en attente et
l'écrit à l'enregistrement, quand chaque page possède son numéro d'objet. Il n'y
a donc ni destination factice `[0 0 R]` ni seconde passe à gérer.

Une page cible inexistante au moment de l'enregistrement est **ignorée sans
erreur** : le lien disparaît, le reste du document reste valide. Seule une page
`< 1` est refusée immédiatement (`@error = 1`).

### Mode d'ouverture

| Réglage | Valeurs |
|---|---|
| `_PDFX_SetPageMode` | `UseNone`, `UseOutlines`, `UseThumbs`, `FullScreen` |
| `_PDFX_SetPageLayout` | `SinglePage`, `OneColumn`, `TwoColumnLeft`, `TwoColumnRight`, `TwoPageLeft`, `TwoPageRight` |

La casse et les espaces sont ignorés (`"useoutlines"` convient). Une valeur
inconnue renvoie `False` avec `@error = 1` ; une chaîne vide rétablit le choix
automatique. Après `_PDFX_Save`, les quatre fonctions de navigation renvoient
`@error = 2` : le document est gelé.

### Vérifier

`Tools/outline.py` lit l'arbre sans dépendance et résout chaque destination en
numéro de page :

```bash
python Tools/outline.py Examples/04_Manuel.pdf
# Couverture                          page 1  /Fit
# Sommaire                            page 2  y=773.858
# Reference                           page 5  y=751.181
#   Signets                           page 5  y=586.772
#     Destinations                    page 5  y=416.693
# ---- 11 signet(s)
```

`Tools/pdfcheck.py` contrôle en plus, pour chaque PDF : la racine `/Outlines`,
les chaînes `First`/`Last`, les `/Count`, les `/Annots` des pages et les
destinations internes `[N 0 R ...]` — y compris l'absence de `[0 0 R`.

## 10. Enregistrement et validité

`_PDFX_Save` écrit : en-tête `%PDF-1.7`, commentaire binaire, objets, table
`xref` (entrées de 20 octets exactement), `trailer`, `startxref`. Les
`/Length` des flux sont ceux des octets réellement écrits.

Un document ne s'écrit **qu'une fois** : après un enregistrement réussi,
`_PDFX_Save` et `_PDFX_AddPage` renvoient `@error = 2` au lieu de produire un
second fichier incohérent. Si la création du fichier échoue, rien n'est gelé et
l'appel peut être retenté.

Métadonnées et identité :

- `/Title`, `/Author`, `/Subject` et `/Keywords` sont écrits en chaîne littérale
  si le texte est ASCII, en hexadécimal **UTF-16BE** (`<FEFF...>`) sinon : un
  titre avec `€`, `œ` ou un caractère CJK reste exact.
- `/CreationDate` et `/ModDate` sont en **temps universel**, terminés par `Z`
  (`D:20261026184718Z`) : le PDF ne dépend pas du fuseau de la machine.
- `/ID` est une empreinte **MD5 déterministe** du contenu et des métadonnées.
  Deux générations du même document produisent le même identifiant, ce qui rend
  la non-régression mesurable.

`Tools/pdfcheck.py` vérifie tout cela sans dépendance :

```bash
python Tools/pdfcheck.py Examples/03_Images.pdf
# 03_Images.pdf: 53235 octets, 10 objets, 3 flux dont 1 compresses, 0 signets, 0 liens internes, OK
```

Il contrôle : en-tête, `startxref` → `xref`, chaque offset → `N 0 obj`,
`/Length` vs longueur réelle, `/Root` et `/Size`, `/Count` vs `/Kids`, puis la
navigation — racine `/Outlines`, chaînes `First`/`Last`, `/Count` de chaque
signet, `/Annots` et destinations internes des pages.
Les flux `FlateDecode` sont en plus **gonflés avec zlib** : un flux corrompu ou
une longueur fausse est signalé, ce qui valide le compresseur de bout en bout.

`Tools/regress.py` garantit qu'une modification du moteur ne change pas un seul
octet de la sortie. Les PDF de `Tests/Reference/` sont comparés aux PDF régénérés,
les horodatages et le jeton `{date}` étant neutralisés :

```bash
python Tools/regress.py Tests/Reference Examples Tests
# IDENTIQUE 01_Rapport.pdf  (d465bd5247f1a28e)
# IDENTIQUE 01_Torture.pdf  (e3eec5240c03d096)
# ...
```

## 11. Compression

Les flux de contenu pèsent l'essentiel d'un PDF textuel. `_PDFX_SetCompression`
les écrit en **FlateDecode** (zlib / DEFLATE), sans DLL et sans COM, avec un
compresseur écrit en AutoIt :

```autoit
_PDFX_SetCompression($pdf, 6)      ; 0 = brut (défaut), 1..9 = effort croissant
```

| Niveau | Usage |
|---|---|
| 0 | aucun filtre : flux lisibles à l'œil dans un éditeur de texte |
| 1–3 | brouillons, génération interactive |
| 6 | défaut conseillé : bon rapport poids / temps |
| 9 | archives : cherche les répétitions les plus lointaines |

Ce qui est compressé :

- les **flux de contenu** de chaque page, un par page ;
- les **JPEG** restent tels quels : déjà compressés, stockés en `DCTDecode` ;
- les dictionnaires, polices et métadonnées sont trop petits pour gagner.

Un flux qui ne gagne rien — page presque vide, contenu déjà dense — est écrit
en clair. Le choix se fait flux par flux, à l'enregistrement : la présence de
`/Filter /FlateDecode` n'est donc pas garantie pour toutes les pages.

Résultats mesurés sur les exemples (AutoIt 3.3.16.1 x86, Windows 10) :

| Document | Brut | Niveau 6 | Gain |
|---|---|---|---|
| `01_Rapport.pdf` | 18 621 o | 5 835 o | 3,2× |
| `02_Facture.pdf` | 11 088 o | 3 437 o | 3,2× |
| `03_Images.pdf` | 57 971 o | 53 235 o | 1,1× (JPEG dominant) |

Le compresseur utilise un **Huffman fixe** et une recherche de répétitions
bornée par le niveau. Il atteint le taux de zlib niveau 1, à environ 30 Ko/s :
c'est le prix d'AutoIt pur, sans dépendance. Le rendu est strictement identique
et la sortie **déterministe** : deux générations du même document donnent les
mêmes octets, ce que `Tools/regress.py` vérifie.

La compression s'applique à l'enregistrement, pas à l'appel. Un niveau hors
bornes est ramené dans `[0, 9]` avec `@error = 1` ; après `_PDFX_Save`, le
document est gelé et `_PDFX_SetCompression` renvoie `@error = 2`.

## 12. Limites assumées

- **Compression optionnelle, en AutoIt pur.** Elle est désactivée par défaut et
  plafonne au niveau de zlib 1, à environ 30 Ko/s : un très gros document peut
  demander plusieurs secondes. Pour des archives massives, un outil natif reste
  plus rapide.
- **Pas d'embarquement de TTF/OTF.** On utilise les 14 polices standard, ce qui
  garantit un rendu identique partout sans licence à gérer.
- **Pas de lecture de PDF** : PDFX écrit, il ne fusionne pas, n'extrait pas, ne
  remplit pas de formulaire.
- **Pas de chiffrement, pas de signature, pas de PDF/A.**
- **Transparence** : opacité globale par `ExtGState` (`_PDFX_SetAlpha`), mais pas
  de groupes de transparence ni de masques.
- **Dégradés** : non fournis ; on les simule par bandes ou par une image.
- **Navigation limitée au document** : les signets et `_PDFX_LinkPage` ne visent
  que des pages de ce PDF. Pas de destinations nommées, pas d'action JavaScript,
  pas de pièce jointe, pas de lien vers un autre fichier (`/GoToR`). Les signets
  n'ont ni couleur, ni graisse, ni icône : titre, niveau et destination seulement.
- **JPEG progressifs** : acceptés en entrée mais rendus de façon inégale selon
  le lecteur ; réenregistrer en JPEG baseline (GDI+ le fait) pour être sûr.

## 13. Sous le capot

```
document ──► objets indirects (1 Catalog, 2 Pages, puis pages, contenus,
             polices, XObjects, ExtGState)
          └► à la sauvegarde : offsets → table xref → trailer → startxref
```

- Les pages sont vidées (`_PDFX_FlushPage`) dès qu'on en ajoute une autre.
- Les liens internes sont préparés **avant** les pages — l'annotation doit être
  dans `/Annots` dès l'écriture — puis complétés à la fin, quand le numéro
  d'objet de chaque page est connu. Un lien abandonné porte l'objet `0` et le
  second passage l'ignore.
- L'arbre `/Outlines` est construit après la boucle des pages, dans le même
  ordre que les appels : parent, frères précédent/suivant et `/Count` en
  découlent directement.
- Chaque page possède son flux de contenu et son dictionnaire `/Resources`
  construit à partir des polices, images et états réellement utilisés.
- Les couleurs sont normalisées en `r g b RG/rg`, les coordonnées converties en
  une seule passe (`_PDFX_Y`).
- Les textes sont échappés en octal (`\233`) pour tout octet hors ASCII
  imprimable, ce qui rend les accents lisibles par tous les lecteurs.

## 14. Dépannage

| Symptôme | Cause probable |
|---|---|
| Le script se ferme sans rien afficher | erreur de syntaxe : lancer `Au3Check.exe PDFX.au3` |
| Page blanche | aucun `_PDFX_Text`/forme avant `_PDFX_AddPage` suivant |
| Accents remplacés par `?` | caractère hors WinAnsi ; vérifier l'encodage du fichier `.au3` (UTF-8) |
| Image absente | chemin relatif au script : utiliser `@ScriptDir & "\..."` |
| `_PDFX_Image` renvoie False | fichier absent ou image illisible par GDI+ |
| `_PDFX_Save` ou `_PDFX_AddPage` renvoie `@error = 2` | le document a déjà été enregistré : en créer un nouveau pour continuer |
| PDF pas plus petit malgré la compression | contenu déjà dense (images JPEG) ou page presque vide : le moteur retombe sur le flux brut |
| Compression lente sur un gros document | le compresseur est en AutoIt pur (~30 Ko/s) : baisser le niveau ou réserver la compression aux archives |
| Signet absent du volet | titre vide, page hors document, ou signets ajoutés après `_PDFX_Save` (`@error = 2`) |
| Lien présent mais inactif | la page cible n'a jamais été créée : le lien est ignoré à l'enregistrement |
| Le volet des signets reste fermé | `_PDFX_SetPageMode($pdf, "UseNone")` a été demandé explicitement, ou le lecteur ignore le mode d'ouverture |

## 15. Références

- **ISO 32000-1:2008** (PDF 1.7) — §7.5 objets et xref, §7.5.5 trailer,
  §7.5.8 table xref, §8.2 opérateurs graphiques, §8.6 images, §9.4 texte,
  §9.6 polices et polices standard 14, §12.3 signets et destinations,
  §12.5.6.5 annotations de lien, annexe D (WinAnsiEncoding).
- **Adobe PDF Reference 1.7** — métriques AFM des polices standard.
- **MSDN** — GDI+ : `GdipLoadImageFromFile`, `GdipSaveImageToFile`,
  `GdipCreateBitmapFromScan0`, encodeurs d'images.
- **RFC 1950** (zlib) et **RFC 1951** (DEFLATE) — en-tête, blocs à Huffman fixe,
  codes de longueur et de distance, Adler-32. Implémentation écrite pour ce
  projet, sans code repris de zlib.

## 16. Exemples et tests

| Fichier | Contenu |
|---|---|
| `Examples/01_Rapport.au3` | rapport A4 : bannière, KPI, graphique en barres, tableau paginé sur 2 pages, lien |
| `Examples/02_Facture.au3` | facture française : en-tête, bloc client, tableau 5 colonnes, totaux, mentions légales |
| `Examples/03_Images.au3` | JPEG direct, PNG converti, trois modes de dimensionnement, dédoublonnage |
| `Examples/04_Manuel.au3` | manuel de 7 pages : sommaire cliquable écrit avant les chapitres, 11 signets sur 3 niveaux, volet ouvert |
| `Tests/01_Torture.au3` | cas limites : accents, texte long, tableaux qui débordent, 9 pages, formes et images |
| `Tests/02_Robustesse.au3` | 23 vérifications : bornes alpha/couleur, tirets, UTF-16, dates UTC, `/ID`, gel après `Save`, styles d'en-tête, JPEG CMJN |
| `Tests/03_Compression.au3` | 16 vérifications : filtre par page, gain, repli sur flux brut, niveaux bornés, `/ID` stable, gel après `Save` |
| `Tests/04_Navigation.au3` | 36 vérifications : niveaux et bornage, `/Fit` et `/XYZ`, liens avant, lien abandonné, mode automatique, gel après `Save` |

`Tests/02_Robustesse.au3`, `Tests/03_Compression.au3` et
`Tests/04_Navigation.au3` s'exécutent sans intervention et affichent
`OK`/`ECHEC` ligne par ligne ; ils renvoient le code 1 en cas d'échec, ce qui
permet de les enchaîner dans un script de validation.
L'image CMJN de test se trouve dans `Tests/Assets/cmyk_adobe.jpg` ; si ce fichier
est absent, les deux contrôles CMJN sont simplement ignorés.

## 17. Travailler dans SciTE

Rien à configurer : PDFX est un include ordinaire, aussi à l'aise dans
SciTE-Lite (livré avec AutoIt) que dans SciTE4AutoIt3.

1. `Fichier > Ouvrir` → `PDFX\Examples\01_Rapport.au3`
2. `F5` (Go) : Au3Check valide, le PDF est écrit à côté du script.
3. Les `ConsoleWrite` s'affichent dans le volet **Output** :
   `OK C:\...\01_Rapport.pdf (5835 octets, 2 pages)`

À savoir :

- Le répertoire d'exécution est celui du script : `@ScriptDir` pointe sur
  `Examples\`, donc les chemins relatifs des images fonctionnent sans réglage.
- Les blocs `#Region ... #EndRegion` se replient dans la marge : pratique sur un
  fichier de plus de 3 200 lignes.
- Encodage : AutoIt 3.3.16 lit l'UTF-8 sans BOM — vérifié, `"éàç"` donne bien
  `Len=3` et `AscW=233`. Gardez le source en UTF-8 (le défaut de SciTE) et non
  en ANSI/CP1252.
- Dans votre projet, incluez par chemin relatif (`#include "..\PDFX.au3"`) ou
  copiez `PDFX.au3` à côté du script.
- Si un script reste bloqué **sans rien afficher**, c'est presque toujours une
  boîte d'erreur AutoIt cachée derrière la fenêtre : fermez-la, puis ajoutez
  `Opt("TrayIconDebug", 1)` en tête du script pour lire la ligne courante dans
  l'infobulle de l'icône de la barre des tâches.
- `Ctrl+Break` (Stop Executing) ne ferme pas une boîte modale : fermez le
  dialogue, sinon terminez `AutoIt3.exe` dans le gestionnaire de tâches.

---

AutoIt 3.3.14+ · testé sur 3.3.16.1 x86 · Windows 7 → 11.

PDFX 1.3 — © 2026 **Numeric1** · [forum AutoItScript](https://www.autoitscript.com/forum/) · MIT ou domaine public.
