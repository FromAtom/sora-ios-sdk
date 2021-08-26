import Foundation
import WebRTC

/**
 ピアチャネルのイベントハンドラです。
 */
public final class PeerChannelHandlers {
    
    /// このプロパティは onDisconnect に置き換えられました。
    @available(*, deprecated, renamed: "onDisconnect",
    message: "このプロパティは onDisconnect に置き換えられました。")
    public var onDisconnectHandler: ((Error?) -> Void)? {
        get { onDisconnect }
        set { onDisconnect = newValue }
    }
    
    /// このプロパティは onAddStream に置き換えられました。
    @available(*, deprecated, renamed: "onAddStream",
    message: "このプロパティは onConnect に置き換えられました。")
    public var onAddStreamHandler: ((MediaStream) -> Void)? {
        get { onAddStream }
        set { onAddStream = newValue }
    }
    
    /// このプロパティは onRemoveStream に置き換えられました。
    @available(*, deprecated, renamed: "onRemoveStream",
    message: "このプロパティは onRemoveStream に置き換えられました。")
    public var onRemoveStreamHandler: ((MediaStream) -> Void)? {
        get { onRemoveStream }
        set { onRemoveStream = newValue }
    }
    
    /// このプロパティは onUpdate に置き換えられました。
    @available(*, deprecated, renamed: "onUpdate",
    message: "このプロパティは onUpdate に置き換えられました。")
    public var onUpdateHandler: ((String) -> Void)? {
        get { onUpdate }
        set { onUpdate = newValue }
    }
    
    /// このプロパティは onReceiveSignaling に置き換えられました。
    @available(*, deprecated, renamed: "onReceiveSignaling",
    message: "このプロパティは onReceiveSignaling に置き換えられました。")
    public var onReceiveSignalingHandler: ((Signaling) -> Void)? {
        get { onReceiveSignaling }
        set { onReceiveSignaling = newValue }
    }
    
    /// 接続解除時に呼ばれるクロージャー
    public var onDisconnect: ((Error?) -> Void)?
    
    /// ストリームの追加時に呼ばれるクロージャー
    public var onAddStream: ((MediaStream) -> Void)?
    
    /// ストリームの除去時に呼ばれるクロージャー
    public var onRemoveStream: ((MediaStream) -> Void)?
    
    /// マルチストリームの状態の更新に呼ばれるクロージャー。
    /// 更新により、ストリームの追加または除去が行われます。
    public var onUpdate: ((String) -> Void)?
    
    /// シグナリング受信時に呼ばれるクロージャー
    public var onReceiveSignaling: ((Signaling) -> Void)?
    
    /// 初期化します。
    public init() {}
    
}

extension RTCPeerConnectionState: CustomStringConvertible {
    public var description: String {
        switch self {
        case .new:
            return "new"
        case .connecting:
            return "connecting"
        case .connected:
            return "connected"
        case .disconnected:
            return "disconnected"
        case .failed:
            return "failed"
        case .closed:
            return "closed"
        @unknown default:
            return "unknown"
        }
    }
}

// MARK: -

/**
 ピアチャネルの機能を定義したプロトコルです。
 デフォルトの実装は非公開 (`internal`) であり、カスタマイズはイベントハンドラでのみ可能です。
 ソースコードは公開していますので、実装の詳細はそちらを参照してください。
 
 ピアチャネルは映像と音声を送受信するための接続を行います。
 サーバーへの接続を確立すると、メディアストリーム `MediaStream` を通して
 映像と音声の送受信が可能になります。
 メディアストリームはシングルストリームでは 1 つ、マルチストリームでは複数用意されます。
 */
public protocol PeerChannel: AnyObject {
    
    // MARK: - イベントハンドラ
    
    /// イベントハンドラ
    var handlers: PeerChannelHandlers { get set }
    
    /**
     内部処理で使われるイベントハンドラ。
     このハンドラをカスタマイズに使うべきではありません。
     */
    var internalHandlers: PeerChannelHandlers { get set }
    
    // MARK: - 接続情報
    
    /// クライアントの設定
    var configuration: Configuration { get }
    
    /// クライアント ID 。接続成立後にセットされます。
    var clientId: String? { get }
    
    /// 接続 ID 。接続成立後にセットされます。
    var connectionId: String? { get }
    
    /// メディアストリームのリスト。シングルストリームでは 1 つです。
    var streams: [MediaStream] { get }
    
    /// 接続状態
    var state: ConnectionState { get }
    
    /// シグナリングチャネル
    var signalingChannel: SignalingChannel { get }
    
    var videoTrack: RTCVideoTrack? { get set }
    var audioTrack: RTCAudioTrack? { get set }
    
    // MARK: - インスタンスの生成
    
    /**
     初期化します。
     
     - parameter configuration: クライアントの設定
     - parameter signalingChannel: 使用するシグナリングチャネル
     */
    init(configuration: Configuration, signalingChannel: SignalingChannel)
    
    // MARK: - 接続
    
    /**
     サーバーに接続します。
     
     - parameter handler: 接続試行後に呼ばれるクロージャー
     - parameter error: (接続失敗時のみ) エラー
     */
    func connect(handler: @escaping (_ error: Error?) -> Void)
    
