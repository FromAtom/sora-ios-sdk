import Foundation

/**
 "connect" シグナリングメッセージを表します。
 このメッセージはシグナリング接続の確立後、最初に送信されます。
 */
public struct SignalingConnectMessage {
    
    /// ロール
    public var role: SignalingRole
    
    /// チャネル ID
    public var channelId: String
    
    /// メタデータ
    public var metadata: String?
    
    /// SDP 。クライアントの判別に使われます。
    public var sdp: String?
    
    /// マルチストリームの可否
    public var multistreamEnabled: Bool
    
    /// 映像の可否
    public var videoEnabled: Bool
    
    /// 映像コーデック
    public var videoCodec: VideoCodec
    
    /// 映像ビットレート
    public var videoBitRate: Int?
    
    /// 音声の可否
    public var audioEnabled: Bool
    
    /// 音声コーデック
    public var audioCodec: AudioCodec

    /// 最大話者数
    public var maxNumberOfSpeakers: Int?
    
}

/**
 "offer" シグナリングメッセージを表します。
 このメッセージは SDK が "connect" を送信した後に、サーバーから送信されます。
 */
public struct SignalingOfferMessage {
    
    /**
     クライアントが更新すべき設定を表します。
     */
    public struct Configuration {
        
        /// ICE サーバーの情報のリスト
        public let iceServerInfos: [ICEServerInfo]
        
        /// ICE 通信ポリシー
        public let iceTransportPolicy: ICETransportPolicy
    }
    
    /// クライアント ID
    public let clientId: String
    
    /// SDP メッセージ
    public let sdp: String
    
    /// クライアントが更新すべき設定
    public let configuration: Configuration?
    
}

/**
 "notify" シグナリングメッセージで通知されるイベントの種別です。
 詳細は Sora のドキュメントを参照してください。
 */
public enum SignalingNotificationEventType: String {
    
    /// "connection.created"
    case connectionCreated = "connection.created"
    
    /// "connection.updated"
    case connectionUpdated = "connection.updated"
    
    /// "connection.destroyed"
    case connectionDestroyed = "connection.destroyed"
    
}

/**
 "update" シグナリングメッセージを表します。
 このメッセージは送受信の両方で使用されます。
 
 マルチストリーム時にストリームの数が増減するとサーバーから送信されます。
 受信したメッセージの SDP から Answer としての "update" メッセージを生成してサーバーに送信します。
 */
public struct SignalingUpdateOfferMessage {
    
    /// SDP メッセージ
    public let sdp: String
    
}

/**
 "notify" シグナリングメッセージを表します。
 このメッセージはピア接続の確立後、定期的にサーバーから送信されます。
 */
public struct SignalingNotifyMessage {
    
    // MARK: イベント情報
    
    /// イベントの種別
    public let eventType: SignalingNotificationEventType
    
    // MARK: 接続情報
    
    /// ロール
    public let role: SignalingRole?
    
    /// チャネル ID
    public let channelId: String?
    
    /// クライアント ID
    public let clientId: String?
    
    /// 音声の可否
    public let audioEnabled: Bool?
    
    /// 映像の可否
    public let videoEnabled: Bool?
    
    // MARK: 統計情報
    
    /// 接続時間
    public let connectionTime: Int?
    
    /// 接続中のクライアントの数
    public let connectionCount: Int?
    
    /// 接続中のパブリッシャーの数
    public let publisherCount: Int?
    
    /// 接続中のサブスクライバーの数
    public let subscriberCount: Int?
    
    // MARK: スポットライト機能
    
    /// スポットライト ID
    public let spotlightId: String?
    
    /// 固定の有無
    public let isFixed: Bool?
    
    // MARK: メタデータ
    
    /// メタデータ
    public private(set) var metadata: [Any]?
    
}

/**
 "pong" シグナリングメッセージを表します。
 このメッセージはサーバーから "ping" シグナリングメッセージを受信すると
 サーバーに送信されます。
 "ping" 受信後、一定時間内にこのメッセージを返さなければ、
 サーバーとの接続が解除されます。
 */
public struct SignalingPongMessage {}

// MARK: -

/**
 シグナリングメッセージの種別です。
 */
public enum SignalingMessage {
    
    /// "connect" シグナリングメッセージ
    case connect(message: SignalingConnectMessage)
    
    /// "offer" シグナリングメッセージ
    case offer(message: SignalingOfferMessage)
    
    /// "answer" シグナリングメッセージ
    case answer(sdp: String)
    
    /// "candidate" シグナリングメッセージ
    case candidate(ICECandidate)
    
