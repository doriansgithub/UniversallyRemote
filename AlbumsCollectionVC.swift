//
//  AlbumsCollectionVC.swift
//  UniversallyRemote
//
//  Created by dorian on 10/3/25.
//

import Foundation
import UIKit

class AlbumsCollectionVC: UIViewController {
    
    var collectionView: UICollectionView!
    var albums: [RemoteAlbum] = []
    var artist: RemoteArtist?
    var selectedArtist: RemoteArtist?
    private var isFetchingArtwork = true
    var requestedArtworks = Set<String>()
    private var artworkRequestQueue = DispatchQueue(label: "artworkQueue", qos: .userInitiated)
    private var artworkRequestSemaphore = DispatchSemaphore(value: 6)
    var currentArtistName: String = "All"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = selectedArtist?.artistName ?? "Albums"
        view.backgroundColor = .systemBackground
        setupCollectionView()
        isFetchingArtwork = true

        NotificationCenter.default.addObserver(
            forName: Notification.Name("AlbumArtworkUpdated"),
            object: nil,
            queue: .main
        ) { [weak self] notif in
            guard let self = self,
                  let userInfo = notif.userInfo,
                  let albumName = userInfo["albumName"] as? String,
                  let b64 = userInfo["artworkBase64"] as? String else { return }

            if let index = self.albums.firstIndex(where: { $0.albumName == albumName }) {
                // Update model
                self.albums[index].artworkBase64 = b64

                // ✅ Update only visible cell
                let indexPath = IndexPath(item: index, section: 0)
                if let cell = self.collectionView.cellForItem(at: indexPath) as? AlbumCell {
                    if let data = Data(base64Encoded: b64),
                       let image = UIImage(data: data) {
                        cell.artworkView.image = image

                        // ✅ Save to unified cache (memory + disk)
                        UnifiedArtworkCache.shared.store(image, for: albumName)
                    }
                }
            }
        }
        
        // Add long press gesture
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        collectionView.addGestureRecognizer(longPress)
        NotificationCenter.default.post(name: Notification.Name("RemoteRequestFinished"), object: nil)
    }
    
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        let point = gesture.location(in: collectionView)
        guard let indexPath = collectionView.indexPathForItem(at: point) else { return }
        if gesture.state == .began {
            let album = albums[indexPath.item]
            print("🔀 Shuffle genre: \(album)")
            RemotePeerManager.shared.sendCommand("playAlbum:\(album.albumName)")
        }
    }
    
    func updateAlbums(_ newAlbums: [RemoteAlbum], for artist: RemoteArtist) {
        self.selectedArtist = artist
        
        // ✅ Sort alphabetically by album name
        self.albums = newAlbums.sorted {
            $0.albumName.localizedCaseInsensitiveCompare($1.albumName) == .orderedAscending
        }
        
        self.title = artist.artistName
        collectionView.reloadData()
    }
    
    func requestArtwork(for albumName: String) {
        artworkRequestQueue.async {
            self.artworkRequestSemaphore.wait()
            DispatchQueue.main.async {
                RemotePeerManager.shared.sendCommand("getAlbumArtwork:\(albumName)")
            }
            Thread.sleep(forTimeInterval: 0.15) // small delay
            self.artworkRequestSemaphore.signal()
        }
    }

    private func setupCollectionView() {
        
        let layout = UICollectionViewFlowLayout()
        let spacing: CGFloat = 12
        let totalSpacing = spacing * 2
        let itemWidth = (view.bounds.width - totalSpacing) / 4
        
        layout.itemSize = CGSize(width: itemWidth, height: itemWidth + 40)
        layout.sectionInset = UIEdgeInsets(top: spacing, left: spacing, bottom: spacing, right: spacing)
        layout.minimumInteritemSpacing = spacing
        layout.minimumLineSpacing = spacing * 2
                
        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.backgroundColor = .clear
        collectionView.backgroundColor = .clear
        collectionView.isPrefetchingEnabled = false
        collectionView.dataSource = self
        collectionView.delegate = self
        
        collectionView.register(AlbumCell.self, forCellWithReuseIdentifier: "AlbumCell")

        view.addSubview(collectionView)
    }
    
}

// MARK: - UICollectionView DataSource & Delegate
// MARK: - UICollectionView DataSource & Delegate
extension AlbumsCollectionVC: UICollectionViewDataSource, UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return albums.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "AlbumCell", for: indexPath) as! AlbumCell
        let album = albums[indexPath.item]
        // Artwork (placeholder until you load real image from artworkURL)
        if let b64 = album.artworkBase64,
           let data = Data(base64Encoded: b64),
           let image = UIImage(data: data) {
            cell.artworkView.image = image
        } else {
            cell.artworkView.image = UIImage(named: "UniversallyLogoBWT")
            if isFetchingArtwork {
                if !requestedArtworks.contains(album.albumName) {
                    //                    requestedArtworks.insert(album.albumName)
                    self.requestArtwork(for: album.albumName)
                    //                    RemotePeerManager.shared.sendCommand("getAlbumArtwork:\(album.albumName)")
                }
            }
        }
        
        // Labels
        cell.titleLabel.text = album.albumName
        cell.artistLabel.text = album.artistName
        
        // Highlight playing album
        cell.layer.borderWidth = album.isPlaying ? 2 : 0
        cell.layer.borderColor = album.isPlaying ? UIColor.systemGreen.cgColor : UIColor.clear.cgColor
        
        return cell
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // No need for batch fetches anymore
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let album = albums[indexPath.item]
        print("💿 Selected album: \(album.albumName) by \(album.artistName)")
        isFetchingArtwork = false
        
        // 🛑 Cancel ongoing artwork/batch requests before loading details
        RemotePeerManager.shared.cancelArtworkRequest()
        RemotePeerManager.shared.sendCommand("cancelBatchRequest")
        
        // ✅ Proceed to album details
        let detailVC = AlbumDetailVC()
        detailVC.album = album
        navigationController?.pushViewController(detailVC, animated: true)
    }
}

// MARK: - Album Cell
class AlbumCell: UICollectionViewCell {
    let artworkView = UIImageView()
    let titleLabel = UILabel()
    let artistLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        artworkView.contentMode = .scaleAspectFill
        artworkView.layer.cornerRadius = 22
        artworkView.clipsToBounds = true
        artworkView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(artworkView)
        
        titleLabel.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 2
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)
        
        artistLabel.font = UIFont.systemFont(ofSize: 11, weight: .regular)
        artistLabel.textColor = .lightGray
        artistLabel.numberOfLines = 1
        artistLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(artistLabel)
        
        NSLayoutConstraint.activate([
            artworkView.topAnchor.constraint(equalTo: contentView.topAnchor),
            artworkView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            artworkView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            artworkView.heightAnchor.constraint(equalTo: artworkView.widthAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: artworkView.bottomAnchor, constant: 4),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 2),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -2),
            
            artistLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            artistLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 2),
            artistLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -2),
            artistLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -2)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
