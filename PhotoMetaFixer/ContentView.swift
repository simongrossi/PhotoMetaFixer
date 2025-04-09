import SwiftUI
import Photos

// Définir notre type d'erreur personnalisé (inchangé)
enum ExportError: Error, LocalizedError {
    case resourceNotFound
    case exportFailed(String)
    case dateNotFound
    case exifToolNotFound
    case exifToolExecutionFailed(Int, String)
    case exifToolLaunchFailed(String)

    var errorDescription: String? {
        switch self {
        case .resourceNotFound:
            return "Ressource photo non trouvée."
        case .exportFailed(let details):
            return "L'export initial du fichier a échoué: \(details)"
        case .dateNotFound:
            return "La date source sélectionnée est introuvable pour cet élément."
        case .exifToolNotFound:
            return "L'outil ExifTool intégré n'a pas été trouvé."
        case .exifToolExecutionFailed(let exitCode, let details):
            let cleanDetails = details.contains("1 image files updated") ? "" : details
            return "L'exécution d'ExifTool a échoué (code: \(exitCode)).\(cleanDetails.isEmpty ? "" : " Détails: \(cleanDetails)")"
        case .exifToolLaunchFailed(let details):
            return "Le lancement d'ExifTool a échoué: \(details)"
        }
    }
}

// Enum pour choisir la source de date (inchangé)
enum DateSource: String, CaseIterable, Identifiable {
    case creationDate = "Date de Création Originale"
    case modificationDate = "Date de Modification (Ajustée?)"

    var id: String { self.rawValue }
}

struct ContentView: View {
    // États (inchangés)
    @State private var albums: [PHAssetCollection] = []
    @State private var selectedAlbum: PHAssetCollection?
    @State private var photosInSelectedAlbum: [PHAsset] = []
    @State private var selectedAssetIDs: Set<String> = []
    @State private var processMessage: String = ""
    @State private var isLoadingAlbums: Bool = false
    @State private var isLoadingPhotos: Bool = false
    @State private var isProcessingExif: Bool = false
    @State private var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @State private var selectedDateSource: DateSource = .creationDate

