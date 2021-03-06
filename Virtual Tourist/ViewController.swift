//
//  ViewController.swift
//  Virtual Tourist
//
//  Created by Nick Short on 22/11/2015.
//  Copyright © 2015 Nick Short. All rights reserved.
//

import UIKit
import CoreData
import MapKit

class ViewController: UIViewController, MKMapViewDelegate,UIGestureRecognizerDelegate,NSFetchedResultsControllerDelegate {

   
    @IBOutlet weak var MapView: MKMapView!
    @IBOutlet weak var deletePinButton: UIButton!
    
    
    var droppedPin:PinAnnotation!
    
    var deletePins:UIBarButtonItem!
    var pinArray = [Pin]()
    var newPin:Pin!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
     // Do any additional setup after loading the view, typically from a nib.
        
        
        deletePins =  UIBarButtonItem(title: "Edit", style: UIBarButtonItemStyle.Plain, target:self, action:#selector(ViewController.removePinsFromMap))
        self.navigationItem.rightBarButtonItem = deletePins
        deletePinButton.hidden = true
        deletePinButton.userInteractionEnabled = false
        
        
        let singleTap:UILongPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(ViewController.addNewPinToMap(_:)))
        singleTap.numberOfTouchesRequired = 1
        singleTap.delegate = self
        
        MapView.addGestureRecognizer(singleTap)
        MapView.delegate = self
        
