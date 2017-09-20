//
//  ViewController.swift
//  FaceDetector3
//
//  Created by Jung SeungWoo on 2017. 6. 9..
//  Copyright © 2017년 Jung SeungWoo. All rights reserved.
//


import UIKit
import AVFoundation
import Starscream

let kSocketUrl:String = "https://192.168.202.124:9000"
let kTest:String = "String"

class ViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate, AVCaptureVideoDataOutputSampleBufferDelegate, WebSocketDelegate {
    
    @IBOutlet weak var testView: UIImageView!
    
    @IBOutlet weak var previewView: UIView!
    @IBOutlet weak var cameraSegment: UISegmentedControl!
    
    var videoLayer: AVCaptureVideoPreviewLayer!
    var captureSession: AVCaptureSession!
    var videoDevice: AVCaptureDevice!
    
    var isUsingFrontFacingCamera: Bool! = false
    var isUsingNormalName: Bool! = false
    
    var socket: WebSocket!

    var findCapture: Bool! = false
    var firstLoad: Bool! = false
    var dataSending: Bool! = false
    
    var targetArray: Array<CALayer>!
    var textArray: Array<CATextLayer>!
    var thumbArray: Array<CALayer>!
    
    var layerContentImage: CGImage!
    var faceDict: [String:String]!
    var checkArray: Array<Any>!
    var receiveArray:Array<FaceData>!
    
    var imageSize:CGSize!
    var previewBox:CGRect!
    
    var imageDict:[String:UIImage]!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        targetArray = []
        textArray = []
        thumbArray = []
        faceDict = [:]
        imageDict = [:]
        
        layerContentImage = UIImage(named: "squarePNG")?.cgImage
        //isUsingFrontFacingCamera = true

        self.configureWebSocket()
        self.configureCamera()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // プレビュー
        videoLayer.frame = previewView.bounds
        
