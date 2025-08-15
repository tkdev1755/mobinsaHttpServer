import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';


class UiColors{
  static int mainColor = 0XFFbee893;
  static int lightAccentColor = 0xFF005675;
  static int accentColor = 0xFF003247;
  static int textAccentColor = 0xFF002536;
  static int alertRed1 = 0xFFFF8000;
  static int alertRed2 = 0xFFFF2F00;
  static int warningOrange1 = 0xFFFFC300;
  static int warningOrange2 = 0xFFFF6A00;
  static int warningYellow1 = 0xFFFFF200;
  static int warningYellow2 = 0xFFFFAE00;
  static int okGreen = 0xFF49AF5E;
  static int selectBlue = 0xFF00D4FF;
  static int unselected = 0xFF03151E;
  static int okColor = 0xFF0088A3;
  static int white = 0xFFFFFFFF;
  static int black = 0xFF000000;
  static int mainColor50 = 0xFF004461;
}

class UiText{
  int? color;
  FontWeight? weight;
  int? alpha;
  Color? matColor;
  late TextStyle vvLargeText;
  late TextStyle vLargeText;
  late TextStyle largeText;
  late TextStyle mediumText;
  late TextStyle nText;
  late TextStyle nsText;
  late TextStyle smallText;
  late TextStyle mLargeText;
  late TextStyle mMediumText;
  late TextStyle mNormalText;
  late TextStyle mSmallText;
  late TextStyle mSSmallText;
  UiText({this.color, this.weight, this.alpha,this.matColor}) {
    vvLargeText = GoogleFonts.montserrat(textStyle: TextStyle(color: Color(color ?? UiColors.black).withAlpha(alpha ?? 1000),fontSize: 60,overflow: TextOverflow.clip,decoration: TextDecoration.none,fontWeight: weight ?? FontWeight.w400));
    vLargeText = GoogleFonts.montserrat(textStyle: TextStyle(color: Color(color ?? UiColors.black).withAlpha(alpha ?? 1000),fontSize: 35,overflow: TextOverflow.clip,decoration: TextDecoration.none,fontWeight: weight ?? FontWeight.w400));
    largeText = GoogleFonts.montserrat(textStyle: TextStyle(color: Color(color ?? UiColors.black).withAlpha(alpha ?? 1000),fontSize: 30,overflow: TextOverflow.clip,decoration: TextDecoration.none,fontWeight: weight ?? FontWeight.w400));
    mediumText = GoogleFonts.montserrat(textStyle: TextStyle(color: Color(color ??  UiColors.black).withAlpha(alpha ?? 1000),fontSize: 25,overflow: TextOverflow.clip,decoration: TextDecoration.none,fontWeight: weight ?? FontWeight.w400));
    nText = GoogleFonts.montserrat(textStyle: TextStyle(color: Color(color ??  UiColors.black).withAlpha(alpha ?? 1000),fontSize: 20,overflow: TextOverflow.clip,decoration: TextDecoration.none,fontWeight: weight ?? FontWeight.w400));
    nsText =  GoogleFonts.montserrat(textStyle: TextStyle(color: Color(color ??  UiColors.black).withAlpha(alpha ?? 1000),fontSize: 18,overflow: TextOverflow.clip,decoration: TextDecoration.none,fontWeight: weight ?? FontWeight.w400));
    smallText = GoogleFonts.montserrat(textStyle: TextStyle(
        color: Color(color ??  UiColors.black).withAlpha(alpha ?? 1000),
        fontSize: 15,
        overflow: TextOverflow.clip,decoration: TextDecoration.none,fontWeight: weight ?? FontWeight.w400 ));
    mLargeText = GoogleFonts.poppins(textStyle: TextStyle(color: (matColor ?? Color(UiColors.black)).withAlpha(alpha ?? 1000),fontSize: 35,overflow: TextOverflow.clip,decoration: TextDecoration.none,fontWeight: weight ?? FontWeight.w400));
    mMediumText = GoogleFonts.montserrat(textStyle: TextStyle(color: (matColor ?? Color(UiColors.black)).withAlpha(alpha ?? 1000),fontSize: 35,overflow: TextOverflow.clip,decoration: TextDecoration.none,fontWeight: weight ?? FontWeight.w400));
    mNormalText = GoogleFonts.montserrat(textStyle: TextStyle(color: (matColor ?? Color(UiColors.black)).withAlpha(alpha ?? 1000),fontSize: 16,overflow: TextOverflow.clip,decoration: TextDecoration.none,fontWeight: weight ?? FontWeight.w400));
    mSmallText = GoogleFonts.montserrat(textStyle: TextStyle(color: (matColor ?? Color(UiColors.black)).withAlpha(alpha ?? 1000),fontSize: 14,overflow: TextOverflow.clip,decoration: TextDecoration.none,fontWeight: weight ?? FontWeight.w400));
    mSSmallText = GoogleFonts.montserrat(textStyle: TextStyle(color: (matColor ?? Color(UiColors.black)).withAlpha(alpha ?? 1000),fontSize: 12,overflow: TextOverflow.clip,decoration: TextDecoration.none,fontWeight: weight ?? FontWeight.w400));

  }
}

class UiShapes {
  final BorderRadiusGeometry ovalRadius;
  final BorderRadiusGeometry frameRadius;
  final BoxShadow classicShadow;
  UiShapes()
      : ovalRadius = BorderRadius.circular(90.0),
        frameRadius = BorderRadius.circular(12.0),
        classicShadow = BoxShadow(
          color: Colors.black.withOpacity(0.1),
          spreadRadius: 2,
          blurRadius: 7,
          offset: const Offset(0, 0),
        );
  static Widget bPadding(double bottom){
    return Padding(padding: EdgeInsets.only(bottom: bottom),);
  }
  static Widget rPadding(double right){
    return Padding(padding: EdgeInsets.only(right: right),);
  }

}