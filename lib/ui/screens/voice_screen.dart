import 'package:flutter/material.dart';

import '../../core/settings.dart';
import '../../core/speech.dart';
import '../app_scope.dart';
import '../widgets.dart';

/// Hoca sesi: telefondaki Türkçe sesleri dinleyip birini seçme.
class VoiceScreen extends StatefulWidget {
  const VoiceScreen({super.key});

  @override
  State<VoiceScreen> createState() => _VoiceScreenState();
}

class _VoiceScreenState extends State<VoiceScreen> {
  static const sample =
      'Allâhü ekber. Sübhânekellâhümme ve bi hamdik, ve tebârakesmük.';
  late Future<List<TtsVoice>> _voices = Speech.instance.voices();

  @override
  void dispose() {
    Speech.instance.stop();
    super.dispose();
  }

  Future<void> _try(String name) async {
    final s = context.settingsRead;
    final old = Speech.instance.voice;
    Speech.instance.voice = name;
    await Speech.instance.speak(sample, rate: s.readingSpeed.speechRate);
    Speech.instance.voice = old;
  }

  String _label(TtsVoice v, int i) {
    final g = switch (v.male) {
      true => ' · erkek',
      false => ' · kadın',
      null => '',
    };
    return 'Ses ${i + 1}$g${v.network ? ' · internet ister' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    final s = context.settings;
    return Scaffold(
      appBar: AppBar(title: const Text('Hoca Sesi')),
      body: FutureBuilder<List<TtsVoice>>(
        future: _voices,
        builder: (context, snap) {
          final list = snap.data ?? const <TtsVoice>[];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const NoticeBox(
                text:
                    'Fatiha ve sureleri hafız okur. Niyet, tekbir ve duaları telefonun konuşma sesi okur. Her sesi 🔊 ile dinleyin, beğendiğinize dokunun.',
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                secondary: const Icon(Icons.graphic_eq_rounded, size: 32),
                title: const Text('Kalın ses'),
                subtitle: const Text('Sesi erkek sesine yaklaştırır'),
                value: s.deepVoice,
                onChanged: s.setDeepVoice,
              ),
              const Divider(),
              RadioGroup<String>(
                groupValue: s.ttsVoice,
                onChanged: (v) => s.setTtsVoice(v ?? ''),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Radio<String>(value: ''),
                      title: const Text('Otomatik (erkek ses varsa o)'),
                      trailing: IconButton(
                        iconSize: 34,
                        icon: const Icon(Icons.volume_up_rounded),
                        onPressed: () => _try(''),
                      ),
                      onTap: () => s.setTtsVoice(''),
                    ),
                    for (var i = 0; i < list.length; i++)
                      ListTile(
                        leading: Radio<String>(value: list[i].name),
                        title: Text(_label(list[i], i)),
                        trailing: IconButton(
                          iconSize: 34,
                          icon: const Icon(Icons.volume_up_rounded),
                          onPressed: () => _try(list[i].name),
                        ),
                        onTap: () => s.setTtsVoice(list[i].name),
                      ),
                  ],
                ),
              ),
              if (snap.connectionState == ConnectionState.done && list.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Telefonda Türkçe ses bulunamadı. Aşağıdan konuşma ayarlarını açıp "Google Konuşma Hizmetleri"nde Türkçe sesi indirin.',
                  ),
                ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  await Speech.instance.openSettings();
                },
                icon: const Icon(Icons.settings_voice_rounded),
                label: const Text('Telefonun konuşma ayarları'),
              ),
              TextButton(
                onPressed: () =>
                    setState(() => _voices = Speech.instance.voices()),
                child: const Text('Sesleri yenile'),
              ),
            ],
          );
        },
      ),
    );
  }
}
