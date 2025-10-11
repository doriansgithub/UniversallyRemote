import UIKit

class SongsVC: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    private let tableView = UITableView()
    private var songs: [[String: Any]] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Songs"
        tableView.backgroundColor = .clear
        view.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SongCell")
        tableView.frame = view.bounds
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(tableView)
        
    }
    
    // MARK: - Public API
    
    func updateSongs(_ newSongs: [[String: Any]]) {
        self.songs = newSongs
        tableView.reloadData()
    }

    // MARK: - TableView DataSource
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return songs.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SongCell", for: indexPath)
        let song = songs[indexPath.row]
        let songName = song["songName"] as? String ?? "-"
        let artist   = song["artistName"] as? String ?? "-"
        let album    = song["albumName"] as? String ?? "-"
        cell.textLabel?.text = "\(songName) – \(artist) (\(album))"
        cell.textLabel?.numberOfLines = 2
        return cell
    }
    
    // MARK: - TableView Delegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // ✅ dismiss keyboard
        tableView.endEditing(true)

        let song = songs[indexPath.row]
        if let index = song["index"] as? Int {
            print("🎵 Selected index=\(index), song=\(song["songName"] ?? "?")")
            RemotePeerManager.shared.sendCommand("playSongAtIndex:\(index)")
        } else {
            print("⚠️ No index found for selection")
        }
    }
    
}