        if !firstLoad {
            firstLoad = true;
            // セッションの開始
            DispatchQueue.global(qos: .userInitiated).async {
                self.captureSession.startRunning()
            }
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

//MARK: - WebSocket
    
    func configureWebSocket() {
        socket = WebSocket(url:URL(string: kSocketUrl)!)
        socket.disableSSLCertValidation = true
        socket.delegate = self
        socket.connect()
    }
 
    func websocketDidConnect(socket: Starscream.WebSocket) {
        print("websocket is connected ")
    }
    
    func websocketDidDisconnect(socket: Starscream.WebSocket, error: NSError?) {
        print(error?.localizedDescription ?? "")
        print("websocket is disconnected: \(String(describing: error?.localizedDescription))")
        self.configureWebSocket()
    }
    
    func websocketDidReceiveMessage(socket: Starscream.WebSocket, text: String) {
        print("got some text: \(text)")
        dataSending = false
    }
    
    func websocketDidReceiveData(socket: Starscream.WebSocket, data: Data) {
        print("got some data: \(data.count)")
        do {
            let jsonData = try JSONSerialization.jsonObject(with: data) as! [String:Any]
            //print(jsonData)
            let type = jsonData["type"] as! String
            if(type == "PROCESSED") {
                //var resultArray:[[String:Any]]
                let arr = jsonData["detect"] as! [[String:Any]]
                receiveArray = []
                var temp:FaceData
                for value in arr {
                    temp = FaceData.init(dict: value)
                    receiveArray.append(temp)
                    let img = value["img"]
                    if img != nil {
                        //let image:UIImage = self.decodeToBase64String(string: img as! String)
                        imageDict[temp.person] = self.decodeToBase64String(string: img as! String)
                    } else {
                        imageDict[temp.person] = UIImage()
                    }
                }
                
                for metadata in checkArray as! [AVMetadataFaceObject] {
                    let name:String = self.findPersonFromResult(bounds: metadata.bounds)
                    let key:String = String(metadata.faceID)
                    faceDict[key] = name
                    //print(name)
                }
            }
        } catch {
            print(error.localizedDescription)
        }
        
        dataSending = false
    }

    /*
    func findPersonFromResult(bounds:CGRect) -> String {
        var r:CGRect = bounds
        r.origin.x = bounds.origin.y
        r.origin.y = bounds.origin.x
        var p1 = self.centerFromRect(rect: r)
        
        var res:String = ""
        var check_dist:CGFloat = CGFloat.greatestFiniteMagnitude
        var p2:CGPoint = CGPoint.zero
        var dist:CGFloat = 0
        
        for facedata in receiveArray.enumerated() as! [FaceData] {
            
        }
        return ""
    }
    */
    
    func findPersonFromResult(bounds:CGRect) -> String {
        
        var faceRect = rectTransform(base: imageSize, proportion: bounds)
        if isUsingFrontFacingCamera {
            faceRect = faceRect.offsetBy(dx: previewBox.origin.x, dy: previewBox.origin.y)
            
        } else {
            faceRect = faceRect.offsetBy(dx: previewBox.origin.x + previewBox.size.width - faceRect.size.width - (faceRect.origin.x * 2), dy: previewBox.origin.y)
        }
        
        let p1 = self.centerFromRect(rect: faceRect)
        
        var res:String = ""
        var check_dist:Float = Float.greatestFiniteMagnitude
        var p2:CGPoint = CGPoint.zero
        var dist:Float = 0
        
        for facedata in receiveArray {
            p2 = self.centerFromRect(rect: facedata.box)
            dist = hypotf((Float(p1.x-p2.x)), (Float(p1.y-p2.y)));
            //print(p1, p2, dist)
            if(check_dist > dist) {
                check_dist = dist;
                res = facedata.person;
                //print(res)
            }
        }
        return res
    }
    
    func centerFromRect(rect:CGRect) -> CGPoint {
        return CGPoint.init(x: (rect.origin.x + rect.size.width)/2.0, y: (rect.origin.y + rect.size.height)/2.0)
    }
    
    /*
    - (NSString *)findPersonFromResult:(CGRect)bounds {
    //NSLog(@"%@",NSStringFromCGRect(bounds));
    CGRect r = bounds;
    r.origin.x = bounds.origin.y;
    r.origin.y = bounds.origin.x;
    CGPoint p1 = [self centerFromRect:r];
    NSString *_res = nil;
    CGFloat check_dist = CGFLOAT_MAX;
    CGPoint p2 = CGPointZero;
    CGFloat dist = 0;
    for(FaceData *data in self.resultArray) {
    p2 = [self centerFromRect:data.box];
    dist = hypotf((p1.x-p2.x), (p1.y-p2.y));
    if(check_dist > dist) {
    check_dist = dist;
    _res = data.person;
    }
    }
    //NSLog(@"%@",_res);
    return _res;
    }
    */
    
//MARK: - Camera Cofigure
    
    func configureCamera() {
        
        // 入力（背面カメラ）
        
        // find back camera
        if isUsingFrontFacingCamera {
            //front
            guard let camera = AVCaptureDevice.devices().first(where: { ($0 as AnyObject).position == .front }) as? AVCaptureDevice else {
                fatalError("No front facing camera found")
            }
            videoDevice = camera
        } else {
            //back
            guard let camera = AVCaptureDevice.devices().first(where: { ($0 as AnyObject).position == .back }) as? AVCaptureDevice else {
                fatalError("No front facing camera found")
            }
            videoDevice = camera
        }
        
        /*
        guard let camera = AVCaptureDevice.devices().first(where: { ($0 as AnyObject).position == .front }) as? AVCaptureDevice else {
            fatalError("No front facing camera found")
        }
        videoDevice = camera
        */
        
        //videoDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
        let videoInput = try! AVCaptureDeviceInput.init(device: videoDevice)
        
        // セッションのインスタンス生成
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = AVCaptureSessionPreset1280x720
        captureSession.addInput(videoInput)
        
        // 出力（ビデオデータ）
        let metadataOutput = AVCaptureMetadataOutput()
        captureSession.addOutput(metadataOutput)
        
        // メタデータを検出した際のデリゲート設定
        metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        // Faceの認識を設定
        metadataOutput.metadataObjectTypes = [AVMetadataObjectTypeFace]
        for connection in metadataOutput.connections as! [AVCaptureConnection] {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = AVCaptureVideoOrientation.portrait
            }
        }
        
        //capture add
        let captureOutput = AVCaptureVideoDataOutput()
        captureSession.addOutput(captureOutput)
        
        // ピクセルフォーマットを 32bit BGR + A とする
        captureOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as AnyHashable : Int(kCVPixelFormatType_32BGRA)]
        
        // フレームをキャプチャするためのサブスレッド用のシリアルキューを用意
        captureOutput.setSampleBufferDelegate(self, queue: DispatchQueue.main)
        captureOutput.alwaysDiscardsLateVideoFrames = true
        
