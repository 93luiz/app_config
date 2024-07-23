import 'package:app_config/app_config.dart';
import 'package:flutter/material.dart';

class ConfigListTile<T> extends StatelessWidget {
  const ConfigListTile(this.property, {super.key});

  final Property<T> property;

  @override
  Widget build(BuildContext context) {
    if (property.isModifiable) {
      if (property is Property<bool>) {
        return SwitchConfig(property as Property<bool>);
      }
      if (property.availableOptions != null && property.availableOptions!.isNotEmpty) {
        return SelectConfig(property);
      }
      return StreamBuilder<T>(
        stream: property.stream,
        builder: (context, snapshot) {
          return ListTile(
            title: Text(property.title ?? property.name),
            subtitle: Text(property.value.toString()),
          );
        },
      );
    }
    return ListTile(
      title: Text(property.title ?? property.name),
      subtitle: Text(property.value.toString()),
    );
  }
}

class SwitchConfig extends StatelessWidget {
  const SwitchConfig(this.property, {super.key});

  final Property<bool> property;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: property.stream,
      builder: (context, snapshot) {
        return SwitchListTile(
          title: Text(property.title ?? property.name),
          value: snapshot.data ?? property.defaultValue,
          onChanged: property.enabled ? (value) => property.value = value : null,
        );
      },
    );
  }
}

class SelectConfig<T> extends StatelessWidget {
  const SelectConfig(this.property, {super.key});

  final Property<T> property;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<T>(
      stream: property.stream,
      builder: (context, snapshot) {
        return DropdownMenu<T>(
          label: Text(property.title ?? property.name),
          initialSelection: property.value ?? property.defaultValue,
          enabled: property.enabled,
          expandedInsets: const EdgeInsets.symmetric(horizontal: 16.0),
          inputDecorationTheme: const InputDecorationTheme(
            border: InputBorder.none,
          ),
          dropdownMenuEntries: property.availableOptions!
            .map((e) => DropdownMenuEntry<T>(
              value: e,
              label: e.toString(),
            ))
            .toList(),
          onSelected: (value) { if (value != null) property.value = value; },
        );
      }
    );
  }
}