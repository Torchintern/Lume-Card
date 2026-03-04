import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class KycFormScreen extends StatefulWidget {
  const KycFormScreen({super.key});

  @override
  State<KycFormScreen> createState() => _KycFormScreenState();
}

class _KycFormScreenState extends State<KycFormScreen> {

  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _aadhaarController = TextEditingController();
  final TextEditingController _panController = TextEditingController();

  bool _noPan = false;
  bool _loading = false;

  Map<String, List<dynamic>> _groupedSlots = {};
  List<String> _availableDates = [];
  String? _selectedDate;
  int? _selectedSlot;

  @override
  void initState() {
    super.initState();
    _loadSlots();
    _nameController.addListener(() => setState(() {}));
    _aadhaarController.addListener(() => setState(() {}));
    _panController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _aadhaarController.dispose();
    _panController.dispose();
    super.dispose();
  }

  bool _isFormValid() {
    if (_nameController.text.trim().isEmpty) return false;
    if (_aadhaarController.text.length != 12) return false;
    if (!_noPan && _panController.text.length < 10) return false;
    if (_selectedSlot == null) return false;
    return true;
  }

  Future<void> _loadSlots() async {
    try {
      final res = await ApiService.getKycSlots();

      final Map<String, List<dynamic>> grouped = {};
      for (var slot in res) {
        final date = slot["date"].toString();
        if (!grouped.containsKey(date)) {
          grouped[date] = [];
        }
        grouped[date]!.add(slot);
      }

      setState(() {
        _groupedSlots = grouped;
        _availableDates = grouped.keys.toList()..sort();
        if (_availableDates.isNotEmpty) {
          _selectedDate = _availableDates[0];
        }
      });
    } catch (e) {
      debugPrint("Slot error $e");
    }
  }

  Future<void> _submit() async {
    final colorScheme = Theme.of(context).colorScheme;

    if (!_formKey.currentState!.validate()) return;

    if (_selectedSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Please select a slot"),
          backgroundColor: colorScheme.secondary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final studentId = prefs.getInt("student_id") ?? 1;

      final data = {
        "student_id": studentId,
        "full_name": _nameController.text.trim(),
        "aadhaar_number": _aadhaarController.text.trim(),
        "pan_number": _noPan ? null : _panController.text.trim(),
        "no_pan": _noPan,
        "slot_id": _selectedSlot
      };

      final res = await ApiService.bookKyc(data);

      if (res["success"] == true) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => Dialog(
            backgroundColor: colorScheme.surface,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TweenAnimationBuilder(
                    duration: const Duration(milliseconds: 600),
                    tween: Tween<double>(begin: 0.0, end: 1.0),
                    curve: Curves.elasticOut,
                    builder: (context, double value, child) {
                      return Transform.scale(
                        scale: value,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check_circle_rounded,
                            color: colorScheme.primary,
                            size: 44,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "KYC Slot Booked!",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Your KYC slot has been booked successfully. Our team will connect with you on the selected date.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        "Great, thanks!",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }

    } catch (e) {

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed: $e"),
          backgroundColor: colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );

    }

    setState(() => _loading = false);
  }

  Widget _buildSlotCard(Map slot) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bool selected = _selectedSlot == slot["id"];
    final int available = slot["available"] ?? 0;
    final bool isFull = available == 0;

    Color statusColor;
    if (available < 2) {
      statusColor = isDark ? Colors.redAccent : Colors.red;
    } else if (available < 6) {
      statusColor = isDark ? Colors.orangeAccent : Colors.orange;
    } else {
      statusColor = isDark ? Colors.greenAccent : Colors.green.shade600;
    }

    return GestureDetector(
      onTap: isFull
          ? null
          : () {
              setState(() {
                if (_selectedSlot == slot["id"]) {
                  _selectedSlot = null;
                } else {
                  _selectedSlot = slot["id"];
                }
              });
            },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isFull
                ? colorScheme.outlineVariant
                : selected
                    ? colorScheme.primary
                    : colorScheme.outlineVariant,
            width: 2,
          ),
          color: isFull
              ? colorScheme.onSurface.withOpacity(0.05)
              : selected
                  ? colorScheme.primaryContainer.withOpacity(isDark ? 0.3 : 0.8)
                  : colorScheme.surface,
          boxShadow: [
            if (selected && !isFull)
              BoxShadow(
                color: colorScheme.primary.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isFull
                    ? colorScheme.onSurface.withOpacity(0.1)
                    : selected
                        ? colorScheme.primary
                        : colorScheme.primaryContainer.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.calendar_today_rounded,
                color: isFull
                    ? colorScheme.onSurface.withOpacity(0.3)
                    : selected
                        ? colorScheme.onPrimary
                        : colorScheme.primary,
                size: 18,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    slot["time"],
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: isFull
                          ? colorScheme.onSurface.withOpacity(0.3)
                          : selected
                              ? colorScheme.onSurface
                              : colorScheme.onSurface.withOpacity(0.8),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isFull ? "Slots Full" : "$available Slots available",
                    style: TextStyle(
                      color: isFull ? colorScheme.onSurface.withOpacity(0.3) : statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            if (selected && !isFull)
              Icon(Icons.check_circle_rounded, color: colorScheme.primary)
            else if (!isFull)
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: colorScheme.onSurface.withOpacity(0.3))
            else
              Icon(Icons.lock_outline_rounded,
                  size: 16, color: colorScheme.onSurface.withOpacity(0.2)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Complete KYC",
          style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.onPrimary),
        ),
        backgroundColor: colorScheme.primary,
        elevation: 0,
        iconTheme: IconThemeData(color: colorScheme.onPrimary),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),

        child: Form(
          key: _formKey,

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              Text(
                "Verify Your Identity",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: colorScheme.onSurface,
                  letterSpacing: -0.5,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                "Complete KYC to activate your wallet and virtual card.",
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 24),

              /// FULL NAME
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: "Full Name (as per document)",
                  prefixIcon: Icon(Icons.person_outline_rounded,
                      color: colorScheme.primary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide:
                        BorderSide(color: colorScheme.primary, width: 2),
                  ),
                ),
                validator: (v) => v!.isEmpty ? "Enter full name" : null,
              ),

              const SizedBox(height: 20),

              /// AADHAAR
              TextFormField(
                controller: _aadhaarController,
                keyboardType: TextInputType.number,
                maxLength: 12,
                decoration: InputDecoration(
                  labelText: "Aadhaar Number",
                  prefixIcon: Icon(Icons.badge_outlined,
                      color: colorScheme.primary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide:
                        BorderSide(color: colorScheme.primary, width: 2),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.length != 12) {
                    return "Enter valid Aadhaar";
                  }
                  return null;
                },
              ),

              const SizedBox(height: 10),

              /// PAN
              if (!_noPan)
                TextFormField(
                  controller: _panController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: "PAN Number",
                    prefixIcon: Icon(Icons.credit_card_rounded,
                        color: colorScheme.primary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide:
                          BorderSide(color: colorScheme.primary, width: 2),
                    ),
                  ),
                  validator: (v) {
                    if (_noPan) return null;
                    if (v == null || v.length < 10) {
                      return "Enter valid PAN";
                    }
                    return null;
                  },
                ),

