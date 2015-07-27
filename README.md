# FABluetoothManager

A simple bluetooth manager block based to interact with peripherals for iOS

# Installation

Just use cocoapods `pod 'FABluetoothManager'`
Or add the `FABluetoothManager.{h.m}` files to your project

See [Cocoapods](https://cocoapods.org/)

# Getting started

## 1.- Get an instance

```
#import FABluetoothManager.h

FABluetoothManager *manager = [FABluetoothManager manager];
```

## 2.- Scan for peripherals

To start searching for peripherals use the function bellow:

Note : We're using nil as a value for services to find all the peripherals but this is something
you won't do on a real enviroment. See [Apple Bluetooth](https://developer.apple.com/library/ios/documentation/NetworkingInternetWeb/Conceptual/CoreBluetooth_concepts/PerformingCommonCentralRoleTasks/PerformingCommonCentralRoleTasks.html)

```
[manager startSearchingForPeriphetals:^(NSArray *peripherals, NSError *error) {
	NSLog(@"%@",peripherals);
} services:nil];
```

## 3.- Connect to peripheral

Before do any kind of comunication we need to connect to it.

```
ConnetPeripheralBlock completionBlock = ^(CBPeripheralState state, NSError* error){
        if (state == CBPeripheralStateConnected) {
		// Optional you can look for services
//            [self discoverServices:nil
//                        peripheral:peripheral
//                        completion:servicesBlock];
        } else {
            block(nil, error);
        }
    };
[manager connectToPeripheral:peripheral completion:completionBlock];
```

## Discover services and characteristics

Working...

## Read and write values for characteristics

Working on more documentation...

## TODOS:

* Notifications
* Finish the README.
* Fix typos

## Author

Fernando Arellano (fernando.faa@gmail.com)
