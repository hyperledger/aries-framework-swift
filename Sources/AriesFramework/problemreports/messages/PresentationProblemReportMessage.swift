
import Foundation

public class PresentationProblemReportMessage: BaseProblemReportMessage {
    public static var type: String = "https://didcomm.org/present-proof/1.0/problem-report"

    public init(threadId: String) {
        super.init(description: DescriptionOptions(en: "Proof abandoned", code: "abandoned"), type: PresentationProblemReportMessage.type)
        thread = ThreadDecorator(threadId: threadId)
    }

    public required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }
}
