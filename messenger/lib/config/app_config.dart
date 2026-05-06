class AppConfig {
  // 🚀 Централизованный конфиг. При деплое менять только тут!
  // ⚠️ ВАЖНО: localhost работает только в эмуляторе Android!
  // На реальном устройстве замените на IP/домен сервера (напр. http://192.168.x.x:5121/api)
  static const String baseUrl = 'http://localhost:5121/api';
  static const String hubUrl = 'http://localhost:5121/chatHub';
  static const String callHubUrl = 'http://localhost:5121/callHub';
  // ⚠️ Замените на реальные ключи перед релизом!
  static const String giphyApiKey = 'YOUR_GIPHY_API_KEY';
  static const String googleMapsApiKey = 'YOUR_GOOGLE_MAPS_API_KEY';
}
