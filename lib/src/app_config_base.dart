
import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:rxdart/rxdart.dart';

class AppConfig {
  final Map<String,Property> _props = {};
  ConfigSet? _activeConfigSet;

  void activateConfig(ConfigSet config) { _activeConfigSet = config; }
  void deactivateConfig() { _activeConfigSet = null; }
  ConfigSet config() {
    if (_activeConfigSet == null) throw "No config active";
    return _activeConfigSet!;
  }

  ConfigSet createConfig(Set<Value> values) => ConfigSet(appConfig: this, values: values);
  Property<T> property<T>({required String name, required T defaultValue, String? title, String? description, List<T>? availableOptions}) {
    if (_props.containsKey(name)) {
      if (_props[name] is Property<T>) {
        return _props[name] as Property<T>;
      } else {
        throw "Property type for '$name' changed dinamically. This is not supported";
      }
    }
    final Property<T> prop = Property<T>._(name: name, defaultValue: defaultValue, rootConfig: this, title: title, description: description, availableOptions: availableOptions);
    _props['name'] = prop;
    return prop;
  }
}

class ConfigSet {
  final AppConfig appConfig;
  final Set<Value> values;

  getValue<T>(Property<T> property) => values.whereType<Value<T>>().firstWhere(
    (element) => element.property == property,
    orElse: () => property.withValue().fixed(property.defaultValue),
  );

  ConfigSet({
    required this.appConfig,
    required this.values,
  });

  ConfigSet copyWith(Set<Value> values) {
    final Map<String,Value> withKeys = Map.fromEntries(this.values.map((e) => MapEntry(e.property.name, e)));
    withKeys.addEntries(values.map((e) => MapEntry(e.property.name, e)));
    return ConfigSet(appConfig: appConfig, values: withKeys.values.toSet());
  }
}

class Property<T> extends Equatable {
  final AppConfig _rootConfig;
  final String name;
  final T defaultValue;
  final String? title;
  final String? description;
  final List<T>? availableOptions;


  Property._({
    required AppConfig rootConfig,
    required this.name,
    required this.defaultValue,
    this.title,
    this.description,
    this.availableOptions,
  }) : _rootConfig = rootConfig;

  PropertyValueSetter<T> withValue() => PropertyValueSetter<T>._(this);

  Value<T> get _value => _rootConfig.config().getValue(this);
  T get value => _value.value;
  set value(T value) => _value.value = value;
  bool get isVisible => _value._definition is! InvisibleValue;
  bool get isModifiable => _value._definition is _ModifiableValue;
  bool get enabled => (_value._definition as _ModifiableValue).isCurrentlyModifiable;
  Stream<T> get stream {
    final _ValueDefinition<T> definition = _value._definition;
    if (definition is _ModifiableValue<T>) {
      return (definition as _ModifiableValue<T>).stream.map((event) => event ?? defaultValue);
    }
    throw "This value is not modifiable";
  }

  @override
  List<Object?> get props => [name];
}

class PropertyValueSetter<T> {
  final Property<T> property;

  PropertyValueSetter._(this.property);

  Value<T> fixed(T value) => Value<T>._(property, FixedValue<T>(value));
  Value<T> invisible(T value) => Value<T>._(property, InvisibleValue<T>(value));
  Value<T> userDefined({T? initialValue}) => Value<T>._(property, _UserDefinedValue<T>(initialValue: initialValue));

  Value<T> withAndDependency(
    Value<T> child, {
    required List<Property<bool>> dependencies,
  }) => Value<T>._(property, _AndBooleanDependantValue<T>(childValue: child, dependencies: dependencies));
  Value<T> withOrDependency(
    Value<T> child, {
    required List<Property<bool>> dependencies,
  }) => Value<T>._(property, _OrBooleanDependantValue<T>(childValue: child, dependencies: dependencies));
  Value<T> withDependency<R>(
    Value<T> child, {
    required List<Property<R>> dependencies,
    required bool Function(List<Property<R>> dependencies) checkAvailability,
  }) => Value<T>._(
    property,
    _CustomDependantValue<T,R>(
      childValue: child,
      dependencies: dependencies,
      checkAvailability: checkAvailability,
    ),
  );
}


