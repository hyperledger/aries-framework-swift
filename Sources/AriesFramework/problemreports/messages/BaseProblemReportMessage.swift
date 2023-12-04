import Foundation

public struct DescriptionOptions: Codable {
    let en: String
    let code: String
}

public struct FixHintOptions: Codable {
    let en: String
}

public class BaseProblemReportMessage: AgentMessage {
    var description: DescriptionOptions
    var fixHint: FixHintOptions?

    private enum CodingKeys: String, CodingKey {
        case description, fixHint = "fix_hint"
    }

    public init(description: DescriptionOptions, fixHint: FixHintOptions? = nil, type: String) {
        self.description = description
        self.fixHint = fixHint
        super.init(id: UUID().uuidString, type: type)
    }

    public required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        description = try values.decode(DescriptionOptions.self, forKey: .description)
        fixHint = try values.decodeIfPresent(FixHintOptions.self, forKey: .fixHint)
        try super.init(from: decoder)
    }

    public override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(description, forKey: .description)
        try container.encodeIfPresent(fixHint, forKey: .fixHint)
        try super.encode(to: encoder)
    }
}
