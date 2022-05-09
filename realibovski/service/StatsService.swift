import Foundation
import RxSwift

final class StatsService: BaseRequest {
    
    class func sendRightSideStats(stats: EyeStatsDTO) -> Single<SuccessDTO> {
        RightSideStatsRequest(statsData: stats).postRequest()
    }
    class func sendEyeTrackerStats(stats: EyeStatsDTO) -> Single<SuccessDTO> {
        EyeTrackerStatsUploadRequest(statsData: stats).postRequest()
    }
    
    
}
