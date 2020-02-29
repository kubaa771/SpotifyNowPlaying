//
//  AppDelegate.swift
//  SpotifyNowPlaying
//
//  Created by Jakub Iwaszek on 30/01/2020.
//  Copyright © 2020 Jakub Iwaszek. All rights reserved.
//
/*
import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let defaults = UserDefaults.init(suiteName: "com.fusionblender.spotify")

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        if let button = statusItem.button {
            button.title = "Something"
        }
       
    }

    func applicationWillTerminate(_ aNotification: Notification) {
    }

    

}*/

struct Settings{
    
    struct Keys{
        static var windowPosition:String = "AppScreenSizeAndPosition"
        static var appFullScreen:String = "appFullScreen"
    }
}

import Cocoa
import OAuthSwift
import AuthenticationServices

@NSApplicationMain

class AppDelegate: NSObject, NSApplicationDelegate{

    var loginDelegate:SpotifyLoginProtocolExtra!
   
    func applicationWillFinishLaunching(_ notification: Notification) {
        
    }
   
    
    func applicationDidFinishLaunching(_ notification: Notification) {
    
        NSAppleEventManager.shared().setEventHandler(self, andSelector:#selector(self.handleGetURL(event:withReplyEvent:)), forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))    
        
        
    }
    

    func applicationDidResignActive(_ notification: Notification) {
        // Might put code to save location here
    }
    
    
    func applicationWillTerminate(_ notification: Notification) {
       
    }
    
    func application(_ application: NSApplication, open urls: [URL]) {
        print(urls)
    }
    
    
    
    
    
    @objc func handleGetURL(event: NSAppleEventDescriptor!, withReplyEvent: NSAppleEventDescriptor!){
        if let urlString = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue, let url = URL(string: urlString) {
            print("handleGetURL \(url)")
            var code: String?
            var state: String?
            if let queryItems = NSURLComponents(string: url.description)?.queryItems {
                
                for item in queryItems {
                    if item.name == "code" {
                        if let itemValue = item.value {
                            code = itemValue
                        }
                    } else if item.name == "state"{
                        if let itemValue = item.value{
                            state = itemValue
                        }
                    }
                    
                    
                }
            }
            
            if code != nil {
                //loginDelegate.loginSuccess(code: code!)
                NotificationCenter.default.post(name: NotificationNames.callbackNotification.notification, object: code)
            } else {
                //error getting code - create alert
            }
   
           
        }
    }

    
}


enum NotificationNames: String {
    
    case callbackNotification = "callbackNotification"
    case refreshMusicData = "refreshMusicData"
    
    var notification: Notification.Name {
        return Notification.Name(self.rawValue)
    }
}

