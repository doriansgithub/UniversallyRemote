//
//  ViewController.swift
//  UniversallyRemote
//
//  Created by Dorian Mattar on 9/4/25.
//

import UIKit

class ViewController: UIViewController {
    
    @IBOutlet weak var genresView: UIView!
    @IBOutlet weak var songs: UIView!
    @IBOutlet weak var controls: UIView!
    
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var pauseButton: UIButton!
    @IBOutlet weak var nextButton: UIButton!
    @IBOutlet weak var previousButton: UIButton!
    @IBOutlet weak var forward15SecButton: UIButton!
    @IBOutlet weak var rewind15SecButton: UIButton!
    @IBOutlet weak var browseButton: UIButton!

    @IBOutlet weak var songLabel: UILabel!
    @IBOutlet weak var artistLabel: UILabel!
    @IBOutlet weak var albumLabel: UILabel!
    @IBOutlet weak var albumYearLabel: UILabel!
    @IBOutlet weak var lengthLabel: UILabel!
    @IBOutlet weak var remainingLabel: UILabel!

    @IBOutlet weak var slider: UISlider!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        
    }
    
    @IBAction func browseButtonTapped(_ sender: UIButton) {
        print("▶️ Play button tapped")
        if RemotePeerManager.shared.isBrowsing {
            RemotePeerManager.shared.stopBrowsing()
            browseButton.setTitle("Start Browsing", for: .normal)
        } else {
            RemotePeerManager.shared.startBrowsing()
            browseButton.setTitle("Stop Browsing", for: .normal)
        }
    
    }
    
    @IBAction func playButtonTapped(_ sender: UIButton) {
        print("▶️ Play button tapped")
        // Hook into RemotePeerManager or playback logic here
    
    }
    
    @IBAction func pauseButtonTapped(_ sender: UIButton) {
        print("▶️ Pause button tapped")
        // Hook into RemotePeerManager or playback logic here
    }
    
    @IBAction func nextButtonTapped(_ sender: UIButton) {
        print("▶️ Next button tapped")
        // Hook into RemotePeerManager or playback logic here
    }
    
    @IBAction func previousButtonTapped(_ sender: UIButton) {
        print("▶️ Previous button tapped")
        // Hook into RemotePeerManager or playback logic here
    }
    
    @IBAction func forwardButtonTapped(_ sender: UIButton) {
        print("▶️ Forward button tapped")
        // Hook into RemotePeerManager or playback logic here
    }
    
    @IBAction func backButtonTapped(_ sender: UIButton) {
        print("▶️ Back button tapped")
        // Hook into RemotePeerManager or playback logic here
    }
    

}

class SplashViewController: UIViewController {
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // Show splash for 1 second
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            guard let windowScene = UIApplication.shared
                    .connectedScenes
                    .first as? UIWindowScene,
                  let window = windowScene.windows.first else { return }

            // ✅ Load the storyboard-based ViewController
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let mainVC = storyboard.instantiateInitialViewController() as! ViewController
            let navController = UINavigationController(rootViewController: mainVC)

            window.rootViewController = navController
            window.makeKeyAndVisible()
        }
    }
}
