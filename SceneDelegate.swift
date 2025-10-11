//
//  SceneDelegate.swift
//  UniversallyRemote
//
//  Created by dorian on 9/13/25.
//

import Foundation
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        let window = UIWindow(windowScene: windowScene)

        // Start with Splash VC
        let splashVC = SplashViewController()
        window.rootViewController = splashVC

        self.window = window
        window.makeKeyAndVisible()
    }
}
