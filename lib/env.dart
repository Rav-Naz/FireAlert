// lib/env.dart
import 'package:envied/envied.dart';

part 'env.g.dart';

@Envied(path: '.env')
abstract class MyEnv {
  @EnviedField(varName: 'API_URL')
  static const String API_URL = _MyEnv.API_URL;
  @EnviedField(varName: 'MAP_URL')
  static const String MAP_URL = _MyEnv.MAP_URL;
  @EnviedField(varName: 'MAP_ACCESS_TOKEN')
  static const String MAP_ACCESS_TOKEN = _MyEnv.MAP_ACCESS_TOKEN;
}
