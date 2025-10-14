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
                    
                case "albumArtwork":
                    // Data is nested under "data"
                    if let inner = dict["data"] as? [String: Any],
                       let albumName = inner["albumName"] as? String,
                       let b64 = inner["artworkBase64"] as? String {
                        
                        NotificationCenter.default.post(
                            name: Notification.Name("AlbumArtworkUpdated"),
                            object: nil,
                            userInfo: ["albumName": albumName, "artworkBase64": b64]
                        )
                        print("🎨 Received artwork for album \(albumName) (\(b64.count) chars)")
                    } else {
                        print("⚠️ Could not parse albumArtwork payload: \(dict)")
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
    
}
