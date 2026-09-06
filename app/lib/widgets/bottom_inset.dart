import 'package:flutter/material.dart';

/// Sistem gezinme cubugunun (3 tus / jest cubugu) kapladigi alani hesaba katar.
///
/// Neden gerekli: `Navigator.push` ile acilan TAM EKRAN sayfalarda ust
/// Scaffold'un `bottomNavigationBar`'i yoktur, dolayisiyla alt guvenli alani
/// kimse tuketmez. Sabit bir alt bosluk (orn. 20px) 3 tuslu cubugun ~48px'i
/// icin yetmez ve dugme cubugun ALTINDA kalir - gorev #266 tam olarak buydu.
///
/// `SafeArea` yerine bunu kullanmak, zeminin (siyah seritler gibi) cubugun
/// arkasina uzanmaya devam etmesini saglar; yalnizca ICERIK yukari itilir.
///
/// Ekran bir sekme olarak `bottomNavigationBar`'li bir Scaffold icinde
/// barindiriliyorsa Scaffold govdenin MediaQuery'sinden alt bosluğu duser
/// (`removePadding` hem `padding` hem `viewPadding` alt degerini kirpar), bu
/// yuzden burada 0 doner ve fazladan bosluk eklenmez - iki durumda da dogru.
///
/// DIKKAT: Klavye acikken `viewPadding.bottom` fiziksel cubugu bildirmeye
/// devam eder. Metin girisi olan bir ekranda bunu tek basina kullanma;
/// kod tabaninin geri kalanindaki
/// `mq.viewInsets.bottom + mq.padding.bottom + N` kalibini tercih et.
double systemBottomInset(BuildContext context) =>
    MediaQuery.of(context).viewPadding.bottom;

/// `base` + sistem gezinme cubugu kadar alt bosluk.
EdgeInsets bottomSafePadding(
  BuildContext context, {
  double left = 0,
  double top = 0,
  double right = 0,
  double bottom = 0,
}) =>
    EdgeInsets.fromLTRB(left, top, right, bottom + systemBottomInset(context));
