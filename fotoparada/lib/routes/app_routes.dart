import 'package:flutter/material.dart';
import 'package:fotoparada/view/Map/map_full_screen_view.dart';
import 'package:fotoparada/viewmodel/map_viewmodel.dart';

import '../models/checkin_model.dart';
import '../models/coleccion_model.dart';
import '../models/foto_model.dart';
import '../models/reto_model.dart';
import '../view/challenge_detail_view.dart';
import '../view/challenges_view.dart';
import '../view/checkin_view.dart';
import '../view/collection_detail_view.dart';
import '../view/compare_photos_view.dart';
import '../view/timeline_view.dart';
import '../viewmodel/compare_photos_viewmodel.dart';
import '../view/create_challenge_view.dart';
import '../view/edit_photo_view.dart';
import '../view/forgot_password_view.dart';
import '../view/login_view.dart';
import '../view/main_view.dart';
import '../view/my_photos_view.dart';
import '../view/photo_interactions_view.dart';
import '../view/location_detail_view.dart';
import '../view/register_view.dart';
import '../view/share_location_view.dart';
import '../view/upload_photo_view.dart';
import '../viewmodel/share_location_viewmodel.dart';

class AppRoutes {
  AppRoutes._();

  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String main = '/main';
  static const String fullScreenMap = '/fullScreenMap';
  static const String upload = '/upload';
  static const String myPhotos = '/my-photos';
  static const String editPhoto = '/edit-photo';
  static const String photoInteractions = '/photo-interactions';
  static const String shareLocation = '/share-location';
  static const String checkIn = '/check-in';
  static const String challenges = '/challenges';
  static const String challengeDetail = '/challenge-detail';
  static const String createChallenge = '/create-challenge';
  static const String locationDetail = '/location-detail';
  // Integrante 4 - Recuerdos y organización
  static const String timeline = '/timeline';
  static const String comparePhotos = '/compare-photos';
  static const String collectionDetail = '/collection-detail';

  static final Map<String, WidgetBuilder> routes = {
    login: (context) => const LoginView(),
    register: (context) => const RegisterView(),
    forgotPassword: (context) => const ForgotPasswordView(),
    main: (context) => const MainView(),
    upload: (context) => const UploadPhotoView(),
    myPhotos: (context) => const MyPhotosView(),
    editPhoto: (context) => EditPhotoView(
      foto: ModalRoute.of(context)!.settings.arguments as Foto,
    ),
    fullScreenMap: (context) => MapFullScreenView(
      mapViewModel: ModalRoute.of(context)!.settings.arguments as MapViewModel,
    ),
    photoInteractions: (context) => PhotoInteractionsView(
      foto: ModalRoute.of(context)!.settings.arguments as Foto,
    ),
    shareLocation: (context) => ShareLocationView(
      args: ModalRoute.of(context)!.settings.arguments as ShareLocationArgs,
    ),
    // Sin argumento muestra solo el historial de check-ins.
    checkIn: (context) => CheckInView(
      lugar: ModalRoute.of(context)!.settings.arguments as LugarCheckIn?,
    ),
    challenges: (context) => const ChallengesView(),
    challengeDetail: (context) => ChallengeDetailView(
      reto: ModalRoute.of(context)!.settings.arguments as Reto,
    ),
    createChallenge: (context) => const CreateChallengeView(),
    // Recibe un Lugar (fotos cercanas) o solo el nombre del lugar.
    locationDetail: (context) {
      final args = ModalRoute.of(context)!.settings.arguments;
      return args is Lugar
          ? LocationDetailView.desdeLugar(args)
          : LocationDetailView(nombreLugar: args as String);
    },
    // Recibe un Lugar (nombre + coordenadas) o solo el nombre del lugar.
    timeline: (context) {
      final args = ModalRoute.of(context)!.settings.arguments;
      return args is Lugar
          ? TimelineView.desdeLugar(args)
          : TimelineView(nombreLugar: args as String);
    },
    comparePhotos: (context) => ComparePhotosView(
      args: ModalRoute.of(context)!.settings.arguments as ComparePhotosArgs,
    ),
    collectionDetail: (context) => CollectionDetailView(
      coleccion: ModalRoute.of(context)!.settings.arguments as Coleccion,
    ),
  };
}