    /**
     接続を解除します。
     
     - parameter error: 接続解除の原因となったエラー
     */
    func disconnect(error: Error?)

    func attachVideoTrackToSender()
    func detachVideoTrackFromSender()
    func attachAudioTrackToSender()
    func detachAudioTrackFromSender()
    var videoSender: RTCRtpSender? { get }
    var audioSender: RTCRtpSender? { get }
}

// MARK: -

class BasicPeerChannel: PeerChannel {
    
    var handlers: PeerChannelHandlers = PeerChannelHandlers()
    var internalHandlers: PeerChannelHandlers = PeerChannelHandlers()
    let configuration: Configuration
    let signalingChannel: SignalingChannel
    
    private(set) var streams: [MediaStream] = []
    private(set) var iceCandidates: [ICECandidate] = []

    var clientId: String? {
        get { return context.clientId }
    }
    
    var connectionId: String? {
        context.connectionId
    }
    
    var state: ConnectionState {
        get {
            return context.state
        }
    }
    
    private var context: BasicPeerChannelContext!

    public var videoTrack: RTCVideoTrack?
    public var audioTrack: RTCAudioTrack?
    public var videoSender: RTCRtpSender?
    public var audioSender: RTCRtpSender?
    
    var senderStream: MediaStream?
    
    required init(configuration: Configuration, signalingChannel: SignalingChannel) {
        self.configuration = configuration
        self.signalingChannel = signalingChannel
        context = BasicPeerChannelContext(channel: self)
    }
    
    func add(stream: MediaStream) {
        streams.append(stream)
        Logger.debug(type: .peerChannel, message: "call onAddStream")
        internalHandlers.onAddStream?(stream)
        handlers.onAddStream?(stream)
    }
    
    func remove(streamId: String) {
        let stream = streams.first { stream in stream.streamId == streamId }
        if let stream = stream {
            remove(stream: stream)
        }
    }
    
    func remove(stream: MediaStream) {
        streams = streams.filter { each in each.streamId != stream.streamId }
        Logger.debug(type: .peerChannel, message: "call onRemoveStream")
        internalHandlers.onRemoveStream?(stream)
        handlers.onRemoveStream?(stream)
    }
    
    func add(iceCandidate: ICECandidate) {
        iceCandidates.append(iceCandidate)
    }
    
    func remove(iceCandidate: ICECandidate) {
        iceCandidates = iceCandidates.filter { each in each == iceCandidate }
    }
    
    func connect(handler: @escaping (Error?) -> Void) {
        context.connect(handler: handler)
    }
    
    func disconnect(error: Error?) {
        context.disconnect(error: error)
    }
    
    fileprivate func terminateAllStreams() {
        for stream in streams {
            stream.terminate()
        }
        streams.removeAll()
        // Do not call `handlers.onRemoveStreamHandler` here
        // This method is meant to be called only when disconnection cleanup
    }


    // TODO: 実装を context に移した方が良い? => context の方もごちゃごちゃしているので別の場所に整理できたら良い気がする
    func attachVideoTrackToSender() {
        if videoTrack == nil {
            let track = context.initializeVideoTrack()
            videoTrack = track
            
            if let stream = senderStream {
                // TODO: video の方は stream に track を追加する必要がある (CameraVideoCapturer が stream を使うため?)
                stream.nativeStream.addVideoTrack(track)

                if configuration.cameraSettings.isEnabled {
                    context.initializeCameraVideoCapturer(stream: stream)
                }
            }
        }
        
        
        if let sender = videoSender, let track = videoTrack {
            sender.track = track
            Logger.debug(type: .peerChannel, message: "attachVideoTrackToSender")
        }
    }
    
    func detachVideoTrackFromSender() {
        if let sender = videoSender {
            sender.track = nil
            Logger.debug(type: .peerChannel, message: "detachVideoTrackFromSender")
        }
    }
    
    func attachAudioTrackToSender() {
        Logger.debug(type: .peerChannel, message: "AudioSession status before attaching => \(RTCAudioSession.sharedInstance().isActive ? "active" : "inactive")")
        if audioTrack == nil {
            audioTrack = context.initializeAudioTrack()
            
            // TODO: 初回のアタッチで以下のエラーが The operation couldn’t be completed 発生してしまう
            // failed to initialize audio input => The operation couldn’t be completed. (org.webrtc.RTC_OBJC_TYPE(RTCAudioSession) error -3.)
            context.initializeAudioInput(category: AVAudioSession.Category.playAndRecord)
        }
        
        if let sender = audioSender, let track = audioTrack {
            Logger.debug(type: .peerChannel, message: " => \(RTCAudioSession.sharedInstance().isActive)")
            // detachAudioTrackFromSender で sender.track = null した瞬間に RTCAudioSession.sharedInstance().isActive が false になり、 audio の送信が止まってしまうが、
            // context.initializeInputを再度実行すると復活することを確認
            if !RTCAudioSession.sharedInstance().isActive {
                Logger.debug(type: .peerChannel, message: "initializeAudioInput before attachment")
                context.initializeAudioInput(category: AVAudioSession.Category.playAndRecord)
                Logger.debug(type: .peerChannel, message: "AudioSession status after initializeAudioInput => \(RTCAudioSession.sharedInstance().isActive ? "active" : "inactive")")
            }

            sender.track = track
            Logger.debug(type: .peerChannel, message: "attachAudioTrackToSender")
        }
        Logger.debug(type: .peerChannel, message: "AudioSession status after attaching => \(RTCAudioSession.sharedInstance().isActive ? "active" : "inactive")")
    }
    
