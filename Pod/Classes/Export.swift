//
//  Export.swift
//  Pods
//
//  Created by Michael Seemann on 02.10.15.
//
//

import Foundation
import HealthKit

public enum ExportError: ErrorType {
    case IllegalArgumentError(String)
    case DataWriteError(String?)
}

public enum HealthDataToExportType : String {
    case ALL                    = "All"
    case ADDED_BY_THIS_APP      = "Added by this app"
    case GENERATED_BY_THIS_APP  = "Generated by this app"
    
    public static let allValues = [ALL, ADDED_BY_THIS_APP, GENERATED_BY_THIS_APP];
}

public typealias ExportCompletion = (ErrorType?) -> Void
public typealias ExportProgress = (message: String, progressInPercent: NSNumber?) -> Void


class ExportOperation: NSOperation {
    
    var exportConfiguration: ExportConfiguration
    var exportTargets: [ExportTarget]
    var healthStore: HKHealthStore
    var onProgress: ExportProgress
    var onError: ExportCompletion
    var dataExporter: [DataExporter]
    
    init(
        exportConfiguration: ExportConfiguration,
        exportTargets: [ExportTarget],
        healthStore: HKHealthStore,
        dataExporter: [DataExporter],
        onProgress: ExportProgress,
        onError: ExportCompletion,
        completionBlock: (() -> Void)?
        ) {
        
        self.exportConfiguration = exportConfiguration
        self.exportTargets = exportTargets
        self.healthStore = healthStore
        self.dataExporter = dataExporter
        self.onProgress = onProgress
        self.onError = onError
        super.init()
        self.completionBlock = completionBlock
        self.qualityOfService = NSQualityOfService.UserInteractive
    }
    
    override func main() {
        do {
            for exportTarget in exportTargets {
                try exportTarget.startExport();
            }

            
            let exporterCount = Double(dataExporter.count)
            
            for (index, exporter) in dataExporter.enumerate() {
                self.onProgress(message: exporter.message, progressInPercent: Double(index)/exporterCount)
                try exporter.export(healthStore, exportTargets: exportTargets)
            }
            
            for exportTarget in exportTargets {
                try exportTarget.endExport();
            }
            
            self.onProgress(message: "export done", progressInPercent: 1.0)
        } catch let err {
            self.onError(err)
        }
        
    }
}


public class HealthKitDataExporter {
    
