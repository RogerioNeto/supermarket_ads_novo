// ignore_for_file: unnecessary_null_comparison, deprecated_member_use

import 'dart:async' show StreamSubscription, Timer, Future, TimeoutException;
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:audio_session/audio_session.dart' as session;
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    debugPrint("Firebase inicializado!");
  } catch (e) {
    debugPrint("ERRO FIREBASE: $e");
  }
  runApp(const MaterialApp(
      debugShowCheckedModeBanner: false, home: AdminLoginPage()));
}

// ==========================================
// TELA DE LOGIN
// ==========================================
class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});
  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoggingIn = false;

  Future<void> _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Preencha todos os campos!")));
      return;
    }
    setState(() => _isLoggingIn = true);
    try {
      UserCredential userCredential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;

      // MELHORIA DE SEGURANÇA:
      // Em produção, verifique um campo 'isAdmin' no Firestore ou Custom Claims.
      final isAdmin =
          _emailController.text.trim().toLowerCase() == "admin@r13note.com";
      if (isAdmin) {
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) => const StoreSelectionPage()));
      } else {
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) =>
                    SupermarketProApp(storeId: userCredential.user!.uid)));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Erro de Autenticação: $e")));
    } finally {
      setState(() => _isLoggingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 80.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/logo-R13NOTE.png',
                  height: 80,
                  errorBuilder: (c, e, s) =>
                      const Icon(Icons.radio, size: 80, color: Colors.blue)),
              const SizedBox(height: 10),
              const Text("Supermarket Ads R13NOTE",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 40),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text("Acesso ao Painel",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 10),
                      TextField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                              labelText: "E-mail",
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.email))),
                      const SizedBox(height: 10),
                      TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                              labelText: "Senha",
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.lock))),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoggingIn ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8))),
                          child: _isLoggingIn
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : const Text("ENTRAR NA RÁDIO",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// TELA SELEÇÃO DE LOJAS
// ==========================================
class StoreSelectionPage extends StatelessWidget {
  const StoreSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Selecione a Loja"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              WakelockPlus.disable();
              await FirebaseAuth.instance.signOut();
              if (!context.mounted) return;
              Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const AdminLoginPage()));
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('stores').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            if (snapshot.error.toString().contains("permission-denied")) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Text(
                    "Erro de Permissão: Verifique as Regras do Firestore no Console do Firebase.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                ),
              );
            }
            return Center(
                child: Text("Erro ao carregar lojas: ${snapshot.error}"));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
                child: Text("Nenhuma loja cadastrada no Firebase."));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final storeId = docs[index].id;
              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 5),
                child: ListTile(
                  leading: const Icon(Icons.store, color: Colors.blue),
                  title: Text(storeId,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text("Toque para gerenciar anúncios"),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) =>
                              SupermarketProApp(storeId: storeId))),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateStoreDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showCreateStoreDialog(BuildContext context) {
    final newStoreController = TextEditingController();
    bool isSaving = false;
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Cadastrar Nova Loja"),
          content: TextField(
              controller: newStoreController,
              decoration: const InputDecoration(
                  labelText: "ID da Loja (ex: loja-002)")),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text("Cancelar")),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final storeId =
                          newStoreController.text.trim().toLowerCase();
                      if (storeId.isEmpty) return;
                      setDialogState(() => isSaving = true);
                      try {
                        await FirebaseFirestore.instance
                            .collection('stores')
                            .doc(storeId)
                            .set({
                          'ads': [],
                          'music': [],
                          'lastUpdate': FieldValue.serverTimestamp(),
                        });
                        if (!context.mounted) return;
                        Navigator.pop(dialogContext);
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      height: 20, width: 20, child: CircularProgressIndicator())
                  : const Text("Criar"),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// APP PRINCIPAL (PAINEL DA RÁDIO)
// ==========================================
class SupermarketProApp extends StatefulWidget {
  final String storeId;
  const SupermarketProApp({super.key, required this.storeId});
  @override
  State<SupermarketProApp> createState() => _SupermarketProAppState();
}

class _SupermarketProAppState extends State<SupermarketProApp> {
  final ap.AudioPlayer _audioPlayer = ap.AudioPlayer();
  static const String _googleApiKey = String.fromEnvironment('TTS_API_KEY',
      defaultValue: 'AVISO_CHAVE_AUSENTE');