    func detachAudioTrackFromSender() {
        if let sender = audioSender {
            Logger.debug(type: .peerChannel, message: "AudioSession status before detaching => \(RTCAudioSession.sharedInstance().isActive ? "active" : "inactive")")
            sender.track = nil
            Logger.debug(type: .peerChannel, message: "AudioSession status after detaching => \(RTCAudioSession.sharedInstance().isActive ? "active" : "inactive")")
            context.isAudioInputInitialized = false

            /*
            // チャンネル参加者に sendrecv がいると、オレンジ色のインジケーターが消えなかったので category を soloAmbient 変更しようとしたが、
            // 以下のエラーが発生して category の変更が失敗した
            // failed to initialize audio input => The operation couldn’t be completed. (org.webrtc.RTC_OBJC_TYPE(RTCAudioSession) error -3.)
            context.initializeAudioInput(category: AVAudioSession.Category.soloAmbient)
            context.isAudioInputInitialized = false
            */
        }
    }
}

// MARK: -

class BasicPeerChannelContext: NSObject, RTCPeerConnectionDelegate {
    
    final class Lock {
        
        weak var context: BasicPeerChannelContext?
        var count: Int = 0
        var shouldDisconnect: (Bool, Error?) = (false, nil)
        
        func waitDisconnect(error: Error?) {
            if count == 0 {
                context?.basicDisconnect(error: error)
            } else {
                shouldDisconnect = (true, error)
            }
        }
        
        func lock() {
            count += 1
        }
        
        func unlock() {
            if count <= 0 {
                fatalError("count is already 0")
            }
            count -= 1
            if count == 0 {
                disconnect()
            }
        }
        
        func disconnect() {
            switch shouldDisconnect {
            case (true, let error):
                shouldDisconnect = (false, nil)
                if let context = context {
                    if context.state != .disconnecting && context.state != .disconnected {
                        context.basicDisconnect(error: error)
                    }
                }
            default:
                break
            }
        }
    }
    
    weak var channel: BasicPeerChannel!
    var state: ConnectionState = .disconnected {
        didSet {
            Logger.debug(type: .peerChannel,
                         message: "changed BasicPeerChannelContext.state from \(oldValue) to \(state)")
        }
    }
    
    // connect() の成功後は必ずセットされるので nil チェックを省略する
    // connect() 実行前は nil なのでアクセスしないこと
    var nativeChannel: RTCPeerConnection!
    
    var signalingChannel: SignalingChannel {
        get { return channel.signalingChannel }
    }
    
    var webRTCConfiguration: WebRTCConfiguration!
    var clientId: String?
    var connectionId: String?

    var configuration: Configuration {
        get { return channel.configuration }
    }
    
    var onConnectHandler: ((Error?) -> Void)?
    
    var isAudioInputInitialized: Bool = false
    
    private var lock: Lock
    
    private var offerEncodings: [SignalingOffer.Encoding]?

    init(channel: BasicPeerChannel) {
        self.channel = channel
        lock = Lock()
        super.init()
        lock.context = self
        
        signalingChannel.internalHandlers.onDisconnect = { error in
            self.disconnect(error: error)
        }
        
        signalingChannel.internalHandlers.onReceive = handle
    }
    
    func connect(handler: @escaping (Error?) -> Void) {
        if channel.state.isConnecting {
            handler(SoraError.connectionBusy(reason:
                "PeerChannel is already connected"))
            return
        }
        
        Logger.debug(type: .peerChannel, message: "try connecting")
        Logger.debug(type: .peerChannel, message: "try connecting to signaling channel")
        
        self.webRTCConfiguration = channel.configuration.webRTCConfiguration
        nativeChannel = NativePeerChannelFactory.default
            .createNativePeerChannel(configuration: webRTCConfiguration,
                                     constraints: webRTCConfiguration.constraints,
                                     delegate: self)
        guard nativeChannel != nil else {
            let message = "createNativePeerChannel failed"
            Logger.debug(type: .peerChannel, message: message)
            handler(SoraError.peerChannelError(reason: message))
            return
        }
        
        // このロックは finishConnecting() で解除される
        lock.lock()
        onConnectHandler = handler

        // サイマルキャストを利用する場合は、 RTCPeerConnection の生成前に WrapperVideoEncoderFactory を設定する必要がある
        // また、 (非レガシーな) スポットライトはサイマルキャストを利用しているため、同様に設定が必要になる
        WrapperVideoEncoderFactory.shared.simulcastEnabled = configuration.simulcastEnabled || (!Sora.isSpotlightLegacyEnabled && configuration.spotlightEnabled == .enabled)
        
        signalingChannel.connect(handler: sendConnectMessage)
        state = .connecting
    }
    
