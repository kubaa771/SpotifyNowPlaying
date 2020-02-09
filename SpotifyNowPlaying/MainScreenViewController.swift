//
//  ViewController.swift
//  SpotifyNowPlaying
//
//  Created by Jakub Iwaszek on 30/01/2020.
//  Copyright © 2020 Jakub Iwaszek. All rights reserved.
//

import Cocoa
import WebKit
import OAuthSwift
import AuthenticationServices

/*class MainScreenViewController: NSViewController, WKUIDelegate, OAuthSwiftURLHandlerType {

    @IBOutlet var webView: WKWebView!
    
    let defaults = UserDefaults.init(suiteName: "com.fusionblender.spotify")
    var spotifyManager: SpotifyAPIManager = SpotifyAPIManager.shared
    var session: ASWebAuthenticationSession?
    var loginURL: URL!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        webView.uiDelegate = self
        webView.navigationDelegate = self
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
        let request = URLRequest(url: url)
        self.webView.load(request)
        
    }
    
    func loadRequest() {
        let request = URLRequest(url: loginURL)
        webView.load(request)
    }
    
    
    
    
    
    
    
    /*func authorizeSpotifyToken() {
        var url = URLComponents(string: "https://accounts.spotify.com/authorize")
        let clientId = "5c66d67698bc477fa00f63c5da6cbeef"
        
        url?.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: "http://localhost:8080"),
            URLQueryItem(name: "scope", value: "user-read-currently-playing user-read-playback-state")
        ]
        
        let request = URLRequest(url: (url?.url)!)
        
        URLSession.shared.dataTask(with: request) { (data, response, error) in
            guard let data = data,                            // is there data
                let response = response as? HTTPURLResponse,  // is there HTTP response
                (200 ..< 300) ~= response.statusCode,         // is statusCode 2XX
                error == nil else {                           // was there no error, otherwise ...
                    return
            }

            let responseObject = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            print(responseObject)
        }
    }*/

}

extension MainScreenViewController: SpotifyLoginProtocol {
    func loginSuccess(code: String, state: String) {
        print("Login Success: Code \(code)")
        
        self.spotifyManager.authorizeWithRequestToken(code: code) { (String) in
            self.spotifyManager.getSpotifyAccountInfo { (response) in
                switch response.result {
                case .success:
                    
                    let JSON = response.value as! NSDictionary
                    print(JSON)
                    //self.updateUserProfileScreen(json: JSON)
                    
                case let .failure(error):
                    print(error)
                }
            }
        }
    }
    
    func loginFailure(msg: String) {
        print("Login failure: \(msg)")
    }
    
    
    
    
}



extension MainScreenViewController: WKNavigationDelegate {
    
    public func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {

    var code:String? = nil
     var state:String? = nil

     if let t_url = webView.url{

         // If redirect is to Login then user isn't logged in according to initial OAuth2 request.
         // Segue to SpotifyWebLoginViewController for login flow
         if t_url.lastPathComponent == "login"{
            loginURL = webView.url

         }else{

             //Redirect after initial OAuth2 request for authorization.
             //Contains code to pass back to Spotify for Access and Refresh tokens
             if let queryItems = NSURLComponents(string: t_url.description)?.queryItems {

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

                 if let code_found = code{

                     // Get Access and Refresh tokens from Spotify
                     self.spotifyManager.authorizeWithRequestToken(code: code_found, completion:{ response in

                         switch response{
                             case .success(let (credential, _, _)):
                                 print("Authorization Success")
                                 
                                 //Get the account information
                                 self.spotifyManager.getSpotifyAccountInfo(completed: { response in

                                     switch response.result {
                                     case .success:


                                         let JSON = response.value as! NSDictionary
                                         print(JSON)
                                         

                                     case let .failure(error):
                                         print(error)
                                     }

                                 })
                             case .failure(let error):
                                 print(error.description)
                         }

                     })

                 }

             }

         }
     }
    }
    
    
    
    
    
    
    
    
    
    
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Swift.Void){

        if(navigationAction.navigationType == .other){

            if navigationAction.request.url != nil{

                // Called when Spotify redirects to authorize the app Scopes
                if  navigationAction.request.url?.lastPathComponent == "authorize" {
                    decisionHandler(.allow)
                    return
                }

                // If user is logged in already, and App authorized, the first redirect from Spotify
                // returns the code required for the Access and Refresh tokens
                if navigationAction.request.url?.host == "localhost"{
                    let codeAndState = parseCodeAndStateFromURL(navigationAction: navigationAction)

                    if let code_found = codeAndState.0, let state_found = codeAndState.1{
                        loginSuccess(code:code_found, state:state_found)
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
                self.loginFailure(msg:"User cancelled login flow")
                self.dismiss(nil)
                return

            // After the user hits Agree the Spotify service redirects formsubmitted to localhost w/the temp code.
            // Intercept, process, and pass the code back to MainScreenViewController to complete OAuth2 authorization
            // and get access and refresh tokens.
            }else if navigationAction.request.url?.host == "localhost"{

                let codeAndState = parseCodeAndStateFromURL(navigationAction: navigationAction)

                if let code_found = codeAndState.0, let state_found = codeAndState.1{
                    loginSuccess(code:code_found, state:state_found)
                }


                decisionHandler(.cancel)
                self.dismiss(nil)
                return

            }
        }

        decisionHandler(.cancel)

    }
    
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

        
}

extension MainScreenViewController: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return view.window!
    }
}*/

