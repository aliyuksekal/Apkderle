import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/cities.dart';
import '../app_scope.dart';
import '../widgets.dart';

/// Şehir seçimi: elle liste (konum zorunlu değil) veya "Konumumu kullan".
class CityPickerScreen extends StatefulWidget {
  const CityPickerScreen({super.key});

  @override
  State<CityPickerScreen> createState() => _CityPickerScreenState();
}

class _CityPickerScreenState extends State<CityPickerScreen> {
  String query = '';
  bool locating = false;
  String? error;

  Future<void> _useLocation() async {
    setState(() {
      locating = true;
      error = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw 'Telefonun konum özelliği kapalı. Açıp tekrar deneyin ya da listeden şehrinizi seçin.';
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        throw 'Konum izni verilmedi. Listeden şehrinizi seçebilirsiniz.';
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 20),
        ),
      );
      if (!mounted) return;
      // Konum yalnızca cihazda saklanır; hiçbir sunucuya gönderilmez.
      await context.settings.setGps(pos.latitude, pos.longitude);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => error = e is String
          ? e
          : 'Konum alınamadı. Açık alanda tekrar deneyin ya da listeden şehrinizi seçin.');
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = searchCities(query);
    final current = context.settings.cityName;
    return Scaffold(
      appBar: AppBar(title: const Text('Şehir Seçimi')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                children: [
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(68)),
                    onPressed: locating ? null : _useLocation,
                    icon: locating
                        ? const SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(strokeWidth: 3))
                        : const Icon(Icons.my_location_rounded, size: 30),
                    label: Text(locating ? 'Konum bulunuyor…' : 'Konumumu Kullan'),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    NoticeBox(text: error!, warning: true),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    style: Theme.of(context).textTheme.titleMedium,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search_rounded, size: 30),
                      hintText: 'Şehir ara (ör. İzmir)',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16)),
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 18, horizontal: 16),
                    ),
                    onChanged: (v) => setState(() => query = v),
                  ),
                ],
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? Center(
                      child: Text('Şehir bulunamadı',
                          style: Theme.of(context).textTheme.titleLarge))
                  : ListView.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final c = list[i];
                        final sel = c.name == current;
                        return ListTile(
                          minTileHeight: 64,
                          title: Text(c.name),
                          trailing: sel
                              ? const Icon(Icons.check_circle_rounded, size: 30)
                              : null,
                          selected: sel,
                          onTap: () async {
                            await context.settings.setCity(c.name);
                            if (context.mounted) Navigator.pop(context);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
