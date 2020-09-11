import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
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
  List<UserResult> userResults;


  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    initialize();
  }

  void initialize() async {
    await getFollowing();
    await getUsersToFollow();
    await getTimeLine();
  }

  getUsersToFollow() async {
    QuerySnapshot snapshot = await usersRef.getDocuments();

    List<UserResult> userResults = [];
    snapshot.documents.map((doc){
      User user = User.fromDocument(doc);
      final bool isAuthUser = currentUser.id == user.id;
      final bool isFollowingUser = followingList.contains(user.id);
      if((! isAuthUser) && (! isFollowingUser)){
        UserResult userResult = UserResult(user);
        userResults.add(userResult);
      }
    }).toList();
    setState(() {
      this.userResults = userResults;
    });
  }

  getFollowing() async {
    QuerySnapshot snapshot = await followingRef
        .document(widget.currentUser.id)
        .collection('userFollowing')
        .getDocuments();
    setState(() {
      followingList = snapshot.documents.map((doc) => doc.documentID).toList();
    });
  }

  Future<void> getTimeLine() async {
    for(int i = 0; i < followingList.length; i++){
      await getPostsForTimeline(followingList[i]);
    }
  }

  getPostsForTimeline(String followingId) async {
    QuerySnapshot querySnapshot = await postsRef
        .document(followingId)
        .collection('userPosts')
        .orderBy('timestamp', descending: true)
        .getDocuments();
    List <Post> followingPosts = querySnapshot.documents.map((doc) => Post.fromDocument(doc)).toList();
    List<Post> posts = this.posts;
    if(posts == null) {
      posts = followingPosts;
    }else {
      posts.addAll(followingPosts);
    }
    setState(() {
      this.posts = posts;
    });
  }

  buildTimeLine() {
    if(posts == null && userResults == null){
      return circularProgress();
    }else if(posts == null){
      return buildUsersToFollow();
    }
    posts.sort(
            (a,b){
              return DateTime.parse(a.timestamp.toString()).toString().compareTo(DateTime.parse(b.timestamp.toString()).toString());
            }
    );

    return ListView(children: posts);
  }

  buildUsersToFollow() {
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
              Column(children: userResults)
            ]
        )
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
