//
//  PreviewViewController.swift
//  NBATikTok
//
//  Created by RandyLiu on 20/8/2020.
//  Copyright © 2020 h-tamader-team/RandyLiu. All rights reserved.
//

import UIKit
import AVFoundation
import Photos

struct AppUtility {

    static func lockOrientation(_ orientation: UIInterfaceOrientationMask) {
    
        if let delegate = UIApplication.shared.delegate as? AppDelegate {
            delegate.orientationLock = orientation
        }
    }

    /// OPTIONAL Added method to adjust lock and rotate to the desired orientation
    static func lockOrientation(_ orientation: UIInterfaceOrientationMask, andRotateTo rotateOrientation:UIInterfaceOrientation) {
   
        self.lockOrientation(orientation)
    
        UIDevice.current.setValue(rotateOrientation.rawValue, forKey: "orientation")
        UINavigationController.attemptRotationToDeviceOrientation()
    }

}

class PreviewViewController: UIViewController {
    // Status
    private enum ProcessVideoStatus {
        case noVideo
        case recorded
        case uploading
        case uploaded
        case processing
        case processed
    }
    
    // Declare variables
    @IBOutlet weak var uploadButton: UIButton!
    @IBOutlet weak var downloadButton: UIButton!
    @IBOutlet weak var previewView: PreviewView!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var hintLabel: UILabel!
    @IBOutlet weak var backButton: UIButton!
    var playerLayer: AVPlayerLayer?
    public var videoURL: URL?
    private var editedVideoURL: URL?
    private var videoProcessStatus: ProcessVideoStatus = .noVideo
    private var spinnerView: UIView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set size
//        self.previewView.frame.size.height = self.view.frame.height - 200
//        self.previewView.frame.size.width = self.view.frame.width
        
        // Change button style
        uploadButton.layer.cornerRadius = 14
        downloadButton.layer.cornerRadius = 14
        
        uploadButton.isHidden = false
        statusLabel.isHidden = true
        downloadButton.isHidden = true
        downloadButton.isEnabled = false
        
        hintLabel.text = "Scroll down to go back"

        // Do any additional setup after loading the view.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        
        // Set orientation
        AppUtility.lockOrientation(.portrait)
        
        // Play preview video and loop
        DispatchQueue.main.async {
            self.videoProcessStatus = .recorded
            let player = AVPlayer(url: self.videoURL!)
            
            NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: nil) { (_) in
                        player.seek(to: CMTime.zero)
                        player.play()
            }
            
            self.playerLayer = AVPlayerLayer(player: player)
            self.playerLayer!.frame = self.previewView.bounds
            self.previewView!.layer.addSublayer(self.playerLayer!)
            player.play()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        cleanup(outputFileURL: self.videoURL!)
        if(self.editedVideoURL != nil)
        {
            cleanup(outputFileURL: self.editedVideoURL!)
        }
        
        // Set orientation
        AppUtility.lockOrientation(.all)
        
