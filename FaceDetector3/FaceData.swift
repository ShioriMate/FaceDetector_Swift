//
//  FaceData.swift
//  FaceDetector3
//
//  Created by Jung SeungWoo on 2017. 6. 21..
//  Copyright © 2017년 Jung SeungWoo. All rights reserved.
//

import UIKit

class FaceData: NSObject {
    var person:String!
    var identity:String!
    var box:CGRect = CGRect.zero
    //var img:UIImage!
    
    init(dict:[String:Any]) {
        super.init()
        self.identity = dict["identity"] as! String
        self.person = dict["person"] as! String
        let boxString:String = dict["box"] as! String
        let a:[String] = boxString.components(separatedBy:",")
        if a.count == 4 {
            let left = a[0];
            let top = a[1];
            let right = a[2];
            let bottom = a[3];
            self.box = CGRect.init(x: Int(left)!, y: Int(top)!, width: Int(right)! - Int(left)!, height: Int(bottom)! - Int(top)!)
        }
        /*
        guard  let st = dict["img"] as? String else {
            self.img = UIImage()
            return
        }
        //let a:Data! = Data(base64Encoded: st)
        let decodedData = Data(base64Encoded: st, options: .ignoreUnknownCharacters)
        
        self.img = UIImage(data: decodedData!)
 */
    }
}
