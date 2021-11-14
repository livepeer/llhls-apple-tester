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
let endPoint = "https://webhook.site/367d6463-109c-46df-867e-25f851461a8a"

class ViewController: UIViewController {
    
    // This unique identifier will be generated each time the app view is loaded
    var uuid = ""
    
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
        addEvent(event: "Set Url", description: urlText)
        setPlayerItem()
    }
    
    // View to hold the AVPlayerLayer
    @IBOutlet weak var playerContainer: UIView!
    
    let player = AVPlayer()
    var playerLayer : AVPlayerLayer?

    @IBAction func pausePress(_ sender: Any) {
        player.pause()
        addEvent(event: "Pause")
    }
    
    @IBAction func playPress(_ sender: Any) {
        if player.currentItem == nil {
            setPlayerItem()
        }
        player.play()
        addEvent(event: "Play")
    }
    
    @IBAction func stopPress(_ sender: Any) {
        // There is no stop functionality so instead I am destroying the asset in the player
        player.replaceCurrentItem(with: nil)
        addEvent(event: "Stop")
    }
    
    @IBAction func livePress(_ sender: Any) {
        // This seeks to the very end of the stream if a user has paused
        guard let livePosition = player.currentItem?.seekableTimeRanges.last as? CMTimeRange else {
            addEvent(event: "Error", description: "Live Seek Failed")
            return
        }
        addEvent(event: "Live Seek")
        player.seek(to:CMTimeRangeGetEnd(livePosition))
    }
    
    private func setPlayerItem(){
        // Only reset the player item if it is already nil so pause can be tested
        guard let urlString = urlLabel.text, let url = URL(string: urlString) else{
            addEvent(event: "Error", description: "Player Item Set Failed")
            return
        }
        let playerItem = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: playerItem)
        addEvent(event: "Player Item Set")
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

        // Player notifications
        let center = NotificationCenter.default
        center.addObserver(self, selector:#selector(self.newErrorLogEntry(_:)), name: .AVPlayerItemNewErrorLogEntry, object: player.currentItem)
        center.addObserver(self, selector:#selector(self.failedToPlayToEndTime(_:)), name: .AVPlayerItemFailedToPlayToEndTime, object: player.currentItem)
        
        // Generate uuid
        uuid = UUID().uuidString
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
                addEvent(event: "Error", description:localizedError)
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
        addEvent(event: "Error", description:localizedError)
    }

    @objc func failedToPlayToEndTime(_ notification: Notification) {
        if let error = notification.userInfo!["AVPlayerItemFailedToPlayToEndTimeErrorKey"] as? Error {
            addEvent(event: "Error", description: error.localizedDescription)
        }
    }
    
    private func addEvent(event: String, description: String = "") {
        // Format the timestamp
        let now = Date()
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "MM/dd/yy HH:mm:ss"
        let dateString = formatter.string(from: now)
        
        // Print the event string
        let eventString = "\(dateString): \(event) \(description)"
        print(event)
        
        // Dispatch to the main thread to prevent a race case
        DispatchQueue.main.async{
            // Update the table view and data
            self.events.append(eventString)
            self.tableView.reloadData()
        }
        
        // Report the event to the backend
        let json: [String: Any] = ["sessionID": uuid, "event": event, "description": description, "timeStamp": dateString]
        let jsonData = try? JSONSerialization.data(withJSONObject: json)

        // Create post request
        let url = URL(string: endPoint)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        // Insert json data to the request
        request.httpBody = jsonData

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print(error?.localizedDescription ?? "No data")
                return
            }
            let responseJSON = try? JSONSerialization.jsonObject(with: data, options: [])
            if let responseJSON = responseJSON as? [String: Any] {
                print(responseJSON)
            }
        }
        task.resume()
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
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let alertController = UIAlertController(title: "Log", message: self.events[indexPath.row], preferredStyle: .alert)
        //Create and add the Cancel action
        let cancelAction: UIAlertAction = UIAlertAction(title: "Close", style: .cancel) { action -> Void in
          //Just dismiss the action sheet
            self.tableView.deselectRow(at: indexPath, animated: true)
        }
        alertController.addAction(cancelAction)
        self.present(alertController, animated: true, completion: nil)
    }
}

