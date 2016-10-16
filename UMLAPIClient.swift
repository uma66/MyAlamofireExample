//
//  UMLAPIClient.swift
//
//  Created by uma66 on 2016/08/11.
//  Copyright © 2016年
//

import Alamofire
import ObjectMapper

enum UMLRequestResult<T> {
    case Success(T)
    case Failure(T)
    case Error(NSError)
}

class UMLAPIClient<T: UMLAPIBaseEntity> {
    
    typealias CompletionHandelr = (UMLRequestResult<T>) -> Void
    
    private func startRequest(urlRequest: UMLURLRequest, completionHandler: CompletionHandelr) {
        
        let showErrorAlert: () -> Void = {
            if urlRequest.needsRetry() == true {
                UMLAlertDialogHelper.sharedInstance.showNetworkRetryAlert(actionHandler: { action in
                    switch action {
                    case .Default:
                        // RetryButton Pressed
                        self.startRequest(urlRequest, completionHandler: completionHandler)
                        break
                    case .Cancel, .Destructive: break
                    }
                })
            } else {
                UMLAlertDialogHelper.sharedInstance.showNetworkErrorAlert(actionHandler: { _ in })
            }
        }
        
        Alamofire.request(urlRequest)
            .responseJSON { response in
                
                let statusCode: Int? = response.response?.statusCode
                
                if statusCode == 200,
                    let entity = Mapper<T>().map(response.result.value)
                {
                    if entity.isFailure {
                        showErrorAlert()
                        completionHandler(UMLRequestResult<T>.Failure((entity as T)))
                        return
                    }
                    completionHandler(UMLRequestResult<T>.Success((entity as T)))
                    
                } else if statusCode == 400,
                    let entity = Mapper<T>().map(response.result.value)
                {
                    completionHandler(UMLRequestResult<T>.Failure((entity as T)))
                    
                } else if let error = response.result.error
                {
                    showErrorAlert()
                    completionHandler(UMLRequestResult<T>.Error(error))
                }
                
        }
    }
}

extension UMLAPIClient {
    
    func logIn(
        password: String,
        deviceToken: String?,
        completionHandler: CompletionHandelr)
    {
        self.startRequest(UMLURLRequest.LogIn([
            "password": password,
            "deviceToken": deviceToken
            ]),
                          completionHandler: completionHandler);
    }

    func passwordChange(
        userId userId: Int,
        currentPassword: String,
        newPassword: String,
        completionHandler: CompletionHandelr)
    {
        self.startRequest(UMLURLRequest.PasswordChange([
            "userId": userId,
            "currentPassword": currentPassword,
            "newPassword": newPassword]),
                          completionHandler: completionHandler);
    }
    

    //
    //
    //  etc...
    //
    //
    
}

typealias RequestParams = [String: AnyObject?]
typealias UMLRequest = UMLURLRequestConvertible

enum UMLURLRequestConvertible : UMLRequestConvertible {
    
    private enum ContentType : String {
        case None
        case XFormUrlEncoded = "application/x-www-form-urlencoded"
        case Json = "application/json"
    }
    
    case LogIn(RequestParams)
    case PasswordChange(RequestParams)

    //
    //
    // etc....
    //
    //

    
    var URLRequest: NSMutableURLRequest {
        
        let (method, path, contentType, params, needsAccessToken) = self.requestSettings()
        
        let urlRequest: NSURLRequest = {
            
            let URL = NSURL(string: UMLAppConstant.BaseRequestURLStringAPI)
            
            let urlRequest = NSMutableURLRequest(URL: URL!.URLByAppendingPathComponent(path))
            urlRequest.HTTPMethod = method.rawValue
            
            if contentType != .None {
                urlRequest.addValue(contentType.rawValue, forHTTPHeaderField: "Content-Type")
            }
            
            if needsAccessToken == true, let accessToken = UMLAccessTokenHelper.sharedInstance.accessToken {
                urlRequest.addValue(accessToken, forHTTPHeaderField: "access-token")
            }
            
            return urlRequest
        }()
        
        let encoding = Alamofire.ParameterEncoding.URL
        
        var eliminateNilParams: [String: AnyObject]? = [:]
        for key in params.keys {
            if let value = params[key] {
                eliminateNilParams?[key] = value
            }
        }
        
        return encoding.encode(urlRequest, parameters: eliminateNilParams).0
    }
    
    private func requestSettings() -> (
        method: Alamofire.Method,
        path: String,
        contentType: ContentType,
        params: RequestParams,
        needsAccessToken: Bool)
    {   
        switch self {
        case .LogIn(let params):
            return (.POST, "/dir_path/login/", .XFormUrlEncoded, params, true)
        case .PasswordChange(let params):
            return (.PUT, "/dir_path/passwordChange/", .XFormUrlEncoded, params, false)

        //
        //
        // etc....
        //
        //

        }
    }
    
    func needsRetry() -> Bool {
        switch self {
        case .LogIn: return true
        case .PasswordChange: return false

        //
        //
        // etc....
        //
        //

        }
    }
}