        for connection in captureOutput.connections as! [AVCaptureConnection] {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = AVCaptureVideoOrientation.portrait
            }
        }
        
        // 検出エリアのビュー
        /*
         let x: CGFloat = 0.05
         let y: CGFloat = 0.3
         let width: CGFloat = 0.9
         let height: CGFloat = 0.2
         
         let detectionArea = UIView()
         detectionArea.frame = CGRect(x: view.frame.size.width * x, y: view.frame.size.height * y, width: view.frame.size.width * width, height: view.frame.size.height * height)
         detectionArea.layer.borderColor = UIColor.red.cgColor
         detectionArea.layer.borderWidth = 3
         view.addSubview(detectionArea)
         
         // 検出エリアの設定
         metadataOutput.rectOfInterest = CGRect(x: y,y: 1-x-width,width: height,height: width)
         */
        
        // カメラの向きなどを設定する
        /*
         captureSession.beginConfiguration()
         var videoConnection:AVCaptureConnection! = nil
         for connection in metadataOutput.connections as! [AVCaptureConnection] {
         for port in connection.inputPorts as! [AVCaptureInputPort] {
         NSLog("%@",port.mediaType)
         print ()
         if port.mediaType == AVMediaTypeMetadata {
         videoConnection = connection;
         break
         }
         }
         }
         videoConnection.videoOrientation = AVCaptureVideoOrientation.portrait
         
         captureSession.commitConfiguration()
         */
        // プレビュー
        //if !firstLoad {
        if firstLoad {
            videoLayer.session = captureSession
        } else {
            videoLayer = AVCaptureVideoPreviewLayer.init(session: captureSession)
            //if let videoLayer = AVCaptureVideoPreviewLayer.init(session: captureSession) {
            videoLayer.frame = previewView.bounds
            videoLayer.videoGravity = AVLayerVideoGravityResizeAspect
            videoLayer.connection.videoOrientation = AVCaptureVideoOrientation.portrait
            previewView.layer.addSublayer(videoLayer)
            self.previewView.clipsToBounds = false
        }
        
        //}
        
        // }
        
        if firstLoad {
            DispatchQueue.global(qos: .userInitiated).async {
                self.captureSession.startRunning()
            }
        }
        /*
         DispatchQueue.global(qos: .userInitiated).async {
         captureSession.startRunning()
         }
         */
    }

//MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        if findCapture {
 
            if dataSending {
                return;
            }
            
            dataSending = true
            
            
            // キャプチャしたsampleBufferからUIImageを作成
            //let image:UIImage = self.captureImage(sampleBuffer)
            let image:UIImage = self.UIImageFromCMSamleBuffer(buffer:sampleBuffer)
            //print(self.encodeToBase64String(image: image))
            //self.testView.image = image
            imageSize = image.size
            
