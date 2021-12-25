//
//  NumberTileGame.swift
//  swift-2048
//
//  Created by Austin Zheng on 6/3/14.
//  Copyright (c) 2014 Austin Zheng. Released under the terms of the MIT license.
//

import UIKit
import Vision
import AVFoundation

/// A view controller representing the swift-2048 game. It serves mostly to tie a GameModel and a GameboardView
/// together. Data flow works as follows: user input reaches the view controller and is forwarded to the model. Move
/// orders calculated by the model are returned to the view controller and forwarded to the gameboard view, which
/// performs any animations to update its state.
class NumberTileGameViewController : UIViewController, GameModelProtocol {
    // Face recognition init
    private var _captureSession = AVCaptureSession()
    private var _videoDevice = AVCaptureDevice.default(for: AVMediaType.video)
    private var _videoOutput = AVCaptureVideoDataOutput()
//    private var _videoLayer : AVCaptureVideoPreviewLayer? = nil
    
    //Analytics
    var angles: [(String, Double)] = []
    
    var timeForAction: [UInt64] = []
    var timeFromLastAction = DispatchTime.now().rawValue
    
    var actionsForTime: [Int] = []
    var timestampForActions = DispatchTime.now().rawValue
    var curentActionsForTime = 0
    
  // How many tiles in both directions the gameboard contains
  var dimension: Int = 4
  // The value of the winning tile
  var threshold: Int = 2048

  var board: GameboardView?
  var model: GameModel?

  var scoreView: ScoreViewProtocol?

  // Width of the gameboard
  var boardWidth: CGFloat = 300
  // How much padding to place between the tiles
  let thinPadding: CGFloat = 3.0
  let thickPadding: CGFloat = 6.0

  // Amount of space to place between the different component views (gameboard, score view, etc)
  let viewPadding: CGFloat = 10.0

  // Amount that the vertical alignment of the component views should differ from if they were centered
  let verticalViewOffset: CGFloat = 0.0

  init() {
    super.init(nibName: nil, bundle: nil)
    
  }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
     }
    
