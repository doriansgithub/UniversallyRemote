//
//  RemotePeerManager.swift
//  UniversallyRemote
//
//  Created by Dorian Mattar on 9/4/25.
//

import Foundation
import MultipeerConnectivity

protocol RemotePeerManagerDelegate: AnyObject {
    func didReceiveGenres(_ genres: [String])
    func didReceiveNowPlaying(_ info: [String: Any])
    func didReceiveProgress(currentTime: Double, duration: Double)
    func didChangeConnection(connected: Bool)
    func didReceivePlaybackState(isPlaying: Bool)
    
    // Search
    func didReceiveSearchResults(_ results: [[String: Any]])
    
    // ✅ Add these so delegate can receive hierarchical browse data
    func didReceiveArtists(_ artists: [RemoteArtist], for genre: String)
    func didReceiveAlbums(_ albums: [RemoteAlbum], for artist: RemoteArtist)
    func didReceiveSongs(_ songs: [[String: Any]])
    
    func getAllGenres()
}

class RemotePeerManager: NSObject, MCNearbyServiceBrowserDelegate, MCSessionDelegate {
    static let shared = RemotePeerManager()
    private var invitedPeers = Set<MCPeerID>()
    private(set) var discoveredPeers: [MCPeerID] = []
    private var pendingCommands: [String] = []
    private var lastState: MCSessionState?

    var hasConnectedPeers: Bool {
        return !session.connectedPeers.isEmpty
    }
    var isSearching: Bool {
        return isBrowsing && session.connectedPeers.isEmpty
    }
    private var session: MCSession!
    private var browser: MCNearbyServiceBrowser!
    private var peerID: MCPeerID!
    private(set) var isBrowsing = false
    private var currentArtworkTask: String?
    
