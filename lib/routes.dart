class Routes {
  static const login = '/login';
  static const register = '/register';
  static const setup = '/setup'; // arguments: true = โหมดแก้ไขจากหน้าอื่น
  static const home = '/home';
  static const activityForm = '/activity'; // arguments: String? activityId
  static const askAi = '/ask-ai';
  static const aiLoading = '/ai-loading';
  static const options = '/options';
  static const recommendation = '/recommendation'; // arguments: String optionCode
  static const adjust = '/adjust'; // arguments: String optionCode
  static const notifications = '/notifications';
  static const track = '/track'; // arguments: String activityId
  static const history = '/history';
  static const profile = '/profile';
  static const admin = '/admin';
}
