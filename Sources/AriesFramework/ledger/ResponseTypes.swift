import Foundation

struct IndyResponse: Decodable {
    let op: String
    let reason: String?
}

struct BaseResponse<T: Decodable>: Decodable {
    let op: String
    let result: BaseResult<T>
}

struct BaseResult<T: Decodable>: Decodable {
    let type: String
    let seqNo: Int?
    let data: T
}

typealias SchemaResponse = BaseResponse<SchemaData>
struct SchemaData: Decodable {
    let attr_names: [String]?
    let name: String
    let version: String
}

typealias RevRegDefResponse = BaseResponse<RevRegDefData>
struct RevRegDefData: Decodable {
    let id: String
    let credDefId: String
    let tag: String
    let values: RevRegDefValues
}
struct RevRegDefValues: Decodable {
    let issuanceType: String
    let maxCredNum: Int
    let tailsHash: String
    let tailsLocation: String
    let publicKeys: RevRegDefPublicKeys
}
struct RevRegDefPublicKeys: Decodable {
    let accumKey: AccumKey
}
struct AccumKey: Decodable {
    let z: String
}

typealias RegRegResponse = BaseResponse<RegRegData>
struct RegRegData: Decodable {
    let seqNo: Int
    let value: AccumValue
    let txnTime: Int
}
struct AccumValue: Decodable {
    let accum: String
}

typealias RevRegDeltaResponse = BaseResponse<RevRegDeltaData>
struct RevRegDeltaData: Decodable {
    let value: RevRegDeltaValue
}
struct RevRegDeltaValue: Decodable {
    let accum_from: RegRegData?
    let accum_to: RegRegData
    let issued: [Int]
    let revoked: [Int]
}
