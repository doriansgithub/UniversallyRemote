//
//  ViewController.swift
//  UniversallyRemote
//
//  Created by Dorian Mattar on 9/4/25.
//

import UIKit

class ViewController: UIViewController, RemotePeerManagerDelegate, UITableViewDataSource, UITableViewDelegate {
    
    @IBOutlet weak var genresView: UIView!
    private var genresCollectionVC: GenresCollectionVC?
    
    @IBOutlet weak var artistsView: UIView!
    private var artistsCollectionVC: ArtistsCollectionVC?

    @IBOutlet weak var albumsView: UIView!
    private var albumsCollectionVC: AlbumsCollectionVC?

    @IBOutlet weak var allSongsView: UIView!
    @IBOutlet weak var songsTableView: UITableView!
    @IBOutlet weak var controls: UIView!
    @IBOutlet weak var browserStatusBackground: UIImageView!
    @IBOutlet weak var homeGenreBackground: UIImageView!
    @IBOutlet weak var homeGenreButton: UIButton!
    @IBOutlet weak var progressIndicator: UIActivityIndicatorView!
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var pauseButton: UIButton!
    @IBOutlet weak var nextButton: UIButton!
    @IBOutlet weak var previousButton: UIButton!
    @IBOutlet weak var browseButton: UIButton!
    @IBOutlet weak var artistButton: UIButton!
    @IBOutlet weak var albumButton: UIButton!
    @IBOutlet weak var searchButton: UIButton!
    @IBOutlet weak var searchFieldView: UIView!
    @IBOutlet weak var songLabel: UILabel!
    @IBOutlet weak var artistLabel: UILabel!
    @IBOutlet weak var albumLabel: UILabel!
    @IBOutlet weak var lengthLabel: UILabel!
    @IBOutlet weak var remainingLabel: UILabel!

    @IBOutlet weak var homeGenreONBackground: UIImageView!
    @IBOutlet weak var homeArtistsONBackground: UIImageView!
    @IBOutlet weak var homeAlbumsONBackground: UIImageView!
    @IBOutlet weak var homeSearchONBackground: UIImageView!

    
    @IBOutlet weak var searchBarView: UISearchBar!
    private var searchResults: [[String: Any]] = []

    @IBOutlet weak var slider: UISlider!
    
    var isHomeGenreSelected: Bool = false
    private var didRequestGenresOnConnect = false
    private var lastConnectionState: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()

        hideAllViews()
        progressIndicator.isHidden = true
        didRequestGenresOnConnect = false
        lastConnectionState = false
        
        NotificationCenter.default.addObserver(self, selector: #selector(requestStarted), name: Notification.Name("RemoteRequestStarted"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(requestFinished), name: Notification.Name("RemoteRequestFinished"), object: nil)

        searchBarView.delegate = self
        searchBarView.returnKeyType = .search
        RemotePeerManager.shared.delegate = self
        
        // ✅ Table setup
        songsTableView.backgroundColor = .clear
        songsTableView.dataSource = self
        songsTableView.delegate = self
        songsTableView.register(UITableViewCell.self, forCellReuseIdentifier: "SearchResultCell")
        songsTableView.register(SongResultCell.self, forCellReuseIdentifier: "SongResultCell")
        
        playButton.isHidden = false
        pauseButton.isHidden = true
        self.setButtonsDisabled()
        
        searchBarView.searchBarStyle = .minimal
        searchBarView.isTranslucent = true
        searchBarView.backgroundImage = UIImage()
        
        // Embed GenresCollectionVC
        loadArtists()
        loadAlbums()
        loadGenres()
        
        self.setBrowseButtonIdleAppearance()
//        getAllGenres()
    }
    
    @objc private func requestStarted() {
        progressIndicator.startAnimating()
        progressIndicator.isHidden = false
    }

    @objc private func requestFinished() {
        progressIndicator.isHidden = true
        progressIndicator.stopAnimating()
    }
    
    func loadGenres() {
        let genresVC = GenresCollectionVC()
        addChild(genresVC)
        genresVC.view.frame = genresView.bounds
        genresVC.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        genresView.addSubview(genresVC.view)
        genresVC.didMove(toParent: self)

        self.genresCollectionVC = genresVC
    }
    
