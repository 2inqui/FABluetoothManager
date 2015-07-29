//
//  BluetoothManager.h
//  Farellano
//
//  Created by Fernando Arellano on 7/21/15.
//  Copyright (c) 2015 Farellano. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import <CoreBluetooth/CBService.h>

extern NSString * const kPeriphetalIdentifier;
extern NSString * const kPeriphetalRSSIIdentifier;

// Central callbacks
typedef void (^ConnetPeripheralBlock)(CBPeripheralState state, NSError* error);
typedef void (^PeripheralsBlock)(NSArray *peripherals, NSError* error);

// Characteristics callbacks
typedef void (^ReadValueBlock)(NSData* data, NSError* error);
typedef void (^WriteValueBlock)(NSData* data, NSError* error);
typedef void (^NotifyValueBlock)(NSData* data, NSError* error);

// Peripheral callbacks
typedef void (^ServicesBlock)(NSArray* services, NSError* error);
typedef void (^CharacteristicsBlock)(NSArray* characteristics, NSError* error);

@class FABluetoothManager;

@protocol FABluetoothManagerDelegate <NSObject>

- (void)bluetoothManager:(FABluetoothManager*)manager updateState:(CBCentralManagerState)state;

@end

@interface FABluetoothManager : NSObject

@property (nonatomic, retain, readonly) CBCentralManager *centralManager;

@property id<FABluetoothManagerDelegate> delegate;

@property NSMutableArray* peripherals;

+ (id)manager;

/**
 *  Start searching for peripherals
 *  the result is deilvered using the delegate ( BluetoothManagerDelegate )
 *  Note: Do not forget to call stopSearchingForPeriphetals when the search for 
 *  devices is not longer necesary
 *
 *  @param error NSError pointer for posible errors such a Bluetooth Off
 */
- (void)startSearchingForPeriphetals:(PeripheralsBlock)block services:(NSArray*)services;

/**
 *  Strop the service to search for peripherals
 */
- (void)stopSearchingForPeriphetals;

/**
 *  Will try to connect to peripheral
 *
 *  @param peripheral CBPeriphetal to connect
 *  @param block      callback to deliver the result for connection success
 *  @param block      callback to deliver the result when disconnected
 */
- (void)connectToPeripheral:(CBPeripheral *)peripheral connect:(ConnetPeripheralBlock)block disconnect:(ConnetPeripheralBlock)disconnect;

/**
 *  Start searching for services in the given peripheral.
 *  This function will deliver the result through the block and can deliver
 *  as many updates as we get from the CoreBluetooth framework
 *
 *  @param services   NSArray of CBService to search on the device for.
 *  @param peripheral CBPeripheral to search the services in.
 *  @param block      ServicesBlock to deliver the result
 */
- (void)discoverServices:(NSArray*)services peripheral:(CBPeripheral*)peripheral completion:(ServicesBlock)block;

/**
 *  Start searching for characteristics on the giver service
 *
 *  @param characteristics NSArray of CBCharacteristic to search for on the service peripheral
 *  @param service         CBService to search the characteristics in
 *  @param peripheral      CBPeripherar where to search the characteristic
 *  @param block           CharacteristicsBlock to deliver the result
 */
- (void)discoverCharacteristics:(NSArray*)characteristics service:(CBService*)service peripheral:(CBPeripheral*)peripheral completion:(CharacteristicsBlock)block;

/**
 *  Read the value for the characteristic on the peripheral
 *
 *  @param peripheral     CBPeripherar where the characteristic should be read
 *  @param characteristic CBCharacteristic to read the value
 *  @param block          ReadValueBlock to deliver the result
 */
- (void)readCharacteristic:(CBUUID*)characteristic service:(CBUUID*)service peripheral:(CBPeripheral*)peripheral completion:(ReadValueBlock)block disconnect:(ConnetPeripheralBlock)disconnectBlock;;

/**
 *  Write the data to a characteristic
 *
 *  @param value          NSData to be written
 *  @param characteristic CBCharacterictic where the data should be written
 *  @param service        CBService where the characteristic belongs to
 *  @param peripheral     CBPeripheral to write the value
 *  @param block          WriteValueBlock callback used to deliver the result
 */
- (void)writeValue:(NSData*)value characteristic:(CBUUID*)characteristic service:(CBUUID*)service periphera:(CBPeripheral*)peripheral completion:(WriteValueBlock)block disconnect:(ConnetPeripheralBlock)disconnectBlock;;

- (void)notifyCharacteristic:(CBUUID*)characteristic service:(CBUUID*)service peripheral:(CBPeripheral*)peripheral completion:(ReadValueBlock)block disconnect:(ConnetPeripheralBlock)disconnectBlock;

@end