class Value<T> extends Equatable {
  final Property<T> property;
  final _ValueDefinition<T> _definition;

  Value._(this.property, this._definition);

  T get value => _definition.value ?? property.defaultValue;
  set value(T value) {
    if (_definition is! _ModifiableValue) throw "Value is not modifiable";
    (_definition as _ModifiableValue).value = value;
  }
  
  @override
  List<Object?> get props => [property];
}

abstract class _ValueDefinition<T> {
  T? get value;

  _ValueDefinition._();
}

abstract interface class _ModifiableValue<T> {
  Stream<T?> get stream;

  /// Some properties may be unmodifiable based on their dependencies
  bool get isCurrentlyModifiable => true;

  set value(T? value);
}

class FixedValue<T> extends _ValueDefinition<T> {
  @override
  final T? value;

  FixedValue(this.value) : super._();
}

class InvisibleValue<T> extends FixedValue<T> {
  InvisibleValue(super.value);
}

class _UserDefinedValue<T> extends _ValueDefinition<T> implements _ModifiableValue<T> {
  final BehaviorSubject<T> streamController;

  @override
  T? get value => streamController.valueOrNull;

  @override
  Stream<T> get stream => streamController.stream;

  @override
  set value(T? value) {
    if (!isCurrentlyModifiable) throw "This value is not currently modifiable";
    if (value == null) return;
    streamController.add(value);
  }

  _UserDefinedValue({T? initialValue})
    : streamController = initialValue != null ? BehaviorSubject<T>.seeded(initialValue) : BehaviorSubject(),
      super._();
      
  @override
  bool get isCurrentlyModifiable => true;
}

class _AndBooleanDependantValue<T> extends _DependantValue<T,bool> {

  _AndBooleanDependantValue({
    required super.childValue,
    required super.dependencies,
  });

  @override
  bool isAvailable() {
    return dependencies.fold<bool>(true, (previousValue, prop) => previousValue && prop.value);
  }
}

class _OrBooleanDependantValue<T> extends _DependantValue<T,bool> {

  _OrBooleanDependantValue({
    required super.childValue,
    required super.dependencies,
  });

  @override
  bool isAvailable() {
    return dependencies.fold<bool>(true, (previousValue, prop) => previousValue || prop.value);
  }
}

class _CustomDependantValue<T,R> extends _DependantValue<T,R> {
  final bool Function(List<Property<R>> dependencies) checkAvailability;

  _CustomDependantValue({
    required super.childValue,
    required super.dependencies,
    required this.checkAvailability,
  });

  @override
  bool isAvailable() {
    return checkAvailability(dependencies);
  }
}

abstract class _DependantValue<T,R> extends _ValueDefinition<T> implements _ModifiableValue<T> {
  final Value<T> childValue;
  final List<Property<R>> dependencies;
  final BehaviorSubject<T?> streamController = BehaviorSubject();
  final bool keepLastValueOndisable = false;

  bool initialized = false;

  @override
  T? get value {
    if (!initialized) init();
    if (dependencies.isEmpty) {
      return childValue.value;
    }

    if (isAvailable()) {
      return childValue.value;
    }

    return keepLastValueOndisable ? childValue.value : null;
  }

  @override
  Stream<T?> get stream {
    if (!initialized) init();
    return streamController.stream;
  }

  @override
  set value(T? value) {
    if (!initialized) init();
    if (value != null) {
      childValue.value = value;
    }
  }

  bool isAvailable();

  init() {
    listenDependency(childValue);
    dependencies.forEach((element) {
      listenDependency(element._value);
    });
    initialized = true;
  }

  @override
  bool get isCurrentlyModifiable =>
    isAvailable()
    && dependencies.fold(
      childValue._definition is _ModifiableValue && (childValue._definition as _ModifiableValue).isCurrentlyModifiable,
      (previousValue, element) => previousValue || element._value._definition is _ModifiableValue && (element._value._definition as _ModifiableValue).isCurrentlyModifiable,
    );

  listenDependency(Value dependency) {
    if (dependency._definition is _ModifiableValue) {
      (dependency._definition as _ModifiableValue).stream.listen((event) {
        streamController.add(this.value);
      });
    }
  }

  _DependantValue({
    required this.childValue,
    required this.dependencies,
  }) : super._();
}