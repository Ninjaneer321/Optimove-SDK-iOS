  //
  //  AppDelegate.swift
  //  OptimoveSDKDev
  //
  //  Created by Mobile Developer Optimove on 05/09/2017.
  //  Copyright © 2017 Optimove. All rights reserved.
  //
  
  import UIKit
  import OptimoveSDK
  
  @UIApplicationMain
  class AppDelegate: UIResponder,
    UIApplicationDelegate
  {
    
    var window: UIWindow?
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        
        let appController = "https://appcontrollerproject-developer.firebaseapp.com"
        let cdn = "https://sdk-cdn.optimove.net"
        
        let devToken = "8ec0b468286ccccdfaf75eb656c573a2"
        let qaToken = "c10d36d2f267e295f7a43f631025a60b"
        
        let info = OptimoveTenantInfo(url:appController,
                                      token: devToken,
                                      version: "1.0.2",
                                      hasFirebase: false)
        
        Optimove.sharedInstance.configure(info: info)
        //        Optimove.sharedInstance.register(stateDelegate: self)
        return true
    }
    
    //Receive notification only in foreground mode
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable : Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void)
    {
        print("Receive Remote Notification")
        Optimove.sharedInstance.handleRemoteNotificationArrived(userInfo: userInfo,
                                                                fetchCompletionHandler: completionHandler)
        
    }
    
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data)
    {
        print("🔑🔑🔑🔑 APNS Generate Key  🔑🔑🔑🔑")
        var readableToken: String = ""
        for i in 0..<deviceToken.count {
            readableToken += String(format: "%02.2hhx", deviceToken[i] as CVarArg)
        }
        print("Received an APNs device token: \(readableToken)")
        Optimove.sharedInstance.application(didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
    }
  }
  //
  //  extension AppDelegate: OptimoveStateDelegate
  //  {
  //    var optimoveStateDelegateID: Int {
  //        return 2
  //    }
  //
  //    func didBecomeActive()
  //    {
  //        print("SDK Active")
  //    }
  //    func didStartLoading()
  //    {
  //        print("SDK Loading")
  //    }
  //    func didBecomeInvalid(withErrors errors: [OptimoveError])
  //    {
  //        print("SDK invalid  \(errors.reduce(""){return "\($0),\($1)" })")
  //    }
  //
  //  }
  
