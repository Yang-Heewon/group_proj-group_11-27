  import 'package:flutter/material.dart';
  import 'package:image_picker/image_picker.dart';
  import 'package:file_picker/file_picker.dart';
  import 'dart:convert';
  import 'package:shared_preferences/shared_preferences.dart';
  import '../widgets/add_file_card.dart';
  import '../widgets/file_card.dart';
  import '../widgets/add_file_menu.dart';
  import 'dart:io';
  import 'package:path_provider/path_provider.dart';
  import 'package:path/path.dart' as path; // 추가
  import 'summary_screen.dart';
  import 'quiz_screen.dart';
  import 'settings_screen.dart';


  class ImageViewerScreen extends StatelessWidget {
    final String filePath;

    // 파일 경로를 받아오는 생성자
    ImageViewerScreen({required this.filePath});

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        appBar: AppBar(title: Text("Image Viewer")),
        body: Center(
          child: filePath.isNotEmpty // 경로가 비어있지 않은지 확인
              ? Image.file(File(filePath))  // 정상적인 경로일 때만 이미지 표시
              : Text("No image available"),  // 경로가 비어있다면 경고 메시지 표시
        ),
      );
    }
  }

  class HomeScreen extends StatefulWidget {
    final String title;

    HomeScreen({required this.title});

    @override
    _HomeScreenState createState() => _HomeScreenState();
  }

  class _HomeScreenState extends State<HomeScreen> {
  final ImagePicker _picker = ImagePicker();
  Map<String, List<Map<String, dynamic>>> filterFiles = {
    "Discrete": [],
    "MML": [],
    "Image": [],
  };



    Map<String, List<Map<String, dynamic>>> quizFiles = {};

    String selectedFilter = "Discrete";
    int _currentIndex = 0;

    @override
    void initState() {
      super.initState();
      _loadFiles();
    }

    Future<void> _loadFiles() async {
    final prefs = await SharedPreferences.getInstance();
    final savedData = prefs.getString('filterFiles');

    if (savedData != null) {
      setState(() {
        filterFiles = Map<String, List<Map<String, dynamic>>>.from(
          json.decode(savedData).map((key, value) => MapEntry(
            key,
            List<Map<String, dynamic>>.from(value.map((item) {
              final filePath = item["path"];
              // 경로가 존재하는지 확인
              if (filePath != null && File(filePath).existsSync()) {
                return Map<String, dynamic>.from(item);
              } else {
                print("경로가 존재하지 않음: $filePath");
                return null;
              }
            }).where((item) => item != null))), // 유효한 경로만 유지
        ));
      });
    }
  }


    Future<void> _saveFiles() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('filterFiles', json.encode(filterFiles));
      await prefs.setString('quizFiles', json.encode(quizFiles));
    }

    // 파일 추가 시 시간 기록
    Future<void> _pickPDF(String filter) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      String? filePath = result.files.single.path;

      if (filePath != null) {
        // 디렉토리 가져오기
        final directory = await getApplicationDocumentsDirectory();
        final newFilePath = path.join(directory.path, result.files.single.name);

        // 파일 복사
        await File(filePath).copy(newFilePath);

        setState(() {
          filterFiles[filter] ??= [];
          filterFiles[filter]!.add({
            "title": result.files.single.name,
            "subtitle": "PDF Document",
            "path": newFilePath,  // 복사된 파일의 새로운 경로
            "timestamp": DateTime.now().millisecondsSinceEpoch,
          });
        });

        await _saveFiles();  // 파일 정보 저장
      }
    }
  }

  Future<void> _pickQuiz(String filter) async {
      // 퀴즈 추가 시 사용하는 코드
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null) {
        String? filePath = result.files.single.path;
        if (filePath != null) {
          quizFiles[filter] ??= [];
          setState(() {
            quizFiles[filter]!.add({
              "title": result.files.single.name,
              "subtitle": "Quiz Document",
              "path": filePath,
              "timestamp": DateTime.now().millisecondsSinceEpoch,
            });
          });
          await _saveFiles();
        }
      }
    }


    // 이름순, 시간순 정렬하기
    void _sortFiles(String criteria) {
      setState(() {
        if (criteria == "name") {
          filterFiles[selectedFilter]?.sort((a, b) => a["title"].compareTo(b["title"]));
        } else if (criteria == "time") {
          filterFiles[selectedFilter]?.sort((a, b) => b["timestamp"].compareTo(a["timestamp"])); // 내림차순으로 시간 정렬
        }
      });
      _saveFiles();
    }

  void _addFile() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return AddFileMenu(
          onFolderSelected: () => _pickFolder(selectedFilter),
          onImageSelected: () => _pickImageFromGallery(selectedFilter),
          onScanDocument: () => _scanDocument(selectedFilter),
          onTakePicture: () => _takePicture(selectedFilter),
          onPDFSelected: () => _pickPDF(selectedFilter),
          onQuizSelected: () => _pickQuiz(selectedFilter),
          onCancel: () {
            Navigator.pop(context); // BottomSheet을 닫고 이전 화면으로 돌아가도록 설정
          },
        );
      },
    );
  }



    Future<void> _pickFolder(String filter) async {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.any,
      );

      if (result != null) {
        setState(() {
          filterFiles[filter]!.add({
            "title": result.files.single.name,
            "subtitle": "Folder from device",
            "timestamp": DateTime.now().millisecondsSinceEpoch, // 시간 기록
          });
        });
        await _saveFiles();
        Navigator.pop(context);
      }
    }

    Future<void> _pickImageFromGallery(String filter) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      // 디렉토리 가져오기
      final directory = await getApplicationDocumentsDirectory();
      final newFilePath = path.join(directory.path, path.basename(image.path));

      // 파일 복사
      await File(image.path).copy(newFilePath);

      setState(() {
        filterFiles[filter] ??= [];
        filterFiles[filter]!.add({
          "title": "Image from Gallery",
          "subtitle": "Image",
          "path": newFilePath,  // 복사된 파일의 새로운 경로
          "timestamp": DateTime.now().millisecondsSinceEpoch,
        });
      });

      await _saveFiles();  // 파일 정보 저장
    }
  }


    Future<void> _scanDocument(String filter) async {
      final XFile? scannedImage = await _picker.pickImage(source: ImageSource.camera);

      if (scannedImage != null) {
        setState(() {
          filterFiles[filter]!.add({
            "title": "Scanned Document",
            "subtitle": "Image",
            "path": scannedImage.path,
            "timestamp": DateTime.now().millisecondsSinceEpoch, // 시간 기록
          });
        });
        await _saveFiles();
        Navigator.pop(context);
      }
    }

    Future<void> _takePicture(String filter) async {
      final XFile? picture = await _picker.pickImage(source: ImageSource.camera);

      if (picture != null) {
        setState(() {
          filterFiles[filter]!.add({
            "title": "Taken Picture",
            "subtitle": "Image",
            "path": picture.path,
            "timestamp": DateTime.now().millisecondsSinceEpoch, // 시간 기록
          });
        });
        await _saveFiles();
        Navigator.pop(context);
      }
    }

    void _selectFilter(String filter) {
      setState(() {
        selectedFilter = filter;
      });
    }

    Future<void> _confirmDeleteFilter(String filter) async {
      final bool? result = await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("Delete Category"),
          content: Text("Are you sure you want to delete the category '$filter'?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text("No"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: Text("Yes"),
            ),
          ],
        ),
      );

      if (result == true) {
        setState(() {
          filterFiles.remove(filter);
          if (filterFiles.isNotEmpty) {
            selectedFilter = filterFiles.keys.first;
          } else {
            selectedFilter = '';
          }
        });
        await _saveFiles();
      }
    }

    Future<void> _confirmDeleteFile(BuildContext context, int index) async {
      final bool? result = await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("Delete File"),
          content: Text("Are you sure you want to delete this file?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text("No"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: Text("Yes"),
            ),
          ],
        ),
      );

      if (result == true) {
        setState(() {
          filterFiles[selectedFilter]!.removeAt(index);
        });
        await _saveFiles();
      }
    }

    Future<void> _addNewCategory() async {
      TextEditingController categoryController = TextEditingController();
      final String? newCategory = await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("Add New Category"),
          content: TextField(
            controller: categoryController,
            decoration: InputDecoration(labelText: "Category Name"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, categoryController.text);
              },
              child: Text("Add"),
            ),
          ],
        ),
      );

      if (newCategory != null && newCategory.isNotEmpty) {
        setState(() {
          filterFiles[newCategory] = [];
          selectedFilter = newCategory;
        });
        await _saveFiles();
      }
    }

   @override
