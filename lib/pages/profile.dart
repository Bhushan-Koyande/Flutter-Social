import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_social/models/user.dart';
import 'package:flutter_social/pages/edit_profile.dart';
import 'package:flutter_social/pages/home.dart';
import 'package:flutter_social/widgets/header.dart';
import 'package:flutter_social/widgets/post.dart';
import 'package:flutter_social/widgets/post_tile.dart';
import 'package:flutter_social/widgets/progress.dart';
import 'package:flutter_svg/flutter_svg.dart';

class Profile extends StatefulWidget {

  final String profileId;

  Profile({this.profileId});

  @override
  _ProfileState createState() => _ProfileState();
}

class _ProfileState extends State<Profile> {

  final String currentUserId = currentUser?.id;
  bool isFollowing = false;
  String postOrientation = 'grid';
  bool isLoading = false;
  int postCount = 0;
  int followerCount = 0;
  int followingCount = 0;
  List<Post> posts = [];

  @override
  void initState() {
    super.initState();
    getProfilePosts();
    getFollowers();
    getFollowing();
    checkIfFollowing();
  }

  getProfilePosts() async {
    setState(() {
      isLoading = true;
    });
    QuerySnapshot snapshot = await postsRef
                                        .document(widget.profileId)
                                        .collection('userPosts')
                                        .orderBy('timestamp', descending: true)
                                        .getDocuments();
    setState(() {
      isLoading = false;
      postCount = snapshot.documents.length;
      posts = snapshot.documents.map((doc) => Post.fromDocument(doc)).toList();
    });
  }

