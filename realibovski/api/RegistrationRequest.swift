import Foundation

class RegistrartionRequest: BaseRequest {

    init(userData: UserDTO) {
        super.init()

        parameters["gender"] = userData.gender
        parameters["age"] = userData.age
        parameters["cognitive_disorder"] = userData.cognitiveDisorder
        path = "registration"
    }
}
