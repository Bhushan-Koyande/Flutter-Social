import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_social/models/user.dart';
import 'package:flutter_social/pages/home.dart';
import 'package:flutter_social/widgets/progress.dart';

class EditProfile extends StatefulWidget {

  final String currentUserId;

  EditProfile({this.currentUserId});

  @override
  _EditProfileState createState() => _EditProfileState();
}

class _EditProfileState extends State<EditProfile> {

  bool loading = false;
  User user;
  TextEditingController displayNameController = TextEditingController();
  TextEditingController bioController = TextEditingController();
  bool _displayNameValid = true;
  bool _bioValid = true;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    getUser();
  }

  getUser() async {
    setState(() {
      loading = true;
    });
    DocumentSnapshot doc = await usersRef.document(widget.currentUserId).get();
    user = User.fromDocument(doc);
    displayNameController.text = user.displayName;
    bioController.text = user.bio;
    setState(() {
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        backgroundColor: Colors.white,
        centerTitle: true,
        title: Text(
          'Edit Profile',
          style: TextStyle(color: Colors.black),
        ),
        actions: <Widget>[
          IconButton(
              onPressed: (){ Navigator.pop(context); },
              icon: Icon(Icons.done, size: 30.0, color: Colors.green,),
          ),
        ],
      ),
      body: loading ? circularProgress() : ListView(
        children: <Widget>[
          Container(
            child: Column(
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.only(top: 16.0, bottom: 8.0),
                  child: CircleAvatar(
                    radius: 50.0,
                    backgroundImage: NetworkImage(user.photoUrl),
                  ),
                ),
                Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Column(
                      children: <Widget>[
                        buildDisplayNameField(),
                        buildBioField(),
                      ],
                    ),
                ),
                RaisedButton(
                  onPressed: updateProfileData,
                  child: Text(
                    'Update Profile',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontSize: 20.0,
                      fontWeight: FontWeight.bold
                    ),
                  ),
                ),
                Padding(
                    padding: EdgeInsets.all(16.0),
                    child: FlatButton.icon(
                        onPressed: logout,
                        icon: Icon(Icons.cancel, color: Colors.red,),
                        label: Text('Logout',style: TextStyle(color: Colors.red, fontSize: 20.0),),
                    ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Column buildDisplayNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
            padding: EdgeInsets.only(top: 12.0),
            child: Text('Display Name', style: TextStyle(color: Colors.grey,),),
        ),
        TextField(
          controller: displayNameController,
          decoration: InputDecoration(
            hintText: 'Update Display Name',
            errorText: _displayNameValid ? null : 'Display Name too Short'
          ),
        )
      ],
    );
  }

  Column buildBioField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.only(top: 12.0),
          child: Text('Bio', style: TextStyle(color: Colors.grey,),),
        ),
        TextField(
          controller: bioController,
          decoration: InputDecoration(
            hintText: 'Update Bio',
            errorText: _bioValid ? null : 'Bio is too Long'
          ),
        )
      ],
    );
  }

  updateProfileData() {
    setState(() {
      displayNameController.text.trim().length < 3 || displayNameController.text.isEmpty ?
      _displayNameValid = false : _displayNameValid = true;
      bioController.text.trim().length > 200 || bioController.text.isEmpty ?
      _bioValid = false : _bioValid = true;
    });

    if(_displayNameValid && _bioValid){
      usersRef.document(widget.currentUserId).updateData({
        'displayName': displayNameController.text,
        'bio': bioController.text
      });
      SnackBar snackBar = SnackBar(content: Text('Profile updated !'));
      _scaffoldKey.currentState.showSnackBar(snackBar);
    }
  }

  void logout() async {
    await googleSignIn.signOut();
    Navigator.pushReplacement(context, MaterialPageRoute(
        builder: (context) => Home()
    ));
  }
}
