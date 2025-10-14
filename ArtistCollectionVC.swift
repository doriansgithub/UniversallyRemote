//
//  ArtistCollectionVC.swift
//  UniversallyRemote
//
//  Created by dorian on 10/3/25.
//

import Foundation
import UIKit

struct RemoteArtist {
    let artistName: String
    let artworkBase64: String?
    var isPlaying: Bool
}

class ArtistsCollectionVC: UIViewController {
    
    var collectionView: UICollectionView!
    var artists: [RemoteArtist] = []   // Filled by RemotePeerManager
    private var isFetchingArtwork = true
    var requestedArtworks = Set<String>()
    private var artworkRequestQueue = DispatchQueue(label: "artworkQueue", qos: .userInitiated)
    private var artworkRequestSemaphore = DispatchSemaphore(value: 6)
    var currentGenre: String = "All"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Artists"
        view.backgroundColor = .systemBackground
        setupCollectionView()
        isFetchingArtwork = true
        
        NotificationCenter.default.addObserver(
            forName: Notification.Name("ArtistArtworkUpdated"),
            object: nil,
            queue: .main
        ) { [weak self] notif in
            guard let self = self,
                  let userInfo = notif.userInfo,
                  let artistName = userInfo["artistName"] as? String,
                  let b64 = userInfo["artworkBase64"] as? String else { return }
            
            if let index = self.artists.firstIndex(where: { $0.artistName == artistName }) {
                // Update model for persistence
                self.artists[index] = RemoteArtist(
                    artistName: artistName,
                    artworkBase64: b64,
                    isPlaying: self.artists[index].isPlaying
                )

                // ✅ Decode once and save to unified cache (memory + disk)
                if let data = Data(base64Encoded: b64),
                   let image = UIImage(data: data) {
                    UnifiedArtworkCache.shared.store(image, for: artistName)

                    // ✅ Update visible cell directly (no reload, no re-request)
                    let indexPath = IndexPath(item: index, section: 0)
                    if let cell = self.collectionView.cellForItem(at: indexPath) as? ArtistCell {
                        cell.iconView.image = image
                    }
                }
            }
        }
        
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPressForArtist(_:)))
        collectionView.addGestureRecognizer(longPress)

    }
    
    func requestArtwork(for artistName: String) {
        artworkRequestQueue.async {
            self.artworkRequestSemaphore.wait()
            DispatchQueue.main.async {
                RemotePeerManager.shared.sendCommand("getArtistArtwork:\(artistName)")
            }
            Thread.sleep(forTimeInterval: 0.15) // small delay between requests
            self.artworkRequestSemaphore.signal()
        }
    }
    
    @objc private func handleLongPressForArtist(_ gesture: UILongPressGestureRecognizer) {
        let point = gesture.location(in: collectionView)
        guard let indexPath = collectionView.indexPathForItem(at: point) else { return }
        
        if gesture.state == .began {
            let artist = artists[indexPath.item]
            print("🔀 Shuffle artist: \(artist.artistName)")
            RemotePeerManager.shared.sendCommand("playArtist:\(artist.artistName)")
        }
    }

    private func setupCollectionView() {
        let layout = UICollectionViewFlowLayout()
        let spacing: CGFloat = 2
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
        collectionView.dataSource = self
        collectionView.delegate = self
        
        collectionView.register(ArtistCell.self, forCellWithReuseIdentifier: "ArtistCell")
        collectionView.isPrefetchingEnabled = false
        view.addSubview(collectionView)
    }
    
    func updateArtists(_ newArtists: [RemoteArtist]) {
        // ✅ Alphabetical sort by artistName
        artists = newArtists.sorted {
            $0.artistName.localizedCaseInsensitiveCompare($1.artistName) == .orderedAscending
        }
        
        collectionView.reloadData()
    }
}

