import 'package:get/get.dart';

/// Deliberately thin: the home page is demo-shell chrome, not part of the
/// portable feature. It only knows how to navigate to routes it is given.
class HomeController extends GetxController {
  void openRoute(String routeName) => Get.toNamed(routeName);
}