        DispatchQueue.main.async {
            for layer in self.previewView!.layer.sublayers! {
                if(layer is AVPlayerLayer)
                {
                    let _layer = layer as! AVPlayerLayer
                    _layer.player?.pause()
                    layer.removeFromSuperlayer()
                }
            }
        }
    }
    
    func cleanup(outputFileURL: URL) {
        let path = outputFileURL.path
        if FileManager.default.fileExists(atPath: path) {
            do {
                try FileManager.default.removeItem(atPath: path)
            } catch {
                print("Could not remove file at url: \(outputFileURL)")
            }
        }
    }
    
    let screenSize: CGRect = UIScreen.main.bounds
    let session = URLSession.shared
    
    // Upload video to database
    private let videoName = NSUUID().uuidString + ".mp4"
    private let databaseURL = "https://tiktorch.ngrok.io/videos/"
    
    @IBAction func uploadVideo(_ sender: UIButton) {
        self.videoProcessStatus = .uploading
        
        // Change status style
        self.spinnerView = SpinnerView(frame: CGRect(x: screenSize.width/2 - 50, y: screenSize.height/2 - 50, width: 100, height: 100))
        self.view.addSubview(self.spinnerView!)
        self.uploadButton.isHidden = true
        self.uploadButton.isEnabled = true
        self.statusLabel.isHidden = false
        self.statusLabel.isEnabled = true
        self.statusLabel.text = "Uploading"
        self.statusLabel.frame = CGRect(x: screenSize.width/2 - 50, y: screenSize.height/2 - 50, width: 100, height: 100)
        
        // Upload Session
        DispatchQueue.main.async {
            var request = URLRequest(url: NSURL(string: self.databaseURL + "user/original")! as URL)
            request.httpMethod = "POST"
            let boundary = "Boundary+\(arc4random())\(arc4random())"
            var body = Data()

            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

            // User ID
            let key1 = "userId"
            let value1 = "Testsssss"
            let key2 = "video"

            body.appendString(string: "--\(boundary)\r\n")
            body.appendString(string: "Content-Disposition: form-data; name=\"\(key1)\"\r\n\r\n")
            body.appendString(string: "\(value1)\r\n")

            var movieData: Data?
            do {
                movieData = try Data(contentsOf: self.videoURL!, options: Data.ReadingOptions.alwaysMapped)
            } catch _ {
                movieData = nil
                return
            }

            body.appendString(string: "--\(boundary)\r\n")
            body.appendString(string: "Content-Disposition: form-data; name=\"\(key2)\"; filename=\"\(self.videoName)\"\r\n")
            body.appendString(string: "Content-Type: video/mp4\r\n\r\n")
            body.append(movieData!)
            body.appendString(string: "\r\n")

            body.appendString(string: "--\(boundary)--\r\n")
            request.httpBody = body

            let uploadTask = self.session.dataTask(with: request,
                                                           completionHandler: { (responseData, response, error) in

                                                            // Check on some response headers (if it's HTTP)
                                                            if let httpResponse = response as? HTTPURLResponse {
                                                                switch httpResponse.statusCode {
                                                                case 200..<300:
                                                                    print("Success")
                                                                case 400..<500:
                                                                    print("Request error")
                                                                case 500..<600:
                                                                    print("Server error")
                                                                case let otherCode:
                                                                    print("Other code: \(otherCode)")
                                                                }
                                                            }

                                                            // Do something with the response data
                                                            if let
                                                                responseData = responseData,
                                                                let responseString = String(data: responseData, encoding: String.Encoding.utf8) {
                                                                print("Server Response:")
                                                                print(responseString)
                                                                

                                                                // Get video edit status
                                                                DispatchQueue.main.async {
                                                                    self.statusLabel.text = "Processing"
                                                                    self.timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(self.GetEditStatus), userInfo: nil, repeats: true)
                                                                }
                                                            }

                                                            // Do something with the error
                                                            if let error = error {
                                                                print(error.localizedDescription)
                                                            }
            })

            uploadTask.resume()
        }
        
    }
    
    var timer = Timer()
    
    struct StatusResponce: Codable {
      let status: String
    }
    
    @objc func GetEditStatus() {
        DispatchQueue.main.async {
            let request = URLRequest(url: NSURL(string: self.databaseURL + "status/" + self.videoName)! as URL)
            let getTask = self.session.dataTask(with: request, completionHandler: { (data, response, error) in
                                                            
                                                            // Check on some response headers (if it's HTTP)
                                                            if let httpResponse = response as? HTTPURLResponse {
                                                                switch httpResponse.statusCode {
                                                                case 200..<300:
                                                                    print("Success")
                                                                case 400..<500:
                                                                    print("Request error")
                                                                case 500..<600:
                                                                    print("Server error")
                                                                case let otherCode:
                                                                    print("Other code: \(otherCode)")
                                                                }
                                                            }
                                                            
                                                            // Do something with the response data
                                                            if let data = data {
                                                               do {
                                                                let res = try JSONDecoder().decode(StatusResponce.self, from: data)
                                                                print(res.status)
                                                                
                                                                if(res.status == "Finished")
                                                                {

                                                                    //Change status
                                                                    DispatchQueue.main.async {
                                                                        self.videoProcessStatus = .processed
                                                                        self.statusLabel.isHidden = true
                                                                        self.statusLabel.isEnabled = true
                                                                        self.downloadButton.isHidden = false
                                                                        self.downloadButton.isEnabled = true
                                                                    }


                                                                    DispatchQueue.main.async {
                                                                        for view in self.view.subviews {
                                                                            if(view is SpinnerView)
                                                                            {
                                                                                view.removeFromSuperview()
                                                                            }
                                                                        }
                                                                    }
                                                                    
                                                                    DispatchQueue.main.async {
                                                                        for layer in self.previewView!.layer.sublayers! {
                                                                            if(layer is AVPlayerLayer)
                                                                            {
                                                                                let _layer = layer as! AVPlayerLayer
                                                                                _layer.player?.pause()
                                                                                layer.removeFromSuperlayer()
                                                                            }
                                                                        }
                                                                    }
                                                                    
                                                                    DispatchQueue.main.async {
                                                                        let player = AVPlayer(url: URL(string: self.databaseURL + "user/result/" + self.videoName)!)

                                                                        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: nil) { (_) in
                                                                                    player.seek(to: CMTime.zero)
                                                                                    player.play()
                                                                        }

                                                                        self.playerLayer = AVPlayerLayer(player: player)
                                                                        self.playerLayer!.frame = self.previewView.bounds
                                                                        self.previewView!.layer.addSublayer(self.playerLayer!)
                                                                        player.play()
                                                                    }

                                                                    self.timer.invalidate()
                                                                }
                                                               } catch let error {
                                                                  print(error)
                                                               }
                                                            }
                                                            
                                                            // Do something with the error
                                                            if let error = error {
                                                                print(error.localizedDescription)
                                                            }
            })
            
            getTask.resume()
            
        }
    }
    
    @IBAction func DownloadVideo(_ sender: Any) {

//        DispatchQueue.main.async {
//            let downloadRequest = URLRequest(url: NSURL(string: "http://example.com")! as URL)
//            let downloadTask = self.session.downloadTask(with: downloadRequest as URLRequest,
//                                                           completionHandler: { (responceURL, response, error) in
//
//                                                            // Check on some response headers (if it's HTTP)
//                                                            if let httpResponse = response as? HTTPURLResponse {
//                                                                switch httpResponse.statusCode {
//                                                                case 200..<300:
//                                                                    print("Success")
//                                                                case 400..<500:
//                                                                    print("Request error")
//                                                                case 500..<600:
//                                                                    print("Server error")
//                                                                case let otherCode:
//                                                                    print("Other code: \(otherCode)")
//                                                                }
//                                                            }
//
//                                                            // Do something with the response data
//                                                            self.editedVideoURL = responceURL
//
//                                                            // Play preview video and loop
//                                                            DispatchQueue.main.async {
//                                                                let player = AVPlayer(url: self.editedVideoURL!)
//
//                                                                NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: nil) { (_) in
//                                                                            player.seek(to: CMTime.zero)
//                                                                            player.play()
//                                                                }
//
//                                                                self.playerLayer = AVPlayerLayer(player: player)
//                                                                self.playerLayer!.frame = self.previewView.bounds
//                                                                self.previewView!.layer.addSublayer(self.playerLayer!)
//                                                                player.play()
//                                                            }
//
//                                                            // Do something with the error
//                                                            if let error = error {
//                                                                print(error.localizedDescription)
//                                                            }
//            })
//
//            downloadTask.resume()
//        }
//
//        PHPhotoLibrary.shared().performChanges({
//            let options = PHAssetResourceCreationOptions()
//            options.shouldMoveFile = false
//            let creationRequest = PHAssetCreationRequest.forAsset()
//            creationRequest.addResource(with: .video, fileURL: self.editedVideoURL!, options: options)
//        }, completionHandler: { success, error in
//            if !success {
//                print("TikTorch couldn't save the movie to your photo library: \(String(describing: error))")
//            }
//        }
//        )
        
        DispatchQueue.main.async {
            self.spinnerView = SpinnerView(frame: CGRect(x: self.screenSize.width/2 - 50, y: self.screenSize.height/2 - 50, width: 100, height: 100))
            self.view.addSubview(self.spinnerView!)
            self.statusLabel.isHidden = false
            self.statusLabel.isEnabled = true
            self.statusLabel.text = "Downloading"
        }
        
        print("Download")
        DispatchQueue.global(qos: .background).async {
            if let url = URL(string: self.databaseURL + "user/result/" + self.videoName),
                let urlData = NSData(contentsOf: url) {
                let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0];
                let filePath="\(documentsPath)/\(self.videoName)"
                DispatchQueue.main.async {
                    urlData.write(toFile: filePath, atomically: true)
                    PHPhotoLibrary.shared().performChanges({
                        PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: URL(fileURLWithPath: filePath))
                    }) { completed, error in
                        if completed {
                            print("Video is saved!")
                            
                            DispatchQueue.main.async {
                                for view in self.view.subviews {
                                    if(view is SpinnerView)
                                    {
                                        view.removeFromSuperview()
                                    }
                                }
                                
                                self.statusLabel.isHidden = true
                                self.statusLabel.isEnabled = false
                                
                                self.hintLabel.text = "Downloaded"
                            }
                        }
                        
                        if (error != nil) {
                            print(error.debugDescription)
                        }
                    }
                }
            }
        }
        
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}

extension Data{
    
    mutating func appendString(string: String) {
        let data = string.data(using: String.Encoding.utf8, allowLossyConversion: true)
        append(data!)
    }
}
