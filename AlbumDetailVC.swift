//
//  AlbumDetailVC.swift
//  UniversallyRemote
//
//  Created by dorian on 10/3/25.
//

import Foundation
import UIKit

// MARK: - Remote Models
struct RemoteAlbum {
    let id: String
    let albumName: String
    let artistName: String
    var artworkBase64: String?
    var isPlaying: Bool
}

struct RemoteSong {
    let id: String
    let title: String
    let duration: String
    let artworkBase64: String?
    let trackNumber: Int
}

// MARK: - Album Detail VC
class AlbumDetailVC: UIViewController {
    
    var album: RemoteAlbum?   // passed in from AlbumsCollectionVC
    private var tableView: UITableView!
    
    var songs: [RemoteSong] = []   // Will be filled from RemotePeerManager
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = album?.albumName ?? "Album"
        
        setupTableView()
        NotificationCenter.default.addObserver(
            forName: Notification.Name("SongsUpdated"),
            object: nil,
            queue: .main
        ) { [weak self] notif in
            guard let self = self,
                  let userInfo = notif.userInfo,
                  let albumName = userInfo["albumName"] as? String,
                  albumName == self.album?.albumName, // only update this album
                  let newSongs = userInfo["songs"] as? [RemoteSong] else { return }
            
            self.songs = newSongs.sorted { $0.trackNumber < $1.trackNumber }
            self.tableView.reloadData()
        }
        loadSongsForAlbum()
        NotificationCenter.default.post(name: Notification.Name("RemoteRequestFinished"), object: nil)
    }
    
    private func setupTableView() {
        tableView = UITableView(frame: view.bounds, style: .plain)
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(SongCell.self, forCellReuseIdentifier: "SongCell")
        view.addSubview(tableView)
        
        if let album = album {
            let headerView = AlbumHeaderView(album: album, frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 250))
            tableView.tableHeaderView = headerView
        }
    }

    private func loadSongsForAlbum() {
        guard let album = album else { return }
        
        RemotePeerManager.shared.sendCommand("getSongsForAlbum:\(album.albumName)")
        print("📡 Requested songs for album: \(album.albumName)")
    }
}

// MARK: - UITableView DataSource & Delegate
extension AlbumDetailVC: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return songs.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SongCell", for: indexPath) as! SongCell
        let song = songs[indexPath.row]
        cell.configure(with: song)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let song = songs[indexPath.row]

        print("▶️ Play song: \(song.title)")

        // Send play command to Mac
        RemotePeerManager.shared.sendCommand("playSong:\(song.id)")

        tableView.deselectRow(at: indexPath, animated: true)
    }
}

// MARK: - Album Header (artwork + info)
class AlbumHeaderView: UIView {
    
    private let artworkButton = UIButton(type: .custom)
    private var album: RemoteAlbum

    init(album: RemoteAlbum, frame: CGRect) {
        self.album = album
        super.init(frame: frame)

        // --- Artwork as button
        artworkButton.imageView?.contentMode = .scaleAspectFill
        artworkButton.clipsToBounds = true
        artworkButton.layer.cornerRadius = 10
        artworkButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(artworkButton)

        if let b64 = album.artworkBase64,
           let data = Data(base64Encoded: b64),
           let img = UIImage(data: data) {
            artworkButton.setImage(img, for: .normal)
        } else {
            artworkButton.setImage(UIImage(named: "UniversallyLogoBWT"), for: .normal)
        }

        artworkButton.addTarget(self, action: #selector(playAlbumTapped), for: .touchUpInside)

        // --- Labels
        let titleLabel = UILabel()
        titleLabel.text = album.albumName
        titleLabel.font = UIFont.boldSystemFont(ofSize: 18)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        let artistLabel = UILabel()
        artistLabel.text = album.artistName
        artistLabel.font = UIFont.systemFont(ofSize: 14)
        artistLabel.textColor = .gray
        artistLabel.textAlignment = .center
        artistLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(artistLabel)

        NSLayoutConstraint.activate([
            artworkButton.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            artworkButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            artworkButton.widthAnchor.constraint(equalToConstant: 150),
            artworkButton.heightAnchor.constraint(equalTo: artworkButton.widthAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: artworkButton.bottomAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            
            artistLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            artistLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            artistLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10)
        ])
    }

    @objc private func playAlbumTapped() {
        RemotePeerManager.shared.sendCommand("playAlbum:\(album.albumName)")
        print("▶️ Play full album: \(album.albumName)")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Song Cell
class SongCell: UITableViewCell {
    private let titleLabel = UILabel()
    private let durationLabel = UILabel()
    private let menuButton = UIButton(type: .system)

    private var currentSong: RemoteSong?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        titleLabel.font = UIFont.systemFont(ofSize: 15)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        durationLabel.font = UIFont.systemFont(ofSize: 13)
        durationLabel.textColor = .gray
        durationLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(durationLabel)

        menuButton.setImage(UIImage(systemName: "ellipsis"), for: .normal)
        menuButton.showsMenuAsPrimaryAction = true
        menuButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(menuButton)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            titleLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -8),

            menuButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            menuButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            menuButton.widthAnchor.constraint(equalToConstant: 30),   // gives it a fixed size
            menuButton.heightAnchor.constraint(equalToConstant: 30),

            durationLabel.trailingAnchor.constraint(equalTo: menuButton.leadingAnchor, constant: -8),
            durationLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            durationLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 8)
        ])
        
    }

    func configure(with song: RemoteSong) {
        self.currentSong = song
        let num = song.trackNumber > 0 ? "\(song.trackNumber). " : ""
        titleLabel.text = "\(num)\(song.title)"
        durationLabel.text = song.duration

        menuButton.menu = UIMenu(children: [
            UIAction(title: "Add to Queue", image: UIImage(systemName: "text.badge.plus")) { _ in
                RemotePeerManager.shared.sendCommand("addSongToQueue:\(song.id)")
            }
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