    func loadArtists() {
        let artistsVC = ArtistsCollectionVC()
        addChild(artistsVC)
        artistsVC.view.frame = artistsView.bounds
        artistsVC.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        artistsView.addSubview(artistsVC.view)
        artistsVC.didMove(toParent: self)

        self.artistsCollectionVC = artistsVC
    }
    
    func loadAlbums() {
        let albumsVC = AlbumsCollectionVC()
        addChild(albumsVC)
        albumsVC.view.frame = albumsView.bounds
        albumsVC.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        albumsView.addSubview(albumsVC.view)
        albumsVC.didMove(toParent: self)

        self.albumsCollectionVC = albumsVC
    }
    
    // MARK: - RemotePeerManagerDelegate

    func didReceiveNowPlaying(_ info: [String: Any]) {
        DispatchQueue.main.async {
            self.songLabel.text = info["songName"] as? String ?? "-"
            self.artistLabel.text = info["artistName"] as? String ?? "-"
            self.albumLabel.text = info["albumName"] as? String ?? "-"
        }
    }

    func didReceiveProgress(currentTime: Double, duration: Double) {
        DispatchQueue.main.async {
            let elapsed = self.formatTime(currentTime)
            let total   = self.formatTime(duration)

            // 🎵 Show total length
            self.lengthLabel.text = total
            
            // 🎵 Show elapsed time (even though it's called remainingLabel)
            self.remainingLabel.text = elapsed
        }
    }
    
    func didReceiveSearchResults(_ results: [[String: Any]]) {
        DispatchQueue.main.async {
            self.searchResults = results
            self.songsTableView.reloadData()
            
            print("🎯 searchResults count = \(self.searchResults.count)")
            print("🎯 songsTableView frame = \(self.songsTableView.frame)")
            
            NotificationCenter.default.post(name: Notification.Name("RemoteRequestFinished"), object: nil)
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        print ("searchResults count:", searchResults.count)
        return searchResults.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SearchResultCell", for: indexPath)
        let song = searchResults[indexPath.row]
        let songName = song["songName"] as? String ?? "-"
        let artist   = song["artistName"] as? String ?? "-"
        let album    = song["albumName"] as? String ?? "-"
        let id       = song["id"] ?? ""

        cell.textLabel?.text = "\(songName)\n\(artist) (\(album))"
        cell.textLabel?.numberOfLines = 3
        cell.backgroundColor = .clear
        
        // ✅ Add 12pt spacing before the button
        cell.textLabel?.frame = CGRect(
            x: 16,
            y: cell.textLabel?.frame.origin.y ?? 0,
            width: tableView.bounds.width - 80, // subtract button + margin
            height: cell.textLabel?.frame.height ?? 44
        )

        // 🔹 Add to Queue Button using your existing UIAction
        let addAction = UIAction(title: "Add to Queue",
                                 image: UIImage(systemName: "text.badge.plus")) { _ in
            RemotePeerManager.shared.sendCommand("addSongToQueue:\(id)")
            print("🎶 Added to queue: \(songName)")
        }

        let button = UIButton(type: .system)
        button.menu = UIMenu(children: [addAction])
        button.showsMenuAsPrimaryAction = true
        button.setImage(UIImage(systemName: "text.badge.plus"), for: .normal)
        button.tintColor = .systemBlue
        button.translatesAutoresizingMaskIntoConstraints = false
        cell.contentView.addSubview(button)

        NSLayoutConstraint.activate([
            button.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
            button.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
            button.widthAnchor.constraint(equalToConstant: 30),
            button.heightAnchor.constraint(equalToConstant: 30)
        ])

        // ✅ Custom highlight background
        let highlightView = UIView()
        highlightView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.2)
        cell.selectedBackgroundView = highlightView

        return cell
    }
    
    // MARK: - TableView Delegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        print("✅ didSelectRowAt fired, row=\(indexPath.row)")

        tableView.endEditing(true) // dismiss keyboard
        