/*
            var dict:Dictionary
                = ( isUsingNormalName ? ["type":"FRAME",
                                       "identity":"key",
                                       "app":"PROTO_A",
                                       "width":String(describing: Int(image.size.width)),
                                       "height":String(describing: Int(image.size.height)),
                                       "dataURL":self.encodeToBase64String(image: image)]
            :  ["type":"FRAME",
                        "identity":"key",
                        "app":"PROTO_D",
                        "width":String(describing: Int(image.size.width)),
                        "height":String(describing: Int(image.size.height)),
                        "dataURL":self.encodeToBase64String(image: image)])
*/
            var dict:Dictionary = ["type":"FRAME",
                                   "identity":"key",
                                   "app":"PROTO_A",
                                   "width":String(describing: Int(image.size.width)),
                                   "height":String(describing: Int(image.size.height)),
                                   "dataURL":self.encodeToBase64String(image: image)]
            if !isUsingNormalName {
                dict["app"] = "PROTO_D"
            }
            
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted)
                socket.write(data: jsonData)
            } catch {
                print(error.localizedDescription)
            }

            
            // 画像を画面に表示
            /*
            DispatchQueue.main.async {
                
                //self.imageView.image = image
                
                // UIImageViewをビューに追加
                //self.view.addSubview(self.imageView)
            }
 */
        }
    }
    
    //CMSampleBufferをUIImageに変換する
    func UIImageFromCMSamleBuffer(buffer:CMSampleBuffer)-> UIImage {
        // サンプルバッファからピクセルバッファを取り出す
        let pixelBuffer:CVImageBuffer = CMSampleBufferGetImageBuffer(buffer)!
        
        // ピクセルバッファをベースにCoreImageのCIImageオブジェクトを作成
        let ciImage = CIImage(cvImageBuffer: pixelBuffer)
        //CIImageからCGImageを作成
        let pixelBufferWidth = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let pixelBufferHeight = CGFloat(CVPixelBufferGetHeight(pixelBuffer))
        let imageRect:CGRect = CGRect.init(x: 0, y: 0, width: pixelBufferWidth, height: pixelBufferHeight)
        let ciContext = CIContext.init()
        let cgimage = ciContext.createCGImage(ciImage, from: imageRect )
        
        // CGImageからUIImageを作成
        let image = UIImage(cgImage: cgimage!)
        return image
    }
    
    func captureImage(_ sampleBuffer:CMSampleBuffer) -> UIImage{
        
        // Sampling Bufferから画像を取得
        let imageBuffer:CVImageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
        
        // pixel buffer のベースアドレスをロック
        CVPixelBufferLockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
        
        let baseAddress:UnsafeMutableRawPointer = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0)!
        
        let bytesPerRow:Int = CVPixelBufferGetBytesPerRow(imageBuffer)
        let width:Int = CVPixelBufferGetWidth(imageBuffer)
        let height:Int = CVPixelBufferGetHeight(imageBuffer)
        
        
        // 色空間
        let colorSpace:CGColorSpace = CGColorSpaceCreateDeviceRGB()
        
        //let bitsPerCompornent:Int = 8
        // swift 2.0
        let newContext:CGContext = CGContext(data: baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace,  bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue|CGBitmapInfo.byteOrder32Little.rawValue)!
        
        let imageRef:CGImage = newContext.makeImage()!
        let resultImage = UIImage(cgImage: imageRef, scale: 1.0, orientation: UIImageOrientation.right)
        //let resultImage = UIImage(cgImage: imageRef, scale: 1.0, orientation: UIImageOrientation.upMirrored)
        
        return resultImage
    }

    private func encodeToBase64String(image:UIImage) -> String {
        let encodeData:Data! = UIImageJPEGRepresentation(image, 0.8)
        let string:String! = encodeData.base64EncodedString(options:.lineLength64Characters)
        return "data:image/jpeg;base64," + string
    }
    
    private func decodeToBase64String(string:String) -> UIImage {
        guard  let decodedData = Data(base64Encoded: string , options: .ignoreUnknownCharacters) else {
            return UIImage()
        }
        return UIImage(data: decodedData)!
    }
    
