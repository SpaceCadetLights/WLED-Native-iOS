import Foundation

class DeviceApi {
    func updateDevice(device: Device, completionHandler: @escaping (Device) -> Void) {
        let url = getJsonApiUrl(device: device, path: "json/si")
        guard let url else {
            print("Can't update device, url nil")
            return
        }
        print("Reading api at: \(url)")
        
        let task = URLSession.shared.dataTask(with: url, completionHandler: { (data, response, error) in
            if let error = error {
                print("Error with fetching device: \(error)")
                self.updateDeviceOnError(device: device, completionHandler: completionHandler)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("Invalid httpResponse in update")
                self.updateDeviceOnError(device: device, completionHandler: completionHandler)
                return
            }
            guard (200...299).contains(httpResponse.statusCode) else {
                print("Error with the response in update, unexpected status code: \(httpResponse)")
                self.updateDeviceOnError(device: device, completionHandler: completionHandler)
                return
            }
            
            self.onResultFetchDataSuccess(device: device, completionHandler: completionHandler, data: data)
        })
        task.resume()
    }
    
    func postJson(device: Device, jsonData: JsonPost, completionHandler: @escaping (Device) -> Void) {
        let url = getJsonApiUrl(device: device, path: "json")
        guard let url else {
            print("Can't post to device, url nil")
            self.updateDeviceOnError(device: device, completionHandler: completionHandler)
            return
        }
        print("Posting api at: \(url)")
        do {
            let jsonData = try JSONEncoder().encode(jsonData)
            
            var request = URLRequest(url: url)
            request.httpMethod = "post"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = jsonData
            
            let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
                if let error = error {
                    print("Error with fetching device after post: \(error)")
                    self.updateDeviceOnError(device: device, completionHandler: completionHandler)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("Invalid httpResponse in post")
                    self.updateDeviceOnError(device: device, completionHandler: completionHandler)
                    return
                }
                guard (200...299).contains(httpResponse.statusCode) else {
                    print("Error with the response in post, unexpected status code: \(httpResponse)")
                    self.updateDeviceOnError(device: device, completionHandler: completionHandler)
                    return
                }
                
                self.onResultFetchDataSuccess(device: device, completionHandler: completionHandler, data: data)
            }
            task.resume()
        } catch {
            print(error)
            self.updateDeviceOnError(device: device, completionHandler: completionHandler)
        }
    }
    
    private func updateDeviceOnError(device: Device, completionHandler: @escaping (Device) -> Void) {
        print("Device \(device.address ?? "unknown") could not be updated. Marking as offline.")
        device.isOnline = false
        device.networkRssi = 0
        device.isRefreshing = false
        completionHandler(device)
    }
    
    private func getJsonApiUrl(device: Device, path: String) -> URL? {
        let urlString = "http://\(device.address!)/\(path)"
        print(urlString)
        return URL(string: urlString)
    }
    
    private func onResultFetchDataSuccess(device: Device, completionHandler: @escaping (Device) -> Void, data: Data?) {
            guard let data else { return }            
            do {
                let deviceStateInfo = try JSONDecoder().decode(DeviceStateInfo.self, from: data)
                print("Updating \(deviceStateInfo.info.name)")
                device.macAddress = deviceStateInfo.info.mac
                device.isOnline = true
                device.name = device.isCustomName ? device.name : deviceStateInfo.info.name
                device.brightness = deviceStateInfo.state.brightness
                device.isPoweredOn = deviceStateInfo.state.isOn
                device.isRefreshing = false
                device.networkRssi = deviceStateInfo.info.wifi.rssi ?? 0
                
                
                let colorInfo = deviceStateInfo.state.segment?[0].colors?[0]
                let red = Int64(Double(colorInfo![0]) + 0.5)
                let green = Int64(Double(colorInfo![1]) + 0.5)
                let blue = Int64(Double(colorInfo![2]) + 0.5)
                device.color = (red << 16) | (green << 8) | blue
                
                completionHandler(device)
                
            } catch {
                print(error)
                updateDeviceOnError(device: device, completionHandler: completionHandler)
            }
    }
}
