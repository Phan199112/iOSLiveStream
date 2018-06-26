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

class ViewController: UIViewController {
  
  let titleLabel: UILabel = {
    let view = UILabel()
    view.numberOfLines = 0
    view.textAlignment = .center
    view.text = "There are no live streams currently scheduled. Please check back later."
    return view
  }()
  
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

  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    view.backgroundColor = .white
    
    // checks for livestreams every 5 seconds
    timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true, block: { (_) in
      self.update()
    })
    
    startButton.addTarget(self, action: #selector(self.initializeStream), for: .touchUpInside)
    
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
  

  func update() {
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
  }
  
  
}

