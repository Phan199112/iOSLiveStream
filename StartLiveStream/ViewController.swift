//
//  ViewController.swift
//  StartLiveStream
//
//  Created by Aziz on 2018-06-22.
//  Copyright © 2018 Aziz. All rights reserved.
//


import UIKit
import HaishinKit
// ^^ this is the streaming library that streams and manages RTMP session/grabs video/audio frames from camera and passes it on to YouTube's server
import AVFoundation
import SnapKit
// ^^ convenience library for formattting of front end with layout library
import Parse
// communicates with backend server
import SwiftDate
// gets dates in readable format
import SVProgressHUD
import Alamofire

extension UITextView {
  func simple_scrollToBottom() {
    let textCount: Int = text.count
    guard textCount >= 1 else { return }
    scrollRangeToVisible(NSMakeRange(textCount - 1, 1))
  }
}


class ViewController: UIViewController {
  let API_KEY = "AIzaSyDY2FaAt00BAe_Qsh4n2VKPdGImbXAuxNY"
  
  // set font of comments
  let titleLabel: UILabel = {
    let view = UILabel()
    view.numberOfLines = 0
    view.textAlignment = .center
    view.text = "Check with server...hold on"
    
    
    return view
  }()
  
  let textView: UITextView = {
    let view = UITextView()
    view.backgroundColor = .clear
    view.textColor = .white
    view.isSelectable = false
    return view
  }()
  
  var messages = [String]()
  
  let startButton: UIButton = {
    let button = UIButton(type: .system)
    button.setTitle("   Start Streaming   ", for: .normal)
    button.setTitleColor(.black, for: .normal)
    button.layer.borderColor = UIColor.lightGray.cgColor
    button.layer.borderWidth = 1
    button.layer.cornerRadius = 4
    button.titleLabel?.font = UIFont.systemFont(ofSize: 22)
    button.isHidden = true
    return button
  }()
  
  var timer: Timer?
  var stream: PFObject?
  
  let session: AVAudioSession = AVAudioSession.sharedInstance()
  
  var hkView: UIView?
  var rtmpStream: RTMPStream?
  var rtmpConnection: RTMPConnection?
  
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    view.backgroundColor = .white
    