class MainScreenViewController: NSViewController, WKUIDelegate {

    let defaults = UserDefaults.init(suiteName: "com.fusionblender.spotify")
    var webView: WKWebView!
    var spotifyManager:SpotifyAPIManager = SpotifyAPIManager.shared
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    var tokenCode: String!
    
    //MARK:- Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        webView = WKWebView()
        
        webView.uiDelegate = self
        webView.navigationDelegate = self
        
        
        
    }

    
    override func viewDidAppear() {
        
        spotifyManager.setAuthorizeHandler(vc: self)
        spotifyManager.authorizeScope()
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "estimatedProgress" {
            print(Float(webView.estimatedProgress))
        }
    }

   
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
       
        if let swlvc = segue.destinationController as? SpotifyWebLoginViewController{
            swlvc.loginURL = webView.url
            swlvc.loginDelegate = self
        }
    }
    
    func changeButtonText(data: NSDictionary) {
        if let item = data["item"] as? NSDictionary {
            let songName = item["name"] as? String
            let artists = item["artists"] as? [String: Any]
            let artistName = artists?["name"] as? String
            if let button = statusItem.button {
                button.title = "♬ " + (artistName ?? "") + " - " + (songName ?? "")
                sleep(7)
                loginSuccess(code: tokenCode)
            }
        }
        
    }
    
    
    /**
     Updates the main screen labels and NSImageView with data from Spotify.
     Called after querying Spotify using getSpotifyAccountInfo
     
     - Parameters:
        - json: the JSON dictionary containing the response values for the user data
     
     - Returns: Void
     */
    
}


//MARK:- OAuthSwiftURLHandler
extension MainScreenViewController: OAuthSwiftURLHandlerType {
    
    /**
     Handler for OAuthSwift.
     
     Handler function callback when OAuthSwift instance makes initial request for authorization.
     Permits use of webview to negotiate redirects from Spotify and intercept navigation with
     webview methods.
     
     - Parameters:
     - url: the full url from OAuthSwift initial request for authorization
     
     - Returns: Void
     */
    func handle(_ url: URL) {

        let request = URLRequest(url: url)
        self.webView.load(request)
       
    }

}

//MARK:- WKNavigationDelegate
extension MainScreenViewController: WKNavigationDelegate{
    
    /**
     Called when a WebView receives a redirect.
     
     If Spotify user isn't logged in then redirect flow will check the incoming URL, invoke the
     SpotifyWebLoginVC to login, and pass back the access token via the SpotifyLoginProtocol elegate.
     If user is logged in already, authorization component is invoked. Called after oauth2.AUTHORIZE
     returns a redirect to localhost:8080. Gets the temporary request code and uses it in a call to
     oauth2.postOAuthAccessTokenWithRequestCode that returns the temporary access token used to call Spotify APIs.
     
     - Parameters:
        - webView: the invoking webView
        - navigation:contains information for tracking the loading progress of a webpage.

     - Returns: Void
     */
    
    public func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        
        var code:String? = nil
        var state:String? = nil
        
