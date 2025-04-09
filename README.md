# PhotoMetaFixer pour macOS

## Description Courte

PhotoMetaFixer est une application macOS développée en SwiftUI qui permet de mettre à jour les métadonnées EXIF (date/heure) de vos photos en se basant sur les informations de votre bibliothèque Photos. Elle utilise l'outil externe puissant [ExifTool](https://exiftool.org/) pour effectuer les modifications sur des copies temporaires des images.

Particulièrement utile pour les photographes (comme moi !) qui souhaitent corriger les dates après l'importation ou synchroniser la date "ajustée" dans l'application Photos avec les métadonnées EXIF du fichier.

## Fonctionnalités Principales

* Navigation dans les albums de la bibliothèque Photos de macOS.
* Affichage des miniatures et des dates (Création originale / Modification) pour les photos d'un album.
* Sélection multiple de photos via des cases à cocher.
* Choix de la source de date à utiliser pour la mise à jour EXIF :
    * Date de Création Originale (souvent la date de prise de vue)
    * Date de Modification (peut correspondre à la date ajustée manuellement dans Photos)
* Bouton pour lancer la mise à jour EXIF en lot sur les photos sélectionnées.
* Utilisation de l'outil [ExifTool](https://exiftool.org/) (qui doit être inclus lors de la compilation) pour modifier les tags `DateTimeOriginal`, `CreateDate`, et `ModifyDate`.
* Affichage des messages de succès ou d'erreur pour chaque photo traitée.
* Bouton pour actualiser la liste des photos et leurs dates.

## Motivation

L'application Photos sur macOS permet d'ajuster la date et l'heure d'une photo, mais cette modification n'est pas toujours répercutée dans les tags EXIF standards du fichier image lui-même. PhotoMetaFixer vise à combler ce manque en permettant d'utiliser soit la date originale, soit la date de dernière modification (qui correspond souvent à la date ajustée) pour réécrire les tags EXIF pertinents grâce à ExifTool.

## Prérequis pour la Compilation

* macOS [Indiquez la version minimale, ex: 14.0 ou 15.0+] (à vérifier selon les API SwiftUI utilisées)
* Xcode [Indiquez la version, ex: 16.0+]
* **ExifTool :** L'application dépend d'ExifTool. Pour compiler le projet, vous devez :
    1.  Télécharger la **distribution Perl complète** (`.tar.gz`) depuis [exiftool.org](https://exiftool.org/).
    2.  Décompresser l'archive.
    3.  Placer le **script `exiftool`** et le **dossier `Image-ExifTool`** (contenant `lib/`) dans le dossier `PhotoMetaFixer/Ressources/` (ou l'emplacement correspondant) de la structure du projet Xcode *avant* de compiler. Le script de build (`Run Script Phase`) se chargera de les copier correctement dans l'application finale.

## Compilation et Lancement

1.  Clonez ce dépôt GitHub.
2.  Assurez-vous d'avoir les prérequis (Xcode, ExifTool).
3.  Placez le script `exiftool` et le dossier `Image-ExifTool` dans le dossier `PhotoMetaFixer/Ressources/` du projet cloné.
4.  Ouvrez le fichier `PhotoMetaFixer.xcodeproj` avec Xcode.
5.  Sélectionnez le simulateur ou votre Mac comme destination.
6.  Compilez et lancez l'application (Cmd + R).
7.  N'oubliez pas d'ajouter la clé `NSPhotoLibraryUsageDescription` (`Privacy - Photo Library Usage Description`) dans le fichier `Info.plist` si ce n'est pas déjà fait.

## Utilisation

1.  Lancez l'application.
2.  Autorisez l'accès à la photothèque si demandé.
3.  Choisissez un album dans la liste déroulante.
4.  Sélectionnez la "Source de date pour EXIF" souhaitée (Création ou Modification).
5.  Cochez les photos que vous voulez modifier dans la liste. Vous pouvez utiliser "Tout Sélectionner".
6.  Vérifiez la date "Appliquera:" affichée pour les photos sélectionnées.
7.  Cliquez sur le bouton "Modifier EXIF pour X photo(s) sélectionnée(s)".
8.  Consultez la zone de message en bas pour voir le résultat du traitement (succès ou erreurs). Les fichiers modifiés sont des copies temporaires dont le nom est indiqué en cas de succès.

## Limitations et Notes Importantes

* L'application **ne modifie pas directement** les photos dans votre bibliothèque Photos. Elle exporte une copie temporaire, modifie les EXIF de cette copie avec `exiftool`, et signale le nom du fichier temporaire modifié. Vous devrez ensuite gérer ces fichiers temporaires (les retrouver, les réimporter si besoin, etc.).
* La dépendance à `exiftool` (un outil externe en Perl) rend la distribution via le Mac App Store très compliquée (à cause du Sandboxing). Cette application est plutôt destinée à un usage personnel ou à une distribution directe (qui nécessiterait Signature et Notarisation).
* La "Date de Modification" ne correspond à la date ajustée *que si* l'ajustement de date était la *dernière* modification effectuée sur la photo dans l'application Photos.


## Auteur
Simon Grossi
simongrossi