    /// "update" シグナリングメッセージ
    case update(sdp: String)
    
    /// "notify" シグナリングメッセージ
    case notify(message: SignalingNotifyMessage)
    
    /// "ping" シグナリングメッセージ
    case ping
    
    /// "pong" シグナリングメッセージ
    case pong
    
    /**
     "disconnect" シグナリングメッセージ。
     このメッセージは接続を解除する際にサーバーに送信されます。
     このメッセージの送信後は、サーバーからの応答はありません。
     */
    case disconnect
    
    static func decode(from data: Data) throws -> SignalingMessage {
        let decoder = JSONDecoder()
        let msg = try decoder.decode(SignalingMessage.self, from: data)
        switch msg {
        case .notify(message: var notify):
            notify.parseMetadata(from: data)
        default:
            break
        }
        return msg
    }
    
}

// MARK: -
// MARK: Codable

/// :nodoc:
extension SignalingRole: Codable {

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let roleStr = try container.decode(String.self)
        guard let role = SignalingRole(rawValue: roleStr) else {
            throw DecodingError.dataCorruptedError(in: container,
                                                   debugDescription: "invalid 'role' value")
        }
        self = role
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
    
}

/// :nodoc:
extension SignalingConnectMessage: Codable {
    
    enum CodingKeys: String, CodingKey {
        case role
        case channelId = "channel_id"
        case metadata
        case sdp
        case multistream
        case plan_b
        case video
        case audio
        case vad
    }
    
    enum VideoCodingKeys: String, CodingKey {
        case codecType = "codec_type"
        case bitRate = "bit_rate"
    }
    
    enum AudioCodingKeys: String, CodingKey {
        case codecType = "codec_type"
    }
    
    public init(from decoder: Decoder) throws {
        fatalError("not supported")
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(role, forKey: .role)
        try container.encode(channelId, forKey: .channelId)
        
        if let sdp = sdp {
            try container.encode(sdp, forKey: .sdp)
        }
        
        if let metadata = metadata {
            try container.encode(metadata, forKey: .metadata)
        }
        
        if multistreamEnabled {
            try container.encode(true, forKey: .multistream)
            try container.encode(true, forKey: .plan_b)
        }
     
        if videoEnabled {
            if videoCodec != .default || videoBitRate != nil {
                var videoContainer = container
                    .nestedContainer(keyedBy: VideoCodingKeys.self,
                                     forKey: .video)
                if videoCodec != .default {
                    try videoContainer.encode(videoCodec, forKey: .codecType)
                }
                if let bitRate = videoBitRate {
                    try videoContainer.encode(bitRate, forKey: .bitRate)
                }
            }
        } else {
            try container.encode(false, forKey: .video)
        }
        
        if audioEnabled {
            switch audioCodec {
            case .default:
                break
            default:
                var audioContainer = container
                    .nestedContainer(keyedBy: AudioCodingKeys.self, forKey: .audio)
                try audioContainer.encode(audioCodec, forKey: .codecType)
            }
        } else {
            try container.encode(false, forKey: .audio)
        }
        
        if let num = maxNumberOfSpeakers {
            try container.encode(num, forKey: .vad)
        }
    }
    
}

/// :nodoc:
extension SignalingOfferMessage.Configuration: Codable {
    
    enum CodingKeys: String, CodingKey {
        case iceServerInfos = "iceServers"
        case iceTransportPolicy = "iceTransportPolicy"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        iceServerInfos = try container.decode([ICEServerInfo].self,
                                              forKey: .iceServerInfos)
        iceTransportPolicy = try container.decode(ICETransportPolicy.self,
                                                  forKey: .iceTransportPolicy)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(iceServerInfos, forKey: .iceServerInfos)
        try container.encode(iceTransportPolicy, forKey: .iceTransportPolicy)
    }
    
}

/// :nodoc:
extension SignalingOfferMessage: Codable {
    
    enum CodingKeys: String, CodingKey {
        case clientId = "client_id"
        case sdp
        case configuration = "config"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        clientId = try container.decode(String.self, forKey: .clientId)
        sdp = try container.decode(String.self, forKey: .sdp)
        if container.contains(.configuration) {
            configuration = try container.decode(Configuration.self,
                                                 forKey: .configuration)
        } else {
            configuration = nil
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        fatalError("not supported")
    }
    
}

/// :nodoc:
extension SignalingUpdateOfferMessage: Codable {
    
    enum CodingKeys: String, CodingKey {
        case sdp
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sdp = try container.decode(String.self, forKey: .sdp)
    }
    
