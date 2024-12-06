import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'summary_screen.dart'; // 요약 내용을 표시하는 화면

class PDFViewScreen extends StatefulWidget {
  final String filePath;

  PDFViewScreen({required this.filePath});

  @override
  _PDFViewScreenState createState() => _PDFViewScreenState();
}

class _PDFViewScreenState extends State<PDFViewScreen> {
  bool isLoading = true;
  int? totalPages = 0;
  int currentPage = 0;
  Map<String, List<Map<String, dynamic>>> filterFiles = {
    "Summary": [],
  };

  @override
  void initState() {
    super.initState();
  }

  /// **PDF에서 특정 페이지의 텍스트 추출**
  Future<String> _extractTextFromPdf(String filePath, int pageNumber) async {
    final fileBytes = File(filePath).readAsBytesSync();
    final PdfDocument document = PdfDocument(inputBytes: fileBytes);
    final String pageText = PdfTextExtractor(document).extractText(
      startPageIndex: pageNumber - 1,
      endPageIndex: pageNumber - 1,
    );
    document.dispose();
    return pageText;
  }

  /// **API를 호출하여 요약 생성**
  Future<String> _summarizePageText(String pageText) async {
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
            {"role": "system", "content": "You are a helpful assistant that summarizes text."},
            {"role": "user", "content": "Summarize the following text:\n\n$pageText"}
          ],
          "temperature": 0.7
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return result['choices'][0]['message']['content'];  // 요약 결과 반환
      } else {
        throw Exception("Failed to summarize: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Error summarizing page: $e");
    }
  }

  /// **Summary 버튼 클릭 시 요약 생성 및 저장**
  Future<void> _onSummaryPressed() async {
  setState(() {
    isLoading = true;
  });

  try {
    // 1. PDF에서 텍스트 추출
    final pageText = await _extractTextFromPdf(widget.filePath, currentPage);

    if (pageText.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Page $currentPage has no text to summarize.")),
      );
      setState(() {
        isLoading = false;
      });
      return;
    }

    // 2. API 호출로 요약 생성
    final summary = await _summarizePageText(pageText);

    // 3. SharedPreferences에 요약 저장
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("${widget.filePath}_summary", summary);

    // 4. filterFiles에 요약 추가
    setState(() {
      filterFiles["Summary"] = [
        {
          'title': "${widget.filePath}_summary",
          'subtitle': "Summary of the document",
          'path': summary,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      ];
    });

    // 5. SummaryScreen으로 이동
    Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => SummaryScreen(filterFiles: {
      "Summary": [
        {
          'title': "${widget.filePath}_summary",
          'subtitle': "Summary of the document",
          'path': summary, // 요약 결과
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      ],
    }),
  ),
);
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Error summarizing page: $e")),
    );
  } finally {
    setState(() {
      isLoading = false;
    });
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.filePath.startsWith("http")
            ? "Viewing Online PDF"
            : "Viewing Local PDF"),
        actions: [
          if (!isLoading)
            IconButton(
              icon: Icon(Icons.summarize),
              onPressed: _onSummaryPressed,
            ),
        ],
      ),
      body: Stack(
        children: [
          PDFView(
            filePath: widget.filePath,
            enableSwipe: true,
            onPageChanged: (page, total) {
              setState(() {
                currentPage = (page! + 1);
                totalPages = total;
              });
            },
            onRender: (pages) {
              setState(() {
                totalPages = pages;
                isLoading = false;
              });
            },
            onError: (error) {
              print("Error loading PDF: $error");
            },
            onPageError: (page, error) {
              print("Error on page $page: $error");
            },
          ),
          if (isLoading) Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