//  required init()

  // View Controller
  override func viewDidLoad()  {
    super.viewDidLoad()
      model = GameModel(dimension: dimension, threshold: threshold, delegate: self)
      view.backgroundColor = UIColor.white
      boardWidth = 0.9*view.bounds.size.width
      setUpFaceRecognition()
    setupGame()
  }

  func reset() {
    assert(board != nil && model != nil)
    let b = board!
    let m = model!
    b.reset()
    m.reset()
    m.insertTileAtRandomLocation(withValue: 2)
    m.insertTileAtRandomLocation(withValue: 2)
  }

  func setupGame() {
    let vcHeight = view.bounds.size.height
    let vcWidth = view.bounds.size.width

    // This nested function provides the x-position for a component view
    func xPositionToCenterView(_ v: UIView) -> CGFloat {
      let viewWidth = v.bounds.size.width
      let tentativeX = 0.5*(vcWidth - viewWidth)
      return tentativeX >= 0 ? tentativeX : 0
    }
    // This nested function provides the y-position for a component view
    func yPositionForViewAtPosition(_ order: Int, views: [UIView]) -> CGFloat {
      assert(views.count > 0)
      assert(order >= 0 && order < views.count)
//      let viewHeight = views[order].bounds.size.height
      let totalHeight = CGFloat(views.count - 1)*viewPadding + views.map({ $0.bounds.size.height }).reduce(verticalViewOffset, { $0 + $1 })
      let viewsTop = 0.5*(vcHeight - totalHeight) >= 0 ? 0.5*(vcHeight - totalHeight) : 0

      // Not sure how to slice an array yet
      var acc: CGFloat = 0
      for i in 0..<order {
        acc += viewPadding + views[i].bounds.size.height
      }
      return viewsTop + acc
    }

    // Create the score view
    let scoreView = ScoreView(backgroundColor: UIColor.black,
      textColor: UIColor.white,
      font: UIFont(name: "HelveticaNeue-Bold", size: 16.0) ?? UIFont.systemFont(ofSize: 16.0),
      radius: 6)
    scoreView.score = 0
//      scoreView.alpha = 0.5
//      scoreView.layer.opacity = 0.5

    // Create the gameboard
    let padding: CGFloat = dimension > 5 ? thinPadding : thickPadding
    let v1 = boardWidth - padding*(CGFloat(dimension + 1))
    let width: CGFloat = CGFloat(floorf(CFloat(v1)))/CGFloat(dimension)
    let gameboard = GameboardView(dimension: dimension,
      tileWidth: width,
      tilePadding: padding,
      cornerRadius: 6,
      backgroundColor: UIColor.black,
      foregroundColor: UIColor.darkGray)
//      gameboard.alpha = 0.5
//      gameboard.layer.opacity = 0.5

    // Set up the frames
    let views = [scoreView, gameboard]

    var f = scoreView.frame
    f.origin.x = xPositionToCenterView(scoreView)
    f.origin.y = yPositionForViewAtPosition(0, views: views)
    scoreView.frame = f

    f = gameboard.frame
    f.origin.x = xPositionToCenterView(gameboard)
    f.origin.y = yPositionForViewAtPosition(1, views: views)
    gameboard.frame = f


    // Add to game state
    view.addSubview(gameboard)
//      view.layer.addSublayer(gameboard.layer)
    board = gameboard
    view.addSubview(scoreView)
//      view.layer.addSublayer(scoreView.layer)
    self.scoreView = scoreView

    assert(model != nil)
    let m = model!
    m.insertTileAtRandomLocation(withValue: 2)
    m.insertTileAtRandomLocation(withValue: 2)
  }

  // Misc
  func followUp() {
    assert(model != nil)
    let m = model!
    let (userWon, _) = m.userHasWon()
    if userWon {
      // TODO: alert delegate we won
        let alert = UIAlertController(title: "Victory", message: "You won!", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ок", style: .default))
        present(alert, animated: true)
        let manager = NetworkManager()
        manager.request(parameters: formJSONString(), method: "POST", endpoint: "send_data_2048")
        _captureSession.stopRunning()
      // TODO: At this point we should stall the game until the user taps 'New Game' (which hasn't been implemented yet)
      return
    }

    // Now, insert more tiles
    let randomVal = Int(arc4random_uniform(10))
    m.insertTileAtRandomLocation(withValue: randomVal == 1 ? 4 : 2)

    // At this point, the user may lose
    if m.userHasLost() {
      // TODO: alert delegate we lost
      NSLog("You lost...")
        let alert = UIAlertController(title: "Defeat", message: "You lost...", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ок", style: .default))
        present(alert, animated: true)
        let manager = NetworkManager()
        manager.request(parameters: formJSONString(), method: "POST", endpoint: "send_data_2048")
        _captureSession.stopRunning()
    }
  }

  // Commands
  func upCommand() {
    assert(model != nil)
    let m = model!
    m.queueMove(direction: MoveDirection.up,
      onCompletion: { (changed: Bool) -> () in
        if changed {
          self.followUp()
        }
      })
  }

  func downCommand() {
    assert(model != nil)
    let m = model!
    m.queueMove(direction: MoveDirection.down,
      onCompletion: { (changed: Bool) -> () in
        if changed {
          self.followUp()
        }
      })
  }

  func leftCommand() {
    assert(model != nil)
    let m = model!
    m.queueMove(direction: MoveDirection.left,
      onCompletion: { (changed: Bool) -> () in
        if changed {
          self.followUp()
        }
      })
  }

  func rightCommand() {
    assert(model != nil)
    let m = model!
    m.queueMove(direction: MoveDirection.right,
      onCompletion: { (changed: Bool) -> () in
        if changed {
          self.followUp()
        }
      })
  }

  // Protocol
  func scoreChanged(to score: Int) {
    if scoreView == nil {
      return
    }
    let s = scoreView!
    s.scoreChanged(to: score)
  }

  func moveOneTile(from: (Int, Int), to: (Int, Int), value: Int) {
    assert(board != nil)
    let b = board!
    b.moveOneTile(from: from, to: to, value: value)
  }

  func moveTwoTiles(from: ((Int, Int), (Int, Int)), to: (Int, Int), value: Int) {
    assert(board != nil)
    let b = board!
    b.moveTwoTiles(from: from, to: to, value: value)
  }

  func insertTile(at location: (Int, Int), withValue value: Int) {
    assert(board != nil)
    let b = board!
    b.insertTile(at: location, value: value)
  }
}


extension NumberTileGameViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func setUpFaceRecognition() {
        self._captureSession = AVCaptureSession()
        self._videoOutput = AVCaptureVideoDataOutput()
        self._videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)

        do {
            let videoInput = try AVCaptureDeviceInput(device: self._videoDevice!) as AVCaptureDeviceInput
            self._captureSession.addInput(videoInput)
        } catch let error as NSError {
            print(error)
        }
        
        self._videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as AnyHashable as! String : Int(kCVPixelFormatType_32BGRA)]

        self._videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue.main)
        self._videoOutput.alwaysDiscardsLateVideoFrames = true
        
        self._captureSession.addOutput(self._videoOutput)

        for connection in self._videoOutput.connections {
            connection.videoOrientation = .portrait
        }
        
