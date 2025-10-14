//
//  GenresCollectionViewController.swift
//  UniversallyRemote
//

import UIKit

class GenresCollectionVC: UIViewController {
    
    var collectionView: UICollectionView!
    var genres: [String] = []   // Will be filled from RemotePeerManager
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Genres"
        view.backgroundColor = .systemBackground

        setupCollectionView()

        // Add long press gesture
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        collectionView.addGestureRecognizer(longPress)
        RemotePeerManager.shared.stopBrowsing() // optional, stop after connecting
    }
    
    private func setupCollectionView() {
        let layout = UICollectionViewFlowLayout()
        let spacing: CGFloat = 2

        // Tell the layout: "I want 264x300-ish cells, fit as many as you can"
        layout.itemSize = CGSize(width: 200, height: 250) // 264 image + label
        layout.estimatedItemSize = .zero   // prevent auto-resize
        layout.sectionInset = UIEdgeInsets(top: spacing, left: spacing, bottom: spacing, right: spacing)
        layout.minimumInteritemSpacing = spacing
        layout.minimumLineSpacing = spacing * 1.5

        collectionView = UICollectionView(frame: view.bounds, collectionViewLayout: layout)
        collectionView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        collectionView.backgroundColor = .clear
        view.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(GenreCell.self, forCellWithReuseIdentifier: "GenreCell")
        view.addSubview(collectionView)
    }
    
    func updateGenres(_ newGenres: [String]) {
        genres = newGenres
        collectionView.reloadData()
        NotificationCenter.default.post(name: Notification.Name("RemoteRequestFinished"), object: nil)
    }
    
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        let point = gesture.location(in: collectionView)
        guard let indexPath = collectionView.indexPathForItem(at: point) else { return }
        if gesture.state == .began {
            let genre = genres[indexPath.item]
            print("🔀 Shuffle genre: \(genre)")
            RemotePeerManager.shared.sendCommand("playGenre:\(genre)") // already working shuffle
        }
    }
    
}

// MARK: - UICollectionView DataSource & Delegate
extension GenresCollectionVC: UICollectionViewDataSource, UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return genres.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "GenreCell", for: indexPath) as! GenreCell
        let genre = genres[indexPath.item]
        
        // Map to broad genre + artwork
        if let broadGenre = getBroadGenre(for: genre),
           let artworkName = genreArtwork[broadGenre] {
            cell.iconView.image = UIImage(named: artworkName)
        } else {
            cell.iconView.image = UIImage(named: "HomeGenreDefault") // fallback
        }
        
        // Background styling
        cell.background1.image = UIImage(named: "WhiteHomeGenreOff")
        cell.background2.image = UIImage(named: "HomeGenreCircle") // placeholder
        
        // Label
        cell.titleLabel.text = genre
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let genre = genres[indexPath.item]
        print("🎵 Selected genre: \(genre)")
        NotificationCenter.default.post(name: Notification.Name("RemoteRequestStarted"), object: nil)
        requestArtists(for: genre)
    }
    
    func requestArtists(for genre: String) {
        RemotePeerManager.shared.currentArtworkTask = "artists"
        RemotePeerManager.shared.sendCommand("getArtistsForGenre:\(genre)")
        RemotePeerManager.shared.sendCommand("getArtistArtwork:\(genre)")
    }
    
    func getBroadGenre(for genre: String) -> String? {
        for (broadGenre, variations) in genreVCMappings {
            if variations.contains(genre) {
                return broadGenre
            }
        }
        return nil
    }
}

class GenreCell: UICollectionViewCell {
    let background1 = UIImageView()
    let background2 = UIImageView()
    let iconView = UIImageView()
    let titleLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        // --- Background 2 (outer circle)
        background2.contentMode = .scaleAspectFill
        background2.clipsToBounds = true
        background2.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(background2)
        
        // --- Background 1 (inner circle)
        background1.contentMode = .scaleAspectFill
        background1.clipsToBounds = true
        background1.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(background1)
        
        // --- Icon
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(iconView)
        
        // --- Label
        titleLabel.textAlignment = .center
        titleLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 2
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)
        
        // --- Layout
        NSLayoutConstraint.activate([
            background2.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            background2.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: -10),
            background2.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.9),
            background2.heightAnchor.constraint(equalTo: background2.widthAnchor),
            
            background1.centerXAnchor.constraint(equalTo: background2.centerXAnchor),
            background1.centerYAnchor.constraint(equalTo: background2.centerYAnchor),
            background1.widthAnchor.constraint(equalTo: background2.widthAnchor, multiplier: 0.8),
            background1.heightAnchor.constraint(equalTo: background1.widthAnchor),
            
            iconView.centerXAnchor.constraint(equalTo: background1.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: background1.centerYAnchor),
            iconView.widthAnchor.constraint(equalTo: background1.widthAnchor, multiplier: 0.8),
            iconView.heightAnchor.constraint(equalTo: iconView.widthAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: background2.bottomAnchor, constant: 6),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 2),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -2)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        background1.layer.cornerRadius = background1.frame.width / 2
        background2.layer.cornerRadius = background2.frame.width / 2
        background1.layer.masksToBounds = true
        background2.layer.masksToBounds = true
    }
    
}
