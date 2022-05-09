import Foundation

class EyeTrackerStatsUploadRequest: BaseRequest {

    init(statsData: EyeStatsDTO) {
        super.init()

        parameters["error_count"] = statsData.errorCount
        parameters["time_for_action"] = statsData.timeForAction
        parameters["max_que"] = statsData.maxQue
        parameters["score"] = statsData.score
        
        path = "send_data_eye_tracker"
    }
}
