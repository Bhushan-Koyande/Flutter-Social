import 'package:flutter/material.dart';

Widget cachedNetworkImage(String mediaUrl){
  print(mediaUrl);
  return Image.network(mediaUrl, fit: BoxFit.cover,);
}