//MARK: - AVCaptureMetadataOutputObjectsDelegate
    
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputMetadataObjects metadataObjects: [Any]!, from connection: AVCaptureConnection!) {
        // 複数のメタデータを検出できる
        //for metadata in metadataObjects as! [AVMetadataMachineReadableCodeObject] {
        //print("-------------")
        //print(self.videoLayer.bounds.size, self.getCaptureResolution())
        //print(self.videoPreviewBox(gravity: AVLayerVideoGravityResizeAspect, frameSize: self.videoLayer.bounds.size, apertureSize: self.getCaptureResolution()))
        /*
        labelArray.enumerateObjects({ (object, index, stop) in
            let layer = object as! CALayer
            layer.isHidden = true
        })
 */
        self.removeAllFindLayer()
        
        findCapture = false
        var count = 0
        
        previewBox = self.videoPreviewBox(gravity: AVLayerVideoGravityResizeAspect, frameSize: self.videoLayer.bounds.size, apertureSize: self.getCaptureResolution())
        
        for metadata in metadataObjects as! [AVMetadataFaceObject] {
            // EAN-13Qコードのデータかどうかの確認
            /*
             if metadata.type == AVMetadataObjectTypeEAN13Code || metadata.type == AVMetadataObjectTypeEAN8Code{
             if metadata.stringValue != nil {
             // 検出データを取得
             counter = 0
             if !isDetected || label.text != metadata.stringValue! {
             isDetected = true
             AudioServicesPlaySystemSound(kSystemSoundID_Vibrate) // バイブレーション
             label.text = metadata.stringValue!
             detectionArea.layer.borderColor = UIColor.white.cgColor
             detectionArea.layer.borderWidth = 5
             }
             }
             }
             */
            
            //var faceRect = rectTransform(base: self.getCaptureResolution(), proportion: metadata.bounds)
            var faceRect = rectTransform(base: self.videoLayer.bounds.size, proportion: metadata.bounds)
            if isUsingFrontFacingCamera {
                faceRect = faceRect.offsetBy(dx: previewBox.origin.x, dy: previewBox.origin.y)

            } else {
                faceRect = faceRect.offsetBy(dx: previewBox.origin.x + previewBox.size.width - faceRect.size.width - (faceRect.origin.x * 2), dy: previewBox.origin.y)
            }
            
            //print(faceRect)
            /*
            if ( isMirrored )
            faceRect = CGRectOffset(faceRect, previewBox.origin.x + previewBox.size.width - faceRect.size.width - (faceRect.origin.x * 2), previewBox.origin.y);
            else
            faceRect = CGRectOffset(faceRect, previewBox.origin.x, previewBox.origin.y);
            */
            
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            
            if(targetArray.count > count) {
                let currentLayer = targetArray[count]
                currentLayer.frame = faceRect
                currentLayer.isHidden = false
                //print("find - ",metadata.faceID,self.videoLayer.bounds,metadata.bounds,currentLayer.frame);
                
                let tlayer = textArray[count]
                tlayer.frame = CGRect.init(x: 0, y: faceRect.size.height, width: faceRect.size.width, height: 40)
                tlayer.isHidden = false

                let thumbLayer = thumbArray[count]
                let size:CGFloat =  ((faceRect.size.height/3.0) as CGFloat).rounded(.up)
                thumbLayer.frame = CGRect.init(x: -size , y: 0, width: size, height: size)
                
                let key:String = String(metadata.faceID)
                if let name = faceDict[key] {
                    // 이름을 이미 가지고 있음
                    tlayer.string = name
                    //print(imageDict)
                    //self.testView.image = imageDict[name]
                    thumbLayer.contents = imageDict[name]?.cgImage
                    thumbLayer.isHidden = false
                } else {
                    // 이름이 없다
                    //faceDict[key] = "Unknown"
                    thumbLayer.isHidden = true
                    tlayer.string = "Searching"
                    if !dataSending {
                        findCapture = true
                        checkArray = metadataObjects
                    }
                }
                
            } else {
                //new
                let layer = CALayer()
                //layer.actions = ["contents" : NSNull()]
                layer.contents = layerContentImage
                layer.frame = faceRect
                layer.masksToBounds = false
                previewView.layer.addSublayer(layer)
                targetArray.append(layer)
                
                let tlayer = CATextLayer()
                tlayer.font = UIFont.systemFont(ofSize: 16) as CFTypeRef!
                tlayer.fontSize = 16
                tlayer.masksToBounds = false
                //tlayer.isWrapped = true
                tlayer.truncationMode = kCATruncationEnd
                //tlayer.backgroundColor = UIColor.red.cgColor
                tlayer.foregroundColor = UIColor.yellow.cgColor
                tlayer.opacity = 1
                tlayer.shadowOpacity = 0.5
                tlayer.alignmentMode = kCAAlignmentCenter
                tlayer.frame = CGRect.init(x: 0, y: faceRect.size.height, width: faceRect.size.width, height: 40)
                layer .addSublayer(tlayer)
                textArray.append(tlayer)
                
                let thumblayer = CALayer()
                thumblayer.frame = CGRect.zero
                thumblayer.isHidden = true
                layer.addSublayer(thumblayer)
                thumbArray.append(thumblayer)
            }
            
            CATransaction.commit()
            
            count += 1
            //print("find - ",metadata.faceID);
        }
    }
    
    func videoPreviewBox(gravity:String, frameSize:CGSize, apertureSize:CGSize) -> CGRect {
        //let apertureRatio = apertureSize.height / apertureSize.width;
        let apertureRatio = apertureSize.width / apertureSize.height;
        let viewRatio = frameSize.width / frameSize.height;
        
        var size:CGSize = CGSize.zero;
        if gravity == AVLayerVideoGravityResizeAspectFill {
            if (viewRatio > apertureRatio) {
                size.width = frameSize.width;
                size.height = apertureSize.width * (frameSize.width / apertureSize.height);
            } else {
                size.width = apertureSize.height * (frameSize.height / apertureSize.width);
                size.height = frameSize.height;
            }
        } else if gravity == AVLayerVideoGravityResizeAspect {
            if (viewRatio > apertureRatio) {
                size.width = apertureSize.height * (frameSize.height / apertureSize.width);
                size.height = frameSize.height;
            } else {
                /*
                size.width = frameSize.width;
                size.height = apertureSize.width * (frameSize.width / apertureSize.height);
 */
                size.width = frameSize.width;
                size.height = apertureSize.height * (frameSize.height / apertureSize.height);
            }
        } else if gravity == AVLayerVideoGravityResize {
            size.width = frameSize.width;
            size.height = frameSize.height;
        }
        
        var videoBox:CGRect = CGRect.zero;
        videoBox.size = size;
        if size.width < frameSize.width {
            videoBox.origin.x = (frameSize.width - size.width) / 2;
        } else {
            videoBox.origin.x = (size.width - frameSize.width) / 2;
        }
        
        if size.height < frameSize.height {
            videoBox.origin.y = (frameSize.height - size.height) / 2;
        } else {
            videoBox.origin.y = (size.height - frameSize.height) / 2;
        }
        return videoBox;
    }
    
    func rectTransform(base: CGSize, proportion: CGRect) -> CGRect {
        
        return CGRect(x: (base.width * proportion.origin.y),
                      y: (base.height * proportion.origin.x),
                      width: (base.width * proportion.size.height),
                      height: (base.height * proportion.size.width))
        
        /*
        return CGRect(x: (base.size.width * proportion.origin.x),
                      y: (base.size.height * proportion.origin.y),
                      width: (base.size.width * proportion.size.width),
                      height: (base.size.height * proportion.size.height))
 */
    }
    
    private func getCaptureResolution() -> CGSize {
        // Define default resolution
        var resolution = CGSize(width: 0, height: 0)
        
        // Get cur video device
        //let curVideoDevice = useBackCamera ? backCameraDevice : frontCameraDevice
        //let curVideoDevice = true
        // Set if video portrait orientation
        //let portraitOrientation = orientation == .Portrait || orientation == .PortraitUpsideDown
        let portraitOrientation = true
        
        
        // Get video dimensions
        if let formatDescription = videoDevice.activeFormat.formatDescription {
            let dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
            resolution = CGSize(width: CGFloat(dimensions.width), height: CGFloat(dimensions.height))
            if (portraitOrientation) {
                resolution = CGSize(width: resolution.height, height: resolution.width)
            }
        }
        
        // Return resolution
        return resolution
    }
    
