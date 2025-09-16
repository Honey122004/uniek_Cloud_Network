import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Register platform-specific WebView implementation
  if (Platform.isAndroid) {
    WebViewPlatform.instance = AndroidWebViewPlatform();
  } else if (Platform.isIOS) {
    WebViewPlatform.instance = WebKitWebViewPlatform();
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: WebViewPage(),
    );
  }
}

//
// Splash Screen
//
// class SplashScreen extends StatefulWidget {
//   const SplashScreen({super.key});
//
//   @override
//   State<SplashScreen> createState() => _SplashScreenState();
// }
//
// class _SplashScreenState extends State<SplashScreen> {
//   @override
//   void initState() {
//     super.initState();
//
//     // Navigate after 3s
//     Timer(const Duration(seconds: 3), () {
//       Navigator.pushReplacement(
//         context,
//         MaterialPageRoute(builder: (context) => const WebViewPage()),
//       );
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return const Scaffold(
//       body: Center(
//         child: Text(
//           "Welcome to My WebView App",
//           style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
//         ),
//       ),
//     );
//   }
// }

//
// WebView Page
//
class WebViewPage extends StatefulWidget {
  const WebViewPage({super.key});

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  late final WebViewController _controller;
  final String websiteUrl = "https://uniek.in/";

  @override
  void initState() {
    super.initState();

    // Params depend on platform
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final controller =
    WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(

            onNavigationRequest: (NavigationRequest request) async {
              final url = request.url;

              if (url.startsWith("mailto:")) {
                final uri = Uri.parse(url);

                // Encode subject and body so spaces/special chars are preserved
                final subject = Uri.encodeComponent(uri.queryParameters['subject'] ?? 'Hello');
                final body = Uri.encodeComponent(uri.queryParameters['body'] ?? 'This is a test email');

                // Default mailto: URI (works with most apps)
                final emailUri = Uri.parse(
                  "mailto:${uri.path}?subject=$subject&body=$body",
                );

                // Gmail-specific fallback
                final gmailUri = Uri.parse(
                  "googlegmail://co?to=${uri.path}&subject=$subject&body=$body",
                );

                try {
                  final launched = await launchUrl(
                    emailUri,
                    mode: LaunchMode.externalApplication,
                  );

                  if (!launched) {
                    await launchUrl(gmailUri, mode: LaunchMode.externalApplication);
                  }
                } catch (e) {
                  debugPrint("Email error: $e");
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("No email app found")),
                  );
                }

                return NavigationDecision.prevent;
              }


              if (url.startsWith("tel:")) {
                await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                return NavigationDecision.prevent;
              }

              // 💬 WhatsApp
              if (url.startsWith("whatsapp:") || url.startsWith("whatsapp://")) {
                final whats = Uri.parse(url);
                if (await canLaunchUrl(whats)) {
                  await launchUrl(whats, mode: LaunchMode.externalApplication);
                } else {
                  // fallback to web
                  final fallback = Uri.parse("https://wa.me/911234567890?text=Hello");
                  await launchUrl(fallback, mode: LaunchMode.externalApplication);
                }
                return NavigationDecision.prevent;
              }

              // Handle wa.me links (many sites use this)
              if (url.contains("wa.me") || url.contains("api.whatsapp.com")) {
                final whats = Uri.parse(url.replaceFirst("https://wa.me", "whatsapp://send")
                    .replaceFirst("https://api.whatsapp.com/send", "whatsapp://send"));

                if (await canLaunchUrl(whats)) {
                  await launchUrl(whats, mode: LaunchMode.externalApplication);
                } else {
                  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                }
                return NavigationDecision.prevent;
              }


              // 📱 SMS
              if (url.startsWith("sms:")) {
                await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                return NavigationDecision.prevent;
              }

              // 📍 Maps / geo:
              if (url.startsWith("geo:")) {
                await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                return NavigationDecision.prevent;
              }

              // 🌐 Intent or Play Store links
              if (url.startsWith("intent:") || url.contains("play.google.com")) {
                await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                return NavigationDecision.prevent;
              }

              return NavigationDecision.navigate;
            }

        ),
      )
      ..loadRequest(Uri.parse("https://uniek.in/"));

    if (!kIsWeb && Platform.isAndroid) {
      AndroidWebViewController.enableDebugging(true);
      (controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }

    _controller = controller;
  }




  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (await _controller.canGoBack()) {
          _controller.goBack();
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea( // ✅ use SafeArea here
          child: Padding(
            padding: const EdgeInsets.only(top: 10), // extra space if needed
            child: Column(
              children: [
                Expanded(
                  child: WebViewWidget(controller: _controller),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }







}
