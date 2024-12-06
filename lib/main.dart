import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/summary_screen.dart';
void main() {
  runApp(MyApp());
}
class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // 예시 filterFiles 데이터 정의
    Map<String, List<Map<String, String>>> filterFiles = {
      'Image': [
        {'title': 'Image1', 'summary': 'Summary for Image1', 'path': 'path/to/image1'},
        {'title': 'Image2', 'summary': 'Summary for Image2', 'path': 'path/to/image2'},
      ],
      'Text': [
        {'title': 'Text1', 'summary': 'Summary for Text1', 'path': 'path/to/text1'},
      ],
    };

    return MaterialApp(
      title: 'Flutter Demo',
      initialRoute: '/',
      routes: {
        '/': (context) => HomeScreen(title: 'Home'),  // 홈 화면
        '/summary': (context) => SummaryScreen(filterFiles: filterFiles),  // summary 화면으로 가는 라우트 설정
      },
    );
  }
}

