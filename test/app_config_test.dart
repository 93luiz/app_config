import 'package:app_config/app_config.dart';
import 'package:test/test.dart';

class MyAppConfig extends AppConfig {
  Property<bool> get devMode => property<bool>(
    name: 'dev_mode',
    defaultValue: false,
  );
  Property<bool> get validatePlatform => property<bool>(
    name: 'validate_platform',
    defaultValue: true,
  );

  get prod => createConfig({
    devMode.withValue().fixed(false),
    validatePlatform.withValue().fixed(true),
  });

  get beta => createConfig({
    devMode.withValue().userDefined(),
    validatePlatform.withValue().userDefined(),
  });
}
void main() {
  group('A group of tests', () {

    setUp(() {
      // Additional setup goes here.
    });

    test('First Test', () {
      final config = MyAppConfig();
      config.activateConfig(config.beta);
      final bool coisa = config.devMode.value;

      expect(coisa, isFalse);

      config.devMode.value = true;
      expect(config.devMode.value, isTrue);
      config.devMode.value = false;
      expect(config.devMode.value, isFalse);
    });
  });
}