     let exportQueue: NSOperationQueue = {
        var queue = NSOperationQueue()
        queue.name = "export queue"
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    
    let healthStore: HKHealthStore
    
    let healthKitCharacteristicsTypes: Set<HKCharacteristicType> = Set(arrayLiteral:
        HKObjectType.characteristicTypeForIdentifier(HKCharacteristicTypeIdentifierDateOfBirth)!,
        HKObjectType.characteristicTypeForIdentifier(HKCharacteristicTypeIdentifierBiologicalSex)!,
        HKObjectType.characteristicTypeForIdentifier(HKCharacteristicTypeIdentifierBloodType)!,
        HKObjectType.characteristicTypeForIdentifier(HKCharacteristicTypeIdentifierFitzpatrickSkinType)!
    )

    let healthKitCategoryTypes: Set<HKCategoryType> = Set(arrayLiteral:
        HKObjectType.categoryTypeForIdentifier(HKCategoryTypeIdentifierSleepAnalysis)!,
        HKObjectType.categoryTypeForIdentifier(HKCategoryTypeIdentifierAppleStandHour)!,
        HKObjectType.categoryTypeForIdentifier(HKCategoryTypeIdentifierCervicalMucusQuality)!,
        HKObjectType.categoryTypeForIdentifier(HKCategoryTypeIdentifierOvulationTestResult)!,
        HKObjectType.categoryTypeForIdentifier(HKCategoryTypeIdentifierMenstrualFlow)!,
        HKObjectType.categoryTypeForIdentifier(HKCategoryTypeIdentifierIntermenstrualBleeding)!,
        HKObjectType.categoryTypeForIdentifier(HKCategoryTypeIdentifierSexualActivity)!
    )
    
    let healthKitQuantityTypes: Set<HKQuantityType> = Set(arrayLiteral:
        // Body Measurements
        HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierBodyMassIndex)!,
        HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierBodyFatPercentage)!,
        HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierHeight)!,
        HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierBodyMass)!,
        HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierLeanBodyMass)!,
        // Fitness
        HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierStepCount)!,
        HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierDistanceWalkingRunning)!,
        HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierDistanceCycling)!,
        HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierBasalEnergyBurned)!,
        HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierActiveEnergyBurned)!,
        HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierFlightsClimbed)!,
        HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierNikeFuel)!,
        // Vitals
        HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierHeartRate)!,
        HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierBodyTemperature)!,
        HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierBasalBodyTemperature)!,
        HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierBloodPressureSystolic)!,
        HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierBloodPressureDiastolic)!,
        HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierRespiratoryRate)!,
        // Results
        HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierOxygenSaturation)!,
        HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierPeripheralPerfusionIndex)!,
        HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierBloodGlucose)!,
        HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierNumberOfTimesFallen)!,
        HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierElectrodermalActivity)!,
        HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierInhalerUsage)!,
        HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierBloodAlcoholContent)!,
        HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierForcedVitalCapacity)!,
        HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierForcedExpiratoryVolume1)!,
        HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierPeakExpiratoryFlowRate)!,
        // Nutrition
        HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierDietaryFatTotal)!,
        HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierDietaryFatPolyunsaturated)!,
        HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierDietaryFatMonounsaturated)!,
        HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierDietaryFatSaturated)!,
        HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierDietaryCholesterol)!,
        HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierDietarySodium)!,
        HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierDietaryCarbohydrates)!,
        HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierDietaryFiber)!,
        HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierDietarySugar)!,
        HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierDietaryEnergyConsumed)!,
        HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierDietaryProtein)!,
        HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierDietaryVitaminA)!,
        HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierDietaryVitaminB6)!,
        HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierDietaryVitaminB12)!,
        HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierDietaryVitaminC)!,
        HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierDietaryVitaminD)!,
        HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierDietaryVitaminE)!,
        HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierDietaryVitaminK)!,
        HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierDietaryCalcium)!,
        HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierDietaryIron)!,
        HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierDietaryThiamin)!,
        HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierDietaryRiboflavin)!,
        HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierDietaryNiacin)!,
        HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierDietaryFolate)!,
        HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierDietaryBiotin)!,
        HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierDietaryPantothenicAcid)!,
        HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierDietaryPhosphorus)!,
        HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierDietaryIodine)!,
        HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierDietaryMagnesium)!,
        HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierDietaryZinc)!,
        HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierDietarySelenium)!,
        HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierDietaryCopper)!,
        HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierDietaryManganese)!,
        HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierDietaryChromium)!,
        HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierDietaryMolybdenum)!,
        HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierDietaryChloride)!,
        HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierDietaryPotassium)!,
        HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierDietaryCaffeine)!,
        HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierDietaryWater)!,
        HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierUVExposure)!
    )
    
    let healthKitCorrelationTypes: Set<HKCorrelationType> = Set(arrayLiteral:
        HKObjectType.correlationTypeForIdentifier(HKCorrelationTypeIdentifierBloodPressure)!,
        HKObjectType.correlationTypeForIdentifier(HKCorrelationTypeIdentifierFood)!
    )
    
    public init(healthStore: HKHealthStore) {
        self.healthStore = healthStore
    }
    
    public func export(exportTargets exportTargets: [ExportTarget], exportConfiguration: ExportConfiguration, onProgress: ExportProgress, onCompletion: ExportCompletion) -> Void {
        for exportTarget in exportTargets {
            if(!exportTarget.isValid()){
                onCompletion(ExportError.IllegalArgumentError("invalid export target \(exportTarget)"))
                return
            }
        }

        
        var requestAuthorizationTypes: Set<HKObjectType> = Set()
        requestAuthorizationTypes.unionInPlace(healthKitCharacteristicsTypes as Set<HKObjectType>!)
        requestAuthorizationTypes.unionInPlace(healthKitQuantityTypes as Set<HKObjectType>!)
        requestAuthorizationTypes.unionInPlace(healthKitCategoryTypes as Set<HKObjectType>!)
        requestAuthorizationTypes.insert(HKObjectType.workoutType())

 
        healthStore.requestAuthorizationToShareTypes(nil, readTypes: requestAuthorizationTypes) {
            (success, error) -> Void in
            
            self.healthStore.preferredUnitsForQuantityTypes(self.healthKitQuantityTypes) {
                (typeMap, error) in
        
                let dataExporter : [DataExporter] = self.getDataExporters(exportConfiguration, typeMap: typeMap)
                        
                let exportOperation = ExportOperation(
                    exportConfiguration: exportConfiguration,
                    exportTargets: exportTargets,
                    healthStore: self.healthStore,
                    dataExporter: dataExporter,
                    onProgress: onProgress,
                    onError: {(err:ErrorType?) -> Void in
                        onCompletion(err)
                    },
                    completionBlock:{
                        onCompletion(nil)
                    }
                )
                
                self.exportQueue.addOperation(exportOperation)
            }
        }
        
    }
    
    internal func getDataExporters(exportConfiguration: ExportConfiguration, typeMap: [HKQuantityType : HKUnit]) -> [DataExporter]{
        var result : [DataExporter] = []
        
        result.append(MetaDataExporter(exportConfiguration: exportConfiguration))
        
        // user data are only exported if type is ALL, beacause the app can never write these data!
        if exportConfiguration.exportType == .ALL {
            result.append(UserDataExporter(exportConfiguration: exportConfiguration))
        }
        
        // add all Qunatity types
        for(type, unit) in typeMap {
            result.append(QuantityTypeDataExporter(exportConfiguration: exportConfiguration, type: type , unit: unit))
        }
        
        // add all Category types
        for categoryType in healthKitCategoryTypes {
            result.append(CategoryTypeDataExporter(exportConfiguration: exportConfiguration, type: categoryType))
        }
        
        // add all correlation types
        for correlationType in healthKitCorrelationTypes {
            result.append(CorrelationTypeDataExporter(exportConfiguration: exportConfiguration, type: correlationType))
        }
        
        // appen the workout data type
        result.append(WorkoutDataExporter(exportConfiguration: exportConfiguration))
        
        return result
    }

}
