import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_social/models/user.dart';
import 'package:flutter_social/pages/create_account.dart';
import 'package:flutter_social/pages/feed.dart';
import 'package:flutter_social/pages/profile.dart';
import 'package:flutter_social/pages/search.dart';
import 'package:flutter_social/pages/timeline.dart';
import 'package:flutter_social/pages/upload.dart';
import 'package:google_sign_in/google_sign_in.dart';

final GoogleSignIn googleSignIn = GoogleSignIn();
final FirebaseAuth firebaseAuth = FirebaseAuth.instance;
final usersRef = Firestore.instance.collection('users');
final postsRef = Firestore.instance.collection('posts');
final commentsRef = Firestore.instance.collection('comments');
final followersRef = Firestore.instance.collection('followers');
final followingRef = Firestore.instance.collection('following');
final activityFeedRef = Firestore.instance.collection('feed');
final timelineRef = Firestore.instance.collection('timeline');
final storageRef = FirebaseStorage.instance.ref();

User currentUser;
final DateTime timestamp = DateTime.now();

class Home extends StatefulWidget {
  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool isAuth = false;
  FirebaseMessaging _firebaseMessaging = FirebaseMessaging();
  PageController pageController;
  int pageIndex = 0;
  
  @override
  void initState() {
    super.initState();
    pageController = PageController();
    googleSignIn.onCurrentUserChanged.listen( (account) async {
      if(account != null){
        await createUserInFirestore();
        setState(() {
          isAuth = true;
        });
        configurePushNotifications();
      }else{
        setState(() {
          isAuth = false;
        });
      }
    }, onError: (err){
      print('Error signing in '+err.toString());
    });

    googleSignIn.signInSilently(suppressErrors: false).then( (account) async {
      if(account != null){
        await createUserInFirestore();
        setState(() {
          isAuth = true;
        });
      }else{
        setState(() {
          isAuth = false;
        });
      }
    }).catchError((err){
      print('Error signing in '+err.toString());
    });
  }

  configurePushNotifications() {
    final GoogleSignInAccount user = googleSignIn.currentUser;
    if(Platform.isIOS){
      getiOSPermission();
    }
    _firebaseMessaging.getToken().then((token) {
      print('Firebase Messaging token: $token\n');
      usersRef.document(user.id).updateData({
        'androidNotificationToken': token
      });
    });

    _firebaseMessaging.configure(
      //onLaunch: (Map<String, dynamic> message) async {},
      //onResume: (Map<String, dynamic> message) async {},
      onMessage: (Map<String, dynamic> message) async {
        print('on message: $message\n');
        final String recipientId = message['data']['recipient'];
        final String body = message['notification']['body'];
        if(recipientId == user.id){
          print('notification shown !');
          SnackBar snackBar = SnackBar(content: Text(body, overflow: TextOverflow.ellipsis,));
          _scaffoldKey.currentState.showSnackBar(snackBar);
        }else{
          print('notification not shown');
        }
      },
    );
  }

  getiOSPermission() {
    _firebaseMessaging.requestNotificationPermissions(IosNotificationSettings(alert: true, badge: true, sound: true));
    _firebaseMessaging.onIosSettingsRegistered.listen((settings) {
      print('Settings registered: $settings');
    });
  }

  @override
  void dispose() {
    super.dispose();
    pageController.dispose();
  }
  
  login() async {
    final GoogleSignInAccount googleUser = await googleSignIn.signIn();
    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final AuthCredential credential = GoogleAuthProvider.getCredential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
    );
    final AuthResult authResult = await firebaseAuth.signInWithCredential(credential);
    final FirebaseUser firebaseUser = authResult.user;
    print('signed in' + firebaseUser.email);
  }
  
  logout() {
    googleSignIn.signOut();
    print('signed out');
  }

  createUserInFirestore() async {
    final GoogleSignInAccount user = googleSignIn.currentUser;
    DocumentSnapshot doc = await usersRef.document(user.id).get();
    if(! doc.exists ){
      String username = await Navigator.push(context, MaterialPageRoute(
          builder: (context) => CreateAccount()
      ));
      if(username == null){
        username = user.displayName;
      }
      usersRef.document(user.id).setData({
        "id": user.id,
        "username": username,
        "photoUrl": user.photoUrl,
        "email": user.email,
        "displayName": user.displayName,
        "bio": "",
        "timestamp": timestamp
      });
      // make new user their own follower ( to include their post in their timeline )
      await followersRef
          .document(user.id)
          .collection('userFollowers')
          .document(user.id)
          .setData({});
      doc = await usersRef.document(user.id).get();
    }
    currentUser = User.fromDocument(doc);
    print(currentUser);
    print(currentUser.username);
  }

  onPageChanged(int pageIndex) {
    setState(() {
      this.pageIndex = pageIndex;
    });
  }

  onTap(int pageIndex) {
    pageController.animateToPage(pageIndex, duration: Duration(milliseconds: 500), curve: Curves.easeOut);
  }

  Scaffold buildAuthScreen() {
    return Scaffold(
      key: _scaffoldKey,
      body: PageView(
        children: <Widget>[
          TimeLine(currentUser: currentUser),
          ActivityFeed(),
          Upload(currentUser: currentUser),
          Search(),
          Profile(profileId: currentUser?.id),
        ],
        controller: pageController,
        onPageChanged: onPageChanged,
        physics: NeverScrollableScrollPhysics(),
      ),
      bottomNavigationBar: CupertinoTabBar(
        currentIndex: pageIndex,
        onTap: onTap,
        activeColor: Theme.of(context).primaryColor,
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.whatshot)),
          BottomNavigationBarItem(icon: Icon(Icons.notifications_active, size: 35.0,)),
          BottomNavigationBarItem(icon: Icon(Icons.photo_camera)),
          BottomNavigationBarItem(icon: Icon(Icons.search)),
          BottomNavigationBarItem(icon: Icon(Icons.account_circle)),
        ],
      )
    );
  }

  Scaffold buildUnAuthScreen() {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              Theme.of(context).accentColor,Theme.of(context).primaryColor
            ]
          )
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Text('FlutterSocial',style: TextStyle(fontSize: 90.0, fontFamily: 'Signatra', color: Colors.white),),
            InkWell(
              onTap: login,
              child: Container(
                width: 260.0,
                height: 60.0,
                decoration: BoxDecoration(
                  image: DecorationImage(image: AssetImage('assets/google_signin_button.png'), fit: BoxFit.cover),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return isAuth ? buildAuthScreen() : buildUnAuthScreen();
  }
}
