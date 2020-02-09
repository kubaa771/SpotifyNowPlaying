//
//  SpotifyWebLoginViewController.swift
//  SpotifyNowPlaying
//
//  Created by Jakub Iwaszek on 31/01/2020.
//  Copyright © 2020 Jakub Iwaszek. All rights reserved.
//

import Cocoa
import WebKit
import OAuthSwift
import Alamofire

class SpotifyWebLoginViewController: NSViewController, WKUIDelegate {
    
    @IBOutlet weak var webView: WKWebView!
    var loginURL:URL?
    var loginDelegate:SpotifyLoginProtocol!
    
    var spotifyManager:SpotifyAPIManager = SpotifyAPIManager.shared
    
    //MARK:- Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        webView.navigationDelegate = self
    }
    
    override func viewDidAppear() {
        
        super.viewDidAppear()
        
        guard let t_login_url = self.loginURL else{
            self.loginDelegate.loginFailure(msg:"Malformed URL")
            dismiss(self)
            return
        }
        
       
        
        let request = URLRequest(url: t_login_url)
        self.webView.load(request)
        
        // Fade-in WebView
        NSAnimationContext.runAnimationGroup({ _ in
            NSAnimationContext.current.duration = 2.0
            webView.animator().alphaValue = 1.0
        }) {
            // Complete Code if needed later on
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "estimatedProgress" {
            print(Float(webView.estimatedProgress))
        }
    }
}

//MARK:- WKNavigationDelegate
extension SpotifyWebLoginViewController: WKNavigationDelegate{
    
    
    /**
     Decides whether to allow of disallow navigation of the webview.
     Permits Spotify login and redirects to app authorization page.
     Intercepts Accept and Cancel from user to process in mainVC
     
     - Parameter webview: the webview invoking the navigation policy
     
     - Returns: Void
     */
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Swift.Void){
        
        if(navigationAction.navigationType == .other){
            
            if navigationAction.request.url != nil{

                // Called when Spotify redirects to authorize the app Scopes
                if  navigationAction.request.url?.lastPathComponent == "authorize" {
                    decisionHandler(.allow)
                    return
                }
                
                // If user is not logged in but the App is authorized, the first redirect from Spotify
                // returns the code required for the Access and Refresh tokens
                if navigationAction.request.url?.host == "localhost"{
                    let codeAndState = parseCodeAndStateFromURL(navigationAction: navigationAction)
                    
                    if let code_found = codeAndState.0, let state_found = codeAndState.1{
                        loginDelegate.loginSuccess(code:code_found)
                    }
                    
                    decisionHandler(.cancel)
                    self.dismiss(nil)
                    return
                }
                //allows all others including Oauth2 "Login" and Captcha from Spotify
                decisionHandler(.allow)
                return
                

            }
           
            decisionHandler(.cancel)
            return
            
        }else if navigationAction.navigationType == .formSubmitted{ // User submits login and authorize forms
            
            // Invoked when user accepts request for App Scopes
            if  navigationAction.request.url?.lastPathComponent == "accept" {
                decisionHandler(.allow)
                return
                
            // Invoked when user cancels request for App Scopes, handle appropriately
            }else if navigationAction.request.url?.lastPathComponent == "cancel"{
             
                decisionHandler(.allow)
                self.loginDelegate.loginFailure(msg:"User cancelled login flow")
                self.dismiss(nil)
                return
                
            // After the user hits Agree the Spotify service redirects formsubmitted to localhost w/the temp code.
            // Intercept, process, and pass the code back to MainScreenViewController to complete OAuth2 authorization
            // and get access and refresh tokens.
            }else if navigationAction.request.url?.host == "localhost"{
                    
                let codeAndState = parseCodeAndStateFromURL(navigationAction: navigationAction)
                
                if let code_found = codeAndState.0, let state_found = codeAndState.1{
                    loginDelegate.loginSuccess(code:code_found)
                }
                
                
                decisionHandler(.cancel)
                self.dismiss(nil)
                return
                
            }
        }
        
        decisionHandler(.cancel)
    
    }

    
}

/**
 Parses the redirect from the Spotify service that contains the initial access code
 
 - Parameters:
    - navigationAction: navigation object contains information about an action that may cause a navigation
 
 - Returns: Tuple containing initial access code and state
 */
private func parseCodeAndStateFromURL(navigationAction: WKNavigationAction) -> (String?, String?){


    var code:String? = nil
    var state:String? = nil

    if let queryItems = NSURLComponents(string: navigationAction.request.url!.description)?.queryItems {
        
        for item in queryItems {
            if item.name == "code" {
                if let itemValue = item.value {
                    code = itemValue
                }
            }else if item.name == "state"{
                if let itemValue = item.value{
                    state = itemValue
                }
            }
            
            
        }
        
    }
    
    return (code,state)

}

