class FritzBoxConfig {
  const FritzBoxConfig({this.baseUrl = 'http://fritz.box', this.username, required this.password});

  final String baseUrl;
  final String? username;
  final String password;
}