    func sendConnectMessage(error: Error?) {
        if let error = error {
            Logger.error(type: .peerChannel,
                         message: "failed connecting to signaling channel (\(error.localizedDescription))")
            onConnectHandler?(error)
            onConnectHandler = nil
            return
        }
        
        if configuration.isSender {
            Logger.debug(type: .peerChannel, message: "try creating offer SDP")
            NativePeerChannelFactory.default
                .createClientOfferSDP(configuration: webRTCConfiguration,
                                      constraints: webRTCConfiguration.constraints)
                { sdp, sdpError in
                    if let error = sdpError {
                        Logger.debug(type: .peerChannel,
                                     message: "failed to create offer SDP (\(error.localizedDescription))")
                    } else {
                        Logger.debug(type: .peerChannel,
                                     message: "did create offer SDP")
                    }
                    self.sendConnectMessage(with: sdp, error: error)
            }
        } else {
            self.sendConnectMessage(with: nil, error: nil)
        }
    }
    
    func sendConnectMessage(with sdp: String?, error: Error?) {
        if error != nil {
            Logger.error(type: .peerChannel,
                         message: "failed connecting to signaling channel (\(error!.localizedDescription))")
            disconnect(error: SoraError.peerChannelError(
                reason: "failed connecting to signaling channel"))
            return
        }
        
        Logger.debug(type: .peerChannel,
                     message: "did connect to signaling channel")
        
        var role: SignalingRole!
        var multistream = configuration.multistreamEnabled || configuration.spotlightEnabled == .enabled
        switch configuration.role {
        case .publisher, .sendonly:
            role = .sendonly
        case .subscriber, .recvonly:
            role = .recvonly
        case .group, .sendrecv:
            role = .sendrecv
            multistream = true
        case .groupSub:
            role = .recvonly
            multistream = true
        }
        
        let soraClient = "Sora iOS SDK \(SDKInfo.shared.version) (\(SDKInfo.shared.shortRevision))"
        
        var webRTCVersion: String?
        if let info = WebRTCInfo.load() {
            webRTCVersion = "Shiguredo-build \(info.version) (\(info.version).\(info.commitPosition).\(info.maintenanceVersion) \(info.shortRevision))"
        }
        
        let simulcast = configuration.simulcastEnabled || (!Sora.isSpotlightLegacyEnabled && configuration.spotlightEnabled == .enabled)
        let connect = SignalingConnect(
            role: role,
            channelId: configuration.channelId,
            clientId: configuration.clientId,
            metadata: configuration.signalingConnectMetadata,
            notifyMetadata: configuration.signalingConnectNotifyMetadata,
            sdp: sdp,
            multistreamEnabled: multistream,
            videoEnabled: configuration.videoEnabled,
            videoCodec: configuration.videoCodec,
            videoBitRate: configuration.videoBitRate,
            // WARN: video only では answer 生成に失敗するため、
            // 音声トラックを使用しない方法で回避する
            // audioEnabled: config.audioEnabled,
            audioEnabled: true,
            audioCodec: configuration.audioCodec,
            audioBitRate: configuration.audioBitRate,
            spotlightEnabled: configuration.spotlightEnabled,
            spotlightNumber: configuration.spotlightNumber,
            spotlightFocusRid: configuration.spotlightFocusRid,
            spotlightUnfocusRid: configuration.spotlightUnfocusRid,
            simulcastEnabled: simulcast,
            simulcastRid: configuration.simulcastRid,
            soraClient: soraClient,
            webRTCVersion: webRTCVersion,
            environment: DeviceInfo.current.description)
        Logger.debug(type: .peerChannel, message: "send connect")
        signalingChannel.send(message: Signaling.connect(connect))
    }
    
    func initializeSenderStream(mid: Dictionary<String, String>? = nil) {
        let nativeStream = NativePeerChannelFactory.default
            .createNativeSenderStream(streamId: configuration.publisherStreamId,
                                      constraints: webRTCConfiguration.constraints)
        let stream = BasicMediaStream(peerChannel: channel,
                                      nativeStream: nativeStream)
        channel.senderStream = stream
        
        if let audioMid = mid?["audio"] {
            let transceiver = nativeChannel.transceivers.first { $0.mid == audioMid }
            
            if let transceiver = transceiver {
                var error: NSError? = nil
                transceiver.setDirection(RTCRtpTransceiverDirection.sendOnly, error: &error)
                if error != nil {
                    Logger.error(type: .peerChannel, message: "failed to set direction to transceiver for audio")
                } else {
                    Logger.debug(type: .peerChannel,
                                 message: "set audio sender: mid => \(audioMid), transceiver => \(transceiver.debugDescription)")
                    channel.audioSender = transceiver.sender
                    channel.audioSender!.streamIds = [nativeStream.streamId]
                }
            } else {
                Logger.error(type: .peerChannel, message: "transceiver not found")
            }
        }
        
        if let videoMid = mid?["video"] {
            let transceiver = nativeChannel.transceivers.first(where: { $0.mid == videoMid })
            if let transceiver = transceiver {
                var error: NSError? = nil
                transceiver.setDirection(RTCRtpTransceiverDirection.sendOnly, error: &error)
                if error != nil {
                    Logger.error(type: .peerChannel, message: "failed to set direction to transceiver for video")
                } else {
                    Logger.debug(type: .peerChannel,
                                 message: "set video sender: mid => \(videoMid), transceiver => \(transceiver.debugDescription)")
                    channel.videoSender = transceiver.sender
                    channel.videoSender!.streamIds = [nativeStream.streamId]
                }
            }
        }
        
        /*
        TODO: audioEnabled, videoEnabled がシグナリングとデバイス初期化の2つの目的に使用されているので整理が必要
        一旦、デフォルトでデバイスが初期化されないようにしてみる
        if configuration.audioEnabled {
            channel.attachAudioTrackToSender()
        }
        
        if configuration.videoEnabled {
            channel.attachVideoTrackToSender()
        }
        */
        
        channel.add(stream: stream)
        Logger.debug(type: .peerChannel,
                     message: "create publisher stream (id: \(configuration.publisherStreamId))")
    }
    
