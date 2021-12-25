//
//  NetworkManager.swift
//  swift-2048
//
//  Created by Yaroslav Fomenko on 25.12.2021.
//  Copyright © 2021 Austin Zheng. All rights reserved.
//

import Foundation

final class NetworkManager {
    private var url: String = "http://61cb-77-220-209-41.ngrok.io"
    
    func request(parameters: Data?, method: String = "GET", endpoint: String = "") {
        guard let url = URL(string: "\(url)/\(endpoint)") else {
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        request.setValue("application/json", forHTTPHeaderField: "accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let parameters = parameters{
//            guard let jsonData = try? JSONSerialization.data(withJSONObject: parameters) else {
//                return
//            }
            request.httpBody = parameters
        }
        URLSession.shared.dataTask(with: request) {data, response, error in
            if let error = error {
//                completion(.failure(error))
                return
            }
            do {
                let json = try JSONSerialization.jsonObject(with: data!, options: []) as? NSDictionary
                if ((json!["answer"] as? String)?.contains("success"))! {
                    print ("OK")
                    if let image = json!["image"] {
                        print ("Get image")
                    }
                }
            } catch {
                print(error)
            }
        }.resume()
    }
}