        if let t_url = webView.url{
            
            // If redirect is to Login then user isn't logged in according to initial OAuth2 request.
            // Segue to SpotifyWebLoginViewController for login flow
            if t_url.lastPathComponent == "login"{
                self.performSegue(withIdentifier: "segueWebLogin", sender: self)
                
            }else{
                
                //Redirect after initial OAuth2 request for authorization.
                //Contains code to pass back to Spotify for Access and Refresh tokens
                if let queryItems = NSURLComponents(string: t_url.description)?.queryItems {
                    
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
                    
                    if let code_found = code{
                        
                        // Get Access and Refresh tokens from Spotify
                        self.spotifyManager.authorizeWithRequestToken(code: code_found, completion:{ response in
                            
                            switch response{
                                case .success(let (credential, _, _)):
                                    print("Authorization Success")
                                    self.spotifyManager.getSpotifyAccountInfo(completed: { response in
                                        
                                        switch response.result {
                                        case .success:
                                            
                                            
                                            let JSON = response.value as! NSDictionary
                                            print(JSON)
                                            self.tokenCode = code_found
                                            self.changeButtonText(data: JSON)
                                            //tucos
                                            
                                        case let .failure(error):
                                            print(error)
                                        }
                                        
                                    })
                                case .failure(let error):
                                    print(error.description)
                            }

                        })
                        
                    }

                }
                
            }
        }
        
    }
    
    /**
     Decides whether to allow or cancel navigation
     Invoke the segue if user is logged in and needs to reauthorize Spotify Scope
     
     - Parameter webView: the webview that invokes the navigation action
     
     - Returns: Void
     */
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Swift.Void){
        
        print("MainScreenVC: Deciding Policy")
        
        if(navigationAction.navigationType == .other)
        {
            if navigationAction.request.url != nil
            {

                // Initial or access token request
                if navigationAction.request.url?.lastPathComponent == "authorize" || navigationAction.request.url?.host == "localhost"{
                    decisionHandler(.allow)
                    return
                    
                }else{
                
                    self.performSegue(withIdentifier: "segueWebLogin", sender: self)
                    
                }
        
            }
            decisionHandler(.cancel)
            return
        }
        
      
        decisionHandler(.cancel)
    }
    
    
    
    func webView(webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: NSError) {
        print(error.localizedDescription)
    }
    func webView(webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        print("Starting to load")
    }
    func webView(webView: WKWebView, didFinishNavigation navigation: WKNavigation!) {
        print("Finishing loading")
    }
    
}



//MARK:- NSWindowDelegate
extension MainScreenViewController: NSWindowDelegate{
    
    /*
    func window(_ window: NSWindow, willPositionSheet sheet: NSWindow, using rect: NSRect) -> NSRect {
       return NSRect.init(x:0, y: 0, width: 300, height: 600)
    }
    
    func windowDidEnterFullScreen(_ notification: Notification) {
        defaults?.set(true, forKey: Settings.Keys.appFullScreen)
    }
    
    func windowDidExitFullScreen(_ notification: Notification) {
        defaults?.set(false, forKey: Settings.Keys.appFullScreen)
    }*/
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        
        let window = NSApplication.shared.mainWindow!
        if(sender == window) {
            defaults?.set(window.isZoomed ? true : false, forKey:Settings.Keys.appFullScreen)
        }
        return true;
    }
 
 
}


//MARK:- SpotifyLoginProtocol
extension MainScreenViewController:SpotifyLoginProtocol{
    
    /**
     User cancelled authorization from WebLoginViewController
     
     - Parameters
        - msg: request code to send to Spotify for access and refresh tokens
     
     - Returns: Void
     */
    func loginFailure(msg:String) {
        print("Login Failure:" + msg)
    }
    
    
    /**
     User is ogged in from WebLoginViewController. Complete the login process
     
     - Parameters:
        - code: request code to send to Spotify for access and refresh tokens
        - state: used to validate request server-side.  Not used here
     
     - Returns: Void
     */
    func loginSuccess(code:String) {
        self.tokenCode = code
        print("Login Success: Code \(code)")
        
        // Complete the authorization, get the access and refresh tokens, call the spotify API
        self.spotifyManager.authorizeWithRequestToken(code: code) { (String) in
            self.spotifyManager.getSpotifyAccountInfo(completed: { response in
                
                switch response.result {
                case .success:
                    
                    let JSON = response.value as! NSDictionary
                    print(JSON)
                    self.changeButtonText(data: JSON)
                    
                    
                case let .failure(error):
                    print(error)
                }
                
            })

        }
    }
    
}

protocol SpotifyLoginProtocol{
    
    func loginSuccess(code:String)
    func loginFailure(msg:String)
}


