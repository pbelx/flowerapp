import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bush Bean Image Uploader',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const HomePage(),
    );
  }
}

class ImageResult {
  final int flowerCount;
  final String imageId;

  ImageResult({required this.flowerCount, required this.imageId});

  factory ImageResult.fromJson(Map<String, dynamic> json) {
    return ImageResult(
      flowerCount: json['flower_count'],
      imageId: json['image_id'],
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<XFile> _images = [];
  final picker = ImagePicker();
  String? _accessToken;
  List<ImageResult> _results = [];

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _accessToken = prefs.getString('access_token');
    });
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', token);
    setState(() {
      _accessToken = token;
    });
  }

  Future<void> login() async {
    final uri = Uri.parse('https://flower.entebbe.fun/auth/token');
    try {
      final response = await http.post(
        uri,
        headers: <String, String>{
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode(<String, String>{
          'username': _usernameController.text,
          'password': _passwordController.text,
        }),
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        await _saveToken(jsonResponse['access_token']);
        print('Login successful');
      } else {
        print('Login failed: ${response.body}');
      }
    } catch (e) {
      print('Error during login: $e');
    }
  }

  Future getImages() async {
    final pickedFiles = await picker.pickMultiImage();

    setState(() {
      _images = pickedFiles;
    });
  }

  Future<void> uploadImages() async {
    if (_images.isEmpty) return;
    if (_accessToken == null) {
      print('Please login first');
      return;
    }

    final uri = Uri.parse('https://flower.entebbe.fun/images/batch');
    var request = http.MultipartRequest('POST', uri);
    request.headers['Authorization'] = 'Bearer $_accessToken';

    for (var image in _images) {
      request.files
          .add(await http.MultipartFile.fromPath('images', image.path));
    }

    try {
      final response = await request.send();
      if (response.statusCode == 200) {
        final responseBody = await response.stream.bytesToString();
        final jsonResponse = json.decode(responseBody);
        print('Images uploaded successfully');
        print('Results: ${jsonResponse['results']}');
        setState(() {
          _results = (jsonResponse['results'] as List)
              .map((item) => ImageResult.fromJson(item))
              .toList();
        });
      } else {
        print('Image upload failed');
      }
    } catch (e) {
      print('Error uploading images: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bush Bean Flower Count'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextField(
                controller: _usernameController,
                decoration: InputDecoration(labelText: 'Username'),
              ),
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(labelText: 'Password'),
                obscureText: true,
              ),
              ElevatedButton(
                onPressed: login,
                child: const Text('Login'),
              ),
              const SizedBox(height: 20),
              Text(_accessToken == null ? 'Not logged in' : 'Logged in'),
              const SizedBox(height: 20),
              Container(
                width: 200,
                child: Column(
                  children: [
                    Text('Selected Images: ${_images.length}'),
                    ElevatedButton(
                      onPressed: getImages,
                      child: const Text('Select Images'),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: uploadImages,
                      child: const Text('Upload Images'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text('Results:'),
              ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  final result = _results[index];
                  return ListTile(
                    title: Text('Image ID: ${result.imageId}'),
                    subtitle: Text('Flower Count: ${result.flowerCount}'),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
