//
//  ViewController.swift
//  SpotifyNowPlaying
//
//  Created by Jakub Iwaszek on 31/01/2020.
//  Copyright © 2020 Jakub Iwaszek. All rights reserved.
//

import Cocoa
import WebKit
import OAuthSwift
import AuthenticationServices
import SafariServices

class ViewController: NSViewController, OAuthSwiftURLHandlerType{

    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    var spotifyManager: SpotifyAPIManager = SpotifyAPIManager.shared
    var loginURL: URL!
    var tokenCode: String!
    var refreshTimer: Timer!
    

    override func viewDidLoad() {
        super.viewDidLoad()
        NotificationCenter.default.addObserver(self, selector: #selector(self.handleRedirect(_:)), name: NotificationNames.callbackNotification.notification, object: nil)
    }

    override func viewDidAppear() {
        spotifyManager.setAuthorizeHandler(vc: self)
        spotifyManager.authorizeScope()
    }
    

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


    func handle(_ url: URL) {
        print("Initial Request URL:\n\n\n \(url.description)")
        NSWorkspace.shared.open(url)
        
        /*session = ASWebAuthenticationSession(url: url, callbackURLScheme: spotifyManager.urlScheme) { (url, error) in
            print(url)
            if let url = url {
                print(url)
            } else {
                print(error)
            }
        }
        
        
        session?.presentationContextProvider = self
        session?.start()*/
        
        
        
        /*let req = ASAuthorizationProvider()
        req.createRequest()
        let controller = ASAuthorizationController(authorizationRequests: [req])
        ASWebAuthenticationSessionRequestDelegate
        controller.*/
    }
    
    func updateSpotifyData(data: NSDictionary) {
        if let item = data["item"] as? NSDictionary {
            let songName = item["name"] as? String
            var artistsNamesString: String = ""
            let artists = (item["artists"] as? Array<NSDictionary>)!
            for artist in artists {
                guard let artistName = artist["name"] as? String else { return }
                artistsNamesString.append(contentsOf: " " + artistName)
            }
            
            changeButtonText(artistName: artistsNamesString, songName: songName ?? "")
           
        }
        
    }
    
    func changeButtonText(artistName: String, songName: String) {
        if let button = statusItem.button {
            button.title = "♬" + (artistName) + " - " + (songName)
            //loginSuccess(code: tokenCode)
            //refreshMusicData()
        }
    }
    
    @objc func handleRedirect(_ notification: Notification) {
        if let code = notification.object as? String {
            tokenCode = code
            loginSuccess(code: code)
        } else {
            loginFailure(msg: "Wrong access token")
        }
    }
    
    
}

extension ViewController: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return view.window!
    }
}

extension ViewController:SpotifyLoginProtocolExtra{
    
    func loginFailure(msg:String) {
        print("Login Failure:" + msg)
    }
    
    func loginSuccess(code:String) {
        self.tokenCode = code
        print("Login Success: Code \(code)")
        
        // Complete the authorization, get the access and refresh tokens, call the spotify API
        self.spotifyManager.authorizeWithRequestToken(code: code) { (String) in
            self.spotifyManager.getSpotifyAccountInfo(completed: { response in
                
                switch response.result {
                case .success:
                    
                    if let JSON = response.value as? NSDictionary {
                        print(JSON)
                        self.refreshTimer = Timer.scheduledTimer(timeInterval: 4.0, target: self, selector: #selector(self.refreshMusicData), userInfo: nil, repeats: true)
                        self.updateSpotifyData(data: JSON)
                    } else {
                        print("start listening")
                        self.refreshTimer = Timer.scheduledTimer(timeInterval: 4.0, target: self, selector: #selector(self.refreshMusicData), userInfo: nil, repeats: true)
                    }
                    
                case let .failure(error):
                    print(error)
                }
                
            })

        }
    }
    
    @objc func refreshMusicData() {
        self.spotifyManager.getSpotifyAccountInfo(completed: { response in
            
            switch response.result {
            case .success:
                
                if let JSON = response.value as? NSDictionary {
                    self.updateSpotifyData(data: JSON)
                } else {
                    print("start listening")
                }
                
                
            case let .failure(error):
                print(error)
                self.spotifyManager.renewAccessToken()
                    
            }
            
        })
    }
    
}

protocol SpotifyLoginProtocolExtra{
    
    func loginSuccess(code:String)
    func loginFailure(msg:String)
}


