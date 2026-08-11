// Yalnızca moderatör hesabının erişebildiği destek talepleri paneli.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:vibe_life/app_theme.dart';
import 'package:vibe_life/destek_servis.dart';
import 'package:vibe_life/error_messages.dart';
import 'package:vibe_life/utils/tarih_saat.dart';
import 'package:vibe_life/vibe_snackbar.dart';

class DestekTalepleriPanelPage extends StatefulWidget {
  const DestekTalepleriPanelPage({super.key});

  @override
  State<DestekTalepleriPanelPage> createState() =>
      _DestekTalepleriPanelPageState();
}

class _DestekTalepleriPanelPageState extends State<DestekTalepleriPanelPage> {
  bool _erisimKontrolEdiliyor = true;
  bool _erisimVar = false;
  String _durumFiltresi = 'tumu';

  static const _durumEtiketleri = <String, String>{
    'pending': 'Bekliyor',
    'reviewed': 'İncelendi',
    'resolved': 'Çözüldü',
    'rejected': 'Reddedildi',
  };

  @override
  void initState() {
    super.initState();
    _erisimiDogrula();
  }

  Future<void> _erisimiDogrula() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) Navigator.pop(context);
      return;
    }

    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final yetkili = doc.data()?['isModerator'] == true;
      if (!mounted) return;
      if (!yetkili) {
        Navigator.pop(context);
        vibeSnackbarGoster(
          context,
          'Bu alana erişim yetkin yok.',
          tip: VibeMesajTipi.uyari,
        );
        return;
      }
      setState(() {
        _erisimVar = true;
        _erisimKontrolEdiliyor = false;
      });
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      vibeSnackbarGoster(
        context,
        internetAwareErrorMessage(
          error: e,
          fallback: 'Erişim doğrulanamadı.',
        ),
      );
    }
  }

  Future<void> _durumGuncelle(
    DocumentReference<Map<String, dynamic>> ref,
    String durum,
  ) async {
    try {
      await ref.update({
        'status': durum,
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': FirebaseAuth.instance.currentUser?.uid ?? '',
      });
      if (!mounted) return;
      vibeSnackbarGoster(
        context,
        'Talep durumu güncellendi.',
        tip: VibeMesajTipi.basari,
      );
    } catch (e) {
      if (!mounted) return;
      vibeSnackbarGoster(
        context,
        internetAwareErrorMessage(
          error: e,
          fallback: 'Durum güncellenemedi.',
        ),
      );
    }
  }

  String _durumMetni(String durum) =>
      _durumEtiketleri[durum] ?? durum;

  String _kategoriMetni(String kategori) =>
      DestekServis.kategoriler[kategori] ?? kategori;

  Color _durumRengi(String durum) {
    switch (durum) {
      case 'pending':
        return Colors.orangeAccent;
      case 'resolved':
        return Colors.greenAccent;
      case 'rejected':
        return Colors.redAccent;
      default:
        return Colors.blueAccent;
    }
  }

  bool _filtreyeUyuyor(String status) {
    if (_durumFiltresi == 'tumu') return true;
    return status == _durumFiltresi;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vibe = context.vibe;

    if (_erisimKontrolEdiliyor || !_erisimVar) {
      return Scaffold(
        appBar: AppBar(title: const Text('Destek Talepleri')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Destek Talepleri')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Row(
              children: [
                _filtreChip('tumu', 'Tümü'),
                _filtreChip('pending', 'Bekleyen'),
                _filtreChip('reviewed', 'İncelenen'),
                _filtreChip('resolved', 'Çözülen'),
                _filtreChip('rejected', 'Reddedilen'),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('supportTickets')
                  .orderBy('createdAt', descending: true)
                  .limit(200)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: theme.colorScheme.primary,
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        internetAwareErrorMessage(
                          error: snapshot.error!,
                          fallback: 'Talepler yüklenemedi.',
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: vibe.mutedText),
                      ),
                    ),
                  );
                }

                final docs = (snapshot.data?.docs ?? [])
                    .where((doc) =>
                        _filtreyeUyuyor(
                          (doc.data()['status'] ?? 'pending').toString(),
                        ))
                    .toList();

                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      'Destek talebi bulunamadı.',
                      style: TextStyle(color: vibe.mutedText),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 20),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    final status =
                        (data['status'] ?? 'pending').toString();
                    final kategori =
                        (data['kategori'] ?? '').toString();
                    final konu = (data['konu'] ?? '').toString();
                    final mesaj = (data['mesaj'] ?? '').toString();
                    final kullaniciAdi =
                        (data['kullaniciAdi'] ?? 'Vibe Kullanıcısı')
                            .toString();
                    final userId = (data['userId'] ?? '').toString();
                    final appVersion =
                        (data['appVersion'] ?? '').toString();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: vibe.cardDecoration(radius: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: vibe.inputFill,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _kategoriMetni(kategori).toUpperCase(),
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurface,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _durumMetni(status),
                                  style: TextStyle(
                                    color: _durumRengi(status),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  tarihSaatYaz(data['createdAt']),
                                  style: TextStyle(
                                    color: vibe.faintText,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              konu,
                              style: TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              mesaj,
                              style: TextStyle(
                                color: vibe.mutedText,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '@$kullaniciAdi · $userId',
                              style: TextStyle(
                                color: vibe.faintText,
                                fontSize: 12,
                              ),
                            ),
                            if (appVersion.isNotEmpty)
                              Text(
                                'Sürüm: $appVersion',
                                style: TextStyle(
                                  color: vibe.faintText,
                                  fontSize: 12,
                                ),
                              ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (status != 'reviewed')
                                  OutlinedButton(
                                    onPressed: () =>
                                        _durumGuncelle(doc.reference, 'reviewed'),
                                    child: const Text('İncelendi'),
                                  ),
                                if (status != 'resolved')
                                  ElevatedButton(
                                    onPressed: () =>
                                        _durumGuncelle(doc.reference, 'resolved'),
                                    child: const Text('Çözüldü'),
                                  ),
                                if (status != 'rejected')
                                  OutlinedButton(
                                    onPressed: () =>
                                        _durumGuncelle(doc.reference, 'rejected'),
                                    child: const Text('Reddet'),
                                  ),
                                if (status != 'pending')
                                  TextButton(
                                    onPressed: () =>
                                        _durumGuncelle(doc.reference, 'pending'),
                                    child: const Text('Beklemeye al'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _filtreChip(String deger, String etiket) {
    final secili = _durumFiltresi == deger;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(etiket),
        selected: secili,
        onSelected: (_) => setState(() => _durumFiltresi = deger),
      ),
    );
  }
}