        let song = searchResults[indexPath.row]
        if let index = song["index"] as? Int {
            print("🎵 Selected index=\(index), song=\(song["songName"] ?? "?")")
            RemotePeerManager.shared.sendCommand("playSongAtIndex:\(index)")
        } else {
            print("⚠️ No index found for selection")
        }
    }

    // helper to format seconds → mm:ss
    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite else { return "0:00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    @IBAction func homeGenrePressed(_ sender: Any) {
        getAllGenres()
    }
    
    @IBAction func homeArtistsPressed(_ sender: Any) {
//        RemotePeerManager.shared.cancelArtworkRequest()
//        getAllArtists()
//        RemotePeerManager.shared.requestAllArtistArtworks()
        getAllArtists()
    }

    @IBAction func homeAlbumsPressed(_ sender: Any) {
//        RemotePeerManager.shared.cancelArtworkRequest()
//        RemotePeerManager.shared.requestAllAlbumArtworks()
        getAllAlbums()
    }
    
    @IBAction func homeSearchPressed(_ sender: Any) {
        RemotePeerManager.shared.cancelArtworkRequest()
        searchAllSongs()
    }
    
    func hideAllViews() {
        requestFinished()
        homeGenreONBackground.isHidden = true
        homeArtistsONBackground.isHidden = true
        homeAlbumsONBackground.isHidden = true
        homeSearchONBackground.isHidden = true
        genresView.isHidden = true
        allSongsView.isHidden = true
        albumsView.isHidden = true
        artistsView.isHidden = true
        allSongsView.isHidden = true
        searchFieldView.isHidden = true
    }
    
    func getAllGenres() {
        RemotePeerManager.shared.sendCommand("getGenres")
        hideAllViews()
        genresView.isHidden = false
        homeGenreONBackground.isHidden = false
    }
    
    func didReceiveGenres(_ genres: [String]) {
        DispatchQueue.main.async {
            self.genresCollectionVC?.updateGenres(genres)
            self.hideAllViews()
            self.genresView.isHidden = false
            self.homeGenreONBackground.isHidden = false
        }
    }
    
    func getAllArtists() {
//        // 🛑 Stop any ongoing transfers first
//        RemotePeerManager.shared.cancelArtworkRequest()
//        RemotePeerManager.shared.sendCommand("cancelBatchRequest")
//
//        // 🚀 Begin new batched artist loading
//        RemotePeerManager.shared.sendCommand("getAllArtistsBatch")

//        RemotePeerManager.shared.sendCommand("getArtistsForGenre:All")
        hideAllViews()
        artistsView.isHidden = false
        homeArtistsONBackground.isHidden = false
    }
    
    func didReceiveArtists(_ artists: [RemoteArtist], for genre: String) {
        DispatchQueue.main.async {
            self.artistsCollectionVC?.currentGenre = genre
            self.artistsCollectionVC?.updateArtists(artists)
            self.showLevel(.artists(genre))
        }
    }

    func didReceiveAlbums(_ albums: [RemoteAlbum], for artist: RemoteArtist) {
        DispatchQueue.main.async {
            self.albumsCollectionVC?.currentArtistName = artist.artistName
            self.albumsCollectionVC?.updateAlbums(albums, for: artist)
            self.showLevel(.albums(artist.artistName))
            
            // ✅ Check artwork cache and sync missing ones
            RemotePeerManager.shared.checkArtworkCacheAndSyncIfNeeded(allAlbums: albums)
        }
    }
    
    func getAllAlbums() {
//        // 🛑 Stop any ongoing transfers first
//        RemotePeerManager.shared.cancelArtworkRequest()
//        RemotePeerManager.shared.sendCommand("cancelBatchRequest")
//
//        // 🚀 Begin new batched album loading
//        RemotePeerManager.shared.sendCommand("getAllAlbumsBatch")
        
//        RemotePeerManager.shared.sendCommand("getAllAlbums")
        
        hideAllViews()
        albumsView.isHidden = false
        homeAlbumsONBackground.isHidden = false
    }
    
    func searchAllSongs() {
        hideAllViews()
        searchFieldView.isHidden = false
        allSongsView.isHidden = false
        homeSearchONBackground.isHidden = false
    }

    func didReceiveSongs(_ songs: [[String: Any]]) {
        DispatchQueue.main.async {
            self.searchResults = songs
            self.songsTableView.reloadData()
            self.showLevel(.songs("someAlbum"))
        }
    }
        
    func showLevel(_ level: BrowseLevel) {
        hideAllViews()

        switch level {
        case .genres:
            genresView.isHidden = false
        case .artists:
            artistsView.isHidden = false
            homeArtistsONBackground.isHidden = false
        case .albums:
            albumsView.isHidden = false
            homeAlbumsONBackground.isHidden = false
        case .songs:
            allSongsView.isHidden = false
            searchFieldView.isHidden = false
            homeSearchONBackground.isHidden = false
        }
        currentLevel = level
    }
    
    func didChangeConnection(connected: Bool) {
        // 👇 If the state hasn’t changed, ignore this call
        if connected == lastConnectionState { return }
        lastConnectionState = connected
        
        DispatchQueue.main.async {
            if RemotePeerManager.shared.hasConnectedPeers {
                self.setBrowseButtonConnectedAppearance()
                self.setButtonsEnabled()

                if !self.didRequestGenresOnConnect {
                    self.didRequestGenresOnConnect = true
                    self.getAllGenres()   // only once per connect
                }
            } else if RemotePeerManager.shared.isSearching {
                self.setBrowseButtonIdleAppearance()
                self.setButtonsDisabled()
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    guard let self = self else { return }
                    if RemotePeerManager.shared.hasConnectedPeers {
                        print("⚠️ Ignored false disconnect blip — still connected")
                        return
                    }
                    print("❌ Confirmed disconnect — disabling UI")
                    self.setBrowseButtonDisconnectedAppearance()
                    self.setButtonsDisabled()
                    self.didRequestGenresOnConnect = false  // reset for next session
                }
            }
        }
    }
    
    func setButtonsEnabled() {
        self.playButton.isEnabled = true
        self.pauseButton.isEnabled = true
        self.nextButton.isEnabled = true
        self.previousButton.isEnabled = true
        self.artistButton.isEnabled = true
        self.albumButton.isEnabled = true
        self.searchButton.isEnabled = true
    }
    
    func setButtonsDisabled() {
        self.playButton.isEnabled = false
        self.pauseButton.isEnabled = false
        self.nextButton.isEnabled = false
        self.previousButton.isEnabled = false
        self.artistButton.isEnabled = false
        self.albumButton.isEnabled = false
        self.searchButton.isEnabled = false
    }
    
    @objc func setBrowseButtonDisconnectedAppearance() {
        browserStatusBackground.image = UIImage(named: "ClientDisconnected")
    }
    
    @objc func setBrowseButtonConnectedAppearance() {
        browserStatusBackground.image = UIImage(named: "ClientConnected")
    }
    
    @objc func setBrowseButtonIdleAppearance() {
        browserStatusBackground.image = UIImage(named: "ClientSearching")
    }

    @IBAction func playButtonTapped(_ sender: UIButton) {
        print("▶️ Play button tapped")
        RemotePeerManager.shared.sendCommand("play")
        self.playButton.isHidden = true
        self.pauseButton.isHidden = false

    }

    @IBAction func pauseButtonTapped(_ sender: UIButton) {
        print("⏸ Pause button tapped")
        RemotePeerManager.shared.sendCommand("pause")
        self.playButton.isHidden = false
        self.pauseButton.isHidden = true

   }
    
    func didReceivePlaybackState(isPlaying: Bool) {
        DispatchQueue.main.async {
            print("📲 iOS received playback state: \(isPlaying)")
            
            if isPlaying && self.playButton.isHidden == false {
                // Only update if UI still shows Play
                self.playButton.isHidden = true
                self.pauseButton.isHidden = false
            } else if !isPlaying && self.pauseButton.isHidden == false {
                // Only update if UI still shows Pause
                self.playButton.isHidden = false
                self.pauseButton.isHidden = true
            } else {
                print("ℹ️ Ignored redundant playback state update")
            }
        }
    }
    
    @IBAction func nextButtonTapped(_ sender: UIButton) {
        print("⏭ Next button tapped")
        RemotePeerManager.shared.sendCommand("next")
    }

    @IBAction func previousButtonTapped(_ sender: UIButton) {
        print("⏮ Previous button tapped")
        RemotePeerManager.shared.sendCommand("previous")
    }
    
    @IBAction func refreshServerPressed(_ sender: Any) {
        RemotePeerManager.shared.clearOldServers()
        RemotePeerManager.shared.stopBrowsing()
        RemotePeerManager.shared.startBrowsing()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            
            let peers = RemotePeerManager.shared.discoveredPeers
            guard !peers.isEmpty else {
                let alert = UIAlertController(title: "No Servers Found",
                                              message: "Make sure your UniMac server is running.",
                                              preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true)
                return
            }
            
            let alert = UIAlertController(title: "Select Server", message: nil, preferredStyle: .actionSheet)
            for peer in peers {
                alert.addAction(UIAlertAction(title: peer.displayName, style: .default) { _ in
                    RemotePeerManager.shared.connect(to: peer)
                })
            }
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            self.present(alert, animated: true)
        }
    }
    
    func autoSelectOrPromptServer() {
        let peers = RemotePeerManager.shared.discoveredPeers
        
        guard !peers.isEmpty else {
            let alert = UIAlertController(title: "No Servers Found",
                                          message: "Make sure your UniMac server is running.",
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.present(alert, animated: true)
            return
        }
        
        if peers.count == 1 {
            // ✅ Auto-connect
            RemotePeerManager.shared.connect(to: peers[0])
            print("🔗 Auto-connected to \(peers[0].displayName)")
        } else {
            // ✅ Multiple → prompt as before
            let alert = UIAlertController(title: "Select Server", message: nil, preferredStyle: .actionSheet)
            for peer in peers {
                alert.addAction(UIAlertAction(title: peer.displayName, style: .default) { _ in
                    RemotePeerManager.shared.connect(to: peer)
                })
            }
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            self.present(alert, animated: true)
        }
    }

}

