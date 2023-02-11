//
//  MapScreen.swift
//  MapKit-Directions
//
//  Created by Sean Allen on 9/1/18.
//  Copyright © 2018 Sean Allen. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation
import ActiveLookSDK

class MapScreen: UIViewController {
    
    @IBOutlet weak var Stopper: UIButton!
    @IBOutlet weak var updateGlasses: UIButton!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var addressLabel: UILabel!
    @IBOutlet weak var goButton: UIButton!
    
    let locationManager = CLLocationManager()
    let regionInMeters: Double = 10000
    var previousLocation: CLLocation?
    
    let geoCoder = CLGeocoder()
    var directionsArray: [MKDirections] = []
    
    // MARK: - Activelook init
    private let glassesName: String = "ENGO 2 090756"
    private var glassesConnected: Glasses?
    private let scanDuration: TimeInterval = 10.0
    private let connectionTimeoutDuration: TimeInterval = 5.0
    
    private var scanTimer: Timer?
    private var connectionTimer: Timer?
    
    private lazy var alookSDKToken: String = {
        guard let infoDictionary: [String: Any] = Bundle.main.infoDictionary else { return "" }
        guard let activelookSDKToken: String = infoDictionary["ACTIVELOOK_SDK_TOKEN"] as? String else { return "" }
        return activelookSDKToken
    }()
    
    private lazy var activeLook: ActiveLookSDK = {
        try! ActiveLookSDK.shared(
            token: alookSDKToken,
            onUpdateStartCallback: { SdkGlassesUpdate in
                print("onUpdateStartCallback")
            }, onUpdateAvailableCallback: { (SdkGlassesUpdate, _: () -> Void) in
                print("onUpdateAvailableCallback")
            }, onUpdateProgressCallback: { SdkGlassesUpdate in
                print("onUpdateProgressCallback")
            }, onUpdateSuccessCallback: { SdkGlassesUpdate in
                print("onUpdateSuccessCallback")
            }, onUpdateFailureCallback: { SdkGlassesUpdate in
                print("onUpdateFailureCallback")
            })
    }()
    
    
    private func startScanning() {
        activeLook.startScanning(
            onGlassesDiscovered: { [weak self] (discoveredGlasses: DiscoveredGlasses) in
                if discoveredGlasses.name == self!.glassesName{
                    discoveredGlasses.connect(
                        onGlassesConnected: { [weak self] (glasses: Glasses) in
                            guard let self = self else { return }
                            self.connectionTimer?.invalidate()
                            self.stopScanning()
                            self.glassesConnected = glasses
                            self.glassesConnected?.clear()
                        }, onGlassesDisconnected: { [weak self] in
                            guard let self = self else { return }
                            
                            let alert = UIAlertController(title: "Glasses disconnected", message: "Connection to glasses lost", preferredStyle: .alert)
                            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { (_) in
                                self.navigationController?.popToRootViewController(animated: true)
                            }))
                            
                            self.navigationController?.present(alert, animated: true)
                            
                        }, onConnectionError: { [weak self] (error: Error) in
                            guard let self = self else { return }
                            self.connectionTimer?.invalidate()
                            
                            let alert = UIAlertController(title: "Error", message: "Connection to glasses failed: \(error.localizedDescription)", preferredStyle: .alert)
                            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                            self.present(alert, animated: true)
                        })
                }
            }, onScanError: { [weak self] (error: Error) in
                self?.stopScanning()
            }
        )
        
        scanTimer = Timer.scheduledTimer(withTimeInterval: scanDuration, repeats: false) { timer in
            self.stopScanning()
        }
    }
    
    private func stopScanning() {
        activeLook.stopScanning()
        scanTimer?.invalidate()
    }
    
    //Mark: - init
    override func viewDidLoad() {
        super.viewDidLoad()
        self.startScanning()
        goButton.layer.cornerRadius = goButton.frame.size.height/2
        checkLocationServices()
    }
    
    
    
    func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    
    func centerViewOnUserLocation() {
        if let location = locationManager.location?.coordinate {
            let region = MKCoordinateRegion.init(center: location, latitudinalMeters: regionInMeters, longitudinalMeters: regionInMeters)
            mapView.setRegion(region, animated: true)
        }
    }
    
    
    func checkLocationServices() {
        if CLLocationManager.locationServicesEnabled() {
            setupLocationManager()
            checkLocationAuthorization()
        } else {
            // Show alert letting the user know they have to turn this on.
        }
    }
    
    
    func checkLocationAuthorization() {
        switch CLLocationManager.authorizationStatus() {
        case .authorizedWhenInUse:
            startTackingUserLocation()
        case .denied:
            // Show alert instructing them how to turn on permissions
            break
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .restricted:
            // Show an alert letting them know what's up
            break
        case .authorizedAlways:
            break
        @unknown default:
            break
        }
    }
    
    
    func startTackingUserLocation() {
        mapView.showsUserLocation = true
        centerViewOnUserLocation()
        locationManager.startUpdatingLocation()
        previousLocation = getCenterLocation(for: mapView)
    }
    
    
    func getCenterLocation(for mapView: MKMapView) -> CLLocation {
        let latitude = mapView.centerCoordinate.latitude
        let longitude = mapView.centerCoordinate.longitude
        
        return CLLocation(latitude: latitude, longitude: longitude)
    }
    
    
    func getDirections() {
        guard let location = locationManager.location?.coordinate else {
            //TODO: Inform user we don't have their current location
            return
        }
        
        let request = createDirectionsRequest(from: location)
        let directions = MKDirections(request: request)
        resetMapView(withNew: directions)
        
        directions.calculate { [unowned self] (response, error) in
            //TODO: Handle error if needed
            guard let response = response else { return } //TODO: Show response not available in an alert
            
            for route in response.routes {
                self.mapView.addOverlay(route.polyline)
                self.mapView.setVisibleMapRect(route.polyline.boundingMapRect, animated: true)
            }
        }
    }
    
    
    func createDirectionsRequest(from coordinate: CLLocationCoordinate2D) -> MKDirections.Request {
        let destinationCoordinate       = getCenterLocation(for: mapView).coordinate
        let startingLocation            = MKPlacemark(coordinate: coordinate)
        let destination                 = MKPlacemark(coordinate: destinationCoordinate)
        
        let request                     = MKDirections.Request()
        request.source                  = MKMapItem(placemark: startingLocation)
        request.destination             = MKMapItem(placemark: destination)
        request.transportType           = .automobile
        request.requestsAlternateRoutes = true
        
        return request
    }
    
    
    func resetMapView(withNew directions: MKDirections) {
        mapView.removeOverlays(mapView.overlays)
        directionsArray.append(directions)
        let _ = directionsArray.map { $0.cancel() }
    }
    
    
    @IBAction func stopLens(_ sender: UIButton) {
        //startInterrupterLoop(isRunning: false)
    }
    @IBAction func updatetapped(_ sender: UIButton) {
        //startInterrupterLoop(isRunning: true)
    }
    @IBAction func goButtonTapped(_ sender: UIButton) {
        getDirections()
        generateImageFromMap()
    }
}