    // Formatteurs de date (inchangés)
    private let exifDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter
    }()
    private let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()

    var body: some View {
        VStack {
            Text("PhotoMetaFixer")
                .font(.largeTitle)
                .padding(.bottom)

            // --- Gestion Autorisation & Sélection Album (inchangée) ---
            if authorizationStatus == .notDetermined {
                 Button("Autoriser l'accès aux Photos") { requestAuthorization() }.padding()
             } else if authorizationStatus == .denied || authorizationStatus == .restricted {
                 Text("Accès à la photothèque refusé...").foregroundColor(.red).padding()
             }
            else {
                // Sélecteur d'album (inchangé)
                HStack{
                     Text("Choisir un album :")
                     if isLoadingAlbums {
                         ProgressView().padding(.leading)
                     } else if albums.isEmpty {
                         Text("Aucun album trouvé.").foregroundColor(.gray)
                     } else {
                         Picker("", selection: $selectedAlbum) {
                             Text("Sélectionnez un album").tag(nil as PHAssetCollection?)
                             ForEach(albums, id: \.localIdentifier) { album in
                                 Text(album.localizedTitle ?? "Album sans nom").tag(album as PHAssetCollection?)
                             }
                         }
                     }
                     Spacer()
                }.padding(.horizontal)

                // Sélecteur Source de date (inchangé)
                Picker("Source de date pour EXIF :", selection: $selectedDateSource) {
                    ForEach(DateSource.allCases) { source in
                        Text(source.rawValue).tag(source)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 5)


                // --- Affichage des photos ---
                if isLoadingPhotos {
                     ProgressView("Chargement des photos...").padding()
                 } else if selectedAlbum != nil {
                    if photosInSelectedAlbum.isEmpty {
                         Text("Cet album est vide.").foregroundColor(.gray).padding()
                     } else {
                        // Barre d'outils Liste : Sélectionner Tout + Actualiser (inchangée)
                        HStack {
                             Button(action: toggleSelectAll) {
                                 Label(selectedAssetIDs.count == photosInSelectedAlbum.count ? "Tout Désélectionner" : "Tout Sélectionner",
                                       systemImage: selectedAssetIDs.count == photosInSelectedAlbum.count ? "xmark.square" : "checkmark.square")
                             }
                             Spacer()
                             Button { refreshPhotoList() } label: {
                                 Label("Actualiser", systemImage: "arrow.clockwise")
                             }
                                .disabled(isLoadingPhotos || selectedAlbum == nil)
                         }
                         .padding(.horizontal)
                         .padding(.bottom, 4)

                        // Liste des photos (inchangée)
                        List {
                            ForEach(photosInSelectedAlbum, id: \.localIdentifier) { asset in
                                HStack {
                                    // Checkbox
                                    Image(systemName: selectedAssetIDs.contains(asset.localIdentifier) ? "checkmark.square.fill" : "square")
                                        .foregroundColor(selectedAssetIDs.contains(asset.localIdentifier) ? .accentColor : .gray)
                                        .font(.title2)
                                        .onTapGesture { toggleSelection(for: asset) }
                                        .padding(.trailing, 6)

                                    // Miniature
                                    Image(nsImage: thumbnail(for: asset) ?? NSImage(systemSymbolName: "photo", accessibilityDescription: "Image manquante")!)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 50, height: 50)
                                        .clipped()
                                        .cornerRadius(6)

                                    // Informations Dates
                                    VStack(alignment: .leading, spacing: 4) {
                                         Text("Création: \(asset.creationDate != nil ? displayDateFormatter.string(from: asset.creationDate!) : "Inconnue")")
                                             .font(.caption).foregroundColor(.gray)
                                         Text("Modification: \(asset.modificationDate != nil ? displayDateFormatter.string(from: asset.modificationDate!) : "Inconnue")")
                                             .font(.caption).foregroundColor(.gray)

                                         let dateToApply = (selectedDateSource == .creationDate) ? asset.creationDate : asset.modificationDate
                                         if let validDate = dateToApply {
                                             Text("Appliquera (\(selectedDateSource.rawValue.prefix(4))): \(exifDateFormatter.string(from: validDate))")
                                                 .font(.callout).bold().foregroundColor(.blue)
                                         } else {
                                              Text("Appliquera: Date source inconnue")
                                                 .font(.callout).bold().foregroundColor(.orange)
                                         }
                                     }
                                    Spacer()
                                }
                                .padding(.vertical, 6)
                            }
                        }
                        .frame(maxHeight: .infinity)

                        // Bouton d'action (inchangé)
                        Button(action: processSelectedAssets) {
                             Label("Modifier EXIF pour \(selectedAssetIDs.count) photo(s) sélectionnée(s)", systemImage: "wand.and.stars")
                         }
                            .disabled(selectedAssetIDs.isEmpty || isProcessingExif)
                            .padding(.top)
                            .buttonStyle(.borderedProminent)

                        if isProcessingExif { ProgressView("Traitement en cours...").padding(.bottom) }

                    }
                } else {
                     Text("Veuillez sélectionner un album pour afficher les photos.").foregroundColor(.gray).padding()
                 }
            }

            Spacer()

            // Zone de message (inchangée)
             ScrollView {
                 Text(processMessage)
                     .foregroundColor(processMessage.contains("Erreur") || processMessage.contains("échoué") ? .red : .green)
                     .padding(10)
                     .frame(maxWidth: .infinity, alignment: .leading)
                     .textSelection(.enabled)
             }
                .frame(height: 80)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal)
                .padding(.bottom)

        }
        .frame(minWidth: 750, minHeight: 600)
        .onAppear { checkAuthorization() }
        // ** Correction Avertissement: Utiliser la nouvelle syntaxe onChange **
        .onChange(of: selectedAlbum) { oldValue, newValue in
             // Réinitialiser quand l'album change
             photosInSelectedAlbum = []
             selectedAssetIDs = []
             processMessage = ""
             // Utiliser newValue ici (le nouvel album sélectionné)
             if let album = newValue { fetchPhotos(in: album) }
         }
        // ** Correction Avertissement: Utiliser la nouvelle syntaxe onChange **
        .onChange(of: authorizationStatus) { oldValue, newValue in
             // Utiliser newValue ici (le nouveau statut d'autorisation)
             if newValue == .authorized || newValue == .limited {
                 // Recharger les albums seulement si nécessaire (évite rechargement si déjà autorisé)
                 if albums.isEmpty {
                     fetchAlbums()
                 }
             }
         }

    } // Fin de var body

    // --- Fonctions Logiques ---

    // checkAuthorization, requestAuthorization, fetchAlbums, fetchPhotos, refreshPhotoList (inchangées)
    func checkAuthorization() {
         authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
         if authorizationStatus == .notDetermined {}
         else if authorizationStatus == .authorized || authorizationStatus == .limited {
              if albums.isEmpty { fetchAlbums() }
          }
     }
    func requestAuthorization() {
         PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
             DispatchQueue.main.async { self.authorizationStatus = status }
         }
     }
    func fetchAlbums() {
         isLoadingAlbums = true
         albums = []
         let fetchOptions = PHFetchOptions()
         fetchOptions.sortDescriptors = [NSSortDescriptor(key: "localizedTitle", ascending: true)]
         let userAlbums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: fetchOptions)
         var fetchedAlbums: [PHAssetCollection] = []
         userAlbums.enumerateObjects { (collection, _, _) in fetchedAlbums.append(collection) }
         DispatchQueue.main.async {
             self.albums = fetchedAlbums
             self.isLoadingAlbums = false
         }
     }
    func fetchPhotos(in album: PHAssetCollection) {
         isLoadingPhotos = true
         photosInSelectedAlbum = [] // Vider pour recharger
         let fetchOptions = PHFetchOptions()
         fetchOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
         fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
         let result = PHAsset.fetchAssets(in: album, options: fetchOptions)
         var fetchedAssets: [PHAsset] = []
         result.enumerateObjects { (asset, _, _) in fetchedAssets.append(asset) }
         DispatchQueue.main.async {
             self.photosInSelectedAlbum = fetchedAssets
             self.isLoadingPhotos = false
             self.selectedAssetIDs = self.selectedAssetIDs.filter { id in fetchedAssets.contains(where: { $0.localIdentifier == id }) }
         }
     }
     func refreshPhotoList() {
         guard let album = selectedAlbum, !isLoadingPhotos else { return }
         print("Actualisation de la liste des photos pour l'album: \(album.localizedTitle ?? "N/A")")
         processMessage = ""
         fetchPhotos(in: album)
     }

    // toggleSelection, toggleSelectAll (inchangées)
    func toggleSelection(for asset: PHAsset) {
         if selectedAssetIDs.contains(asset.localIdentifier) { selectedAssetIDs.remove(asset.localIdentifier) }
         else { selectedAssetIDs.insert(asset.localIdentifier) }
     }
    func toggleSelectAll() {
         if selectedAssetIDs.count == photosInSelectedAlbum.count { selectedAssetIDs.removeAll() }
         else { selectedAssetIDs = Set(photosInSelectedAlbum.map { $0.localIdentifier }) }
     }


    // processSelectedAssets (inchangée)
    func processSelectedAssets() {
        guard !selectedAssetIDs.isEmpty else { return }
        isProcessingExif = true
        processMessage = "Début du traitement pour \(selectedAssetIDs.count) photo(s) en utilisant [\(selectedDateSource.rawValue)]..."
        let idsToProcess = selectedAssetIDs
        var successCount = 0
        var errorCount = 0
        var errors: [String] = []
        let assetsToProcess = photosInSelectedAlbum.filter { idsToProcess.contains($0.localIdentifier) }

        func processNextAsset(index: Int) {
            guard index < assetsToProcess.count else {
                DispatchQueue.main.async {
                    var finalMessage = "Traitement terminé. \(successCount) succès."
                    if errorCount > 0 { finalMessage += " \(errorCount) erreur(s)." }
                    if !errors.isEmpty { finalMessage += (finalMessage.isEmpty ? "" : "\n") + "Erreurs:\n" + errors.joined(separator: "\n") }
                    processMessage = finalMessage
                    isProcessingExif = false
                }
                return
            }
            let asset = assetsToProcess[index]
            let assetShortId = String(asset.localIdentifier.prefix(8))
            let dateToUse = (selectedDateSource == .creationDate) ? asset.creationDate : asset.modificationDate
            DispatchQueue.main.async { processMessage = "Traitement [\(index + 1)/\(assetsToProcess.count)]: \(assetShortId)..." }

            exportAsset(asset: asset, dateToApply: dateToUse) { result in
                 DispatchQueue.main.async {
                    switch result {
                    case .success(_): successCount += 1
                    case .failure(let error):
                        errorCount += 1
                        errors.append("Photo \(assetShortId): \(error.localizedDescription)")
                    }
                    processNextAsset(index: index + 1)
                 }
            }
        }
        processNextAsset(index: 0)
    }


    // exportAsset (inchangée - contient déjà le fix network access)
    func exportAsset(asset: PHAsset, dateToApply: Date?, completion: @escaping (Result<String, ExportError>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let validDate = dateToApply else {
                 DispatchQueue.main.async { completion(.failure(.dateNotFound)) }
                 return
            }
            let resources = PHAssetResource.assetResources(for: asset)
            guard let photoResource = resources.first(where: { $0.type == .photo }) else {
                DispatchQueue.main.async { completion(.failure(.resourceNotFound)) }
                return
            }
            let uniqueID = UUID().uuidString
            let tmpURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("\(uniqueID)_temp.jpg")
            let manager = PHAssetResourceManager.default()
            let requestOptions = PHAssetResourceRequestOptions()
            requestOptions.isNetworkAccessAllowed = true
            let semaphore = DispatchSemaphore(value: 0)
            var exportError: Error? = nil
            manager.writeData(for: photoResource, toFile: tmpURL, options: requestOptions) { error in
                exportError = error
                semaphore.signal()
            }
            _ = semaphore.wait(timeout: .distantFuture)
            if let error = exportError {
                 if let nsError = error as NSError?, nsError.domain == PHPhotosError.errorDomain, nsError.code == PHPhotosError.accessRestricted.rawValue || nsError.code == PHPhotosError.accessUserDenied.rawValue {
                     print("Erreur d'accès PHPhotosError: Vérifiez les autorisations (Accès Complet vs Limité).")
                 }
                DispatchQueue.main.async { completion(.failure(.exportFailed(error.localizedDescription))) }
                return
            }

            let formattedDate = self.exifDateFormatter.string(from: validDate)
            guard let toolPath = Bundle.main.path(forResource: "exiftool", ofType: "") else {
                 try? FileManager.default.removeItem(at: tmpURL)
                 DispatchQueue.main.async { completion(.failure(.exifToolNotFound)) }
                 return
            }
            let process = Process()
            process.executableURL = URL(fileURLWithPath: toolPath)
            process.arguments = [ "-overwrite_original", "-DateTimeOriginal=\(formattedDate)", "-CreateDate=\(formattedDate)", "-ModifyDate=\(formattedDate)", tmpURL.path ]
            let libPath = (Bundle.main.resourcePath ?? "") + "/Image-ExifTool/lib"
            if FileManager.default.fileExists(atPath: libPath) { process.environment = ["PERL5LIB": libPath] }
            else { print("‼️ Attention: Dossier \(libPath) non trouvé.") }
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            var processError: Error? = nil
            var terminationStatus: Int32 = -1
            var errorOutput: String = ""
            do {
                try process.run()
                process.waitUntilExit()
                terminationStatus = process.terminationStatus
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                errorOutput = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            } catch { processError = error }

            if let error = processError {
                 try? FileManager.default.removeItem(at: tmpURL)
                 DispatchQueue.main.async { completion(.failure(.exifToolLaunchFailed(error.localizedDescription))) }
            } else if terminationStatus != 0 {
                 try? FileManager.default.removeItem(at: tmpURL)
                 DispatchQueue.main.async { completion(.failure(.exifToolExecutionFailed(Int(terminationStatus), errorOutput))) }
            } else {
                 DispatchQueue.main.async { completion(.success("EXIF mis à jour pour \(tmpURL.lastPathComponent)")) }
            }
        }
    }

    // thumbnail (contient déjà le fix return)
     func thumbnail(for asset: PHAsset) -> NSImage? {
         let imageManager = PHImageManager.default()
         let options = PHImageRequestOptions()
         options.isSynchronous = true
         options.deliveryMode = .highQualityFormat
         options.resizeMode = .exact
         options.isNetworkAccessAllowed = true

         var resultImage: NSImage? = nil
         let targetSize = CGSize(width: 100, height: 100)

         imageManager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options) { image, info in
             resultImage = image
             if image == nil {
                 print("Erreur chargement miniature pour \(asset.localIdentifier): \(info?[PHImageErrorKey] ?? "Erreur inconnue")")
             }
         }
         // Retour ajouté précédemment
         return resultImage ?? NSImage(systemSymbolName: "photo.fill", accessibilityDescription: "Miniature indisponible")
     }

} // Fin de struct ContentView

// Extension supprimée précédemment