  String _selectedGenre = '';

  final List<String> _genres = ['Gospel', 'Pop', 'Sertanejo', 'Rock'];

  final List<Map<String, String>> _googleVoices = [
    {"name": "Feminina Ultra-Realista", "id": "pt-BR-Wavenet-A"},
    {"name": "Feminina Profissional", "id": "pt-BR-Neural2-A"},
    {"name": "Masculina Profissional", "id": "pt-BR-Neural2-B"},
    {"name": "Masculina Natural", "id": "pt-BR-Wavenet-D"},
  ];
  String _selectedGoogleVoice = "pt-BR-Wavenet-A";

  final _textController = TextEditingController();
  final _labelController = TextEditingController();
  late TextEditingController _songsBetweenAdsController;
  late TextEditingController _musicIntervalController;

  int _songsBetweenAds = 3; // Padrão: 3 músicas
  int _songsPlayedCount = 0;
  int _musicInterval = 300;
  
  // ==========================================
  // CORREÇÃO: Inicia como 'false' e com Strings vazias em vez de null
  bool _useJingles = false; 
  String _customJingleIn = '';
  String _customJingleOut = '';
  // ==========================================
  
  late String _storeId;

  List<Map<String, dynamic>> _adsPlaylist = [];
  List<Map<String, dynamic>> _musicPlaylist = [];
  Timer? _adsTimer;
  Timer? _musicTimer;
  bool _isRunning = false;
  bool _isSpeaking = false;
  int _currentMusicIndex = 0;
  final Set<int> _selectedIndices = {};
  final Map<String, String> _ttsCache = {};
  StreamSubscription? _firestoreSubscription;

  @override
  void initState() {
    super.initState();
    _storeId = widget.storeId;
    _songsBetweenAdsController =
        TextEditingController(text: _songsBetweenAds.toString());
    _musicIntervalController =
        TextEditingController(text: _musicInterval.toString());
    _initApp();
  }

  @override
  void dispose() {
    _firestoreSubscription?.cancel();
    _adsTimer?.cancel();
    _musicTimer?.cancel();
    _songsBetweenAdsController.dispose();
    _musicIntervalController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _configureAudioSession() async {
    try {
      final auSession = await session.AudioSession.instance;
      await auSession.configure(const session.AudioSessionConfiguration(
        avAudioSessionCategory: session.AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions:
            session.AVAudioSessionCategoryOptions.duckOthers,
        avAudioSessionMode: session.AVAudioSessionMode.defaultMode,
        androidAudioAttributes: session.AndroidAudioAttributes(
          contentType: session.AndroidAudioContentType.speech,
          usage: session.AndroidAudioUsage.assistanceNavigationGuidance,
        ),
        androidAudioFocusGainType:
            session.AndroidAudioFocusGainType.gainTransientMayDuck,
        androidWillPauseWhenDucked: false,
      ));
    } catch (e) {
      debugPrint("Erro ao configurar AudioSession: $e");
    }
  }

  Future<void> _savePlaylist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ads_playlist', jsonEncode(_adsPlaylist));
    await prefs.setString('music_playlist', jsonEncode(_musicPlaylist));
    await prefs.setInt('songs_between_ads', _songsBetweenAds);
    await prefs.setInt('music_interval', _musicInterval);

    await FirebaseFirestore.instance.collection('stores').doc(_storeId).set({
      'ads': _adsPlaylist,
      'music': _musicPlaylist,
      'lastUpdate': FieldValue.serverTimestamp(),
      'songsBetweenAds': _songsBetweenAds,
      'musicInterval': _musicInterval,
      'jingleIn': _customJingleIn,
      'jingleOut': _customJingleOut,
    });
    setState(() {});
  }

  Future<void> _loadPlaylist() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedAds = prefs.getString('ads_playlist');
    final String? savedMusic = prefs.getString('music_playlist');
    _customJingleIn = prefs.getString('jingle_in_path')!;
    _customJingleOut = prefs.getString('jingle_out_path')!;

    _songsBetweenAds = prefs.getInt('songs_between_ads') ?? 3;
    _musicInterval = prefs.getInt('music_interval') ?? 300;
    setState(() {
      _songsBetweenAdsController.text = _songsBetweenAds.toString();
      _musicIntervalController.text = _musicInterval.toString();
    });