    // checks for livestreams every 5 seconds
    timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true, block: { (_) in
      self.update()
    })
    
    startButton.addTarget(self, action: #selector(self.auth), for: .touchUpInside)
    
    view.addSubview(titleLabel)
    titleLabel.snp.makeConstraints { (make) in
      make.left.right.equalToSuperview()
      make.centerX.equalToSuperview()
      make.top.equalToSuperview().offset(100)
    }
    
    view.addSubview(startButton)
    startButton.snp.makeConstraints { (make) in
      make.centerX.equalToSuperview()
      make.top.equalTo(titleLabel.snp.bottom).offset(30)
    }
    
    self.update()
  }
  
  func getComments() {
    guard hkView?.superview != nil else { print("returning"); return }
    
    
    Alamofire.request("https://www.googleapis.com/youtube/v3/liveChat/messages?liveChatId=EiEKGFVDU1VhR3BfcjRNN3ZJLTZCc250OTh4ZxIFL2xpdmU&part=snippet&key=AIzaSyDY2FaAt00BAe_Qsh4n2VKPdGImbXAuxNY", method: .get).responseJSON { (resp) in
      
      guard let resp = resp.value as? [String:Any],
        let items = resp["items"] as? [[String:Any]] else {
          print("uh oh ")
          return
      }
      
      self.messages = items.map { ($0["snippet"] as? [String: Any])?["displayMessage"] as? String ?? ":("}
      let text = self.messages.reduce("") { (res, msg) in
        return "\(res)\n\(msg)\n"
      }
      self.textView.text = text
      self.textView.simple_scrollToBottom()
    }
  }
  
  
  func update() {
    getComments()
    // queries the stream table in parse (only table that matters!)
    let query = PFQuery(className:"Stream")
    // checks to see if endsat is greater than now
    query.whereKey("endsAt", greaterThan:Date())
    
    // ends at gives interval so that we know this stream is presently going
    query.order(byAscending: "endsAt")
    
    // makes it so latest stream is first and cuts off remaining
    query.limit = 1
    query.findObjectsInBackground { (objs, error) in
      
      // checks if there is a current stream
      guard let stream = objs?.last, let startsAt = stream["startsAt"] as? Date else {
        self.titleLabel.text = "There are no live streams currently scheduled. Please check back later."
        self.startButton.isHidden = true
        return
      }
      
      self.stream = stream
      
      //      this sets the time before the stream where the "start streaming" button appears
      if ((Date() + 15.minutes) < startsAt) {
        self.titleLabel.text = "Next scheduled livestream is \(startsAt.colloquialSinceNow() ?? "")\nAbout 15 minutes before the stream starts, you will be able to start streaming.\nWe'll send you a push notification."
        self.startButton.isHidden = true
      } else {
        self.titleLabel.text = "Next scheduled livestream is \(startsAt.colloquialSinceNow() ?? "")"
        
        self.startButton.isHidden = false
        
        // only if the time is less than 15 minutes before start time
      }
      
    }
    
  }
  
  @objc func auth() {
    let alert = UIAlertController(title: "Passcode", message: "Please specify the passcode to initiate livestream", preferredStyle: UIAlertControllerStyle.alert)
    let action = UIAlertAction(title: "Go", style: .default) { (alertAction) in
      let textField = alert.textFields![0] as UITextField
      
      guard let text = textField.text, let passcode = self.stream?["passcode"] as? String, text == passcode else {
        SVProgressHUD.showError(withStatus: "Wrong passcode.")
        return
      }
      
      SVProgressHUD.showSuccess(withStatus: "Awesome")
      
      self.initializeStream()
    }
    
    
    alert.addTextField { (textField) in
      textField.placeholder = "Passcode"
      textField.isSecureTextEntry = true
    }
    
    alert.addAction(action)
    
    present(alert, animated: true, completion: nil)
    
    
  }
  
  @objc func initializeStream() {
    guard let stream = stream else { return }
    
    // audio quality so that it doesn't kill user's data; video is default
    do {
      // preferred sample rate is how many times in a sample it samples the audio; higher means better audio
      try session.setPreferredSampleRate(44_100)
      try session.setCategory(AVAudioSessionCategoryPlayAndRecord, with: .allowBluetooth)
      try session.setMode(AVAudioSessionModeDefault)
      try session.setActive(true)
    } catch {
      print("av audio session error")
    }
    
    
    
    let rtmpConnection:RTMPConnection = RTMPConnection()
    
    let rtmpStream: RTMPStream = RTMPStream(connection: rtmpConnection)
    
    rtmpStream.captureSettings = [
      "fps": 30, // FPS
      "sessionPreset": AVCaptureSession.Preset.medium, // input video width/height
      "continuousAutofocus": false, // use camera autofocus mode
      "continuousExposure": false, //  use camera exposure mode
    ]
    
    rtmpStream.videoSettings = [
      "width": 360, // video output width
      "height": 640, // video output height
      "bitrate": 160 * 1024, // video output bitrate
      // "dataRateLimits": [160 * 1024 / 8, 1], optional kVTCompressionPropertyKey_DataRateLimits property
      "maxKeyFrameIntervalDuration": 2, // key frame / sec
    ]
    
    rtmpStream.attachAudio(AVCaptureDevice.default(for: .audio)) { error in
      // print(error)
    }
    rtmpStream.attachCamera(DeviceUtil.device(withPosition: .front)) { error in
      // print(error)
    }
    // hkview is the live camera view where you can see yourself streaming
    let hkView = HKView(frame: view.bounds)
    hkView.videoGravity = AVLayerVideoGravity.resizeAspectFill
    hkView.attachStream(rtmpStream)
    
    
    // add ViewController#view
    view.addSubview(hkView)
    
    // HARD CODED
    //    rtmpConnection.connect("rtmp://live-yto.twitch.tv/app/live_216028934_JUtjWUzoIjEbjev25FC8s3Y9Dcdt7H")
    //    rtmpConnection.connect("rtmp://a.rtmp.youtube.com/live2")
    //    rtmpStream.publish("20p6-zu7z-rxjf-5ur8")
    
    rtmpConnection.connect(stream["streamURL"] as? String ?? "")
    rtmpStream.publish(stream["streamKey"] as? String ?? "")
    
    
    
    let liveLabel = UILabel()
    liveLabel.backgroundColor = .green
    liveLabel.textColor = .white
    liveLabel.text = "  LIVE  "
    liveLabel.layer.cornerRadius = 3
    liveLabel.layer.masksToBounds = true
    
    
    hkView.addSubview(liveLabel)
    liveLabel.snp.makeConstraints { (make) in
      make.left.top.equalToSuperview().offset(20)
    }
    
    hkView.addSubview(textView)
    textView.snp.makeConstraints {
      $0.left.bottom.equalToSuperview()
      $0.right.equalToSuperview().multipliedBy(0.5)
      $0.height.equalToSuperview().multipliedBy(0.4)
    }
    
    self.hkView = hkView
    self.rtmpConnection = rtmpConnection
    self.rtmpStream = rtmpStream
    
    
    
    let hangupButton = UIButton(type: .system)
    hangupButton.setImage(UIImage(named: "hangup"), for: .normal)
    hangupButton.tintColor = .red
    
    hkView.addSubview(hangupButton)
    hangupButton.snp.makeConstraints { (make) in
      make.bottom.right.equalToSuperview().offset(-20)
    }
    
    hangupButton.addTarget(self, action: #selector(self.hangup), for: .touchUpInside)
    
  }
  
  @objc func hangup() {
    
    SVProgressHUD.show(withStatus: "Hold Up")
    
    Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { (_) in
      self.rtmpConnection?.close()
      self.hkView?.removeFromSuperview()
      self.textView.removeFromSuperview()
      
      SVProgressHUD.dismiss()
    }
  }
  
  
}

