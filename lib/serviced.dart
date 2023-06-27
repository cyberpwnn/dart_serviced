library serviced;

import 'package:fast_log/fast_log.dart';
import 'package:precision_stopwatch/precision_stopwatch.dart';

enum ServiceState {
  offline,
  online,
  starting,
  stopping,
  failed,
}

T svc<T extends Service>({bool quiet = false}) => services().get(quiet: quiet);

typedef ServiceConstructor<T extends Service> = T Function();

ServiceProvider? _serviceProvider;

ServiceProvider services() {
  _serviceProvider ??= ServiceProvider._createStandard();
  return _serviceProvider!;
}

class ServiceProvider {
  List<Future<void>> tasks = [];
  Map<Type, Service> services = {};
  Map<Type, ServiceConstructor<dynamic>> constructors = {};

  ServiceProvider._();

  Future<void> waitForStartup() =>
      Future.wait(tasks).then((value) => tasks = []);

  factory ServiceProvider._createStandard() {
    ServiceProvider provider = ServiceProvider._();
    return provider;
  }

  void register<T extends Service>(ServiceConstructor<T> constructor,
      {bool lazy = true}) {
    constructors.putIfAbsent(T, () => constructor);
    verbose("Registered Service $T");
    if (!lazy) {
      verbose("Auto-starting Service $T");
      get<T>();
    }
  }

  T get<T extends Service>({bool quiet = false}) {
    T t = getQuiet();

    if (quiet) {
      return t;
    }

    if (t.state == ServiceState.offline || t.state == ServiceState.failed) {
      t.startService();
    }

    return t;
  }

  T getQuiet<T extends Service>() {
    if (!services.containsKey(T)) {
      if (!constructors.containsKey(T)) {
        throw Exception("No service registered for type $T");
      }

      services.putIfAbsent(T, () => constructors[T]!());
    }

    return services[T] as T;
  }
}

abstract class Service {
  ServiceState _state = ServiceState.offline;
  ServiceState get state => _state;
  String get name => runtimeType.toString().replaceAll("Service", "");

  void restartService() {
    PrecisionStopwatch p = PrecisionStopwatch.start();
    verbose("Restarting $name Service");
    stopService();
    startService();
    verbose("Restarted $name Service in ${p.getMilliseconds()}ms");
  }

  void startService() {
    if (!(_state == ServiceState.offline || _state == ServiceState.failed)) {
      throw Exception("$name Service cannot be started while $state");
    }

    PrecisionStopwatch p = PrecisionStopwatch.start();
    _state = ServiceState.starting;
    verbose("Starting $name Service");

    try {
      if (this is AsyncStartupTasked) {
        PrecisionStopwatch px = PrecisionStopwatch.start();
        verbose("Queued Startup Task: $name");
        services()
            .tasks
            .add((this as AsyncStartupTasked).onStartupTask().then((value) {
              success(
                  "Completed $name Startup Task in ${px.getMilliseconds()}ms");
            }));
      }

      onStart();
      _state = ServiceState.online;
    } catch (e, es) {
      _state = ServiceState.failed;
      error("Failed to start $name Service: $e");
      error(es);
    }

    if (_state == ServiceState.starting) {
      _state = ServiceState.failed;
    }

    if (_state == ServiceState.failed) {
      warn(
          "Failed to start $name Service! It will be offline until you restart the app or the service is re-requested.");
    } else {
      success("Started $name Service in ${p.getMilliseconds()}ms");
    }
  }

  void stopService() {
    if (!(_state == ServiceState.online)) {
      throw Exception("$name Service cannot be stopped while $state");
    }

    PrecisionStopwatch p = PrecisionStopwatch.start();
    _state = ServiceState.stopping;
    verbose("Stopping $name Service");

    try {
      onStop();
      _state = ServiceState.offline;
    } catch (e, es) {
      _state = ServiceState.offline;
      error("Failed while stopping $name Service: $e");
      error(es);
    }

    if (_state == ServiceState.failed) {
      warn("Failed to stop $name Service! It is still marked as offline.");
    } else {
      success("Stopped $name Service in ${p.getMilliseconds()}ms");
    }
  }

  void onStart();

  void onStop();
}

abstract class AsyncStartupTasked {
  Future<void> onStartupTask();
}

abstract class StatelessService extends Service {
  @override
  void onStart() {}

  @override
  void onStop() {}
}

Future<void> initializeLogging() async {
  lDebugMode = true;
}