              const SizedBox(height: 10),

              CheckboxListTile(
                value: _noPan,
                activeColor: colorScheme.primary,
                checkColor: colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                title: const Text(
                  "No PAN Card / Still Minor",
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                onChanged: (v) {
                  setState(() {
                    _noPan = v!;
                  });
                },
              ),

              const SizedBox(height: 30),

              Text(
                "Select KYC Slot",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: colorScheme.onSurface,
                  letterSpacing: -0.5,
                ),
              ),

              const SizedBox(height: 14),

              if (_groupedSlots.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: CircularProgressIndicator(),
                  ),
                )
              else ...[
                // Date Selection
                SizedBox(
                  height: 50,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _availableDates.length,
                    itemBuilder: (context, index) {
                      final dateStr = _availableDates[index];
                      final isSelected = _selectedDate == dateStr;

                      // Parse YYYY-MM-DD
                      DateTime dt = DateTime.parse(dateStr);
                      String day = dt.day.toString();
                      String monthName = _getMonthName(dt.month);

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedDate = dateStr;
                            _selectedSlot = null;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          margin: const EdgeInsets.only(right: 12),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? colorScheme.primary
                                : colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? colorScheme.primary
                                  : colorScheme.outlineVariant,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            "$day ${monthName.toUpperCase()}",
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.visible,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? colorScheme.onPrimary
                                  : colorScheme.onSurface,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 25),

                if (_selectedDate != null) ...[
                  Text(
                    "Available Time Slots",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...(_groupedSlots[_selectedDate] ?? [])
                      .map((slot) => _buildSlotCard(slot))
                      .toList(),
                ],
              ],

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: (_loading || !_isFormValid()) ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _loading
                      ? SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                              color: colorScheme.onPrimary, strokeWidth: 2.5),
                        )
                      : const Text(
                          "Book KYC Slot",
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),

              const SizedBox(height: 30),

            ],
          ),
        ),
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }
}