    public func encode(to encoder: Encoder) throws {
        fatalError("not supported")
    }
    
}

/// :nodoc:
extension SignalingNotifyMessage: Codable {
    
    enum CodingKeys: String, CodingKey {
        case eventType = "event_type"
        case role = "role"
        case connectionTime = "minutes"
        case connectionCount = "channel_connections"
        case publisherCount = "channel_upstream_connections"
        case subscriberCount = "channel_downstream_connections"
        case channelId = "channel_id"
        case clientId = "client_id"
        case spotlightId = "spotlight_id"
        case audio = "audio"
        case video = "video"
        case fixed = "fixed"
        case metadata = "metadata"
        case metadataList = "metadata_list"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        eventType = SignalingNotificationEventType(rawValue:
            try container.decode(String.self, forKey: .eventType))!
        
        if let raw = try container.decodeIfPresent(String.self, forKey: .role) {
            role = SignalingRole(rawValue: raw)
        } else {
            role = nil
        }
        
        connectionTime = try container.decodeIfPresent(Int.self, forKey: .connectionTime)
        connectionCount = try container.decodeIfPresent(Int.self, forKey: .connectionCount)
        publisherCount = try container.decodeIfPresent(Int.self, forKey: .publisherCount)
        subscriberCount = try container.decodeIfPresent(Int.self, forKey: .subscriberCount)
        channelId = try container.decodeIfPresent(String.self, forKey: .channelId)
        clientId = try container.decodeIfPresent(String.self, forKey: .clientId)
        audioEnabled = try container.decodeIfPresent(Bool.self, forKey: .audio)
        videoEnabled = try container.decodeIfPresent(Bool.self, forKey: .video)
        spotlightId = try container.decodeIfPresent(String.self, forKey: .spotlightId)
        isFixed = try container.decodeIfPresent(Bool.self, forKey: .fixed)
        
        // metadata には任意のデータが入るため、 Decoder ではデコードできない
    }
    
    mutating func parseMetadata(from data: Data) {
        do {
            let json = try JSONSerialization.jsonObject(with: data, options: [])
            if let msg = json as? [String: Any] {
                if let metadata =
                    msg[SignalingNotifyMessage.CodingKeys.metadata.rawValue] {
                    self.metadata = [metadata]
                } else if let metadataList =
                    msg[SignalingNotifyMessage.CodingKeys.metadataList.rawValue] {
                    self.metadata = metadataList as? [Any]
                }
            }
        } catch {
            // 何もしない
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        fatalError("not supported")
    }
    
}

/// :nodoc:
extension SignalingMessage: Codable {
    
    enum MessageType: String {
        case connect
        case offer
        case answer
        case update
        case candidate
        case notify
        case ping
        case pong
        case disconnect
    }
    
    enum CodingKeys: String, CodingKey {
        case type
        case sdp
        case candidate
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "offer":
            self = .offer(message: try SignalingOfferMessage(from: decoder))
        case "update":
            let update = try SignalingUpdateOfferMessage(from: decoder)
            self = .update(sdp: update.sdp)
        case "notify":
            self = .notify(message: try SignalingNotifyMessage(from: decoder))
        case "ping":
            self = .ping
        default:
            fatalError("not supported decoding '\(type)'")
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .connect(message: let message):
            try container.encode(MessageType.connect.rawValue, forKey: .type)
            try message.encode(to: encoder)
        case .offer(message: let message):
            try container.encode(MessageType.offer.rawValue, forKey: .type)
            try message.encode(to: encoder)
        case .answer(sdp: let sdp):
            try container.encode(MessageType.answer.rawValue, forKey: .type)
            try container.encode(sdp, forKey: .sdp)
        case .candidate(let candidate):
            try container.encode(MessageType.candidate.rawValue, forKey: .type)
            try container.encode(candidate.sdp, forKey: .candidate)
        case .update(sdp: let sdp):
            try container.encode(MessageType.update.rawValue, forKey: .type)
            try container.encode(sdp, forKey: .sdp)
        case .notify(message: _):
            fatalError("not supported encoding 'notify'")
        case .ping:
            fatalError("not supported encoding 'ping'")
        case .pong:
            try container.encode(MessageType.pong.rawValue, forKey: .type)
        case .disconnect:
            try container.encode(MessageType.disconnect.rawValue, forKey: .type)
        }
    }
    
}

// MARK: - CustomStringConvertible

extension SignalingOfferMessage.Configuration: CustomStringConvertible {
    
    public var description: String {
        let encoder = JSONEncoder()
        let data = try! encoder.encode(self)
        return String(data: data, encoding: .utf8)!
    }
    
}