  Column buildCountColumn(String label, int count) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Text(count.toString(),style: TextStyle(fontSize: 22.0, fontWeight: FontWeight.bold),),
        Container(
          margin: EdgeInsets.only(top: 4.0),
          child: Text(label, style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w400, fontSize: 15.0),),
        )
      ],
    );
  }

  editProfile() {
    Navigator.push(context, MaterialPageRoute(
        builder: (context) => EditProfile(currentUserId: currentUserId)
    ));
  }

  Container buildButton({ String text, Function function }) {
    return Container(
      padding: EdgeInsets.only(top: 2.0),
      child: FlatButton(
          onPressed: function,
          child: Container(
            width: 250.0,
            height: 27.0,
            child: Text(text, style: TextStyle(color: isFollowing ? Colors.black : Colors.white, fontWeight: FontWeight.bold),),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isFollowing ? Colors.white : Colors.blue,
              border: Border.all(
                color: isFollowing ? Colors.grey : Colors.blue,
              ),
              borderRadius: BorderRadius.circular(5.0),
            ),
          ),
      ),
    );
  }

  buildProfileButton() {
    bool isProfileOwner = currentUserId == widget.profileId;
    if(isProfileOwner){
      return buildButton(text: 'Edit Profile', function: editProfile);
    }else if(isFollowing){
      return buildButton(text: 'Unfollow', function: handleUnfollowUser);
    }else if (! isFollowing){
      return buildButton(text: 'Follow', function: handleFollowUser);
    }
  }

  handleUnfollowUser() {
    setState(() {
      isFollowing = false;
    });
    // Handle un-Follower
    followersRef
        .document(widget.profileId)
        .collection('userFollowers')
        .document(currentUserId)
        .get().then((doc) => {
          if(doc.exists){
            doc.reference.delete()
          }
        });
    // Handle un-Following
    followingRef
        .document(currentUserId)
        .collection('userFollowing')
        .document(widget.profileId)
        .get().then((doc) => {
          if(doc.exists){
            doc.reference.delete()
          }
        });
    // Remove posts from TimeLine
    //deletePostsFromTimeline();
  }

  handleFollowUser() {
    setState(() {
      isFollowing = true;
    });
    // Handle Follower
    followersRef
        .document(widget.profileId)
        .collection('userFollowers')
        .document(currentUserId).setData({});
    // Handle Following
    followingRef
        .document(currentUserId)
        .collection('userFollowing')
        .document(widget.profileId).setData({});
    //Add activity feed notification
    activityFeedRef
        .document(widget.profileId)
        .collection('feedItems')
        .document(currentUserId)
        .setData({
          'type': 'follow',
          'ownerId': widget.profileId,
          'username': currentUser.username,
          'userId': currentUser.id,
          'userProfileImg': currentUser.photoUrl,
          'timestamp': timestamp
        });
    // Add posts to TimeLine
    //addPostsToTimeline();
  }

  buildProfileHeader() {
    return FutureBuilder(
      future: usersRef.document(widget.profileId).get(),
      builder: (context, snapshot){
        if(! snapshot.hasData ){
          return circularProgress();
        }
        User user = User.fromDocument(snapshot.data);
        return Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  CircleAvatar(
                    radius: 40.0,
                    backgroundColor: Colors.grey,
                    backgroundImage: NetworkImage(user.photoUrl),
                  ),
                  Expanded(
                    flex: 1,
                    child: Column(
                      children: <Widget>[
                        Row(
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: <Widget>[
                            buildCountColumn('posts', postCount),
                            buildCountColumn('followers', followerCount),
                            buildCountColumn('following', followingCount),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: <Widget>[
                            buildProfileButton(),
                          ],
                        )
                      ],
                    ),
                  )
                ],
              ),
              Container(
                alignment: Alignment.centerLeft,
                padding: EdgeInsets.only(top: 12.0),
                child: Text(user.username, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0,),),
              ),
              Container(
                alignment: Alignment.centerLeft,
                padding: EdgeInsets.only(top: 4.0),
                child: Text(user.displayName, style: TextStyle(fontWeight: FontWeight.bold,),),
              ),
              Container(
                alignment: Alignment.centerLeft,
                padding: EdgeInsets.only(top: 2.0),
                child: Text(user.bio,),
              )
            ],
          ),
        );
      },
    );
  }

  buildProfilePosts() {
    if(isLoading){
      return circularProgress();
    }else if (posts.isEmpty) {
      return Container(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            SvgPicture.asset('assets/no_content.svg', height: 260.0,),
            Padding(
              padding: EdgeInsets.only(top: 20.0),
              child: Text(
                  'No Posts',
                   style: TextStyle(
                     color: Colors.redAccent,
                     fontSize: 40.0,
                     fontWeight: FontWeight.bold,
                   ),
              )
            )
          ],
        ),
      );
    }else if(postOrientation == 'grid') {
      List<GridTile> gridTiles = [];
      posts.forEach((post) {
        gridTiles.add(GridTile(child: PostTile(post: post,)));
      });
      return GridView.count(
        crossAxisCount: 3,
        childAspectRatio: 1.0,
        mainAxisSpacing: 1.5,
        crossAxisSpacing: 1.5,
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        children: gridTiles,
      );
    }else if(postOrientation == 'list'){
      return Column(
        children: posts,
      );
    }
  }

  setPostOrientation(String orientation) {
    setState(() {
      postOrientation = orientation;
    });
  }

  buildTogglePostOrientation() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        IconButton(
              icon: Icon(Icons.grid_on,
              color: postOrientation == 'grid' ? Theme.of(context).primaryColor : Colors.grey ),
              onPressed: () => setPostOrientation('grid'),
        ),
        IconButton(
          icon: Icon(Icons.list,
              color: postOrientation == 'list' ? Theme.of(context).primaryColor : Colors.grey ),
          onPressed: () => setPostOrientation('list'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: header(context, titleText: 'Profile'),
      body: ListView(
        children: <Widget>[
          buildProfileHeader(),
          Divider(height: 0.0,),
          buildTogglePostOrientation(),
          Divider(height: 0.0,),
          buildProfilePosts(),
        ],
      )
    );
  }

  void checkIfFollowing() async {
    DocumentSnapshot doc =await followersRef
        .document(widget.profileId)
        .collection('userFollowers')
        .document(currentUserId).get();
    setState(() {
      isFollowing = doc.exists;
    });
  }

  void getFollowers() async {
    QuerySnapshot snapshot = await followersRef.document(widget.profileId).collection('userFollowers').getDocuments();
    setState(() {
      followerCount = snapshot.documents.length;
    });
  }

  void getFollowing() async {
    QuerySnapshot snapshot = await followingRef.document(widget.profileId).collection('userFollowing').getDocuments();
    setState(() {
      followingCount = snapshot.documents.length;
    });
  }

  void addPostsToTimeline() async {
    QuerySnapshot postsToAdd = await postsRef.document(widget.profileId).collection('userPosts').getDocuments();
    postsToAdd.documents.map((doc) {
      timelineRef.document(currentUser.id).collection('timelinePosts').document(doc.documentID).setData(doc.data);
    });
  }

  void deletePostsFromTimeline() async {
    QuerySnapshot postsToDelete = await timelineRef.document(currentUserId).collection('timelinePosts').where('ownerId', isEqualTo: widget.profileId).getDocuments();
    postsToDelete.documents.map((doc) {
      if (doc.exists){
        doc.reference.delete();
      }
    });
  }

}
