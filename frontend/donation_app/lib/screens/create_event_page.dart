import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/auth_service.dart';
import '../services/event_service.dart';
import 'auth_page.dart';

const Color primaryBlue = Color(0xFF7353BA);
const Color darkBlue = Color(0xFF39275F);
const Color backgroundBlue = Color(0xFFF8F6FF);
const Color borderBlue = Color(0xFFE7E0F3);

class CreateEventPage extends StatefulWidget {
  const CreateEventPage({
    super.key,
    required this.authService,
    this.initialEvent,
  });

  final AuthService authService;
  final EventRecord? initialEvent;

  @override
  State<CreateEventPage> createState() => _CreateEventPageState();
}

class _CreateEventPageState extends State<CreateEventPage> {
  final _formKey = GlobalKey<FormState>();
  late final _events = EventService(widget.authService);
  late final _eventId = widget.initialEvent?.id ?? EventService.newId();

  late final _organizationController = TextEditingController(
    text:
        widget.initialEvent?.organization ??
        widget.authService.currentSession?.name ??
        '',
  );

  final _endDateController = TextEditingController();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _dateController = TextEditingController();
  final _locationController = TextEditingController();
  final _slotsController = TextEditingController();

  final List<String> _categories = [
    'Байгаль орчин',
    'Нийгмийн халамж',
    'Боловсрол',
    'Цэвэр орчин',
    'Бусад',
  ];

  String _category = 'Байгаль орчин';
  DateTime? _selectedDate;
  DateTime? _selectedEndDate;
  bool _isPublishing = false;
  String? _error;

  // Газрын зураг дээр сонгосон байршил
  LatLng? _selectedLocation;
  static const LatLng _defaultLocation = LatLng(47.9184, 106.9177);

  Uint8List? _imageBytes;
  String? _imageName;
  String? _uploadedImageUrl;

  String get _locationValue {
    final enteredLocation = _locationController.text.trim();
    if (enteredLocation.isNotEmpty) return enteredLocation;

    final point = _selectedLocation;
    if (point == null) return '';
    return '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}';
  }

  @override
  void initState() {
    super.initState();

    final event = widget.initialEvent;
    if (event == null) return;

    _titleController.text = event.title;
    _descriptionController.text = event.description;
    _dateController.text = EventRecord.dateLabel(event.startsAt);
    _endDateController.text = EventRecord.dateLabel(event.endsAt);
    _locationController.text = event.location;
    _slotsController.text = '${event.capacity}';
    _selectedDate = event.startsAt;
    _selectedEndDate = event.endsAt;
    _category = eventCategories[event.category] ?? event.category;
    _uploadedImageUrl = event.imageUrl;
  }

