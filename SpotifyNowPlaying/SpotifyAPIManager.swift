//
//  SpotifyAPIManager.swift
//  SpotifyNowPlaying
//
//  Created by Jakub Iwaszek on 30/01/2020.
//  Copyright © 2020 Jakub Iwaszek. All rights reserved.
//

import Foundation
import OAuthSwift
import Alamofire

class SpotifyAPIManager {
    var baseURL: String = "https://api.spotify.com"
    var authURLString =  "https://accounts.spotify.com/authorize"
    var consumerKey = "5c66d67698bc477fa00f63c5da6cbeef"
    var responseType = "code"
    var urlScheme = "spotifyNowPlaying://"
    var oauth2: OAuth2Swift!
    
    var accessToken: String!
    var refreshToken: String!
    var scopes: [String]!
    var expires: Int!

    static let shared = SpotifyAPIManager()
    
    private init() {
        oauth2 = OAuth2Swift(consumerKey: "5c66d67698bc477fa00f63c5da6cbeef", consumerSecret: "9d159cda0e704d8fad0cb49dd1440bf6", authorizeUrl: "https://accounts.spotify.com/en/authorize", accessTokenUrl: "https://accounts.spotify.com/api/token", responseType: "code")
    }
    
    func authorizeScope(){
        _ = oauth2.authorize(withCallbackURL: URL(string: urlScheme)!, scope: "user-read-currently-playing user-read-playback-state user-read-private user-read-email", state: "test12345") { result in
            
            switch result {
            case .success( (_, _, _)):
                print("Authorization success")
            case .failure(let error):
                print(error.description)
            }
        }
        
    }
    
    func authorizeWithRequestToken(code: String, completion: @escaping(Result<OAuthSwift.TokenSuccess, OAuthSwiftError>) -> ()) {
        oauth2.postOAuthAccessTokenWithRequestToken(byCode: code, callbackURL: URL.init(string: urlScheme)!) { result in
            switch result {
            case .failure(let error):
                print("postOAuthAccessTokenWithRequestToken Error: \(error)")
                //if error._code == -2 {
                //TODO: token expired
//                self.renewAccessToken(refreshToken: self.refreshToken) { result in
//                    print("success")
//                }
                //}
                completion(result)
            case .success(let response):
                print("Received Authorization Token: ")
                print(response)
                
                if let access_token = response.parameters["access_token"], let refresh_token = response.parameters["refresh_token"], let expires = response.parameters["expires_in"], let scope = response.parameters["scope"] {
                    
                    
                    self.refreshToken = refresh_token as? String
                    self.accessToken = access_token as? String
                    
                    if let t_scope = scope as? String {
                        let t_vals = t_scope.split(separator: " ")
                        self.scopes = [String]()
                        t_vals.forEach { (scopeParameter) in
                            self.scopes.append(String(scopeParameter))
                        }
                    }
                    
                    self.expires = expires as? Int
                    
                    print("ACCESS TOKEN \(String(describing: self.accessToken))")
                    print("REFRESH TOKEN \(String(describing: self.refreshToken))")
                    print("EXPIRES \(String(describing: self.expires))")
                    print("SCOPE: \(String(describing: self.scopes))")

                    completion(result)
                    
                    
                }
            }
        }
    }
    
    func renewAccessToken() {
        let clientSecret = "9d159cda0e704d8fad0cb49dd1440bf6"
        let authorizationString = "\(consumerKey):\(clientSecret)"
        let encodedAuthorization = authorizationString.data(using: .utf8)!.base64EncodedString()
        
        let headers: OAuthSwift.Headers = [
            "Authorization": "Basic \(encodedAuthorization)",
        ]
        
        let parameters: OAuthSwift.Parameters = [
            "grant_type": "refresh_token",
            "refresh_token": self.refreshToken!,
        ]
        
        
        //TODO: sprawdzic czy dziala
       
        
        oauth2.renewAccessToken(withRefreshToken: self.refreshToken, parameters: parameters, headers: headers) { (result) in
            switch result {
            case .failure(let error):
                print("renewAccessTokenError: \(error)")
                //completion(result)
            case .success(let response):
                print("Received Authorization Token: ")
                print(response)
                
                if let access_token = response.parameters["access_token"] as? String, let expires = response.parameters["expires_in"] as? Int{
                    print(access_token)
                    
                    self.setTokens(refresh: self.refreshToken, access: access_token)
                    self.setExpires(expires: expires)
                    
                }
            }
        }
        
        
    }
    
    func getSpotifyAccountInfo(completed: @escaping(AFDataResponse<Any>) -> ()){
        let aboutURL = baseURL + "/v1/me/player/currently-playing"
        let headers: HTTPHeaders = [
            "Authorization": "Bearer " + self.accessToken,
        ]
        
        AF.request(aboutURL, headers: headers).validate().responseJSON { (response) in
            completed(response)
        }
        
    }
    
    func setAuthorizeHandler(vc:OAuthSwiftURLHandlerType){
        oauth2.authorizeURLHandler = vc
    }

    func setTokens(refresh:String, access:String){
        self.refreshToken = refresh
        self.accessToken = access
    }

    func setScopes(scopes:[String]){

        self.scopes = scopes
    }

    func setExpires(expires:Int){

        self.expires = expires
    }

    
}