    func initializeAudioTrack() -> RTCAudioTrack {
        return NativePeerChannelFactory.default.createNativeAudioTrack(trackId: configuration.publisherAudioTrackId,
                                                                                     constraints: configuration.webRTCConfiguration.nativeConstraints)
    }
    
    func initializeVideoTrack() -> RTCVideoTrack {
        return NativePeerChannelFactory.default.createNativeVideoTrack(trackId: configuration.publisherVideoTrackId)
    }
    
    func initializeCameraVideoCapturer(stream: MediaStream) {
        let position = configuration.cameraSettings.position
        
        // position に対応した CameraVideoCapturer を取得する
        guard position != .unspecified else {
            Logger.error(type: .peerChannel, message: "CameraSettings.position should not be .unspecified")
            return
        }
        let capturer = position == .front ? CameraVideoCapturer.front : CameraVideoCapturer.back
    
        if let device = CameraVideoCapturer.device(for: position) {
            // デバイスに対応したフォーマットとフレームレートを取得する
            guard let format = CameraVideoCapturer.format(width: configuration.cameraSettings.resolution.width,
                                                          height: configuration.cameraSettings.resolution.height,
                                                          for: device) else {
                Logger.error(type: .peerChannel, message: "CameraVideoCapturer.suitableFormat failed: suitable format rate is not found")
                return
            }
            
            guard let frameRate = CameraVideoCapturer.maxFrameRate(configuration.cameraSettings.frameRate, for: format) else {
                Logger.error(type: .peerChannel, message: "CameraVideoCapturer.suitableFormat failed: suitable frame rate is not found")
                return
            }
            
            if CameraVideoCapturer.current != nil && CameraVideoCapturer.current!.isRunning {
                // CameraVideoCapturer.current を停止してから capturer を start する
                CameraVideoCapturer.current!.stop() { (error: Error?) in
                    guard error == nil else {
                        Logger.debug(type: .peerChannel,
                                     message: "CameraVideoCapturer.stop failed =>  \(error!)")
                        return
                    }

                    capturer.start(format: format,
                          frameRate: frameRate) { (error: Error?) in
                        guard error == nil else {
                            Logger.debug(type: .peerChannel,
                                         message: "CameraVideoCapturer.start failed =>  \(error!)")
                            return
                        }
                        capturer.stream = stream
                    }
                }
            } else {
                capturer.start(format: format, frameRate: frameRate) { error in
                    guard error == nil else {
                        Logger.debug(type: .peerChannel,
                                     message: "CameraVideoCapturer.start failed =>  \(error!)")
                        return
                    }
                    Logger.debug(type: .peerChannel,
                                 message: "set CameraVideoCapturer to sender stream")
                    capturer.stream = stream
                }
            }
        } else {
            // 起動可能なデバイスが存在しない場合
            // iPhone/iPad であればここに来ない
            Logger.debug(type: .peerChannel,
                         message: "video capturer is not found")
        }
    }
    
    func initializeAudioInput(category: AVAudioSession.Category) {
        if isAudioInputInitialized {
            Logger.debug(type: .peerChannel,
                         message: "audio input is already initialized")
        } else {
            Logger.debug(type: .peerChannel,
                         message: "initialize audio input")
            
            // カテゴリをマイク用途のものに変更する
            // libwebrtc の内部で参照される RTCAudioSessionConfiguration を使う必要がある
            Logger.debug(type: .peerChannel,
                         message: "change audio session category to \(category.rawValue.debugDescription)")
            RTCAudioSessionConfiguration.webRTC().category = category.rawValue
            
            RTCAudioSession.sharedInstance().initializeInput { error in
                if let error = error {
                    Logger.debug(type: .peerChannel,
                                 message: "failed to initialize audio input => \(error.localizedDescription)")
                    return
                }
                self.isAudioInputInitialized = true
                Logger.debug(type: .peerChannel,
                             message: "audio input is initialized => category \(RTCAudioSession.sharedInstance().category)")
            }
        }
    }
    
    /** `initializeSenderStream()` にて生成されたリソースを開放するための、対になるメソッドです。 */
    func terminateSenderStream() {
        if configuration.videoEnabled || configuration.cameraSettings.isEnabled {
            // CameraVideoCapturer が起動中の場合は停止する
            if let current = CameraVideoCapturer.current {
                current.stop { error in
                    if error != nil {
                        Logger.debug(type: .peerChannel,
                                     message: "failed to stop CameraVideoCapturer =>  \(error!)")
                    }
                }
            }
        }
    }
    