  @override
  void dispose() {
    _organizationController.dispose();
    _endDateController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _dateController.dispose();
    _locationController.dispose();
    _slotsController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_isPublishing) return;

    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 82,
      );

      if (picked == null || !mounted) return;

      final bytes = await picked.readAsBytes();
      if (!mounted) return;

      if (bytes.length > EventService.maxImageBytes) {
        setState(() {
          _error = 'Зургийн хэмжээ 5MB-аас ихгүй байх ёстой.';
        });
        return;
      }

      setState(() {
        _imageBytes = bytes;
        _imageName = picked.name;
        _uploadedImageUrl = null;
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Зураг сонгож чадсангүй. Дахин оролдоно уу.';
        });
      }
    }
  }

  void _removeImage() {
    if (_isPublishing) return;

    setState(() {
      _imageBytes = null;
      _imageName = null;
      _uploadedImageUrl = null;
    });
  }

  Future<void> _chooseDate({bool end = false}) async {
    if (_isPublishing) return;

    final now = DateTime.now();
    final initial = end
        ? _selectedEndDate ??
              (_selectedDate ?? now).add(const Duration(hours: 1))
        : _selectedDate ?? now;

    final firstDay = DateTime(now.year, now.month, now.day);

    final date = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(firstDay) ? firstDay : initial,
      firstDate: firstDay,
      lastDate: DateTime(now.year + 5, 12, 31),
      helpText: end ? 'Дуусах огноо сонгох' : 'Эхлэх огноо сонгох',
      cancelText: 'Болих',
      confirmText: 'Сонгох',
    );

    if (!mounted || date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      confirmText: 'Сонгох',
      cancelText: 'Болих',
    );

    if (!mounted || time == null) return;

    final selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    setState(() {
      if (end) {
        _selectedEndDate = selected;
        _endDateController.text = EventRecord.dateLabel(selected);
      } else {
        _selectedDate = selected;
        _dateController.text = EventRecord.dateLabel(selected);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundBlue,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 10),
          child: IconButton(
            onPressed: () => Navigator.pop(context),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: primaryBlue,
              shape: const CircleBorder(),
            ),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        title: Text(
          widget.initialEvent == null
              ? 'Үйл ажиллагаа бүртгэх'
              : 'Үйл ажиллагаа засах',
          style: const TextStyle(
            color: darkBlue,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: borderBlue),
                  boxShadow: [
                    BoxShadow(
                      color: darkBlue.withValues(alpha: 0.04),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBanner(),
                      const SizedBox(height: 24),

                      _buildLabel('Үйл ажиллагааны зураг', required: false),
                      const SizedBox(height: 9),
                      _buildImagePicker(),
                      const SizedBox(height: 22),

                      _buildLabel('Зохион байгуулагч / байгууллага'),
                      const SizedBox(height: 9),
                      _buildField(
                        controller: _organizationController,
                        hint: 'Зохион байгуулагчийн нэр',
                        icon: Icons.business_outlined,
                        validator: (value) =>
                            value == null ||
                                value.trim().isEmpty ||
                                value.trim().length > 50
                            ? '1–50 тэмдэгттэй нэр оруулна уу.'
                            : null,
                      ),
                      const SizedBox(height: 22),

                      _buildLabel('Үйл ажиллагааны нэр'),
                      const SizedBox(height: 9),
                      _buildField(
                        controller: _titleController,
                        hint: 'Жишээ: Мод тарих өдөрлөг',
                        icon: Icons.flag_rounded,
                        validator: (value) {
                          if (value == null ||
                              value.trim().isEmpty ||
                              value.trim().length > 200) {
                            return 'Үйл ажиллагааны нэрээ оруулна уу';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 22),

                      _buildLabel('Ангилал'),
                      const SizedBox(height: 10),
                      _buildCategorySelector(),
                      const SizedBox(height: 22),

                      _buildLabel('Дэлгэрэнгүй тайлбар'),
                      const SizedBox(height: 9),
                      _buildField(
                        controller: _descriptionController,
                        hint: 'Үйл ажиллагааны зорилго, хийх ажлаа бичээрэй...',
                        icon: Icons.description_rounded,
                        maxLines: 5,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Тайлбар оруулна уу';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 22),

                      LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth < 440) {
                            return Column(
                              children: [
                                _dateField(),
                                const SizedBox(height: 20),
                                _locationField(),
                              ],
                            );
                          }

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _dateField()),
                              const SizedBox(width: 14),
                              Expanded(child: _locationField()),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 22),

                      _dateField(end: true),
                      const SizedBox(height: 22),

                      _buildLabel('Оролцогчдын тоо'),
                      const SizedBox(height: 9),
                      _buildField(
                        controller: _slotsController,
                        hint: 'Жишээ: 30',
                        icon: Icons.groups_rounded,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Оролцогчдын тоог оруулна уу';
                          }

                          final count = int.tryParse(value.trim());

                          if (count == null ||
                              count <= 0 ||
                              count > 2147483647) {
                            return '1–2147483647 бүхэл тоо оруулна уу';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 10),

                      const Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: primaryBlue,
                            size: 18,
                          ),
                          SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              'Хэдэн сайн дурын ажилтан оролцохыг зааж өгнө үү.',
                              style: TextStyle(
                                color: Color(0xFF6E84A8),
                                fontSize: 12,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),

                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),

                      _buildPublishButton(),
                      const SizedBox(height: 17),

                      const Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.verified_user_rounded,
                              color: primaryBlue,
                              size: 17,
                            ),
                            SizedBox(width: 7),
                            Flexible(
                              child: Text(
                                'Сайн үйлсийг хамтдаа бүтээцгээе 💙',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFF7185A5),
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    final bytes = _imageBytes;

    if (bytes == null) {
      return Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: borderBlue, width: 1.4),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _isPublishing ? null : _pickImage,
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0EBFA),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.add_photo_alternate_rounded,
                    color: primaryBlue,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Зураг нэмэх',
                  style: TextStyle(
                    color: darkBlue,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'JPG эсвэл PNG, 5MB хүртэл',
                  style: TextStyle(color: Color(0xFF7185A5), fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(bytes, fit: BoxFit.cover),
            Positioned(
              right: 12,
              bottom: 12,
              child: Row(
                children: [
                  FilledButton.icon(
                    onPressed: _isPublishing ? null : _pickImage,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: darkBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.photo_library_rounded, size: 18),
                    label: const Text(
                      'Солих',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Зургийг устгах',
                    onPressed: _isPublishing ? null : _removeImage,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Color(0xFFE5484D),
                    ),
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(23),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7353BA), Color(0xFF60429F), Color(0xFF39275F)],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFFFD166), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Text(
              '✦  VOLUNTEER HUB',
              style: TextStyle(
                color: const Color(0xFFFFD166),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Шинэ үйл ажиллагаа\nүүсгэцгээе!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 27,
              fontWeight: FontWeight.w900,
              height: 1.25,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 11),
          const Text(
            'Санаачилгаа хуваалцаж, бусдад урам зориг өгөөрэй.',
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.7),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              width: 78,
              height: 70,
              decoration: BoxDecoration(
                color: const Color(0xFFFFD166),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.event_available_rounded,
                color: darkBlue,
                size: 42,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text, {bool required = true}) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Text(
            text,
            style: const TextStyle(
              color: darkBlue,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 4),
          if (required)
            const Text(
              '*',
              style: TextStyle(
                color: Color(0xFFFF6B83),
                fontWeight: FontWeight.bold,
              ),
            )
          else
            const Text(
              '(заавал биш)',
              style: TextStyle(color: Color(0xFF94A5C0), fontSize: 12),
            ),
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    VoidCallback? onTap,
    bool readOnly = false,
  }) {
    return TextFormField(
      enabled: !_isPublishing,
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      onTap: onTap,
      readOnly: readOnly,
      style: const TextStyle(
        color: darkBlue,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          color: Color(0xFF94A5C0),
          fontSize: 13,
          fontWeight: FontWeight.normal,
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 15, right: 11, top: 2),
          child: Icon(icon, color: primaryBlue, size: 21),
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 48,
          minHeight: 48,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: maxLines > 1 ? 18 : 17,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(19),
          borderSide: const BorderSide(color: borderBlue),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(19),
          borderSide: const BorderSide(color: borderBlue),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(19),
          borderSide: const BorderSide(color: primaryBlue, width: 1.7),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(19),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(19),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        errorStyle: const TextStyle(fontSize: 11),
      ),
    );
  }

  Widget _buildCategorySelector() {
    const icons = [
      Icons.eco_rounded,
      Icons.favorite_rounded,
      Icons.menu_book_rounded,
      Icons.recycling_rounded,
      Icons.more_horiz_rounded,
    ];

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderBlue),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Үйл ажиллагааны төрлөө сонгоно уу',
            style: TextStyle(color: Color(0xFF7185A5), fontSize: 12),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 9,
            children: List.generate(_categories.length, (index) {
              final category = _categories[index];
              final selected = _category == category;

              return InkWell(
                borderRadius: BorderRadius.circular(30),
                onTap: () {
                  if (!_isPublishing) {
                    setState(() => _category = category);
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFFF0EBFA) : Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: selected ? primaryBlue : borderBlue,
                      width: selected ? 1.4 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icons[index],
                        size: 17,
                        color: selected ? primaryBlue : const Color(0xFF8295B5),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        category,
                        style: TextStyle(
                          color: selected ? primaryBlue : darkBlue,
                          fontSize: 11,
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w500,
                        ),
                      ),
                      if (selected) ...[
                        const SizedBox(width: 5),
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 15,
                          color: primaryBlue,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _dateField({bool end = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(end ? 'Дуусах огноо, цаг' : 'Эхлэх огноо, цаг'),
        const SizedBox(height: 9),
        _buildField(
          controller: end ? _endDateController : _dateController,
          hint: end ? 'Дуусах огноо сонгох' : 'Эхлэх огноо сонгох',
          icon: Icons.calendar_month_rounded,
          readOnly: true,
          onTap: () => _chooseDate(end: end),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Огноо сонгоно уу';
            }

            if (end &&
                _selectedDate != null &&
                _selectedEndDate != null &&
                !_selectedEndDate!.isAfter(_selectedDate!)) {
              return 'Дуусах цаг эхлэх цагаас хойш байна.';
            }

            return null;
          },
        ),
      ],
    );
  }

  Future<void> _selectLocationOnMap() async {
    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerPage(
          initialLocation: _selectedLocation ?? _defaultLocation,
        ),
      ),
    );

    if (result == null || !mounted) return;

    setState(() {
      _selectedLocation = result;
    });
  }

  Widget _locationField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Байршил'),
        const SizedBox(height: 9),
        _buildField(
          controller: _locationController,
          hint: 'Үйл ажиллагаа болох газрын нэр',
          icon: Icons.location_on_rounded,
          validator: (value) {
            if ((value == null || value.trim().isEmpty) &&
                _selectedLocation == null) {
              return 'Байршлаа оруулна уу';
            }
            return null;
          },
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _isPublishing ? null : _selectLocationOnMap,
          icon: const Icon(Icons.map_outlined),
          label: const Text('Газрын зураг дээр байршил сонгох'),
          style: OutlinedButton.styleFrom(
            foregroundColor: primaryBlue,
            minimumSize: const Size(double.infinity, 48),
            side: const BorderSide(color: borderBlue),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
        ),
        if (_selectedLocation != null) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0EBFA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Байршил сонгогдсон ✓\n'
              'Өргөрөг: ${_selectedLocation!.latitude.toStringAsFixed(6)}\n'
              'Уртраг: ${_selectedLocation!.longitude.toStringAsFixed(6)}',
              style: const TextStyle(
                color: darkBlue,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPublishButton() {
    return Container(
      width: double.infinity,
      height: 59,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF9B83D2), Color(0xFF7353BA), Color(0xFF60429F)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withValues(alpha: 0.27),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: _isPublishing ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        icon: _isPublishing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.send_rounded, size: 21),
        label: Text(
          _isPublishing
              ? 'Түр хүлээнэ үү...'
              : widget.initialEvent == null
              ? 'Үйл ажиллагаа нийтлэх'
              : 'Өөрчлөлтийг хадгалах',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_isPublishing || !_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    if (widget.authService.currentSession == null) {
      await Navigator.of(context).push<AuthSession>(
        MaterialPageRoute(
          builder: (_) => AuthPage(authService: widget.authService),
        ),
      );

      if (!mounted || widget.authService.currentSession == null) return;
    }

    setState(() {
      _isPublishing = true;
      _error = null;
    });

    try {
      var imageUrl = _uploadedImageUrl;
      final bytes = _imageBytes;

      if (bytes != null && imageUrl == null) {
        imageUrl = await _events.uploadImage(bytes, _imageName ?? 'image.jpg');
        _uploadedImageUrl = imageUrl;
      }

      final existing = widget.initialEvent;

      final event = existing == null
          ? await _events.create(
              id: _eventId,
              title: _titleController.text,
              description: _descriptionController.text,
              organization: _organizationController.text,
              category: categoryCode(_category),
              location: _locationValue,
              startsAt: _selectedDate!,
              endsAt: _selectedEndDate!,
              capacity: int.parse(_slotsController.text.trim()),
              imageUrl: imageUrl,
            )
          : await _events.update(
              id: existing.id,
              title: _titleController.text,
              description: _descriptionController.text,
              organization: _organizationController.text,
              category: categoryCode(_category),
              location: _locationValue,
              startsAt: _selectedDate!,
              endsAt: _selectedEndDate!,
              capacity: int.parse(_slotsController.text.trim()),
              imageUrl: imageUrl,
            );

      if (!mounted) return;
      Navigator.of(context).pop(event);
    } on AuthException catch (error) {
      if (!mounted) return;

      setState(() => _error = error.message);

      if (error.statusCode == 401) {
        await Navigator.of(context).push<AuthSession>(
          MaterialPageRoute(
            builder: (_) => AuthPage(authService: widget.authService),
          ),
        );

        if (mounted && widget.authService.currentSession != null) {
          setState(() {
            _error = 'Нэвтэрлээ. Мэдээллээ шалгаад дахин нийтлээрэй.';
          });
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = 'Нийтлэх үед алдаа гарлаа: $error';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isPublishing = false);
      }
    }
  }
}

/// Арга хэмжээний байршлыг газрын зураг дээр сонгох хуудас.
class LocationPickerPage extends StatefulWidget {
  const LocationPickerPage({super.key, required this.initialLocation});

  final LatLng initialLocation;

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  late LatLng _selectedPoint;

  @override
  void initState() {
    super.initState();
    _selectedPoint = widget.initialLocation;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundBlue,
      appBar: AppBar(
        title: const Text('Байршил сонгох'),
        centerTitle: true,
        backgroundColor: backgroundBlue,
        foregroundColor: darkBlue,
        surfaceTintColor: Colors.transparent,
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Text(
              'Газрын зураг дээр үйл ажиллагаа болох газраа '
              'товшоод тэмдэглэгээг байрлуулна уу.',
              textAlign: TextAlign.center,
              style: TextStyle(color: darkBlue, height: 1.4),
            ),
          ),
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: _selectedPoint,
                initialZoom: 14,
                onTap: (tapPosition, point) {
                  setState(() => _selectedPoint = point);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.volunteerhub.app',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selectedPoint,
                      width: 52,
                      height: 52,
                      child: const Icon(
                        Icons.location_pin,
                        color: Colors.red,
                        size: 48,
                      ),
                    ),
                  ],
                ),
                RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution('© OpenStreetMap contributors'),
                  ],
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Өргөрөг: '
                    '${_selectedPoint.latitude.toStringAsFixed(6)}',
                    style: const TextStyle(color: darkBlue),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Уртраг: '
                    '${_selectedPoint.longitude.toStringAsFixed(6)}',
                    style: const TextStyle(color: darkBlue),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop<LatLng>(context, _selectedPoint);
                      },
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Байршил баталгаажуулах'),
                      style: FilledButton.styleFrom(
                        backgroundColor: primaryBlue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
