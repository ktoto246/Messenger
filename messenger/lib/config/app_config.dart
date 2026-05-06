class AppConfig {
  // 🚀 Централизованный конфиг. При деплое менять только тут!
  static const String baseUrl = 'http://localhost:5121/api'; 
  static const String hubUrl = 'http://localhost:5121/chatHub';
  static const String callHubUrl = 'http://localhost:5121/callHub';
  static const String giphyApiKey = 'YOUR_GIPHY_API_KEY';
  static const String googleMapsApiKey = 'YOUR_GOOGLE_MAPS_API_KEY';
}
