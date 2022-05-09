import Foundation
import Alamofire
import RxSwift
import RxCocoa

struct UploadData {
    let data: Data
    let key: String
    let filename: String
    let mimeType: String
}

class BaseRequest {

    var host = UserDefaults.standard.string(forKey: "server") ?? ""
    var session: Session = {
        return Session.default
    }()

    lazy var headers: [String: String] = {

        var innerHeaders: [String: String] = [:]

        innerHeaders["Accept"] = "application/json"
        innerHeaders["Content-Type"] = "application/json"
        innerHeaders["Jwt"] = "\(AuthService.jwt)"
        
        return innerHeaders

    }()

    var parameters: [String: Any] = [String: Any]()

    var path = ""

    var encoding: ParameterEncoding = JSONEncoding.default
    
    private let maxRetryCount = 3
    
    func request<T: Decodable>() -> Single<T> {
        getRequest()
    }

    func deleteRequest<T: Decodable>() -> Single<T> {
        request(.delete)
    }

    func postRequest<T: Decodable>() -> Single<T> {
        request(.post)
    }

    func getRequest<T: Decodable>() -> Single<T> {
        request(.get)
    }

    func putRequest<T: Decodable>() -> Single<T> {
        request(.put)
    }
    
    func uploadRequest<T: Decodable>(data: [String: UploadData]) -> Single<T> {

        let url = URL(string: host + path)
        let urlRequest = try! URLRequest(url: url!, method: .post, headers: HTTPHeaders(headers))
        let parameters = self.parameters
        let session = self.session

        return Single<T>.create { single -> Disposable in
            session.upload(
                    multipartFormData: { multipartFormData in
                        for (key, value) in data {
                            multipartFormData.append(
                                    value.data,
                                    withName: key,
                                    fileName: value.filename,
                                    mimeType: value.mimeType
                            )
                        }

                        for (key, value) in parameters {
                            if let v = value as? String, let data = v.data(using: String.Encoding.utf8) {
                                multipartFormData.append(data, withName: key)
                            }
                        }
                    },
                    with: urlRequest,
                    interceptor: self
            )
                    .uploadProgress { progress in
                        print("Upload Progress: \(progress.fractionCompleted)")
                    }
                    .validate()
                    .responseJSON { response in
                        BaseRequest.responseJSON(response: response) { (data: T?, error: Error?) in
                            if let error = error {
//                                single(.error(error))
                            } else if let result = data {
                                single(.success(result))
                            } else if let error = error {
//                                single(.error(error))
                            } else {
//                                single(.error(makeError(with: NSLocalizedString("Wrong data format", comment: ""))))
                            }
                        }
                    }
            
            return Disposables.create()
        }
    }

    func request<T: Decodable>(_ method: Alamofire.HTTPMethod) -> Single<T> {

        let requestEncoding = method == .get ? URLEncoding.default : encoding

        let endpoint = host + "/" + path
        let parameters = self.parameters
        let headers = self.headers
        let session = self.session
        
        return Single<T>.create { single -> Disposable in
            session.request(
                            endpoint,
                            method: method,
                            parameters: parameters,
                            encoding: requestEncoding,
                            headers: HTTPHeaders(headers),
                            interceptor: self
                    )
                    .validate()
                    .responseJSON { response in
                        BaseRequest.responseJSON(response: response) { (data: T?, error: Error?) in
                            if let error = error {
//                                single(.error(error))
                            } else if let result = data {
                                single(.success(result))
                            } else {
//                                single(.error(makeError(with: NSLocalizedString("Wrong data format", comment: ""))))
                            }
                        }
                    }

            return Disposables.create()
        }

    }
    

    static func responseJSON<T: Decodable>(response: AFDataResponse<Any>, callback: @escaping (T?, Error?) -> Void) {
        switch response.result {
        case .success:
            guard let data = response.data else {
//                callback(nil, makeError(with: NSLocalizedString("There is no data from server", comment: "")))
                print(response.debugDescription)
                return
            }
//            if let baseError = try? JSONDecoder().decode(Error.self, from: data) {
//                callback(nil, makeError(from: baseError))
//            } else {
                do {
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase
                    callback(try decoder.decode(T.self, from: data), nil)
                } catch {
                    callback(nil, error)
                }
//            }
        case .failure(let error):
//            if let baseError = try? JSONDecoder().decode(ErrorResponseDTO.self, from: response.data ?? Data()) {
//                callback(nil, makeError(from: baseError))
//                return
//            }
            if case AFError.responseSerializationFailed(reason: .inputDataNilOrZeroLength) = error {
                callback(nil, nil)
                return
            }
            
            callback(nil, error)
        }
    }

}


extension BaseRequest: RequestInterceptor {
    
    func retry(_ request: Request, for session: Session, dueTo error: Error,
                  completion: @escaping (RetryResult) -> Void) {
        
        guard request.retryCount < maxRetryCount,
              error.code == .internetConnection ||
            error.code == .internetConnectionInterrupted else {
            completion(.doNotRetry)
            return
        }
 
        let delay: TimeInterval
        switch request.retryCount {
        case 1:
            delay = 1
        case 2:
            delay = 3
        default:
            delay = 0
        }
        completion(.retryWithDelay(delay))
    }
    
}

extension Error {
    var code: ErrorCode { ErrorCode(rawValue: (self as NSError).code) ?? .unknownError }
    var domain: String { (self as NSError).domain }
}

enum ErrorCode: Int {
    case unknownError = -999
    case internetConnection = -1009
    case internetConnectionInterrupted = 13
    
    case canceledByUser = -2
    case fallbackToPassword = -3
    case lockedOut = -8
}
