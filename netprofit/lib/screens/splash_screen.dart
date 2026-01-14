import 'dart:async';
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'login_screen.dart';
import '../widgets/fish_animation.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(Duration(seconds: 5), () {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => LoginScreen()));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/splash-bg.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: Stack(
          children: [
            // Animated Swimming Fish
            SwimmingFish(fishImage: 'assets/fish1.png'),
            SwimmingFish(fishImage: 'assets/fish2.png'),
            SwimmingFish(fishImage: 'assets/fish3.png'),
            SwimmingFish(fishImage: 'assets/fish4.png'),
            
            // Content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
              ZoomIn(
                duration: Duration(seconds: 5),
                manualTrigger: false,
                child: Pulse(
                  duration: Duration(seconds: 3),
                  infinite: true,
                  child: Image.asset('assets/logo-rounded.png', width: 200),
                ),
              ),
              SizedBox(height: 20),
              Text(
                "Rukmal Fish Delivery",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: const Color.fromARGB(255, 255, 255, 255)),
              ),
            ],
          ),
            ),
          ],
        ),
      ),
    );
  }
}