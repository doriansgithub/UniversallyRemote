//
//  RemotePeerManager.swift
//  UniversallyRemote
//
//  Created by Dorian Mattar on 9/4/25.
//

import Foundation
import MultipeerConnectivity
import UIKit

extension RemotePeerManager {
    
    // MARK: - Artwork Cache Verification (Albums Only)
    func checkArtworkCacheAndSyncIfNeeded(allAlbums: [RemoteAlbum]) {
        DispatchQueue.global(qos: .background).async {
            // 1️⃣ Load existing cache from disk
            UnifiedArtworkCache.shared.preloadFromDisk()
            print("🧠 Album artwork cache preloaded from disk.")
            
            // 2️⃣ Detect which albums are missing artwork
            let missingAlbums = allAlbums.filter {
                let cleanName = $0.albumName.trimmingCharacters(in: .whitespacesAndNewlines)
                return !cleanName.isEmpty && !UnifiedArtworkCache.shared.hasImage(for: cleanName)
            }
            
            // 3️⃣ If nothing missing, done
            guard !missingAlbums.isEmpty else {
                print("✅ All album artworks already cached.")
                return
            }
            
            // 4️⃣ Request missing ones from the Mac
            DispatchQueue.main.async {
                    // Few missing → individual requests
                    print("📡 Requesting \(missingAlbums.count) missing album artworks individually")
                for album in missingAlbums {
                    let cleanName = album.albumName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !cleanName.isEmpty else { continue }
                    self.sendCommand("getAlbumArtwork:\(cleanName)")
                }
            }
        }
    }
    
    func handleIncomingAlbumArtwork(_ dict: [String: Any]) {
        guard let albumName = dict["albumName"] as? String,
              let base64 = dict["artworkBase64"] as? String,
              let data = Data(base64Encoded: base64),
              let image = UIImage(data: data) else {
            print("⚠️ Corrupted or invalid artwork for \(dict["albumName"] ?? "?") — refetching")
            if let name = dict["albumName"] as? String {
                RemotePeerManager.shared.sendCommand("getAlbumArtwork:\(name)")
            }
            return
        }

        UnifiedArtworkCache.shared.store(image, for: albumName)
        print("✅ Stored valid artwork for \(albumName)")
    }
    
}


// MARK: - UnifiedArtworkCache
class UnifiedArtworkCache {
    static let shared = UnifiedArtworkCache()
    private let memoryCache = NSCache<NSString, UIImage>()
    private let ioQueue = DispatchQueue(label: "artwork.disk.queue", qos: .utility)
    
    private init() {
        memoryCache.countLimit = 300           // up to 300 images
        memoryCache.totalCostLimit = 256 * 1024 * 1024 // 256 MB
        try? FileManager.default.createDirectory(at: cacheFolder,
                                                 withIntermediateDirectories: true)
    }
    
    // MARK: - Core Paths
    private var cacheFolder: URL {
        let folder = FileManager.default.urls(for: .cachesDirectory,
                                              in: .userDomainMask)[0]
            .appendingPathComponent("ArtworkCache", isDirectory: true)
        return folder
    }
    
    // MARK: - Fetch
    func image(for key: String) -> UIImage? {
        // 1️⃣ Memory cache
        if let img = memoryCache.object(forKey: key as NSString) {
            return img
        }
        
        // 2️⃣ Disk cache fallback
        let url = cacheFolder.appendingPathComponent("\(key).jpg")
        if FileManager.default.fileExists(atPath: url.path),
           let img = UIImage(contentsOfFile: url.path) {
            let cost = Int(img.size.width * img.size.height * 4)
            memoryCache.setObject(img, forKey: key as NSString, cost: cost)
            return img
        }
        
        // 3️⃣ Missing entirely
        return nil
    }
    
    // MARK: - Save
    func store(_ image: UIImage, for key: String) {
        let cost = Int(image.size.width * image.size.height * 4)
        memoryCache.setObject(image, forKey: key as NSString, cost: cost)
        
        ioQueue.async {
            let url = self.cacheFolder.appendingPathComponent("\(key).jpg")
            if let data = image.jpegData(compressionQuality: 0.6) {
                try? data.write(to: url)
            }
        }
    }
    
    // MARK: - Preload
    func preloadFromDisk() {
        ioQueue.async {
            guard let files = try? FileManager.default.contentsOfDirectory(
                at: self.cacheFolder,
                includingPropertiesForKeys: nil
            ) else { return }
            
            var loadedCount = 0
            for url in files where url.pathExtension == "jpg" {
                if let img = UIImage(contentsOfFile: url.path) {
                    let key = url.deletingPathExtension().lastPathComponent
                    let cost = Int(img.size.width * img.size.height * 4)
                    self.memoryCache.setObject(img, forKey: key as NSString, cost: cost)
                    loadedCount += 1
                }
            }
            print("🧠 Preloaded \(loadedCount) artworks into memory cache.")
        }
    }
    
    // MARK: - Utility
    func hasImage(for key: String) -> Bool {
        if memoryCache.object(forKey: key as NSString) != nil { return true }
        let fileURL = cacheFolder.appendingPathComponent("\(key).jpg")
        return FileManager.default.fileExists(atPath: fileURL.path)
    }
    
}
