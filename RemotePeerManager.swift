//
//  RemotePeerManager.swift
//  UniversallyRemote
//
//  Created by Dorian Mattar on 9/4/25.
//

import Foundation
import MultipeerConnectivity
import UIKit

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
    var reconnectTimer: Timer?
    
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
    var currentArtworkTask: String?
    
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
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    if !self.pendingCommands.isEmpty {
                        print("📤 Flushing \(self.pendingCommands.count) queued commands")
                        for cmd in self.pendingCommands {
                            self.sendCommand(cmd)
                        }
                        self.pendingCommands.removeAll()
                    } else {
                        // If no pending, start with genres after small delay
                        self.delegate?.getAllGenres()
                    }
                }
                
            case .connecting:
                print("⏳ Connecting to \(peerID.displayName)...")
                // Optional: notify delegate/UI if you want to show "connecting" state
                self.delegate?.didChangeConnection(connected: false)
                
            case .notConnected:
                print("❌ Disconnected from \(peerID.displayName)")
                self.delegate?.didChangeConnection(connected: false)
                
                //                self.startAutoReconnectTimer()  // 🚀 start periodic check if disconnected
                
            @unknown default:
                print("⚠️ Unknown state: \(state.rawValue)")
                self.delegate?.didChangeConnection(connected: false)
            }
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
    
    func cancelArtworkRequest() {
        if currentArtworkTask != nil {
            print("🛑 Cancelling artwork request: \(currentArtworkTask!)")
            currentArtworkTask = nil
        }
    }
    
    func startAutoReconnectTimer() {
        reconnectTimer?.invalidate()
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // Only try if not connected
            if !self.hasConnectedPeers {
                print("🔄 Auto-reconnect check — no peers connected, restarting browser…")
                self.browser.stopBrowsingForPeers()
                self.browser.startBrowsingForPeers()
            }
        }
        RunLoop.main.add(reconnectTimer!, forMode: .common)
    }
    
    func stopAutoReconnectTimer() {
        reconnectTimer?.invalidate()
        reconnectTimer = nil
    }
    
}
