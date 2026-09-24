import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ndef_record/ndef_record.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_ios.dart';
import 'package:nfc_manager_ndef/nfc_manager_ndef.dart';

void main() {
  runApp(const NfcApp());
}

class NfcApp extends StatelessWidget {
  const NfcApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NFC',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const WriterPage(),
    );
  }
}

class WriterPage extends StatefulWidget {
  const WriterPage({super.key});

  @override
  State<WriterPage> createState() => _WriterPageState();
}

class _WriterPageState extends State<WriterPage> {
  final _urlController = TextEditingController();
  String _status =
      'Paste your Google Maps review link, then tap "Write to Card".';
  bool _busy = false;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  // URI prefixes defined by the NFC Forum URI Record Type Definition.
  // Using them shortens the payload so it fits on small cards.
  static const _uriPrefixes = [
    'https://www.',
    'http://www.',
    'https://',
    'http://',
  ];
  static const _uriPrefixCodes = [0x02, 0x01, 0x04, 0x03];

  NdefRecord _uriRecord(String url) {
    var code = 0x00;
    var rest = url;
    for (var i = 0; i < _uriPrefixes.length; i++) {
      if (url.startsWith(_uriPrefixes[i])) {
        code = _uriPrefixCodes[i];
        rest = url.substring(_uriPrefixes[i].length);
        break;
      }
    }
    return NdefRecord(
      typeNameFormat: TypeNameFormat.wellKnown,
      type: Uint8List.fromList([0x55]), // 'U'
      identifier: Uint8List(0),
      payload: Uint8List.fromList([code, ...utf8.encode(rest)]),
    );
  }

  String? _normalizeUrl(String input) {
    var url = input.trim();
    if (url.isEmpty) return null;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) return null;
    return url;
  }

  Future<void> _write() async {
    FocusScope.of(context).unfocus();
    final url = _normalizeUrl(_urlController.text);
    if (url == null) {
      setState(() => _status = 'Please enter a valid link.');
      return;
    }

    final availability = await NfcManager.instance.checkAvailability();
    if (availability != NfcAvailability.enabled) {
      setState(() => _status = 'NFC is not available on this device.');
      return;
    }

    setState(() {
      _busy = true;
      _status = 'Hold the card near the top of your iPhone...';
    });

    final message = NdefMessage(records: [_uriRecord(url)]);

    await NfcManager.instance.startSession(
      pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693},
      alertMessageIos: 'Hold your iPhone near the NFC card.',
      onDiscovered: (tag) async {
        debugPrint('Card detected');
        if (mounted) setState(() => _status = 'Card detected, writing...');
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          await NfcManagerIos.instance.tagSessionSetAlertMessage(
            alertMessage: 'Card detected ✅\nWriting, keep holding...',
          );
        }
        final ndef = Ndef.from(tag);
        String? error;
        if (ndef == null) {
          error = 'This card does not support NDEF.';
        } else if (!ndef.isWritable) {
          error = 'This card is locked / read-only.';
        } else if (message.byteLength > ndef.maxSize) {
          error =
              'Link is too long for this card '
              '(${message.byteLength} of ${ndef.maxSize} bytes).';
        } else {
          try {
            await ndef.write(message: message);
          } catch (e) {
            error = 'Write failed: $e';
          }
        }

        if (error == null) {
          await NfcManager.instance.stopSession(
            alertMessageIos: 'Saved to card ✅',
          );
          _finish('Done! Scanning this card now opens:\n$url');
        } else {
          await NfcManager.instance.stopSession(errorMessageIos: error);
          _finish(error);
        }
      },
      onSessionErrorIos: (error) {
        _finish('Cancelled: ${error.message}');
      },
    );
  }

  void _finish(String status) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _status = status;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('NFC')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Icon(Icons.nfc, size: 80, color: Colors.blue),
            const SizedBox(height: 20),
            TextField(
              controller: _urlController,
              keyboardType: TextInputType.url,
              autocorrect: false,
              maxLines: 3,
              minLines: 1,
              decoration: const InputDecoration(
                labelText: 'Google Maps review link',
                hintText: 'https://g.page/r/XXXXXXXX/review',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy ? null : _write,
              icon: const Icon(Icons.edit),
              label: const Text('Write to Card'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _status,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
