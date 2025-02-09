import 'package:flutter/foundation.dart';

import '../core/errors/errors.dart';
import '../core/interfaces/modular_interface.dart';
import '../core/interfaces/modular_navigator_interface.dart';
import '../core/interfaces/module.dart';
import '../core/models/bind.dart';
import '../core/models/modular_arguments.dart';
import 'inject.dart';
import 'modular_base.dart';
import 'navigation/modular_router_delegate.dart';

late Module _initialModule;

class ModularImpl implements ModularInterface {
  final ModularRouterDelegate routerDelegate;
  final Map<String, Module> injectMap;
  @override
  IModularNavigator? navigatorDelegate;
  List<Bind>? _overrideBinds;

  @override
  void overrideBinds(List<Bind> binds) {
    _overrideBinds = binds;
  }

  @override
  ModularArguments? get args => routerDelegate.args;

  ModularImpl({
    required this.routerDelegate,
    required this.injectMap,
  });

  @override
  Module get initialModule => _initialModule;

  @override
  void debugPrintModular(String text) {
    if (Modular.debugMode) {
      debugPrint(text);
    }
  }

  @override
  void bindModule(Module module, [String path = '']) {
    final name = module.runtimeType.toString();
    if (!injectMap.containsKey(name)) {
      module.paths.add(path);
      injectMap[name] = module;
      module.instance();
      debugPrintModular("-- ${module.runtimeType.toString()} INITIALIZED");
    } else {
      injectMap[name]?.paths.add(path);
    }
  }

  @override
  void init(Module module) {
    _initialModule = module;
    bindModule(module, "global==");
  }

  @override
  IModularNavigator get to => navigatorDelegate ?? routerDelegate;

  @override
  bool get debugMode => !kReleaseMode;

  @override
  String get initialRoute => '/';

  B? _findExistingInstance<B extends Object>() {
    for (var module in injectMap.values) {
      final bind = module.getInjectedBind<B>();
      if (bind != null) {
        return bind;
      }
    }
    return null;
  }

  @override
  B get<B extends Object>({List<Type>? typesInRequestList, B? defaultValue}) {
    var typesInRequest = typesInRequestList ?? [];
    var result = _findExistingInstance<B>();

    if (result != null) {
      return result;
    }

    for (var key in injectMap.keys) {
      final value = _getInjectableObject<B>(key, typesInRequestList: typesInRequest, checkKey: false);
      if (value != null) {
        return value;
      }
    }

    if (result == null && defaultValue != null) {
      return defaultValue;
    }

    throw ModularError('${B.toString()} not found');
  }

  B? _getInjectableObject<B extends Object>(
    String tag, {
    List<Type>? typesInRequestList,
    bool checkKey = true,
  }) {
    B? value;
    var typesInRequest = typesInRequestList ?? [];
    if (!checkKey) {
      value = injectMap[tag]?.getBind<B>(typesInRequest: typesInRequest);
    } else if (injectMap.containsKey(tag)) {
      value = injectMap[tag]?.getBind<B>(typesInRequest: typesInRequest);
    }

    return value;
  }

  @override
  bool dispose<B extends Object>() {
    var isDisposed = false;
    for (var key in injectMap.keys) {
      if (_removeInjectableObject<B>(key)) {
        isDisposed = true;
        break;
      }
    }
    return isDisposed;
  }

  bool _removeInjectableObject<B>(String tag) {
    return injectMap[tag]?.remove<B>() ?? false;
  }

  @override
  T bind<T extends Object>(Bind<T> bind) => Inject(overrideBinds: _overrideBinds ?? []).get(bind);
}