class SplashViewController: UIViewController {
    let logo = UIImageView(image: UIImage(named: "RemoteAppAppIconV4"))
    let background = UIImageView(image: UIImage(named: "AppsNebulaBackground2"))

    override func viewDidLoad() {
        super.viewDidLoad()

        // --- Background image
        let background = UIImageView(image: UIImage(named: "AppsNebulaBackground2"))
        background.contentMode = .scaleAspectFill
        background.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(background)
        
        NSLayoutConstraint.activate([
            background.topAnchor.constraint(equalTo: view.topAnchor),
            background.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            background.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            background.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        // --- Visual effect (blur) overlay
        let blurEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(blurView)

        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: view.topAnchor),
            blurView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            blurView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        // --- Logo (on top, unchanged)
        logo.contentMode = .scaleAspectFit
        logo.alpha = 0
        logo.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(logo)

        NSLayoutConstraint.activate([
            logo.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logo.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            logo.widthAnchor.constraint(equalToConstant: 200),
            logo.heightAnchor.constraint(equalToConstant: 200)
        ])
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // Fade in over 0.25s
        UIView.animate(withDuration: 0.25, animations: {
            self.logo.alpha = 1
        }) { _ in
            // Hold visible for 0.5s
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                // Fade out over 0.25s
                UIView.animate(withDuration: 0.25, animations: {
                    self.logo.alpha = 0
                }) { _ in
                    // After animation, swap to main VC
                    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                          let window = windowScene.windows.first else { return }

                    let storyboard = UIStoryboard(name: "Main", bundle: nil)
                    let mainVC = storyboard.instantiateInitialViewController() as! ViewController
                    let navController = UINavigationController(rootViewController: mainVC)

                    window.rootViewController = navController
                    window.makeKeyAndVisible()
                }
            }
        }
    }
    
}

extension ViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        let query = searchBar.text ?? ""
        
        if !query.isEmpty {
            RemotePeerManager.shared.sendCommand("search:\(query)")
        } else {
            print("⚠️ Empty query — ignoring search request")
        }
        NotificationCenter.default.post(name: Notification.Name("RemoteRequestStarted"), object: nil)
        
        // ✅ Always clear and dismiss
        searchBar.text = ""
        searchBar.resignFirstResponder()
        view.endEditing(true)
    }
}

class SongResultCell: UITableViewCell {
    let addButton = UIButton(type: .system)
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupButton()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupButton()
    }
    
    private func setupButton() {
        addButton.setTitle("➕ Queue", for: .normal)
        addButton.setTitleColor(.systemBlue, for: .normal)
        addButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        addButton.layer.cornerRadius = 6
        addButton.backgroundColor = UIColor.systemGray6
        addButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(addButton)
        
        NSLayoutConstraint.activate([
            addButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            addButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            addButton.widthAnchor.constraint(equalToConstant: 90),
            addButton.heightAnchor.constraint(equalToConstant: 32)
        ])
    }
    
}