    if (savedAds != null) {
      _adsPlaylist = List<Map<String, dynamic>>.from(jsonDecode(savedAds));
    }
    if (savedMusic != null) {
      _musicPlaylist = List<Map<String, dynamic>>.from(jsonDecode(savedMusic));
    }
    if (_adsPlaylist.isEmpty) {
      _adsPlaylist.add({
        "type": "text",
        "content":
            "Bem-vindos clientes!, aproveitem nossas promoções incríveis de hoje.",
        "label": "Anúncio de Boas-vindas"
      });
    }
  }

  Future<void> _initApp() async {
    await _loadPlaylist();
    setState(() {});
    try {
      final auSession = await session.AudioSession.instance;
      await _configureAudioSession();

      // LOGS DE DEPURAÇÃO:
      auSession.interruptionEventStream.listen((event) {
        debugPrint(
            "AUDIO_DEBUG: Interrupção do sistema: ${event.begin ? 'Início' : 'Fim'} - Tipo: ${event.type}");
      });

      auSession.becomingNoisyEventStream.listen((_) {
        debugPrint("AUDIO_DEBUG: Saída de áudio alterada (Becoming Noisy)");
      });

      await auSession.setActive(false); // Inicia desativada
    } catch (e) {
      debugPrint("Erro AudioSession: $e");
    }
    _listenToRemoteChanges();
  }

  StreamSubscription?
      _musicSubscription; // Crie esta variável no topo da classe se necessário

  void _listenToRemoteChanges() {
    _firestoreSubscription?.cancel();
    _musicSubscription?.cancel();

    // 1. Escuta as configurações da loja (anúncios, intervalos, etc.)
    _firestoreSubscription = FirebaseFirestore.instance
        .collection('stores')
        .doc(_storeId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data()!;
        setState(() {
          if (data['ads'] != null) {
            _adsPlaylist = List<Map<String, dynamic>>.from(data['ads']);
          }
          _customJingleIn = data['jingleIn'];
          _customJingleOut = data['jingleOut'];

          if (data['songsBetweenAds'] != null) {
            _songsBetweenAds = data['songsBetweenAds'];
            if (!_songsBetweenAdsController.selection.isValid) {
              _songsBetweenAdsController.text = _songsBetweenAds.toString();
            }
          }
        });
      }
    });

    // 2. NOVA LÓGICA: Escuta a coleção de músicas filtrando por Loja e pelo Gênero selecionado
    _musicSubscription = FirebaseFirestore.instance
        .collection('musicas')
        .where('lojaId', isEqualTo: _storeId)
        .where('genero',
            isEqualTo: _selectedGenre.isEmpty ? 'Gospel' : _selectedGenre)
        .snapshots()
        .listen((snapshot) {
      List<Map<String, dynamic>> novaPlaylist = [];

      for (var doc in snapshot.docs) {
        final dados = doc.data();
        if (dados['url'] != null) {
          novaPlaylist.add({
            "type": "audio",
            "content": dados['url'].toString(),
            "label": dados['titulo'] ?? "Música da Nuvem",
            "isLocal": false
          });
        }
      }

      setState(() {
        _musicPlaylist = novaPlaylist;
      });

      debugPrint(
          "RÁDIO_DEBUG: Playlist atualizada na nuvem com ${novaPlaylist.length} músicas para o gênero $_selectedGenre");
    });
  }

  Future<dynamic> _fetchGoogleCloudAudio(String text) async {
    if (_googleApiKey == 'AVISO_CHAVE_AUSENTE') return null;

    final url =
        Uri.https('texttospeech.googleapis.com', '/v1/text:synthesize', {
      'key': _googleApiKey,
    });

    final String escapedText = text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "input": {"ssml": "<speak>$escapedText</speak>"},
          "voice": {"languageCode": "pt-BR", "name": _selectedGoogleVoice},
          "audioConfig": {
            "audioEncoding": "MP3",
            "pitch": 0,
            "speakingRate": 1.0
          }
        }),
      );
      if (response.statusCode == 200) {
        final bytes = base64Decode(jsonDecode(response.body)['audioContent']);
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/tts_${text.hashCode}.mp3');
        await file.writeAsBytes(bytes);
        return file.path;
      }
    } catch (e) {
      debugPrint("Erro Google TTS: $e");
    }
    return null;
  }

  Future<void> _playAndWait(String sourcePath,
      {bool isAsset = false, double playbackRate = 1.0}) async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.setPlaybackRate(playbackRate);
      ap.Source source;

      if (isAsset) {
        final assetPath = sourcePath.startsWith('assets/')
            ? sourcePath
            : 'assets/$sourcePath';
        source = ap.AssetSource(assetPath.replaceFirst('assets/', ''));
      } else if (sourcePath.startsWith('http')) {
        source = ap.UrlSource(sourcePath);
      } else {
        source = ap.DeviceFileSource(sourcePath);
      }
      await _audioPlayer.play(source);

      try {
        await _audioPlayer.onPlayerComplete.first.timeout(const Duration(minutes: 6));
      } on TimeoutException catch (_) {
        debugPrint("RÁDIO_DEBUG: Timeout de streaming atingido, pulando música.");
      }

    } catch (e) {
      debugPrint("Erro Play: $e");
    }
  }

  Future<void> _playItemContent(Map<String, dynamic> item) async {
    if (item["type"] == "text") {
      dynamic path = _ttsCache[item["content"]] ??
          await _fetchGoogleCloudAudio(item["content"]);
      if (path != null) await _playAndWait(path);
    } else if (item["type"] == "audio") {
      try {
        bool isAsset =
            item["isLocal"] != true && !item["content"].startsWith('http');
        await _playAndWait(item["content"], isAsset: isAsset);
      } catch (e) {
        await Future.delayed(const Duration(seconds: 2));
      }
    }
  }

  Future<void> _playNextByType(String type) async {
    if (_isSpeaking) return;
    _isSpeaking = true;
    _stopTimers();
    setState(() {});

    final auSession = await session.AudioSession.instance;
    try {
      final auSession = await session.AudioSession.instance;
      if (!await auSession.setActive(true)) return;
      if (type == "text") {
        if (_adsPlaylist.isEmpty) return;
        if (_useJingles) {
          String path = (_customJingleIn.isNotEmpty)
              ? _customJingleIn
              : 'jingle_in.mp3';
          await _playAndWait(path,
              isAsset: _customJingleIn.isNotEmpty, playbackRate: 0.85);
        }
        for (int i = 0; i < _adsPlaylist.length; i++) {
          await _playItemContent(_adsPlaylist[i]);
          if (i < _adsPlaylist.length - 1) {
            await Future.delayed(const Duration(milliseconds: 100));
          }
        }
        if (_useJingles) {
          String path =
              (_customJingleOut.isNotEmpty)
                  ? _customJingleOut
                  : 'jingle_out.mp3';
          await _playAndWait(path,
              isAsset: _customJingleOut == null, playbackRate: 0.85);
        }
      } else {
        if (_musicPlaylist.isEmpty) return;
        final item = _musicPlaylist[_currentMusicIndex % _musicPlaylist.length];
        await _playItemContent(item);
        _currentMusicIndex = (_currentMusicIndex + 1) % _musicPlaylist.length;
      }
      await Future.delayed(const Duration(milliseconds: 500));
    } finally {
      await _audioPlayer.stop();
      await _audioPlayer.release();
      await Future.delayed(const Duration(milliseconds: 500));
      await auSession.setActive(false);

      setState(() {
        _isSpeaking = false;
        if (_isRunning) {
          _runRadioLogic();
        }
      });
    }
  }

  // Nova lógica central da rádio
  Future<void> _runRadioLogic() async {
    if (!_isRunning || _isSpeaking) return;

    if (_songsPlayedCount >= _songsBetweenAds && _adsPlaylist.isNotEmpty) {
      _songsPlayedCount = 0;
      await _playNextByType("text");
    } else {
      if (_musicPlaylist.isNotEmpty) {
        _songsPlayedCount++;
        await _playNextByType("audio");
      } else {
        // Se não houver música, espera um pouco e tenta novamente
        await Future.delayed(const Duration(seconds: 5));
        if (_isRunning) _runRadioLogic();
      }
    }
  }

  void _startAllTimers() {
    _runRadioLogic();
  }

  void _stopTimers() {
    _adsTimer?.cancel();
    _musicTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Supermarket Ads R13NOTE",
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.white)),
            Text("ID da Loja: $_storeId",
                style: const TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        backgroundColor: Colors.blue,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (context) => const AdminLoginPage())),
        ),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Status e Controle:",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildTimerDisplay(
                        "MÚSICAS P/ ANÚNCIO",
                        (_songsBetweenAds - _songsPlayedCount).clamp(0, 99),
                        Colors.green),
                    const Icon(Icons.radio_outlined,
                        size: 40, color: Colors.blue),
                  ],
                ),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _isRunning = !_isRunning;
                      });
                      // Executa efeitos colaterais fora do setState
                      _isRunning ? _startAllTimers() : _stopTimers();
                      _isRunning
                          ? WakelockPlus.enable()
                          : WakelockPlus.disable();
                    },
                    icon: Icon(
                        _isRunning
                            ? Icons.stop_circle
                            : Icons.play_circle_filled,
                        color: Colors.white),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _isRunning
                            ? Colors.red.shade700
                            : Colors.blue.shade700,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    label: Text(
                        _isRunning ? "PARAR AUTOMAÇÃO" : "INICIAR AUTOMAÇÃO",
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 15),
                // SEÇÃO DE JINGLES RECUPERADA
                ExpansionTile(
                  title: const Text("Configurações de Jingle",
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  leading: const Icon(Icons.music_note),
                  children: [
                    SwitchListTile(
                      title: const Text("Usar Jingles"),
                      value: _useJingles,
                      onChanged: (val) => setState(() => _useJingles = val),
                    ),
                    _buildJinglePicker("Jingle de Entrada", _customJingleIn,
                        (path) => setState(() => _customJingleIn = path!)),
                    _buildJinglePicker("Jingle de Saída", _customJingleOut,
                        (path) => setState(() => _customJingleOut = path!)),
                  ],
                ),
                const SizedBox(height: 10),
                ExpansionTile(
                  title: const Text("Configurações de Fluxo",
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  leading: const Icon(Icons.settings_suggest),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _songsBetweenAdsController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                  labelText: "Músicas entre Anúncios",
                                  border: OutlineInputBorder()),
                              onChanged: (val) {
                                setState(() =>
                                    _songsBetweenAds = int.tryParse(val) ?? 3);
                                _savePlaylist();
                              },
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                labelText: "Gênero Musical",
                                border: OutlineInputBorder(),
                              ),
                              // Valida se o gênero selecionado realmente existe na lista antes de setar o valor inicial
                              initialValue: (_genres.isNotEmpty &&
                                      _genres.contains(_selectedGenre))
                                  ? _selectedGenre
                                  : (_genres.isNotEmpty ? _genres.first : null),
                              items: _genres.isEmpty
                                  ? null
                                  : _genres.map((g) {
                                      return DropdownMenuItem<String>(
                                        value: g,
                                        child: Text(g),
                                      );
                                    }).toList(),
                              onChanged: _genres.isEmpty
                                  ? null
                                  : (val) {
                                      if (val != null) {
                                        setState(() {
                                          _selectedGenre = val;
                                          _currentMusicIndex = 0;
                                        });
                                        _savePlaylist();
                                        _listenToRemoteChanges(); // Força o tablet a buscar as músicas do novo gênero na nuvem
                                      }
                                    },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // NOVA SEÇÃO DE ADICIONAR CONTEÚDO (PADRÃO EXPANSION TILE)
                ExpansionTile(
                  title: const Text("Adicionar Novo Conteúdo",
                      style:
                          TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  leading: const Icon(Icons.add_circle_outline),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Expanded(
                              child: ElevatedButton.icon(
                                  onPressed: () => _showAddDialog("text"),
                                  icon: const Icon(Icons.add_comment),
                                  label: const Text("Novo Texto"))),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                // 1. Abre o seletor de arquivos buscando apenas áudios (.mp3, etc)
                                FilePickerResult? result =
                                    await FilePicker.pickFiles(
                                  type: FileType.audio,
                                  allowMultiple: false,
                                );
                                // Garante que um arquivo foi selecionado e possui bytes carregados (essencial para Web)
                                if (result != null &&
                                    result.files.single.bytes != null) {
                                  final fileBytes = result.files.single.bytes!;
                                  final fileName = result.files.single.name;

                                  // Define o gênero padrão inicial usando a sua lista global de gêneros
                                  String? generoSelecionado =
                                      _genres.isNotEmpty ? _genres.first : null;

                                  if (!context.mounted) return;

                                  // 2. Abre a janela interativa para o usuário escolher o gênero
                                  showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (BuildContext context) {
                                      return StatefulBuilder(
                                        builder: (context, setDialogState) {
                                          return AlertDialog(
                                            title: const Text(
                                                'Cadastrar Música na Nuvem'),
                                            content: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Arquivo selecionado:\n$fileName',
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 13),
                                                ),
                                                const SizedBox(height: 20),
                                                DropdownButtonFormField<String>(
                                                  decoration:
                                                      const InputDecoration(
                                                    labelText: "Gênero Musical",
                                                    border:
                                                        OutlineInputBorder(),
                                                  ),
                                                  initialValue:
                                                      generoSelecionado,
                                                  items: _genres.map((g) {
                                                    return DropdownMenuItem<
                                                            String>(
                                                        value: g,
                                                        child: Text(g));
                                                  }).toList(),
                                                  onChanged: (val) {
                                                    setDialogState(() {
                                                      generoSelecionado = val;
                                                    });
                                                  },
                                                ),
                                              ],
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(context),
                                                child: const Text('Cancelar'),
                                              ),
                                              ElevatedButton(
                                                onPressed: generoSelecionado ==
                                                        null
                                                    ? null
                                                    : () async {
                                                        // 1. Armazena a referência do ScaffoldMessenger ANTES de qualquer ação assíncrona
                                                        final messenger =
                                                            ScaffoldMessenger
                                                                .of(context);
                                                        final navigator =
                                                            Navigator.of(
                                                                context);

                                                        // Garante um ID de loja válido
                                                        final idLojaValido =
                                                            (_storeId
                                                                    .toString()
                                                                    .isNotEmpty)
                                                                ? _storeId
                                                                    .toString()
                                                                : 'loja_principal';

                                                        try {
                                                          // 2. Executa o upload para o Firebase Storage
                                                          // Remove espaços, parênteses e caracteres especiais do nome do arquivo
                                                          final nomeLimpo =
                                                              fileName
                                                                  .replaceAll(
                                                                      RegExp(
                                                                          r'[^\w\s\.-]'),
                                                                      '') // Remove símbolos e parênteses
                                                                  .replaceAll(
                                                                      ' ',
                                                                      '_'); // Substitui espaços por underline

// Executa o upload com o nome limpo e seguro para URLs Web
                                                          final storageRef =
                                                              FirebaseStorage
                                                                  .instance
                                                                  .ref()
                                                                  .child(
                                                                      'stores/$idLojaValido/music/$generoSelecionado/$nomeLimpo');

                                                          await storageRef
                                                              .putData(
                                                            fileBytes,
                                                            SettableMetadata(
                                                                contentType:
                                                                    'audio/mpeg'), // Crucial para Web identificar como áudio
                                                          );

                                                          final downloadUrl =
                                                              await storageRef
                                                                  .getDownloadURL();

                                                          // 3. Registra no banco de dados Firestore
                                                          await FirebaseFirestore
                                                              .instance
                                                              .collection(
                                                                  'musicas')
                                                              .add({
                                                            'titulo': fileName
                                                                .replaceAll(
                                                                    '.mp3', ''),
                                                            'genero':
                                                                generoSelecionado,
                                                            'url': downloadUrl,
                                                            'lojaId':
                                                                idLojaValido,
                                                            'criadoEm': FieldValue
                                                                .serverTimestamp(),
                                                          });

                                                          // 4. Se tudo deu certo, exibe a confirmação usando a referência segura
                                                          messenger
                                                              .showSnackBar(
                                                            const SnackBar(
                                                              content: Text(
                                                                  'Música enviada e classificada com sucesso! 🎉'),
                                                              backgroundColor:
                                                                  Colors.green,
                                                            ),
                                                          );

                                                          // 5. FECHA O MODAL SÓ AGORA (Fim do processo bem-sucedido)
                                                          navigator.pop();
                                                        } catch (e) {
                                                          // Se falhar, fecha o modal e avisa o erro
                                                          navigator.pop();

                                                          messenger
                                                              .showSnackBar(
                                                            SnackBar(
                                                              content: Text(
                                                                  'Falha no upload: $e'),
                                                              backgroundColor:
                                                                  Colors.red,
                                                              duration:
                                                                  const Duration(
                                                                      seconds:
                                                                          8),
                                                            ),
                                                          );
                                                        }
                                                      },
                                                child: const Text(
                                                    'Salvar na Nuvem'),
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                    },
                                  );
                                }
                              },
                              icon: const Icon(Icons.library_music),
                              label: const Text("Nova Música"),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 30),
                const Text("Voz do Google (TTS):",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 5),
                // 1. Cria uma lista de vozes garantindo que os IDs sejam ÚNICOS e não nulos
                const SizedBox(height: 5),
                // Uma função executada na hora para processar os dados com segurança
                Builder(
                  builder: (context) {
                    final uniqueVoices = <String, Map>{};
                    for (var v in _googleVoices) {
                      final id = v['id']?.toString() ?? '';
                      if (id.isNotEmpty) {
                        uniqueVoices[id] = v;
                      }
                    }
                    final validVoicesList = uniqueVoices.values.toList();

                    String? dropdownValue;
                    if (validVoicesList.isNotEmpty) {
                      if (validVoicesList.any(
                          (v) => v['id'].toString() == _selectedGoogleVoice)) {
                        dropdownValue = _selectedGoogleVoice;
                      } else {
                        dropdownValue = validVoicesList.first['id'].toString();
                      }
                    }

                    return DropdownButton<String>(
                      isExpanded: true,
                      value: dropdownValue,
                      items: validVoicesList.isEmpty
                          ? null
                          : validVoicesList.map((v) {
                              return DropdownMenuItem<String>(
                                value: v['id'].toString(),
                                child: Text(
                                  v['name'] ?? '',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              );
                            }).toList(),
                      onChanged: validVoicesList.isEmpty
                          ? null
                          : (novoId) {
                              if (novoId != null) {
                                setState(() {
                                  _selectedGoogleVoice = novoId;
                                });
                              }
                            },
                    );
                  },
                ),
                const SizedBox(height: 25),
                _buildListSection("Anúncios de Ofertas", _adsPlaylist, true),
                const SizedBox(height: 15),
                _buildListSection(
                    "Trilha Sonora / Músicas", _musicPlaylist, false),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildJinglePicker(
      String label, String? currentPath, Function(String?) onPick) {
    return ListTile(
      title: Text(label, style: const TextStyle(fontSize: 13)),
      subtitle: Text(
          currentPath != null ? currentPath.split('/').last : "Padrão do App",
          style: const TextStyle(fontSize: 11)),
      trailing: IconButton(
        icon: const Icon(Icons.file_upload, size: 20, color: Colors.blue),
        onPressed: () async {
          FilePickerResult? result =
              await FilePicker.pickFiles(type: FileType.audio);
          if (result != null) {
            onPick(result.files.single.path);
            _savePlaylist();
          }
        },
      ),
    );
  }

  Widget _buildTimerDisplay(String label, int seconds, Color color) {
    return Column(
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold, color: color)),
        Text(
            "${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}",
            style: TextStyle(
                fontSize: 32, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildListSection(
      String title, List<Map<String, dynamic>> list, bool isAds) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 5),
        Container(
          height: 140,
          decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8)),
          child: list.isEmpty
              ? const Center(
                  child: Text("Nenhum item cadastrado",
                      style: TextStyle(fontSize: 12, color: Colors.grey)))
              : ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final item = list[index];
                    final isSelected =
                        isAds && _selectedIndices.contains(index);
                    return ListTile(
                      dense: true,
                      leading: isAds
                          ? Checkbox(
                              value: isSelected,
                              onChanged: (val) => setState(() => val!
                                  ? _selectedIndices.add(index)
                                  : _selectedIndices.remove(index)))
                          : const Icon(Icons.music_note, size: 18),
                      title: Text(item["label"] ?? "Item",
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500)),
                      subtitle: Text(item["content"],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                              icon: const Icon(Icons.edit,
                                  color: Colors.blue, size: 16),
                              onPressed: () => _showAddDialog(
                                  isAds ? "text" : "audio",
                                  index: index)),
                          IconButton(
                              icon: const Icon(Icons.delete,
                                  color: Colors.red, size: 16),
                              onPressed: () {
                                setState(() => list.removeAt(index));
                                _savePlaylist();
                              }),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _showAddDialog(String type, {int? index}) async {
    final targetList = type == "text" ? _adsPlaylist : _musicPlaylist;
    String? pickedFilePath;
    Uint8List? pickedFileBytes; // Para suporte Web

    if (index != null) {
      _textController.text = targetList[index]["content"];
      _labelController.text = targetList[index]["label"] ?? "";
    } else {
      _textController.clear();
      _labelController.clear();

      // Se for música, abre o seletor de arquivos imediatamente
      if (type == "audio") {
        FilePickerResult? result = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['mp3', 'wav', 'm4a', 'mp4'],
        );
        if (result != null) {
          pickedFilePath = result.files.single.path;
          pickedFileBytes = result.files.single.bytes;
          _labelController.text = result.files.single.name;
        } else {
          return; // Usuário cancelou a seleção
        }
      }
    }

    if (!mounted) return;

    showDialog(
        context: context,
        builder: (context) {
          // 1. Movemos a variável para fora do builder do StatefulBuilder
          bool isUploading = false;

          return StatefulBuilder(
            builder: (context, setStateDialog) {
              return AlertDialog(
                title: Text(index == null
                    ? (type == "text"
                        ? "Novo Anúncio de Texto"
                        : "Adicionar Música Completa")
                    : "Editar Anúncio"),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                        controller: _labelController,
                        decoration: const InputDecoration(labelText: "Nome")),
                    const SizedBox(height: 10),
                    if (type == "text")
                      TextField(
                          controller: _textController,
                          maxLines: 3,
                          decoration: const InputDecoration(labelText: "Texto"))
                    else
                      Text("Arquivo: ${_labelController.text}",
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey)),
                  ],
                ),
                actions: [
                  TextButton(
                      onPressed:
                          isUploading ? null : () => Navigator.pop(context),
                      child: const Text("Cancelar")),
                  ElevatedButton(
                    onPressed: isUploading
                        ? null
                        : () async {
                            setStateDialog(() => isUploading = true);
                            String content = _textController.text;

                            if (type == "audio" && index == null) {
                              try {
                                final fileName =
                                    "${DateTime.now().millisecondsSinceEpoch}_${_labelController.text}";
                                final storageRef = FirebaseStorage.instance
                                    .ref()
                                    .child('stores/$_storeId/music/$fileName');

                                if (kIsWeb) {
                                  await storageRef.putData(pickedFileBytes!);
                                } else {
                                  await storageRef
                                      .putFile(File(pickedFilePath!));
                                }
                                content = await storageRef.getDownloadURL();
                              } catch (e) {
                                debugPrint("Erro no upload: $e");
                                setStateDialog(() => isUploading = false);
                                // Remove o return e deixa o fluxo ser tratado
                              }
                            }

                            // Só prossegue se o upload não tiver falhado (content não pode estar vazio se for áudio)
                            if (type == "audio" &&
                                index == null &&
                                content == _textController.text) {
                              return;
                            }

                            setState(() {
                              if (index == null) {
                                targetList.add({
                                  "type": type,
                                  "content": content,
                                  "label": _labelController.text.isEmpty
                                      ? "Item"
                                      : _labelController.text,
                                  "isLocal": false
                                });
                              } else {
                                targetList[index] = {
                                  "type": type,
                                  "content": type == "text"
                                      ? content
                                      : targetList[index]["content"],
                                  "label": _labelController.text,
                                  "isLocal": false
                                };
                              }
                            });
                            _savePlaylist();
                            if (!context.mounted) return;
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    "${type == 'text' ? 'Anúncio' : 'Música'} salvo com sucesso!"),
                                backgroundColor: Colors.green,
                              ),
                            );
                          },
                    child: Text(index == null ? "Adicionar" : "Salvar"),
                  ),
                ],
              );
            },
          );
        });
  }
}
