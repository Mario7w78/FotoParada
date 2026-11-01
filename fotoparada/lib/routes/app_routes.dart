import 'package:flutter/material.dart';
import 'package:fotoparada/view/Map/map_full_screen_view.dart';
import 'package:fotoparada/viewmodel/map_viewmodel.dart';

import '../view/forgot_password_view.dart';
import '../view/login_view.dart';
import '../view/main_view.dart';
import '../view/register_view.dart';
import '../view/upload_photo_view.dart';

class AppRoutes {
  AppRoutes._();

  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String main = '/main';
  static const String fullScreenMap = '/fullScreenMap';
  static const String upload = '/upload';

  static final Map<String, WidgetBuilder> routes = {
    login: (context) => const LoginView(),
    register: (context) => const RegisterView(),
    forgotPassword: (context) => const ForgotPasswordView(),
    main: (context) => const MainView(),
    upload: (context) => const UploadPhotoView(),
    fullScreenMap: (context) => MapFullScreenView(
      mapViewModel: ModalRoute.of(context)!.settings.arguments as MapViewModel,
    ),
  };
}