Widget build(BuildContext context) {
  List<Widget> screens = [
    // Home screen
    HomeScreen(title: 'home'),
    // Summary screen
    SummaryScreen(filterFiles: filterFiles),
    // Quiz screen
    // QuizScreen(),
    // // Settings screen
    // SettingsScreen(),
  ];
  

  return Scaffold(
    appBar: AppBar(
      title: Text(widget.title),
      actions: [
        IconButton(
          icon: Icon(Icons.notifications),
          onPressed: () {}, // Define action for notifications
        ),
        IconButton(
          icon: Icon(Icons.more_vert),
          onPressed: () {}, // Define action for more options
        ),
      ],
    ),
    body: _currentIndex == 0
        ? Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row for filter chips and buttons
                Row(
                  children: [
                    ...filterFiles.keys.map((filter) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: GestureDetector(
                            onLongPress: () => _confirmDeleteFilter(filter),
                            child: FilterChip(
                              label: Text(filter),
                              selected: selectedFilter == filter,
                              selectedColor: Colors.purple[100],
                              checkmarkColor: Colors.purple,
                              onSelected: (bool value) {
                                _selectFilter(filter);
                              },
                            ),
                          ),
                        )),
                    IconButton(
                      icon: Icon(Icons.add),
                      onPressed: _addNewCategory,
                    ),
                    IconButton(
                      icon: Icon(Icons.sort),
                      onPressed: () {
                        // Sort files dialog
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text("Sort Files"),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  title: Text("Sort by Name"),
                                  onTap: () {
                                    _sortFiles("name");
                                    Navigator.pop(context);
                                  },
                                ),
                                ListTile(
                                  title: Text("Sort by Time"),
                                  onTap: () {
                                    _sortFiles("time");
                                    Navigator.pop(context);
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                SizedBox(height: 16),
                // GridView for displaying files and adding files
                Expanded(
                  child: GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 3 / 4,
                    ),
                    itemCount: filterFiles.containsKey(selectedFilter) && filterFiles[selectedFilter] != null
                        ? filterFiles[selectedFilter]!.length + 1
                        : 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return GestureDetector(
                          onTap: _addFile,
                          child: AddFileCard(), // The "Add File" card
                        );
                      } else {
                        final file = filterFiles[selectedFilter]![index - 1];
                        final filePath = file["path"];

                        if (filePath == null) {
                          // Print an error message and return an empty container if the path is null
                          print("파일 경로가 null입니다.");
                          return Container(); // No content is displayed if path is missing
                        }

                        return FileCard(
                          title: file["title"] ?? "Untitled",
                          subtitle: file["subtitle"] ?? "",
                          path: filePath, // Pass the file path for displaying
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          )
        : screens[_currentIndex], // Change to the selected screen

    // Bottom Navigation Bar for navigating between different screens
    bottomNavigationBar: BottomNavigationBar(
      items: [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: "Home",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.description),
          label: "Summary",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.question_mark),
          label: "Quiz",
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.more_horiz),
          label: "Settings",
        ),
      ],
      currentIndex: _currentIndex,
      onTap: (index) {
        setState(() {
          _currentIndex = index; // Update the selected index when tapping a bottom navigation item
        });
      },
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Colors.purple,
      unselectedItemColor: Colors.grey,
    ),
  );
}
  }