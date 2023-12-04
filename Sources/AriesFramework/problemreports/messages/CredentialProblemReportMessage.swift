
import Foundation

public class CredentialProblemReportMessage: BaseProblemReportMessage {
    public static var type: String = "https://didcomm.org/issue-credential/1.0/problem-report"

    public init(threadId: String) {
        super.init(description: DescriptionOptions(en: "Issuance abandoned", code: "issuance-abandoned"), type: CredentialProblemReportMessage.type)
        thread = ThreadDecorator(threadId: threadId)
    }

    public required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }
}