        pinArray = gatherPersistedPins()
        addPersistedPinsToMap()
    }

    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    
    
    // create sharedContext variable
    lazy var sharedContext:NSManagedObjectContext = {
       return CoreDataStackManager.sharedInstance().managedObjectContext
    }()
    
    
        
    
    func gatherPersistedPins() -> [Pin]{
        let fetchRequest = NSFetchRequest(entityName: "Pin")
        do{
            return try sharedContext.executeFetchRequest(fetchRequest) as! [Pin]
        }catch let error as NSError{
            print("Error in addPersistedPins(): \(error)")
            return [Pin]()
        }
    }
    
    
    func addPersistedPinsToMap(){
        for i in  0 ..< pinArray.count{
            let pinCoords:CLLocationCoordinate2D = CLLocationCoordinate2DMake(pinArray[i].latitude as Double,pinArray[i].longitude as Double)
            let annotation = PinAnnotation(pin: pinArray[i],coords: pinCoords)
            self.MapView.addAnnotation(annotation)
        }
    }
    
    
    func addNewPinToMap(gestureRecognizer:UILongPressGestureRecognizer){
        
        let location = gestureRecognizer.locationInView(MapView)
        let coords:CLLocationCoordinate2D = MapView.convertPoint(location, toCoordinateFromView:MapView)
        
        switch gestureRecognizer.state{
        case .Began:
            
            droppedPin = PinAnnotation(pin: nil,coords:coords)
            droppedPin.willChangeValueForKey("coordinate")
            droppedPin.coordinate = coords
            droppedPin.didChangeValueForKey("coordinate")
            self.MapView.addAnnotation(droppedPin)
            
        case .Changed:
            
            droppedPin.willChangeValueForKey("coordinate")
            droppedPin.coordinate = coords
            droppedPin.didChangeValueForKey("coordinate")
            
            
        case .Ended:
            
            self.centerMap(coords)
            
            // create bounding box entity and associate it with pin
            var boundingDictionary:[String:AnyObject] = [String:AnyObject]()
            boundingDictionary[Box.Keys.minLong] = coords.longitude - 0.02 
            boundingDictionary[Box.Keys.minLat] = coords.latitude - 0.02
            boundingDictionary[Box.Keys.maxLong] = coords.longitude + 0.02
            boundingDictionary[Box.Keys.maxLat] = coords.latitude + 0.02
            boundingDictionary[Box.Keys.pageNumber] = 1
           
            
            // set up pin dictionary
            var pinDic:[String:AnyObject] = [String:AnyObject]()
            pinDic[Pin.Keys.latitude] = coords.latitude
            pinDic[Pin.Keys.longitude] = coords.longitude
            pinDic[Pin.Keys.firstTransition] = "true"
            
            // create new pin object
            self.newPin = Pin(dictionary: pinDic, context: self.sharedContext)
            self.pinArray.append(self.newPin)
            droppedPin.pin = self.newPin
            
            let newBox = Box(dictionary: boundingDictionary, context: self.sharedContext)
            newBox.pin = self.newPin
            
            
            var localPathArray:[String] = []
            var urlArray:[NSURL] = []
            
            
            //TODO: if application restart don't reset count
            VTClient.Count.downloaded = 0
            
            
            // do core data stuff
            VTClient.sharedInstance().connectToFlickr(boundingDictionary){
                (result,photoID,error) in
                
                let result = result as! NSArray
                
                for i in 0 ..< photoID.count{
                    
                    // use returned imageURL path to save to core data
                    let fullPath = VTClient.sharedInstance().pathForImage(photoID[i] as! String)
                    localPathArray.append(fullPath)
                    
                    let newURL = result[i] as! NSURL
                    urlArray.append(newURL)
                    
                    // set up photo dictionary
                    var photoDic:[String:AnyObject] = [String:AnyObject]()
                    
                    // add path to image in docs directory to core data
                    photoDic[Photo.Keys.imagePath] = fullPath
                    photoDic[Photo.Keys.savedToDirectory] = "No"
                    
                    let newPhoto = Photo(dictionary: photoDic, context: self.sharedContext)
                    newPhoto.pin = self.newPin
                    
                    do{
                        try self.sharedContext.save()
                    }catch{
                        
                    }
                }
               
                VTClient.sharedInstance().getPictures(urlArray,pathArray: localPathArray)
                
                
            }// end of connectToFlickr
            
        default: break
            
        }
        
    }
    
    
    func centerMap(coords:CLLocationCoordinate2D){
        
        let coordSpan = MKCoordinateSpan(latitudeDelta: 1, longitudeDelta: 1)
        
        let coordinateRegion = MKCoordinateRegionMake(coords,coordSpan)
        MapView.setRegion(coordinateRegion, animated: true)
    }
    
    
    func removePinsFromMap(){
        
        if(deletePins.title == "Edit"){
            deletePinButton.hidden = false
            deletePins.title = "Done"
        }else{
            deletePinButton.hidden = true
            deletePins.title = "Edit"
        }
    }
    
    func mapView(mapView: MKMapView, didSelectAnnotationView view: MKAnnotationView) {
       
        if(deletePinButton.hidden == false){
            
            // remove pin from map
            let pinAnnotation = view.annotation as! PinAnnotation
            self.MapView.removeAnnotation(pinAnnotation)
            
            //remove Pin from core data
            let pinPredicate = NSPredicate(format: "latitude == %@", pinAnnotation.pin.latitude)
            let fetchRequest = NSFetchRequest(entityName: "Pin")
            fetchRequest.predicate = pinPredicate
            
            do{
                let fetchedEntities = try sharedContext.executeFetchRequest(fetchRequest) as! [Pin]
                if let entityToDelete = fetchedEntities.first{
                    sharedContext.deleteObject(entityToDelete)
                }
            }catch{
               
            }
            
          
            do{
                try sharedContext.save()
            }catch{
            
            }
    
        }else{
            // if not deleting a pin segue to collection 
            
            //TODO: if first transition set core data element to true
            
            
            
            
            let controller = self.storyboard?.instantiateViewControllerWithIdentifier("PhotoAlbumViewController") as! PhotoAlbumViewController
            let pin = view.annotation as! PinAnnotation
            controller.currentPinAnnotation = pin
            mapView.deselectAnnotation(pin, animated: true)
            self.navigationController?.pushViewController(controller, animated: true)
        }
    }
   
}

