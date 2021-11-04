//
//  ViewController.swift
//  LLHLS Tester
//
//  Created by Conor Sweeney on 11/4/21.
//

import UIKit
import AVKit

// Static Key for accessing the last set URL
let urlKey = "urlKey"

class ViewController: UIViewController {

    @IBOutlet weak var urlTextField: UITextField!
    @IBOutlet weak var urlLabel: UILabel!
    
    // This is used to save/access the last used URL
    var userDefaults: UserDefaults {
        return UserDefaults.standard
    }
    
    @IBAction func setURL(_ sender: Any) {
        guard let urlText = urlTextField.text else {
            return
        }
        urlLabel.text = urlText
        userDefaults.set(urlText, forKey: urlKey)
    }
    
    // View to hold the AVPlayerLayer
    @IBOutlet weak var playerContainer: UIView!
    
    let player = AVPlayer()
    var playerLayer : AVPlayerLayer?

    @IBAction func pausePress(_ sender: Any) {
        player.pause()
    }
    
    @IBAction func playPress(_ sender: Any) {
        guard let urlString = urlLabel.text, let url = URL(string: urlString) else{
            return
        }
        let playerItem = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: playerItem)
        player.play()
    }
    
    @IBAction func stopPress(_ sender: Any) {
        // There is no stop functionality so instead I am destroying the asset in the player
        player.replaceCurrentItem(with: nil)
    }
    
    @IBAction func livePress(_ sender: Any) {
        // This seeks to the very end of the stream if a user has paused
        player.seek(to: CMTimeMakeWithSeconds(Float64(MAXFLOAT), preferredTimescale: Int32(NSEC_PER_SEC)))
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Fetch the last saved URL so user does not have to reset it
        urlLabel.text = userDefaults.string(forKey: urlKey)
        
        //Add the AVPlayerLayer to the container view
        playerLayer = AVPlayerLayer(player: player)
        playerLayer!.masksToBounds = true
        playerContainer.layer.addSublayer(playerLayer!)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // This keeps the AVPlayerLayer the size of the container at all times
        playerLayer?.frame = CGRect(x: 0.0, y: 0.0, width: playerContainer.frame.width, height: playerContainer.frame.height)
    }

}

