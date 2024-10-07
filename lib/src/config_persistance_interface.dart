abstract interface class ConfigPersistanceInterface {

  Future<void> saveCongif(Map<String,dynamic> json);

  Future<Map<String,dynamic>?> loadConfig();

}