    func createAnswer(isSender: Bool,
                      offer: String,
                      constraints: RTCMediaConstraints,
                      mid: Dictionary<String, String>? = nil,
                      handler: @escaping (String?, Error?) -> Void) {
        Logger.debug(type: .peerChannel, message: "try create answer")
        Logger.debug(type: .peerChannel, message: offer)
        
        Logger.debug(type: .peerChannel, message: "try setting remote description")
        let offer = RTCSessionDescription(type: .offer, sdp: offer)
        nativeChannel.setRemoteDescription(offer) { error in
            guard error == nil else {
                Logger.debug(type: .peerChannel,
                             message: "failed setting remote description: (\(error!.localizedDescription)")
                handler(nil, error)
                return
            }
            Logger.debug(type: .peerChannel, message: "did set remote description")
            Logger.debug(type: .peerChannel, message: "\(offer.sdpDescription)")
            
            if isSender {
                self.initializeSenderStream(mid: mid)
                self.updateSenderOfferEncodings()
            }
            
            Logger.debug(type: .peerChannel, message: "try creating native answer")
            self.nativeChannel.answer(for: constraints) { answer, error in
                guard error == nil else {
                    Logger.debug(type: .peerChannel,
                                 message: "failed creating native answer (\(error!.localizedDescription)")
                    handler(nil, error)
                    return
                }
                Logger.debug(type: .peerChannel, message: "did create answer")
                
                Logger.debug(type: .peerChannel, message: "try setting local description")
                self.nativeChannel.setLocalDescription(answer!) { error in
                    guard error == nil else {
                        Logger.debug(type: .peerChannel,
                                     message: "failed setting local description")
                        handler(nil, error)
                        return
                    }
                    Logger.debug(type: .peerChannel,
                                 message: "did set local description")
                    Logger.debug(type: .peerChannel,
                                 message: "\(answer!.sdpDescription)")
                    Logger.debug(type: .peerChannel,
                                 message: "did create answer")
                    handler(answer!.sdp, nil)
                }
            }
        }
    }
        
    private func updateSenderOfferEncodings() {
        guard let oldEncodings = offerEncodings else {
            return
        }
        Logger.debug(type: .peerChannel, message: "update sender offer encodings")
        for sender in nativeChannel.senders {
            sender.updateOfferEncodings(oldEncodings)
        }
    }
    
    func createAndSendAnswer(offer: SignalingOffer) {
        Logger.debug(type: .peerChannel, message: "try sending answer")
        offerEncodings = offer.encodings
        
        if let config = offer.configuration {
            Logger.debug(type: .peerChannel, message: "update configuration")
            Logger.debug(type: .peerChannel, message: "ICE server infos => \(config.iceServerInfos)")
            Logger.debug(type: .peerChannel, message: "ICE transport policy => \(config.iceTransportPolicy)")
            webRTCConfiguration.iceServerInfos = config.iceServerInfos
            webRTCConfiguration.iceTransportPolicy = config.iceTransportPolicy
            nativeChannel.setConfiguration(webRTCConfiguration.nativeValue)
        }
        
        lock.lock()
        createAnswer(isSender: configuration.isSender,
                     offer: offer.sdp,
                     constraints: webRTCConfiguration.nativeConstraints,
                     mid: offer.mid)
        { sdp, error in
            guard error == nil else {
                Logger.error(type: .peerChannel,
                             message: "failed to create answer (\(error!.localizedDescription))")
                self.lock.unlock()
                self.disconnect(error: SoraError
                    .peerChannelError(reason: "failed to create answer"))
                return
            }
            
            let answer = SignalingAnswer(sdp: sdp!)
            self.signalingChannel.send(message: Signaling.answer(answer))
            self.lock.unlock()
            Logger.debug(type: .peerChannel, message: "did send answer")
        }
    }
    
    
    func createAndSendUpdateAnswer(forOffer offer: String) {
        Logger.debug(type: .peerChannel, message: "create and send update-answer")
        lock.lock()
        createAnswer(isSender: false,
                     offer: offer,
                     constraints: webRTCConfiguration.nativeConstraints)
        { answer, error in
            guard error == nil else {
                Logger.error(type: .peerChannel,
                             message: "failed to create update-answer (\(error!.localizedDescription)")
                self.lock.unlock()
                self.disconnect(error: SoraError
                    .peerChannelError(reason: "failed to create update-answer"))
                return
            }
            
            let message = Signaling.update(SignalingUpdate(sdp: answer!))
            self.signalingChannel.send(message: message)
            
            if (self.configuration.isSender) {
                self.updateSenderOfferEncodings()
            }
            
            Logger.debug(type: .peerChannel, message: "call onUpdate")
            self.channel.internalHandlers.onUpdate?(answer!)
            self.channel.handlers.onUpdate?(answer!)
            
            self.lock.unlock()
        }
    }
    
