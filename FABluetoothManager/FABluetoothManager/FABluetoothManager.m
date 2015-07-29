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

@property BOOL isSearchingPeripherals;

@property(readwrite, copy) ReadValueBlock readValueBlock;
@property(readwrite, copy) WriteValueBlock writeValueBlock;
@property(readwrite, copy) NotifyValueBlock notifyValueBlock;

@property(readwrite, copy) PeripheralsBlock peripheralsBlock;

@property(readwrite, copy) ConnetPeripheralBlock connectBlock;
@property(readwrite, copy) ConnetPeripheralBlock disconnectBlock;

@property(readwrite, copy) ServicesBlock servicesBlock;
@property(readwrite, copy) CharacteristicsBlock characteristicsBlock;

@end

@implementation FABluetoothManager
@synthesize centralManager;

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
        centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
        
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
        self.isSearchingPeripherals = YES;
    }
}

- (void)stopSearchingForPeriphetals
{
    [self.centralManager stopScan];
    self.isSearchingPeripherals = NO;
}

- (void)connectToPeripheral:(CBPeripheral *)peripheral connect:(ConnetPeripheralBlock)block disconnect:(ConnetPeripheralBlock)disconnect;
{
    if (self.isSearchingPeripherals) {
        [self stopSearchingForPeriphetals];
    }
    self.connectBlock = block;
    switch (peripheral.state) {
        case CBPeripheralStateConnecting:
            [self.centralManager cancelPeripheralConnection:peripheral];
        case CBPeripheralStateDisconnected:
            [self.centralManager connectPeripheral:peripheral options:nil];
            break;
        case CBPeripheralStateConnected:
            [self centralManager:self.centralManager didConnectPeripheral:peripheral];
            break;
        default:
            break;
    }
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

- (void)writeValue:(NSData *)value peripheral:(CBPeripheral *)peripheral characteristic:(CBCharacteristic *)characteristic completions:(WriteValueBlock)block
{
    self.writeValueBlock = block;
    peripheral.delegate = self;
    [peripheral writeValue:value forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
}

- (void)notifyValue:(CBPeripheral*)peripheral characterictic:(CBCharacteristic*)characteristic completion:(NotifyValueBlock)block
{
    self.notifyValueBlock = block;
    peripheral.delegate = self;
    [peripheral setNotifyValue:YES forCharacteristic:characteristic];
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
    NSDictionary *p = @{kPeriphetalIdentifier:peripheral,
                        kPeriphetalRSSIIdentifier:RSSI};
    
    NSUInteger index = [self peripheral:peripheral inArray:self.peripherals];
    if (index == NSNotFound) {
        [self.peripherals addObject:p];
    } else {
        [self.peripherals replaceObjectAtIndex:index withObject:p];
    }
    //code to be executed on the main thread when background task is finished
    self.peripheralsBlock(self.peripherals, nil);
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    self.connectBlock(peripheral.state, nil);
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    self.connectBlock(peripheral.state, error);
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    self.disconnectBlock(peripheral.state, error);
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

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    self.notifyValueBlock(characteristic.value, error);
}

#pragma mark - BluetoothManager methods

- (NSInteger)peripheral:(CBPeripheral*)peripheral inArray:(NSArray*)peripherals
{
    for (NSDictionary *dict in peripherals) {
        CBPeripheral *p = dict[kPeriphetalIdentifier];
        if ([p.identifier.UUIDString isEqualToString:peripheral.identifier.UUIDString]) {
            return [peripherals indexOfObject:dict];
        }
    }
    return NSNotFound;
}

- (CBService*)service:(CBUUID*)service inArray:(NSArray*)services
{
    for (CBService *s in services) {
        if ([s.UUID.UUIDString isEqualToString:service.UUIDString]) {
            return s;
        }
    }
    return nil;
}

- (CBCharacteristic*)characterictic:(CBUUID*)characteristic inArray:(NSArray*)characteristics
{
    for (CBCharacteristic *c in characteristics) {
        if ([c.UUID.UUIDString isEqualToString:characteristic.UUIDString]) {
            return c;
        }
    }
    return nil;
}

- (void)readCharacteristic:(CBUUID*)characteristic service:(CBUUID*)service peripheral:(CBPeripheral*)peripheral completion:(ReadValueBlock)block disconnect:(ConnetPeripheralBlock)disconnectBlock
{
    CharacteristicsBlock characteristicsBlock = ^(NSArray* characteristics, NSError *error){
        if (!error) {
            CBCharacteristic *c = [self characterictic:characteristic inArray:characteristics];
            [self readValue:peripheral characteristic:c completions:block];
        } else {
            block(nil,error);
        }
    };
    
    ServicesBlock servicesBlock = ^(NSArray* services, NSError *error){
        if (!error) {
            CBService *s = [self service:service inArray:services];
            [self discoverCharacteristics:@[characteristic]
                                  service:s
                               peripheral:peripheral
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
    
    [self connectToPeripheral:peripheral
                      connect:completionBlock
                   disconnect:disconnectBlock];
}

- (void)writeValue:(NSData*)value characteristic:(CBUUID*)characteristic service:(CBUUID*)service periphera:(CBPeripheral*)peripheral completion:(WriteValueBlock)block disconnect:(ConnetPeripheralBlock)disconnectBlock
{
    CharacteristicsBlock characteristicsBlock = ^(NSArray* characteristics, NSError *error){
        if (!error) {
            CBCharacteristic *c = [self characterictic:characteristic inArray:characteristics];
            [self writeValue:value peripheral:peripheral characteristic:c completions:block];
        } else {
            block(nil,error);
        }
    };
    
    ServicesBlock servicesBlock = ^(NSArray* services, NSError *error){
        if (!error) {
            CBService *s = [self service:service inArray:services];
            [self discoverCharacteristics:@[characteristic]
                                  service:s
                               peripheral:peripheral
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
    
    [self connectToPeripheral:peripheral
                      connect:completionBlock
                   disconnect:disconnectBlock];
}

- (void)notifyCharacteristic:(CBUUID*)characteristic service:(CBUUID*)service peripheral:(CBPeripheral*)peripheral completion:(ReadValueBlock)block disconnect:(ConnetPeripheralBlock)disconnectBlock
{
    CharacteristicsBlock characteristicsBlock = ^(NSArray* characteristics, NSError *error){
        if (!error) {
            CBCharacteristic *c = [self characterictic:characteristic inArray:characteristics];
            [self notifyValue:peripheral characterictic:c completion:block];
        } else {
            block(nil,error);
        }
    };
    
    ServicesBlock servicesBlock = ^(NSArray* services, NSError *error){
        if (!error) {
            CBService *s = [self service:service inArray:services];
            [self discoverCharacteristics:@[characteristic]
                                  service:s
                               peripheral:peripheral
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
    
    [self connectToPeripheral:peripheral
                      connect:completionBlock
                   disconnect:disconnectBlock];
}

@end
