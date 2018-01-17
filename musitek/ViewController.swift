//
//  ViewController.swift
//  musitek
//
//  Created by m.ding on 2018-01-15.
//  Copyright © 2018 biu. All rights reserved.
//

import UIKit
import WebKit
import SystemConfiguration

class ViewController: UIViewController, WKUIDelegate, WKNavigationDelegate {
    
    // a constant indicates if this is pushed to production environment
    let IS_PRODUCTION = false
    
    // a constant where this webview points to, which is our website URL
    // use baidu for testing
    let SITE_URL = "http://www.baidu.com/"
    
    // the webview instance
    var musitekWebview: WKWebView!
    
    // import some util
    var util: Util
    
    // this will probably useful later on
    // since new ios version and the ugly iPhone X fucked up everything
    var isIphoneX = false
    
    var isPageLoaded = false
    
    var timeEntersBackground = Date()
    let EXPIRE_INTERVAL = 2 * 60 * 60.00 // 2 hours in seconds
    
    required init?(coder aDecoder: NSCoder) {
        util = Util(isProduction: IS_PRODUCTION)
        super.init(coder: aDecoder)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidFinishLaunchingWithOptions),
            name: NSNotification.Name(rawValue: "didFinishLaunchingWithOptions"),
            object: nil
        )
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // set the webview frame
        musitekWebview = WKWebView(frame: createWebViewFrame());
        musitekWebview.layer.zPosition = 0.0
        self.musitekWebview.uiDelegate = self
        musitekWebview.navigationDelegate = self
        
        // avoid the gray stuff when scrolling down
        musitekWebview?.scrollView.bounces = false
        
        // render webview on screen
        view.addSubview(musitekWebview)
        
        // add listener for app entering foreground & background
        addAppDelegateListeners()
    }
    
    // view is now visible on screen, only at this point we can render UI components
    override func viewDidAppear(_ animated: Bool) {
        
        // if internet is available, load website; else, keep displaying alert
        loadPageIfInternetAvailable()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // app went background
    @objc func applicationDidBecomeActive(){
        let now = Date()
        let interval = now.timeIntervalSince(timeEntersBackground as Date)
        if (interval >= EXPIRE_INTERVAL) { // in seconds
            util.log("expire, let's refresh")
            
            // refresh the webview
            isPageLoaded = false
            clearCache()
            loadPageIfInternetAvailable()
        }
    }
    
    // add listeners for events happening from appDelegate
    func addAppDelegateListeners(){
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidEnterBackground),
            name: .UIApplicationDidEnterBackground,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: .UIApplicationDidBecomeActive,
            object: nil
        )
    }
    
    // app went background
    @objc func applicationDidEnterBackground(){
        let now = Date()
        timeEntersBackground = now
    }
    
    // check if the device is connected to internet
    func isInternetAvailable() -> Bool {
        var zeroAddress = sockaddr_in()
        zeroAddress.sin_len = UInt8(MemoryLayout.size(ofValue: zeroAddress))
        zeroAddress.sin_family = sa_family_t(AF_INET)
        
        let defaultRouteReachability = withUnsafePointer(to: &zeroAddress) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {zeroSockAddress in
                SCNetworkReachabilityCreateWithAddress(nil, zeroSockAddress)
            }
        }
        
        var flags = SCNetworkReachabilityFlags()
        if !SCNetworkReachabilityGetFlags(defaultRouteReachability!, &flags) {
            return false
        }
        let isReachable = flags.contains(.reachable)
        let needsConnection = flags.contains(.connectionRequired)
        return (isReachable && !needsConnection)
    }
    
    func loadPageIfInternetAvailable() {
        if isInternetAvailable() == true {
            util.log("Internect connected")
            // when the internet status changed from disconnected back to connected, reload the webview
            // viewDidAppear() which calls this loadPageIfInternetAvailable(),
            // may be called multiple times during the whole app lifecycle.
            // to avoid refreshing page everytime viewDidAppear() is called, we set and check the isPageLoaded flag
            if (!isPageLoaded) {
                loadPage()
                isPageLoaded = true
            }
            return
        }
        
        util.log("No internet")
        
        // Create the alert controller
        let alertController = UIAlertController(title: "No Internet",
                                                message: "Please check that you are connected to the Internet and try again.",
                                                preferredStyle: .alert)
        
        // Create the action
        let retryAction = UIAlertAction(title: "Retry", style: UIAlertActionStyle.default) {
            UIAlertAction in
            self.util.log("retry button pressed")
            // after user clicking this button, we check the connection again
            self.loadPageIfInternetAvailable()
        }
        
        // Add the action(button)
        alertController.addAction(retryAction)
        
        // Present the controller
        self.present(alertController, animated: true, completion: nil)
    }
    
    // load website
    func loadPage() {
        if let url = URL(string: SITE_URL) {
            let request = URLRequest(url: url)
            musitekWebview?.load(request as URLRequest)
        }
    }
    
    func createWebViewFrame() -> CGRect {
        util.log("createWebViewFrame()")
        let statusBarSize = UIApplication.shared.statusBarFrame.size
        let statusBarHeight = Swift.min(statusBarSize.width, statusBarSize.height)
        if (isIphoneX) {
            if #available(iOS 11.0, *) {
                util.log("this is iPhoneX and iOS11, The safeArea frame is: \(self.view.safeAreaLayoutGuide.layoutFrame), safeArea bottom: \(self.view.safeAreaInsets.bottom)")
                return CGRect( x: 0, y: statusBarHeight, width: self.view.frame.width, height: self.view.frame.height - statusBarHeight - 34.0)
            } else {
                // Fallback on earlier versions
                // do nothing, but return this anyway, in case smth fucked up
                return CGRect( x: 0, y: statusBarHeight, width: self.view.frame.width, height: self.view.frame.height - statusBarHeight )
            }
        } else {
            return CGRect( x: 0, y: statusBarHeight, width: self.view.frame.width, height: self.view.frame.height - statusBarHeight )
        }
    }
    
    // app almost finish launching
    @objc func applicationDidFinishLaunchingWithOptions() {
        util.log("listener applicationDidFinishLaunchingWithOptions()")
    }
    
    // clear webview cache
    func clearCache() {
        util.log("clearCache")
        
        // clear UIWebView cache
        URLCache.shared.removeAllCachedResponses()
        URLCache.shared.diskCapacity = 0
        URLCache.shared.memoryCapacity = 0
        
        // clear WkWebView cache
        if #available(iOS 9.0, *) {
            let websiteDataTypes = NSSet(array: [WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache])
            let date = NSDate(timeIntervalSince1970: 0)
            
            WKWebsiteDataStore.default().removeData(ofTypes: websiteDataTypes as! Set<String>,
                                                    modifiedSince: date as Date,
                                                    completionHandler:{ })
        } else {
            let libraryPath = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.libraryDirectory,
                                                                  FileManager.SearchPathDomainMask.userDomainMask,
                                                                  false).first!
            do {
                util.log("clearCache::libraryPath = \(libraryPath)")
                try FileManager.default.removeItem(atPath: libraryPath)
            } catch {
                util.log("[clearCache] error")
            }
            URLCache.shared.removeAllCachedResponses()
        }
    }


}

