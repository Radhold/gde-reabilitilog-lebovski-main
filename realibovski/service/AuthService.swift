import Foundation
import RxSwift

final class AuthService: BaseRequest {
    
    static var jwt = ""
    
    class func registration(userData: UserDTO) -> Single<JWT> {
        RegistrartionRequest(userData: userData).postRequest()
    }
    
}