//        self._videoLayer = AVCaptureVideoPreviewLayer(session: self._captureSession)
//        self._videoLayer?.frame = UIScreen.main.bounds
//        self._videoLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
//        self._videoLayer?.opacity = 0.7
//        self.view.layer.addSublayer(self._videoLayer!)

        self._captureSession.startRunning()
    }
    
    private func imageFromSampleBuffer(sampleBuffer: CMSampleBuffer) -> UIImage {
        let imageBuffer: CVImageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
        CVPixelBufferLockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
        let baseAddress = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = (CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)
        let context = CGContext(data: baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo)
        let imageRef = context!.makeImage()
        
        CVPixelBufferUnlockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
        let resultImage: UIImage = UIImage(cgImage: imageRef!)
        return resultImage
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
                
        let captureSessiongroup = DispatchGroup()
        
        captureSessiongroup.enter()
        self._captureSession.stopRunning()

        DispatchQueue.global(qos: .userInteractive).async {
            let image: UIImage = self.imageFromSampleBuffer(sampleBuffer: sampleBuffer)

            let requestFaceRect = VNDetectFaceRectanglesRequest { request, _ in
                for observation in request.results as! [VNFaceObservation] {
                    if #available(iOS 15.0, *) {
                        if let pitch = observation.pitch {
                            let pitchValue = pitch.doubleValue * 180.0 / Double.pi
                            // 20 - down
                            // -20 -up
                            if pitchValue >= 10 {
                                DispatchQueue.main.async {
                                    self.downCommand()
                                    self.collectStatistics(forAction: .down, withValue: pitchValue)
                                }
                                sleep(1)
                            }
                            if pitchValue <= -15 {
                                DispatchQueue.main.async {
                                    self.upCommand()
                                    self.collectStatistics(forAction: .up, withValue: pitchValue)
                                }
                                sleep(1)
                            }
                            
                            
                        } else {
                            print("-------")
                        }
                    } else {
                        // Fallback on earlier versions
                    }
                    if let roll = observation.roll {
                        let rollValue = roll.doubleValue * 180.0 / Double.pi
                        //20 - right
                        //-20 - left
                        if rollValue >= 15 {
                            DispatchQueue.main.async {
                                self.rightCommand()
                                self.collectStatistics(forAction: .right, withValue: rollValue)
                            }
                            sleep(1)

                        }
                        if rollValue <= -15 {
                            DispatchQueue.main.async {
                                self.leftCommand()
                                self.collectStatistics(forAction: .left, withValue: rollValue)
                            }
                            sleep(1)
                        }
                        
                    } else {
                        print("-------")
                    }
                }
                captureSessiongroup.leave()
            }
            
            if let cgImage = image.cgImage {
                let faceRecHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                try? faceRecHandler.perform([requestFaceRect])
            }
        }
        
        let workItem = DispatchWorkItem {
            self._captureSession.startRunning()
        }
        
        captureSessiongroup.notify(queue: DispatchQueue.main, work: workItem)

    }
    
    func collectStatistics(forAction actionType: ActionType, withValue value: Double) {
        angles.append((actionType.rawValue, value))
        let newActionTime = DispatchTime.now().rawValue
        let interval = newActionTime - timeFromLastAction
        timeForAction.append(interval)
        if newActionTime - timestampForActions > 400000000 {
            actionsForTime.append(curentActionsForTime)
            timestampForActions = newActionTime
            curentActionsForTime = 0
        } else {
            curentActionsForTime += 1
        }
    }
    
    enum ActionType: String {
        case up = "up"
        case down = "down"
        case left = "left"
        case right = "right"
    }
    
    func formJSONString() -> Data? {
        let date = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd.MM.yyyy hh:mm:ss"
        let curDate = dateFormatter.string(from: date)
        
//        var formatedAnglesString =  String(angles).replacingOccurrences(of: "(", with: "[").replacingOccurrences(of: ")", with: "]")
        var formatedAnglesString = ""
        angles.forEach{
            formatedAnglesString = "[\"\($0.0)\", \($0.1)], "
        }
        formatedAnglesString = formatedAnglesString.trimmingCharacters(in: [",", " "])
        
        let timeForActionstring = "\"0\":{\"name\":\"timeForAction\", \"value\":\(timeForAction), \"date\":\"\(curDate)\"}"
        let actionsForTimeString = "\"1\":{\"name\":\"actionsForTime\", \"value\":\(actionsForTime), \"date\":\"\(curDate)\"}"
        let anglesString = "\"2\":{\"name\":\"angles\", \"value\":[\(formatedAnglesString)], \"date\":\"\(curDate)\"}"
        let scoreString = "\"3\":{\"name\":\"score\", \"value\":\(model!.score), \"date\":\"\(curDate)\"}"
        
        let finalString = "{\(timeForActionstring), \(actionsForTimeString), \(anglesString), \(scoreString)}"
        print(finalString)
        
        return finalString.data(using: .utf8)
        
    }
    
}