//MARK: - Private
    
    private func removeAllFindLayer() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        for value in targetArray {
            value.isHidden = true
        }
        
        /*
        for value in textArray {
            value.isHidden = true
        }
        */
        
        CATransaction.commit()
    }
    
//MARK: - IBAction
    
    @IBAction func onClickSwitchCamera(sender: UISegmentedControl) {
        //socket.disconnect()
        
        //captureSession.beginConfiguration()
        captureSession.stopRunning()
        
        checkArray = []
        faceDict.removeAll()
        self.removeAllFindLayer()
        
        for old in captureSession.inputs as! [AVCaptureInput] {
            captureSession.removeInput(old)
        }
        
        for old in captureSession.outputs as! [AVCaptureOutput] {
            captureSession.removeOutput(old)
        }
        
        let selected: Int = sender.selectedSegmentIndex;
        if selected == 1 {
            //front
            isUsingFrontFacingCamera = true
            /*
            guard let camera = AVCaptureDevice.devices().first(where: { ($0 as AnyObject).position == .front }) as? AVCaptureDevice else {
                fatalError("No front facing camera found")
            }
            videoDevice = camera
 */
        } else {
            //back
            isUsingFrontFacingCamera = false
           /*
            guard let camera = AVCaptureDevice.devices().first(where: { ($0 as AnyObject).position == .back }) as? AVCaptureDevice else {
                fatalError("No front facing camera found")
            }
            videoDevice = camera
 */
        }
        
        /*
        let videoInput = try! AVCaptureDeviceInput.init(device: videoDevice)
        captureSession.addInput(videoInput)
        */
        
        //captureSession.commitConfiguration()
        self.configureCamera()
    }
    
    @IBAction func onClickSwitchCheckStyle(sender: UISegmentedControl) {
        captureSession.stopRunning()
        
        checkArray = []
        faceDict.removeAll()
        self.removeAllFindLayer()
        
        let selected: Int = sender.selectedSegmentIndex;
        if selected == 1 {
            //name
            isUsingNormalName = true
        } else {
            //celeb
            isUsingNormalName = false
        }
        
        captureSession.startRunning()
    }
}

