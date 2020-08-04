import 'dart:async';

import 'package:animator/animator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_social/models/user.dart';
import 'package:flutter_social/pages/comments.dart';
import 'package:flutter_social/pages/feed.dart';
import 'package:flutter_social/pages/home.dart';
import 'package:flutter_social/widgets/custom_image.dart';
import 'package:flutter_social/widgets/progress.dart';

class Post extends StatefulWidget {

  final String postId;
  final String ownerId;
  final String username;
  final String location;
  final String description;
  final String mediaUrl;
  final dynamic likes;

  Post({this.postId, this.ownerId, this.username, this.location, this.description, this.mediaUrl, this.likes}) ;

  factory Post.fromDocument(DocumentSnapshot doc){
    return Post(
      postId: doc['postId'],
      ownerId: doc['ownerId'],
      username: doc['username'],
      location: doc['location'],
      description: doc['description'],
      mediaUrl: doc['mediaUrl'],
      likes: doc['likes'],
    );
  }

  int getLikesCount(likes) {
    if(likes == null){
      return 0;
    }
    int count = 0;
    likes.values.forEach((val) => {
      if(val == true){
        count = count + 1
      }
    });
    return count;
  }

  @override
  _PostState createState() => _PostState(
    postId: this.postId,
    ownerId: this.ownerId,
    username: this.username,
    location: this.location,
    description: this.description,
    mediaUrl: this.mediaUrl,
    likesCount: getLikesCount(this.likes),
    likes: this.likes
  );
}

class _PostState extends State<Post> {

  String currentUserId = currentUser?.id;

  final String postId;
  final String ownerId;
  final String username;
  final String location;
  final String description;
  final String mediaUrl;
  bool isLiked;
  bool showHeart = false;
  int likesCount;
  Map likes;

  _PostState({this.postId, this.ownerId, this.username, this.location, this.description, this.mediaUrl, this.likesCount, this.likes}) ;

  @override
  Widget build(BuildContext context) {

    isLiked = (likes[currentUserId] == true);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        buildPostHeader(),
        buildPostImage(),
        buildPostFooter(),
      ],
    );
  }

  buildPostHeader() {
    return FutureBuilder(
      future: usersRef.document(ownerId).get(),
      builder: (context, snapshot){
        if(! snapshot.hasData ){
          return circularProgress();
        }
        User user = User.fromDocument(snapshot.data);
        bool isPostOwner = currentUserId == ownerId;
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.grey,
            backgroundImage: NetworkImage(user.photoUrl),
          ),
          title: GestureDetector(
            child: Text(user.username,style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),),
            onTap: () => showProfile(context, profileId: user.id),
          ),
          subtitle: Text(location),
          trailing: isPostOwner ? IconButton(icon: Icon(Icons.more_vert), onPressed: () => handleDeletePost(context),) : Text(''),
        );
      },
    );
  }

  deletePost() async {
    postsRef
        .document(ownerId)
        .collection('userPosts')
        .document(postId)
        .get()
        .then((doc) {
          if(doc.exists){
            doc.reference.delete();
          }
        });
    storageRef.child('post_$postId.jpg').delete();
    QuerySnapshot activityFeedSnapshot = await activityFeedRef
        .document(ownerId)
        .collection('feedItems')
        .where('postId', isEqualTo: postId)
        .getDocuments();
    activityFeedSnapshot.documents.forEach((doc) {
      if(doc.exists){
        doc.reference.delete();
      }
    });
    QuerySnapshot commentSnapshot = await commentsRef.document(postId).collection('comments').getDocuments();
    commentSnapshot.documents.forEach((doc) {
      if(doc.exists){
        doc.reference.delete();
      }
    });
  }

  handleDeletePost(BuildContext parentContext) {
    return showDialog(
      context: parentContext,
      builder: (context){
        return SimpleDialog(
          title: Text('Remove this post ?'),
          children: <Widget>[
            SimpleDialogOption(
              onPressed: (){
                Navigator.pop(context);
                deletePost();
              },
              child: Text('Delete', style: TextStyle(color: Colors.red),),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
          ],
        );
      }
    );
  }

  handleLikePost() {
    bool _isLiked = likes[currentUserId] == true;
    if(_isLiked){
      postsRef
      .document(ownerId)
      .collection('userPosts')
      .document(postId)
      .updateData({ 'likes.$currentUserId' : false });
      removeLikeFromActivityFeed();
      setState(() {
        likesCount -= 1;
        isLiked = false;
        likes[currentUserId] = false;
      });
    }else if(! _isLiked ){
      postsRef
          .document(ownerId)
          .collection('userPosts')
          .document(postId)
          .updateData({ 'likes.$currentUserId' : true });
      addLikeToActivityFeed();
      setState(() {
        likesCount += 1;
        showHeart = true;
        isLiked = true;
        likes[currentUserId] = true;
      });
      Timer(Duration(milliseconds: 500), () {
        setState(() {
          showHeart = false;
        });
      });
    }
  }

  addLikeToActivityFeed() {
    bool isNotPostOwner = currentUserId != ownerId;
    if(isNotPostOwner){
      activityFeedRef.document(ownerId).collection('feedItems').document(postId).setData({
        'type': 'like',
        'username': currentUser.username,
        'userId': currentUser.id,
        'userProfileImg': currentUser.photoUrl,
        'postId': postId,
        'mediaUrl': mediaUrl,
        'timestamp': timestamp
      });
    }
  }

  removeLikeFromActivityFeed() {
    bool isNotPostOwner = currentUserId != ownerId;
    if (isNotPostOwner){
      activityFeedRef.document(ownerId).collection('feedItems').document(postId).get().then((doc) {
        if(doc.exists){
          doc.reference.delete();
        }
      });
    }
  }

  buildPostImage() {
    return GestureDetector(
      onDoubleTap: () => handleLikePost,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          cachedNetworkImage(mediaUrl),
          showHeart ?
          Animator(
            duration: Duration(milliseconds: 400),
            tween: Tween(begin: 0.8, end: 1.4),
            curve: Curves.elasticOut,
            cycles: 0,
            builder: (context, anim, child) => Transform.scale(
              scale: anim.value, 
              child: Icon(Icons.favorite, color: Colors.redAccent, size: 80.0,),
            )
          )
           : Text(''),
        ],
      ),
    );
  }

  buildPostFooter() {
    return Column(
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.only(top: 40.0, left: 20.0),
            ),
            GestureDetector(
              child: Icon(
                isLiked ? Icons.favorite : Icons.favorite_border,
                size: 28.0,
                color: Colors.pink,
              ),
              onTap: handleLikePost,
            ),
            Padding(
              padding: EdgeInsets.only(left: 20.0),
            ),
            GestureDetector(
              child: Icon(
                Icons.chat,
                size: 28.0,
                color: Colors.blue[900],
              ),
              onTap: () => showComments(
                context,
                postId: postId,
                ownerId: ownerId,
                mediaUrl: mediaUrl
              ),
            )
          ],
        ),
        Row(
          children: <Widget>[
            Container(
              margin: EdgeInsets.only(left: 20.0),
              child: Text(
                '$likesCount likes',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
            )
          ],
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              margin: EdgeInsets.only(left: 20.0),
              child: Text(
                '$username ',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(child: Text(description)),
          ],
        )
      ],
    );
  }

}

showComments(BuildContext context, {String postId, String ownerId, String mediaUrl}) {
  Navigator.push(context, MaterialPageRoute(
      builder: (context) => Comments(postId: postId, postOwnerId: ownerId, postMediaUrl: mediaUrl, )
  ));
}
