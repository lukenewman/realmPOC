//
//  AppDelegate.swift
//  realm
//
//  Created by Luke Newman on 1/13/20.
//  Copyright © 2020 Luke Newman. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions:[UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {

        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = UINavigationController(rootViewController: ViewController(style: .plain))
        window?.makeKeyAndVisible()
        
        return true
    }

}
