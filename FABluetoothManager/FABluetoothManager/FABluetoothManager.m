//
//  BluetoothManager.m
//  Farellano
//
//  Created by Fernando Arellano on 7/21/15.
//  Copyright (c) 2015 Farellano. All rights reserved.
//

#import "FABluetoothManager.h"

const char * kBluetoothManagerIdentifier = "com.farellano.fabluetoothmanager";
NSString * kBluetoothManagerError = @"com.farellano.fabluetoothmanager.error";

NSString * const kPeriphetalIdentifier = @"periphetal";
NSString * const kPeriphetalRSSIIdentifier = @"rssi";

@interface FABluetoothManager () <CBCentralManagerDelegate, CBPeripheralDelegate>

@property (nonatomic,retain) CBCentralManager *centralManager;

@property(readwrite, copy) ReadValueBlock readValueBlock;
@property(readwrite, copy) WriteValueBlock writeValueBlock;
@property(readwrite, copy) PeripheralsBlock peripheralsBlock;
@property(readwrite, copy) ConnetPeripheralBlock connectBlock;

@property(readwrite, copy) ServicesBlock servicesBlock;
@property(readwrite, copy) CharacteristicsBlock characteristicsBlock;

@end

@implementation FABluetoothManager

+ (id)manager
{
    static FABluetoothManager *sharedMyManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedMyManager = [[self alloc] init];
    });
    return sharedMyManager;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
        
        self.peripherals = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)startSearchingForPeriphetals:(PeripheralsBlock)block services:(NSArray*)services;
{
    self.peripheralsBlock = block;
    if (self.centralManager.state  != CBCentralManagerStatePoweredOn) {
        NSError *error = [NSError errorWithDomain:kBluetoothManagerError
                                    code:-1
                                userInfo:@{NSLocalizedFailureReasonErrorKey:@"Bluetooth is turned off",
                                           NSLocalizedDescriptionKey:@"Please check your bluetooth settings"}];
        self.peripheralsBlock(nil, error);
    } else {
        [self.centralManager scanForPeripheralsWithServices:services options:nil];
    }
}

- (void)stopSearchingForPeriphetals
{
    [self.centralManager stopScan];
}

- (void)connectToPeripheral:(CBPeripheral *)peripheral completion:(ConnetPeripheralBlock)block
{
    self.connectBlock = block;
    [self.centralManager connectPeripheral:peripheral options:nil];
}

- (void)discoverServices:(NSArray *)services peripheral:(CBPeripheral *)peripheral completion:(ServicesBlock)block
{
    self.servicesBlock = block;
    NSArray *cachedServices = [self cachedServices:services periphetal:peripheral];
    if (cachedServices && cachedServices.count > 0) {
        self.servicesBlock(cachedServices, nil);
    } else {
        peripheral.delegate = self;
        [peripheral discoverServices:services];
    }
}

- (void)discoverCharacteristics:(NSArray *)characteristics service:(CBService *)service peripheral:(CBPeripheral *)peripheral completion:(CharacteristicsBlock)block
{
    self.characteristicsBlock = block;
    
    
    NSArray *cachedCharacteristics = [self cachedCharacteristics:characteristics service:service];
    if (cachedCharacteristics && cachedCharacteristics.count > 0) {
        self.characteristicsBlock(cachedCharacteristics, nil);
    } else {
        peripheral.delegate = self;
        [peripheral discoverCharacteristics:characteristics forService:service];
    }
}

- (void)readValue:(CBPeripheral *)peripheral characteristic:(CBCharacteristic *)characteristic completions:(ReadValueBlock)block
{
    self.readValueBlock = block;
    peripheral.delegate = self;
    [peripheral readValueForCharacteristic:characteristic];
}

- (NSArray*)cachedServices:(NSArray*)services periphetal:(CBPeripheral*)periphetal
{
    return [periphetal.services filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"UUID IN %@", services]];
}

- (NSArray*)cachedCharacteristics:(NSArray*)characteristics service:(CBService*)service;
{
    return [service.characteristics filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"UUID IN %@", characteristics]];
}

#pragma mark - CBCentralManagerDelegate

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    [self.delegate bluetoothManager:self updateState:central.state];
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    NSUInteger index = [self.peripherals indexOfObject:peripheral];
    if (index == NSNotFound) {
        [self.peripherals addObject:@{kPeriphetalIdentifier:peripheral,
                                      kPeriphetalRSSIIdentifier:RSSI}];
    } else {
        [self.peripherals replaceObjectAtIndex:index withObject:@{kPeriphetalIdentifier:peripheral,
                                                                  kPeriphetalRSSIIdentifier:RSSI}];
    }
    //code to be executed on the main thread when background task is finished
    self.peripheralsBlock(self.peripherals, nil);
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    [self stopSearchingForPeriphetals];
    self.connectBlock(peripheral.state, nil);
}


- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    self.connectBlock(peripheral.state, error);
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    self.connectBlock(peripheral.state, error);
}

#pragma mark - CBPeriphitalDelegate

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    self.servicesBlock(peripheral.services, error);
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    self.characteristicsBlock(service.characteristics, error);
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    self.writeValueBlock(characteristic.value, error);
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    self.readValueBlock(characteristic.value, error);
}

#pragma mark - BluetoothManager methods

- (void)readCharacteristic:(CBUUID*)characteristic service:(CBUUID*)service periphera:(CBPeripheral*)peripheral completion:(ReadValueBlock)block
{
    CharacteristicsBlock characteristicsBlock = ^(NSArray* characteristics, NSError *error){
        if (!error) {
            [self readValue:peripheral characteristic:[characteristics objectAtIndex:1] completions:block];
        } else {
            block(nil,error);
        }
    };
    
    ServicesBlock servicesBlock = ^(NSArray* services, NSError *error){
        if (!error) {
            [self discoverCharacteristics:@[characteristic]
                                                      service:[services firstObject] peripheral:peripheral
                                                   completion:characteristicsBlock];
        } else {
            block(nil, error);
        }
    };
    
    ConnetPeripheralBlock completionBlock = ^(CBPeripheralState state, NSError* error){
        if (state == CBPeripheralStateConnected) {
            [self discoverServices:@[service]
                        peripheral:peripheral
                        completion:servicesBlock];
        } else {
            block(nil, error);
        }
    };
    
    [self connectToPeripheral:peripheral completion:completionBlock];
}

@end
