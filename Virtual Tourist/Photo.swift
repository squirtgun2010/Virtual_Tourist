//
//  Photo.swift
//  Virtual Tourist
//
//  Created by Nick Short on 20/12/2015.
//  Copyright © 2015 Nick Short. All rights reserved.
//

import Foundation
import UIKit
import CoreData

class Photo:NSManagedObject{
    
    struct Keys{
        static let imagePath = "imagePath"
        //static let title = "title"
        
    }
    
    @NSManaged var imagePath:String
    //@NSManaged var title:String
    //@NSManaged var photoId:Int
    
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
    
    init(dictionary: [String : AnyObject], context: NSManagedObjectContext) {
        
        
        let entity =  NSEntityDescription.entityForName("Photo", inManagedObjectContext: context)!
        super.init(entity: entity,insertIntoManagedObjectContext: context)
        
        imagePath = dictionary[Photo.Keys.imagePath] as! String
        //title = dictionary[Photo.Keys.title] as! String
        
        
    }
    
    
}