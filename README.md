Basic Service management for dart

## Features

* Lazy Services
* Auto Start Services
* Async Startup

## Getting started

```dart
import 'package:serviced/serviced.dart';

// This is a stateless service singleton
class TestStatelessService extends StatelessService {}

class TestService extends Service {
  @override
  void onStart() {
    // Called before the service is started
  }

  @override
  void onStop() {
    // Called before the service is stopped
  }
}

void main() async {
  // Register services here
  services().register(() => TestService());

  // This service will be started automatically
  services().register(() => TestStatelessService(), lazy: false); 
  
  // Start all services that are not lazy
  await services().waitForStartup();
  runApp(YourApp());
}

```
