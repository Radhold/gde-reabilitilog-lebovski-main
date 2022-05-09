import Foundation

struct EyeStatsDTO: Codable {
    let errorCount: Int?
    let timeForAction: [Double]?
    let maxQue: Int?
    let score: Int?
}
