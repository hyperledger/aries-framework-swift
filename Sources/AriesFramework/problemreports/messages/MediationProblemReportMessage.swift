
import Foundation

public class MediationProblemReportMessage: BaseProblemReportMessage {
    public static var type: String = "https://didcomm.org/coordinate-mediation/1.0/problem-report"

    public required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }
}
