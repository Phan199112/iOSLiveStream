//
//  ViewController.swift
//  StartLiveStream
//
//  Created by Aziz on 2018-06-22.
//  Copyright © 2018 Aziz. All rights reserved.
//

import UIKit
import HaishinKit
import AVFoundation
import SnapKit
import Parse
import SwiftDate

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
    let query = PFQuery(className:"Stream")
    query.whereKey("endsAt", greaterThan:Date())
    query.order(byAscending: "endsAt")
    query.limit = 1
    query.findObjectsInBackground { (objs, error) in
      
      guard let stream = objs?.last, let startsAt = stream["startsAt"] as? Date else {
        self.titleLabel.text = "There are no live streams currently scheduled. Please check back later."
        self.startButton.isHidden = true
        return
      }
      
      self.stream = stream
      
      if ((Date() + 15.minutes) < startsAt) {
        self.titleLabel.text = "Next scheduled livestream is \(startsAt.colloquialSinceNow() ?? "")\nAbout 15 minutes before the stream starts, you will be able to start streaming.\nWe'll send you a push notification."
        self.startButton.isHidden = true
      } else {
        self.titleLabel.text = "Next scheduled livestream is \(startsAt.colloquialSinceNow() ?? "")"
        
        self.startButton.isHidden = false
      }
      
    }

  }
  
  @objc func initializeStream() {
    guard let stream = stream else { return }
    
    
    do {
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
    rtmpStream.attachCamera(DeviceUtil.device(withPosition: .back)) { error in
      // print(error)
    }
    
    let hkView = HKView(frame: view.bounds)
    hkView.videoGravity = AVLayerVideoGravity.resizeAspectFill
    hkView.attachStream(rtmpStream)
    
    // add ViewController#view
    view.addSubview(hkView)
    
    //    rtmpConnection.connect("rtmp://live-yto.twitch.tv/app/live_216028934_JUtjWUzoIjEbjev25FC8s3Y9Dcdt7H")
//    rtmpConnection.connect("rtmp://a.rtmp.youtube.com/live2")
//    rtmpStream.publish("20p6-zu7z-rxjf-5ur8")
    
      rtmpConnection.connect(stream["streamURL"] as? String ?? "")
      rtmpStream.publish(stream["streamKey"] as? String ?? "")
  }
  
  
}

