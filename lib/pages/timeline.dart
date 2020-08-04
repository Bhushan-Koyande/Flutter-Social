import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_social/models/user.dart';
import 'package:flutter_social/pages/home.dart';
import 'package:flutter_social/pages/search.dart';
import 'package:flutter_social/widgets/header.dart';
import 'package:flutter_social/widgets/post.dart';
import 'package:flutter_social/widgets/progress.dart';

class TimeLine extends StatefulWidget {

  final User currentUser;

  TimeLine({this.currentUser}) ;

  @override
  _TimeLineState createState() => _TimeLineState();
}

class _TimeLineState extends State<TimeLine> {

  List<Post> posts;
  List<String> followingList;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    getTimeLine();
    getFollowing();
  }

  getFollowing() async {
    QuerySnapshot snapshot = await followingRef
        .document(currentUser.id)
        .collection('userFollowing')
        .getDocuments();
    setState(() {
      followingList = snapshot.documents.map((doc) => doc.documentID).toList();
    });
  }

  getTimeLine() async {
    QuerySnapshot snapshot =await timelineRef
        .document(widget.currentUser.id)
        .collection('timelinePosts')
        .orderBy('timestamp', descending: true)
        .getDocuments();

    List<Post> posts = snapshot.documents.map((doc) => Post.fromDocument(doc)).toList();
    setState(() {
      this.posts = posts;
    });
  }

  buildTimeLine() {
    if(posts == null){
      return circularProgress();
    }else if(posts.isEmpty){
      return buildUsersToFollow();
    }
    return ListView(children: posts);
  }

  buildUsersToFollow() {
    return StreamBuilder(
      stream: usersRef.orderBy('timestamp', descending: true).limit(20).snapshots(),
      builder: (context, snapshot) {
        if(! snapshot.hasData ) {
          circularProgress();
        }
        List<UserResult> userResults = [];
        snapshot.data.documents.map((doc){
          User user = User.fromDocument(doc);
          final bool isAuthUser = currentUser.id == user.id;
          final bool isFollowingUser = followingList.contains(user.id);
          if(isAuthUser){
            return;
          }else if(isFollowingUser){
            return;
          }else{
            UserResult userResult =UserResult(user);
            userResults.add(userResult);
          }
        });
        return Container(
          color: Theme.of(context).accentColor.withOpacity(0.2),
          child: Column(
            children: <Widget>[
              Container(
                padding: EdgeInsets.all(12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      Icons.person_add,
                      color: Theme.of(context).primaryColor,
                      size: 30.0,
                    ),
                    SizedBox(width: 8.0,),
                    Text('Users to follow', style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 30.0),),
                  ],
                ),
              ),
              Column(children: userResults),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: header(context, isAppTitle: true),
      body: RefreshIndicator(
        onRefresh: () => getTimeLine(),
        child: buildTimeLine(),
      )
    );
  }
}