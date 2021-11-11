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
    
    @IBOutlet weak var tableView: UITableView!
    
    // This is used to save/access the last used URL
    var userDefaults: UserDefaults {
        return UserDefaults.standard
    }
    
    var events = [String]()
    
    @IBAction func setURL(_ sender: Any) {
        guard let urlText = urlTextField.text else {
            return
        }
        urlLabel.text = urlText
        userDefaults.set(urlText, forKey: urlKey)
        addActionEvent(action: "Set URL \(urlText)")
        setPlayerItem()
    }
    
    // View to hold the AVPlayerLayer
    @IBOutlet weak var playerContainer: UIView!
    
    let player = AVPlayer()
    var playerLayer : AVPlayerLayer?

    @IBAction func pausePress(_ sender: Any) {
        player.pause()
        addActionEvent(action: "Pause")
    }
    
    @IBAction func playPress(_ sender: Any) {
        if player.currentItem == nil {
            setPlayerItem()
        }
        player.play()
        addActionEvent(action: "Play")
    }
    
    @IBAction func stopPress(_ sender: Any) {
        // There is no stop functionality so instead I am destroying the asset in the player
        player.replaceCurrentItem(with: nil)
        addActionEvent(action: "Stop")
    }
    
    @IBAction func livePress(_ sender: Any) {
        // This seeks to the very end of the stream if a user has paused
        player.seek(to: CMTimeMakeWithSeconds(Float64(MAXFLOAT), preferredTimescale: Int32(NSEC_PER_SEC)))
        addActionEvent(action: "Live")
    }
    
    private func setPlayerItem(){
        // Only reset the player item if it is already nil so pause can be tested
        guard let urlString = urlLabel.text, let url = URL(string: urlString) else{
            return
        }
        let playerItem = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: playerItem)
        addActionEvent(action: "Player Item Set")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Fetch the last saved URL so user does not have to reset it
        urlLabel.text = userDefaults.string(forKey: urlKey)
        
        //Add the AVPlayerLayer to the container view
        playerLayer = AVPlayerLayer(player: player)
        playerLayer!.masksToBounds = true
        playerContainer.layer.addSublayer(playerLayer!)
        
        // Add observer for AVPlayer status and AVPlayerItem status
        self.player.addObserver(self, forKeyPath: #keyPath(AVPlayer.status), options: [.new, .initial], context: nil)
        self.player.addObserver(self, forKeyPath: #keyPath(AVPlayer.currentItem.status), options:[.new, .initial], context: nil)

        // Watch notifications
        let center = NotificationCenter.default
        center.addObserver(self, selector:#selector(self.newErrorLogEntry(_:)), name: .AVPlayerItemNewErrorLogEntry, object: player.currentItem)
        center.addObserver(self, selector:#selector(self.failedToPlayToEndTime(_:)), name: .AVPlayerItemFailedToPlayToEndTime, object: player.currentItem)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // This keeps the AVPlayerLayer the size of the container at all times
        playerLayer?.frame = CGRect(x: 0.0, y: 0.0, width: playerContainer.frame.width, height: playerContainer.frame.height)
    }
    
    // Observe If AVPlayerItem.status Changed to Fail
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        if object as? AVPlayer != nil, keyPath == #keyPath(AVPlayer.currentItem.status){
            let newStatus: AVPlayerItem.Status
            if let newStatusAsNumber = change?[NSKeyValueChangeKey.newKey] as? NSNumber {
                newStatus = AVPlayerItem.Status(rawValue: newStatusAsNumber.intValue)!
            } else {
                newStatus = .unknown
            }
            if newStatus == .failed {
                guard let localizedError = self.player.currentItem?.error?.localizedDescription else {
                    return
                }
                addErrorEvent(error: localizedError)
            }
        }
    }

    // Getting error from Notification payload
    @objc func newErrorLogEntry(_ notification: Notification) {
        guard let object = notification.object, let playerItem = object as? AVPlayerItem else {
            return
        }
        
        guard let errorLog: AVPlayerItemErrorLog = playerItem.errorLog() else {
            return
        }
        
        guard let localizedError = self.player.currentItem?.error?.localizedDescription else {
            return
        }
        addErrorEvent(error: localizedError)
    }

    @objc func failedToPlayToEndTime(_ notification: Notification) {
        if let error = notification.userInfo!["AVPlayerItemFailedToPlayToEndTimeErrorKey"] as? Error {
            addErrorEvent(error: error.localizedDescription)
        }
    }
    
    private func addActionEvent(action: String){
        let actionStr = "Action: \(action)"
        addEvent(event: actionStr)
    }
    
    private func addErrorEvent(error: String){
        let errorStr = "Error: \(error)"
        addEvent(event: errorStr)
    }
    
    private func addEvent(event: String) {
        // Format the timestamp
        let now = Date()
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "MM/dd/yy HH:mm:ss"
        let dateString = formatter.string(from: now)
        let eventString = "\(dateString) \(event)"
        print(event)
        
        // Dispatch to the main thread to prevent a race case
        DispatchQueue.main.async{
            self.events.append(eventString)
            self.tableView.reloadData()
        }
        
    }
}

extension ViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return events.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Get reusable cell.
        if let cell = tableView.dequeueReusableCell(withIdentifier: "reuseId") {
            // Set text of textLabel.
            // ... Use indexPath.item to get the current row index.
            if let label = cell.textLabel {
                label.text = events[indexPath.item]
            }
            // Return cell.
            return cell
        }
        // Return empty cell.
        return UITableViewCell()
    }
}