extension MapScreen: CLLocationManagerDelegate {
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        checkLocationAuthorization()
    }
}


extension MapScreen: MKMapViewDelegate {
    
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        let center = getCenterLocation(for: mapView)
        
        guard let previousLocation = self.previousLocation else { return }
        
        guard center.distance(from: previousLocation) > 50 else { return }
        self.previousLocation = center
        
        geoCoder.cancelGeocode()
        
        geoCoder.reverseGeocodeLocation(center) { [weak self] (placemarks, error) in
            guard let self = self else { return }
            
            if let _ = error {
                //TODO: Show alert informing the user
                return
            }
            
            guard let placemark = placemarks?.first else {
                //TODO: Show alert informing the user
                return
            }
            
            let streetNumber = placemark.subThoroughfare ?? ""
            let streetName = placemark.thoroughfare ?? ""
            
            DispatchQueue.main.async {
                self.addressLabel.text = "\(streetNumber) \(streetName)"
            }
        }
    }
    
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let renderer = MKPolylineRenderer(overlay: overlay as! MKPolyline)
        renderer.strokeColor = .blue
        return renderer
    }
    
    // Start the interrupter loop
    /*func startInterrupterLoop(isRunning: Bool) {
        // Create a timer that will fire every 1 second
        let timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { timer in
            if isRunning == true {
                // Call the function
                self.generateImageFromMap()
            } else {
                // Stop the timer if the interrupter loop is no longer running
                timer.invalidate()
            }
        }

        // Add the timer to the run loop
        RunLoop.current.add(timer, forMode: .common)
    }*/
    
    private func generateImageFromMap() {
        let mapSnapshotterOptions = MKMapSnapshotter.Options()
        mapSnapshotterOptions.region = self.mapView.region
        mapSnapshotterOptions.size = CGSize(width: 200, height: 200)
        mapSnapshotterOptions.mapType = MKMapType.mutedStandard
        mapSnapshotterOptions.showsBuildings = false
        mapSnapshotterOptions.showsPointsOfInterest = false


        let snapShotter = MKMapSnapshotter(options: mapSnapshotterOptions)
        
        
        snapShotter.start() { snapshot, error in
            if let image = snapshot?.image{
                self.glassesConnected?.imgStream(image: image, x: 0, y: 0, imgStreamFmt: .MONO_4BPP_HEATSHRINK)
            }else{
                print("Missing snapshot")
            }
        }
    
    }
}