    private func loadPeerID(name: String) -> MCPeerID {
        let key = "savedPeerID"
        if let data = UserDefaults.standard.data(forKey: key),
           let peer = try? NSKeyedUnarchiver.unarchivedObject(ofClass: MCPeerID.self, from: data) {
            return peer
        }
        let newPeer = MCPeerID(displayName: name)
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: newPeer, requiringSecureCoding: true) {
            UserDefaults.standard.set(data, forKey: key)
        }
        return newPeer
    }
    
    weak var delegate: RemotePeerManagerDelegate?
    
    override init() {
        super.init()
        peerID = loadPeerID(name: UIDevice.current.name)
        
        // ✅ Create the session
        session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .none)
        session.delegate = self

        // ✅ Create the browser
        browser = MCNearbyServiceBrowser(peer: peerID, serviceType: "music-control")
        browser.delegate = self
    }
    
    // MARK: - Send Commands
    
    func sendCommand(_ command: String) {
        guard let data = command.data(using: .utf8) else { return }

        if !hasConnectedPeers {
            print("⏳ Queueing command (not connected yet): \(command)")
            pendingCommands.append(command)
            return
        }

        do {
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
            print("📡 Sent command: \(command)")
        } catch {
            print("⚠️ Failed to send command: \(error.localizedDescription)")
        }
    }
    
    // Inside RemotePeerManager
    func connect(to peer: MCPeerID) {
        browser.invitePeer(peer, to: session, withContext: nil, timeout: 10)
    }
    
    // MARK: - MCNearbyServiceBrowserDelegate
    func browser(_ browser: MCNearbyServiceBrowser,
                 foundPeer peerID: MCPeerID,
                 withDiscoveryInfo info: [String : String]?) {
        print("👀 Found peer: \(peerID.displayName)")
        
        // Deduplicate
        if !discoveredPeers.contains(where: { $0.displayName == peerID.displayName }) {
            discoveredPeers.append(peerID)
        } else {
            print("ℹ️ Ignored duplicate peer: \(peerID.displayName)")
            return
        }
        
        if discoveredPeers.count == 1 {
            // ✅ Only one server found → auto-connect
            print("✅ Only one peer, auto-connecting: \(peerID.displayName)")
            connect(to: peerID)
            self.delegate?.getAllGenres()
        } else {
            // ✅ More than one peer → post notification so VC can present picker
            NotificationCenter.default.post(name: Notification.Name("MultiplePeersFound"),
                                            object: nil,
                                            userInfo: ["peers": discoveredPeers])
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        print("❌ Lost peer: \(peerID.displayName)")
        discoveredPeers.removeAll { $0.displayName == peerID.displayName }
    }
    
    // MARK: - MCSessionDelegate
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        guard state != lastState else {
            print("ℹ️ Ignored duplicate state: \(state.rawValue)")
            return
        }
        lastState = state

        print("Peer \(peerID.displayName) state: \(state.rawValue)")
        print("Connected peers (raw): \(session.connectedPeers.map { $0.displayName })")

        // Deduplicate by displayName
        let uniquePeers = Array(Set(session.connectedPeers.map { $0.displayName }))
        print("Connected peers (unique): \(uniquePeers)")

        DispatchQueue.main.async {
            switch state {
            case .connected:
                self.delegate?.didChangeConnection(connected: true)

                // ✅ Flush queued commands when connected
                if !self.pendingCommands.isEmpty {
                    print("📤 Flushing \(self.pendingCommands.count) queued commands")
                    for cmd in self.pendingCommands {
                        self.sendCommand(cmd)
                    }
                    self.pendingCommands.removeAll()
                }

            case .connecting:
                print("⏳ Connecting to \(peerID.displayName)...")
                // Optional: notify delegate/UI if you want to show "connecting" state
                self.delegate?.didChangeConnection(connected: false)

            case .notConnected:
                print("❌ Disconnected from \(peerID.displayName)")
                self.delegate?.didChangeConnection(connected: false)
            @unknown default:
                print("⚠️ Unknown state: \(state.rawValue)")
                self.delegate?.didChangeConnection(connected: false)
            }
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        // Try JSON first
        if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let type = dict["type"] as? String {
            // 💓 Any inbound data proves we’re connected
            DispatchQueue.main.async {
                self.delegate?.didChangeConnection(connected: true)

                switch type {
                case "genres":
                    if let genres = dict["data"] as? [String] {
                        self.delegate?.didReceiveGenres(genres)
                        NotificationCenter.default.post(name: Notification.Name("RemoteRequestFinished"), object: nil)
                    }

                case "artists":
                    if let arr = dict["data"] as? [[String: Any]],
                       let genre = dict["genre"] as? String {
                        let artists = arr.map {
                            RemoteArtist(
                                artistName: $0["name"] as? String ?? "",
                                artworkBase64: $0["artworkBase64"] as? String,
                                isPlaying: $0["isPlaying"] as? Bool ?? false
                            )
                        }

                        if genre.lowercased() == "all" {
                            self.delegate?.didReceiveArtists(artists, for: "All")
                        } else {
                            self.delegate?.didReceiveArtists(artists, for: genre)
                        }

                        NotificationCenter.default.post(name: Notification.Name("RemoteRequestFinished"), object: nil)
                    }

                case "artistsBatch":
                    if let arr = dict["data"] as? [[String: Any]],
                       let genre = dict["genre"] as? String {
                        let newArtists = arr.map {
                            RemoteArtist(
                                artistName: $0["name"] as? String ?? "",
                                artworkBase64: $0["artworkBase64"] as? String,
                                isPlaying: $0["isPlaying"] as? Bool ?? false
                            )
                        }

                        if genre.lowercased() == "all" {
                            self.delegate?.didReceiveArtists(newArtists, for: "All")
                        } else {
                            self.delegate?.didReceiveArtists(newArtists, for: genre)
                        }
                    }
                    
                case "artistArtworks":
                    guard self.currentArtworkTask == "artists" else {
                        print("🛑 Ignored artistArtworks (not active request)")
                        return
                    }
                    self.currentArtworkTask = nil
                    if let arr = dict["data"] as? [[String: Any]] {
                        for item in arr {
                            if let artist = item["artistName"] as? String,
                               let b64 = item["artworkBase64"] as? String {
                                NotificationCenter.default.post(
                                    name: Notification.Name("ArtistArtworkUpdated"),
                                    object: nil,
                                    userInfo: ["artistName": artist, "artworkBase64": b64]
                                )
                            }
                        }
                        print("🎨 Received \(arr.count) artist artworks")
                    }

                case "artistArtwork":
                    if let artistName = dict["artistName"] as? String,
                       let b64 = dict["artworkBase64"] as? String {
                        NotificationCenter.default.post(
                            name: Notification.Name("ArtistArtworkUpdated"),
                            object: nil,
                            userInfo: ["artistName": artistName, "artworkBase64": b64]
                        )
                    }
                    
                case "albums":
                    if let arr = dict["data"] as? [[String: Any]] {
                        let albums = arr.map {
                            RemoteAlbum(
                                id: $0["id"] as? String ?? "",
                                albumName: $0["albumName"] as? String ?? ($0["name"] as? String ?? ""),
                                artistName: $0["artistName"] as? String ?? ($0["artist"] as? String ?? ""),
                                artworkBase64: $0["artworkBase64"] as? String,
                                isPlaying: $0["isPlaying"] as? Bool ?? false
                            )
                        }

                        if let artistName = dict["artist"] as? String {
                            let remoteArtist = RemoteArtist(artistName: artistName, artworkBase64: nil, isPlaying: false)
                            self.delegate?.didReceiveAlbums(albums, for: remoteArtist)
                        } else if let genre = dict["genre"] as? String, genre.lowercased() == "all" {
                            let remoteArtist = RemoteArtist(artistName: "All", artworkBase64: nil, isPlaying: false)
                            self.delegate?.didReceiveAlbums(albums, for: remoteArtist)
                        }

                        NotificationCenter.default.post(name: Notification.Name("RemoteRequestFinished"), object: nil)
                    }

                case "albumsBatch":
                    if let arr = dict["data"] as? [[String: Any]] {
                        let newAlbums = arr.map {
                            RemoteAlbum(
                                id: $0["id"] as? String ?? "",
                                albumName: $0["albumName"] as? String ?? ($0["name"] as? String ?? ""),
                                artistName: $0["artistName"] as? String ?? ($0["artist"] as? String ?? ""),
                                artworkBase64: $0["artworkBase64"] as? String,
                                isPlaying: $0["isPlaying"] as? Bool ?? false
                            )
                        }

                        // Append instead of replacing
                        if let artistName = dict["artist"] as? String {
                            let remoteArtist = RemoteArtist(artistName: artistName, artworkBase64: nil, isPlaying: false)
                            self.delegate?.didReceiveAlbums(newAlbums, for: remoteArtist)
                        } else if let genre = dict["genre"] as? String, genre.lowercased() == "all" {
                            let remoteArtist = RemoteArtist(artistName: "All", artworkBase64: nil, isPlaying: false)
                            self.delegate?.didReceiveAlbums(newAlbums, for: remoteArtist)
                        }
                    }
                    
                case "albumArtworks":
                    guard self.currentArtworkTask == "albums" else {
                        print("🛑 Ignored albumArtworks (not active request)")
                        return
                    }
                    self.currentArtworkTask = nil
                    if let arr = dict["data"] as? [[String: Any]] {
                        for item in arr {
                            if let album = item["albumName"] as? String,
                               let b64 = item["artworkBase64"] as? String {
                                NotificationCenter.default.post(
                                    name: Notification.Name("AlbumArtworkUpdated"),
                                    object: nil,
                                    userInfo: ["albumName": album, "artworkBase64": b64]
                                )
                            }
                        }
                        print("🎨 Received \(arr.count) album artworks")
                    }
                    
                case "songs":
                    if let arr = dict["data"] as? [[String: Any]],
                       let albumName = dict["albumName"] as? String {
                        let songs = arr.map {
                            RemoteSong(
                                id: $0["id"] as? String ?? "",
                                title: $0["title"] as? String ?? "Unknown",
                                duration: $0["duration"] as? String ?? "",
                                artworkBase64: $0["artworkBase64"] as? String,
                                trackNumber: $0["trackNumber"] as? Int ?? 0
                            )
                        }
                        NotificationCenter.default.post(name: Notification.Name("SongsUpdated"), object: nil,
                            userInfo: ["albumName": albumName, "songs": songs])
                        NotificationCenter.default.post(name: Notification.Name("RemoteRequestFinished"), object: nil)
                    }

                case "nowPlaying":
                    self.delegate?.didReceiveNowPlaying(dict)

                case "progress":
                    if let current = dict["currentTime"] as? Double,
                       let duration = dict["duration"] as? Double {
                        self.delegate?.didReceiveProgress(currentTime: current, duration: duration)
                    }

                case "playbackState":
                    if let isPlaying = dict["isPlaying"] as? Bool {
                        self.delegate?.didReceivePlaybackState(isPlaying: isPlaying)
                    }

                case "searchResults":
                    if let results = dict["songs"] as? [[String: Any]] {
                        self.delegate?.didReceiveSearchResults(results)
                    } else {
                        print("⚠️ Could not parse searchResults: \(dict["songs"] ?? "nil")")
                    }

                default:
                    print("⚠️ Unknown JSON type: \(type)")
                }
            }

        } else if let message = String(data: data, encoding: .utf8) {
            // Handle simple text commands (non-JSON)
            print("📩 Received plain message: \(message)")
            if message == "connected" {
                DispatchQueue.main.async {
                    self.delegate?.didChangeConnection(connected: true)
                }
            }
        } else {
            print("⚠️ Received undecodable data (\(data.count) bytes)")
        }
    }
    // Required stubs
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
    
    func startBrowsing() {
        if isBrowsing {
            print("⚠️ Already browsing, ignoring startBrowsing()")
            return
        }
        invitedPeers.removeAll()
        browser.startBrowsingForPeers()
        isBrowsing = true
        print("🔍 Started browsing for peers")
    }
    
    func stopBrowsing() {
        guard isBrowsing else { return }
        browser.stopBrowsingForPeers()
        isBrowsing = false
        print("🛑 Stopped browsing for peers")
    }
    
    func clearOldServers() {
        discoveredPeers.removeAll()
    }
    
    func requestAllArtistArtworks() {
        cancelArtworkRequest() // 🛑 stop any previous one
        currentArtworkTask = "artists"
        sendCommand("getAllArtistArtworks")
    }

    func requestAllAlbumArtworks() {
        cancelArtworkRequest()
        currentArtworkTask = "albums"
        sendCommand("getAllAlbumArtworks")
    }

    func cancelArtworkRequest() {
        if currentArtworkTask != nil {
            print("🛑 Cancelling artwork request: \(currentArtworkTask!)")
            currentArtworkTask = nil
        }
    }
    
}
