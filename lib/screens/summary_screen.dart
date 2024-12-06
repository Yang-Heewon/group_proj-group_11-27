import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SummaryScreen extends StatefulWidget {
  final Map<String, List<Map<String, dynamic>>> filterFiles; // filterFiles를 Map<String, dynamic> 형태로 받음

  const SummaryScreen({Key? key, required this.filterFiles}) : super(key: key);

  @override
  _SummaryScreenState createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  List<Map<String, String>> messages = []; // 채팅 메시지 리스트
  late TextEditingController _controller; // 채팅 입력 컨트롤러
  late ScrollController _scrollController; // 스크롤 컨트롤러 추가
  bool isButtonEnabled = false; // 버튼 활성화 여부

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _scrollController = ScrollController(); // 스크롤 컨트롤러 초기화
    _loadInitialSummary(); // 초기 요약 메시지 로드
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }
 Future<void> _saveSummaryChats() async {
  final prefs = await SharedPreferences.getInstance();
  List<String> chatContents = messages.map((message) => message["content"]!).toList();
  await prefs.setStringList('summaryChats', chatContents); // summaryChats를 저장
}


  /// 초기 요약 메시지 로드 함수
  void _loadInitialSummary() {
    List<Map<String, dynamic>> filterSummaryFiles = widget.filterFiles['Summary'] ?? [];

    if (filterSummaryFiles.isNotEmpty) {
      String summary = filterSummaryFiles[0]['path']; // 요약 텍스트
      setState(() {
        messages.add({
          "sender": "PDF Summary",
          "content": summary,
          "time": DateTime.now().toIso8601String(),
        });
      });
    }
  }


  /// 사용자가 메시지를 추가하는 함수
  Future<void> _addMessage(String message) async {
  setState(() {
    messages.add({
      "sender": "나", // 메시지 보낸 사람 (사용자)
      "content": message, // 메시지 내용
      "time": DateTime.now().toIso8601String(), // 전송 시간
    });
    _controller.clear(); // 입력창 초기화
    isButtonEnabled = false; // 버튼 비활성화
  });
  
  // 메시지를 SharedPreferences에 저장
  await _saveSummaryChats();
  
  _scrollToBottom(); // 스크롤을 메시지 하단으로 이동
  
  // API에 메시지를 전송
  await _sendMessageToApi(message);
}


  /// 서버에 메시지 전송 및 응답 처리
  Future<void> _sendMessageToApi(String message) async {
    try {
      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'), // Llama3 API URL
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer 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', // API 키
        },
        body: jsonEncode({
          "model": "llama3-8b-8192",
          "messages": [
            {"role": "system", "content": "You are a helpful assistant."},
            {"role": "user", "content": message} // 사용자가 입력한 메시지를 그대로 전달
          ],
          "temperature": 0.7
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        if (responseData is Map<String, dynamic> &&
            responseData.containsKey('choices') &&
            responseData['choices'].isNotEmpty &&
            responseData['choices'][0]['message']['content'] != null) {
          String reply = responseData['choices'][0]['message']['content'];
          _addBotMessage(reply);
        } else {
          _addBotMessage("알 수 없는 응답을 받았습니다.");
        }
      } else {
        _addBotMessage("서버 오류가 발생했습니다. (${response.statusCode})");
      }
    } catch (e) {
      _addBotMessage("네트워크 오류가 발생했습니다. 다시 시도해주세요.");
    }
  }

  /// AI Bot의 응답을 추가하는 함수
  void _addBotMessage(String message) {
    setState(() {
      messages.add({
        "sender": "AI Bot",
        "content": message,
        "time": DateTime.now().toIso8601String(),
      });
    });
    _scrollToBottom(); // 메시지 추가 후 스크롤을 최하단으로 이동
  }

  /// 스크롤을 최하단으로 이동하는 함수
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// 채팅 입력 필드
  Widget _buildChatInputField() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 5.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              onTap: _scrollToBottom, // 입력 필드 클릭 시 최하단으로 이동
              onChanged: (value) {
                setState(() {
                  isButtonEnabled = value.isNotEmpty;
                });
              },
              decoration: InputDecoration(hintText: "메시지를 입력하세요..."),
            ),
          ),
          IconButton(
            icon: Icon(Icons.send, color: isButtonEnabled ? Colors.blue : Colors.grey),
            onPressed: isButtonEnabled ? () => _addMessage(_controller.text) : null,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Summary & Chat"),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController, // 스크롤 컨트롤러 연결
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                return ListTile(
                  title: Text(
                    message["content"]!,
                    style: TextStyle(
                      color: message["sender"] == "나" ? Colors.blue : Colors.black,
                    ),
                  ),
                  subtitle: Text(
                    "${message["sender"]} - ${message["time"]!}",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                );
              },
            ),
          ),
          _buildChatInputField(),
        ],
      ),
    );
  }
}