    func createAndSendReAnswer(forReOffer reOffer: String) {
        Logger.debug(type: .peerChannel, message: "create and send re-answer")
        lock.lock()
        createAnswer(isSender: false,
                     offer: reOffer,
                     constraints: webRTCConfiguration.nativeConstraints)
        { answer, error in
            guard error == nil else {
                Logger.error(type: .peerChannel,
                             message: "failed to create re-answer (\(error!.localizedDescription)")
                self.lock.unlock()
                self.disconnect(error: SoraError
                    .peerChannelError(reason: "failed to create re-answer"))
                return
            }
            
            let message = Signaling.reAnswer(SignalingReAnswer(sdp: answer!))
            self.signalingChannel.send(message: message)
            
            if (self.configuration.isSender) {
                self.updateSenderOfferEncodings()
            }
            
            Logger.debug(type: .peerChannel, message: "call onUpdate")
            self.channel.internalHandlers.onUpdate?(answer!)
            self.channel.handlers.onUpdate?(answer!)
            
            self.lock.unlock()
        }
    }
    
    func handle(signaling: Signaling) {
        Logger.debug(type: .mediaStream, message: "handle signaling => \(signaling.typeName())")
        switch signaling {
        case .offer(let offer):
            clientId = offer.clientId
            connectionId = offer.connectionId
            createAndSendAnswer(offer: offer)
            
        case .update(let update):
            if configuration.isMultistream {
                createAndSendUpdateAnswer(forOffer: update.sdp)
            }
        case .reOffer(let reOffer):
            createAndSendReAnswer(forReOffer: reOffer.sdp)

        case .ping(let ping):
            let pong = SignalingPong()
            if ping.statisticsEnabled == true {
                nativeChannel.statistics { report in
                    var json: [String: Any] = ["type": "pong"]
                    let stats = Statistics(contentsOf: report)
                    json["stats"] = stats.jsonObject
                    do {
                        let data = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted])
                        if let message = String(data: data, encoding: .utf8) {
                            self.signalingChannel.send(text: message)
                        } else {
                            self.signalingChannel.send(message: .pong(pong))
                        }
                    } catch {
                        self.signalingChannel.send(message: .pong(pong))
                    }
                }
            } else {
                signalingChannel.send(message: .pong(pong))
            }
            