// MARK: - UICollectionView DataSource & Delegate
extension ArtistsCollectionVC: UICollectionViewDataSource, UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return artists.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ArtistCell", for: indexPath) as! ArtistCell
        let artist = artists[indexPath.item]
        cell.titleLabel.text = artist.artistName

        if let b64 = artist.artworkBase64,
           let data = Data(base64Encoded: b64),
           let image = UIImage(data: data) {
            cell.iconView.image = image
        } else {
            cell.iconView.image = UIImage(named: "UniversallyLogoBWT")
            // ✅ Only send artwork request if fetching is still active
            if isFetchingArtwork {
                self.requestArtwork(for: artist.artistName)
//                RemotePeerManager.shared.sendCommand("getArtistArtwork:\(artist.artistName)")
            }
        }
        
        cell.setPlaying(artist.isPlaying)
        return cell
    }
    
    // Load visible cell artwork lazily from cache
    func collectionView(_ collectionView: UICollectionView,
                        willDisplay cell: UICollectionViewCell,
                        forItemAt indexPath: IndexPath) {
        let artist = artists[indexPath.item]
        guard let artistCell = cell as? ArtistCell else { return }

        // ✅ Try to get from unified cache (memory or disk)
        if let cached = UnifiedArtworkCache.shared.image(for: artist.artistName) {
            artistCell.iconView.image = cached
        } else {
            // 🧠 Request from Mac (throttled)
            artworkRequestQueue.async {
                self.artworkRequestSemaphore.wait()
                DispatchQueue.main.async {
                    RemotePeerManager.shared.sendCommand("getArtistArtwork:\(artist.artistName)")
                }
                Thread.sleep(forTimeInterval: 0.1)
                self.artworkRequestSemaphore.signal()
            }
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let offsetY = scrollView.contentOffset.y
        let contentHeight = scrollView.contentSize.height
        let frameHeight = scrollView.frame.size.height

        if offsetY > contentHeight - frameHeight * 2 {
            if currentGenre.lowercased() == "all" {
                RemotePeerManager.shared.sendCommand("getAllArtistsBatch")
            } else {
                RemotePeerManager.shared.sendCommand("getArtistsBatchForGenre:\(currentGenre)")
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let artist = artists[indexPath.item]
        print("🎤 Selected artist: \(artist.artistName)")
        isFetchingArtwork = false
        
        // 🛑 Cancel any ongoing artwork/batch requests
        RemotePeerManager.shared.cancelArtworkRequest()
        RemotePeerManager.shared.sendCommand("cancelBatchRequest")

        // ✅ Tell Mac to send albums for this artist
        NotificationCenter.default.post(name: Notification.Name("RemoteRequestStarted"), object: nil)
//        RemotePeerManager.shared.sendCommand("getAlbumsForArtist:\(artist.artistName)")
        requestAlbums(for: artist.artistName)
    }
    
    func requestAlbums(for artist: String) {
        RemotePeerManager.shared.currentArtworkTask = "albums"
        RemotePeerManager.shared.sendCommand("getAlbumsForArtist:\(artist)")
    }
    
}

// MARK: - Cell
class ArtistCell: UICollectionViewCell {
    let iconView = UIImageView()
    let titleLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        iconView.contentMode = .scaleAspectFill
        iconView.layer.cornerRadius = frame.width / 8
        iconView.clipsToBounds = true
        iconView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(iconView)
        
        titleLabel.textAlignment = .center
        titleLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 2
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            iconView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            iconView.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.7),
            iconView.heightAnchor.constraint(equalTo: iconView.widthAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 6),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 2),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -2)
        ])
    }
    
    func configure(with artist: RemoteArtist) {
        titleLabel.text = artist.artistName
        
        if let b64 = artist.artworkBase64,
           let data = Data(base64Encoded: b64),
           let image = UIImage(data: data) {
            iconView.image = image
        } else {
            iconView.image = UIImage(named: "UniversallyLogoBWT") // fallback
        }
        
        setPlaying(artist.isPlaying)
    }
    
    func setPlaying(_ isPlaying: Bool) {
        if isPlaying {
            iconView.layer.borderWidth = 3
            iconView.layer.borderColor = UIColor.green.cgColor
        } else {
            iconView.layer.borderWidth = 0
            iconView.layer.borderColor = nil
        }
        layer.borderWidth = isPlaying ? 2 : 0
        layer.borderColor = isPlaying ? UIColor.systemGreen.cgColor : UIColor.clear.cgColor
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
