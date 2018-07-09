//
//  AppDelegate.swift
//  StartLiveStream
//
//  Created by Aziz on 2018-06-22.
//  Copyright © 2018 Aziz. All rights reserved.
//

import UIKit
import Parse

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

  var window: UIWindow?

  
  let serverURL = "http://ec2-18-220-194-44.us-east-2.compute.amazonaws.com:1337/parse"
  let appID = "dreamstream"

  func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
    
    
    window = UIWindow(frame: UIScreen.main.bounds)
    window?.makeKeyAndVisible()
    
    window?.rootViewController = ViewController()
    
    
    Parse.initialize(with: ParseClientConfiguration(block: { (config) in
      config.applicationId = self.appID
      config.server = self.serverURL
    }))
    
    return true
  }
}