        default:
            break
        }
        
        Logger.debug(type: .peerChannel, message: "call onReceiveSignaling")
        channel.internalHandlers.onReceiveSignaling?(signaling)
        channel.handlers.onReceiveSignaling?(signaling)
    }
    
    func finishConnecting() {
        Logger.debug(type: .peerChannel, message: "did connect")
        Logger.debug(type: .peerChannel,
                     message: "media streams = \(channel.streams.count)")
        Logger.debug(type: .peerChannel,
                     message: "native senders = \(nativeChannel.senders.count)")
        Logger.debug(type: .peerChannel,
                     message: "native receivers = \(nativeChannel.receivers.count)")
        state = .connected
        
        if onConnectHandler != nil {
            Logger.debug(type: .peerChannel, message: "call connect(handler:)")
            onConnectHandler!(nil)
            onConnectHandler = nil
        }
        lock.unlock()
    }
    
    func disconnect(error: Error?) {
        switch state {
        case .disconnecting, .disconnected:
            break
        default:
            Logger.debug(type: .peerChannel, message: "wait to disconnect")
            lock.waitDisconnect(error: error)
        }
    }
    
    func basicDisconnect(error: Error?) {
        Logger.debug(type: .peerChannel, message: "try disconnecting")
        if let error = error {
            Logger.error(type: .peerChannel,
                         message: "error: \(error.localizedDescription)")
        }
        
        state = .disconnecting
        
        if configuration.isSender {
            terminateSenderStream()
        }
        channel.terminateAllStreams()
        nativeChannel.close()
        
        signalingChannel.send(message: Signaling.disconnect)
        signalingChannel.disconnect(error: error)
        
        state = .disconnected
        
        Logger.debug(type: .peerChannel, message: "call onDisconnect")
        channel.internalHandlers.onDisconnect?(error)
        channel.handlers.onDisconnect?(error)
        
        if onConnectHandler != nil {
            Logger.debug(type: .peerChannel, message: "call connect(handler:)")
            onConnectHandler!(error)
            onConnectHandler = nil
        }
        
        Logger.debug(type: .peerChannel, message: "did disconnect")
    }
    
    // MARK: - RTCPeerConnectionDelegate
    
    func peerConnection(_ nativePeerConnection: RTCPeerConnection,
                        didChange stateChanged: RTCSignalingState) {
        Logger.debug(type: .peerChannel,
                     message: "signaling state: \(stateChanged)")
    }
    
    func peerConnection(_ nativePeerConnection: RTCPeerConnection,
                        didAdd stream: RTCMediaStream) {
        Logger.debug(type: .peerChannel,
                     message: "try add a stream (id: \(stream.streamId))")
        for cur in channel.streams {
            if cur.streamId == stream.streamId {
                Logger.debug(type: .peerChannel,
                             message: "stream already exists")
                return
            }
        }
        
        if channel.configuration.isMultistream &&
            stream.streamId == clientId {
            Logger.debug(type: .peerChannel,
                         message: "stream already exists in multistream")
            return
        }
        
        Logger.debug(type: .peerChannel, message: "add a stream")
        stream.audioTracks.first?.source.volume = MediaStreamAudioVolume.max
        
        // WARN: connect シグナリングで audio=false とすると answer の生成に失敗するため、
        // 音声トラックを使用しない方法で回避する
        if !configuration.audioEnabled {
            Logger.debug(type: .peerChannel, message: "disable audio tracks")
            let tracks = stream.audioTracks
            for track in tracks {
                track.source.volume = 0
                stream.removeAudioTrack(track)
            }
        }
        
        let stream = BasicMediaStream(peerChannel: self.channel,
                                      nativeStream: stream)
        channel.add(stream: stream)
    }
    
    func peerConnection(_ nativePeerConnection: RTCPeerConnection,
                        didRemove stream: RTCMediaStream) {
        Logger.debug(type: .peerChannel,
                     message: "removed a media stream (id: \(stream.streamId))")
        channel.remove(streamId: stream.streamId)
    }
    
    func peerConnectionShouldNegotiate(_ nativePeerConnection: RTCPeerConnection) {
        Logger.debug(type: .peerChannel, message: "required negatiation")
    }
    
    func peerConnection(_ nativePeerConnection: RTCPeerConnection,
                        didChange newState: RTCIceConnectionState) {
        Logger.debug(type: .peerChannel,
                     message: "ICE connection state: \(newState)")
    }
    
    func peerConnection(_ nativePeerConnection: RTCPeerConnection,
                        didChange newState: RTCIceGatheringState) {
        Logger.debug(type: .peerChannel,
                     message: "ICE gathering state: \(newState)")
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection,
                        didChange newState: RTCPeerConnectionState) {
        Logger.debug(type: .peerChannel,
                     message: "peer connection state: \(String(describing: newState))")
        switch newState {
        case .failed:
            disconnect(error: SoraError.peerChannelError(reason: "peer connection state: failed"))
        case .connected:
            // peer connection state が connecting => connected => connecting => connected と変化するケースがあった
            // 初回の connected のみで finishConnecting を実行したい
            if state != .connected {
                finishConnecting()
            }
        default:
            break
        }
    }
    
    func peerConnection(_ nativePeerConnection: RTCPeerConnection,
                        didGenerate candidate: RTCIceCandidate) {
        Logger.debug(type: .peerChannel,
                     message: "generated ICE candidate \(candidate)")
        let candidate = ICECandidate(nativeICECandidate: candidate)
        channel.add(iceCandidate: candidate)
        let message = Signaling.candidate(SignalingCandidate(candidate: candidate))
        signalingChannel.send(message: message)
    }
    
    func peerConnection(_ nativePeerConnection: RTCPeerConnection,
                        didRemove candidates: [RTCIceCandidate]) {
        Logger.debug(type: .peerChannel,
                     message: "removed ICE candidate \(candidates)")
        let candidates = channel.iceCandidates.filter {
            old in
            for candidate in candidates {
                let remove = ICECandidate(nativeICECandidate: candidate)
                if old == remove {
                    return true
                }
            }
            return false
        }
        for candidate in candidates {
            channel.remove(iceCandidate: candidate)
        }
    }
    
    // NOTE: Sora はデータチャネルに非対応
    func peerConnection(_ nativePeerConnection: RTCPeerConnection,
                        didOpen dataChannel: RTCDataChannel) {
        Logger.debug(type: .peerChannel, message: "opened data channel (ignored)")
        // 何もしない
    }
    
}

extension RTCRtpSender {
    
    func updateOfferEncodings(_ encodings: [SignalingOffer.Encoding]) {
        Logger.debug(type: .peerChannel, message: "update offer encodings for sender => \(senderId)")
        
        // paramaters はアクセスのたびにコピーされてしまうので、すべての parameters をセットし直す
        let newParameters = parameters // コピーされる
        for oldEncoding in newParameters.encodings {
            Logger.debug(type: .peerChannel, message: "update encoding => \(ObjectIdentifier(oldEncoding))")
            for encoding in encodings {
                guard oldEncoding.rid == encoding.rid else {
                    continue
                }
                
                if let rid = encoding.rid {
                    Logger.debug(type: .peerChannel, message: "rid => \(rid)")
                    oldEncoding.rid = rid
                }
                
                Logger.debug(type: .peerChannel, message: "active => \(encoding.active)")
                oldEncoding.isActive = encoding.active
                Logger.debug(type: .peerChannel, message: "old active => \(oldEncoding.isActive)")

                if let value = encoding.maxFramerate {
                    Logger.debug(type: .peerChannel, message: "maxFramerate:  \(value)")
                    oldEncoding.maxFramerate = NSNumber(floatLiteral: value)
                }
                
                if let value = encoding.maxBitrate {
                    Logger.debug(type: .peerChannel, message: "maxBitrate: \(value))")
                    oldEncoding.maxBitrateBps = NSNumber(integerLiteral: value)
                }
                
                if let value = encoding.scaleResolutionDownBy {
                    Logger.debug(type: .peerChannel, message: "scaleResolutionDownBy: \(value))")
                    oldEncoding.scaleResolutionDownBy = NSNumber(value: value)
                }
                
                break
            }
        }
        
        self.parameters = newParameters
    }
}
