import 'dart:async';
import 'package:flutter/material.dart';
import 'package:instructai/course_model.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:instructai/quiz_screen.dart';

class CourseDetailScreen extends StatefulWidget {
  final CourseModel course;

  const CourseDetailScreen({super.key, required this.course});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen>
    with TickerProviderStateMixin {
  final MethodChannel _resetSessionChannel = const MethodChannel(
      'instructai/resetSession');
  final EventChannel _streamChannel = const EventChannel('genai/stream');

  String? selectedModule;
  String userInput = "";
  String generatedLesson = "";

  bool isGenerating = false;
  bool _isPromptInProgress = false;
  bool _inSession = false;

  StreamSubscription? _streamSubscription;
  late AnimationController _fadeController;
  late AnimationController _slideController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _fadeController.dispose();
    _slideController.dispose();
    _resetModelSession();
    super.dispose();
  }

  Future<void> _resetModelSession() async {
    const methodChannel = MethodChannel('genai/method');
    try {
      await methodChannel.invokeMethod('resetSession');
    } catch (e) {
      debugPrint("Error resetting session: $e");
    }
  }

  Future<void> _startSessionGeneration() async {
    if (selectedModule == null || _isPromptInProgress) return;

    if (!mounted) return;

    setState(() {
      generatedLesson = "";
      isGenerating = true;
    });

    _slideController.forward();

    await _resetModelSession();
    _isPromptInProgress = true;

    final prompt = """
You are an expert course designer and educator.

Below is the complete course roadmap. From it, find the **"$selectedModule"** section and extract its listed topics.  
You must teach these topics **one by one**, in a clear, focused, and professional manner.

---

###Full Course Roadmap:
${widget.course.roadmap}

---

###Module to Teach:
"$selectedModule"

---

###Student's Focus:
"${userInput.trim().isEmpty ? 'Gain a deep understanding of the module\'s topics and master them thoroughly' : userInput.trim()}"

---

###Instructions:
- Identify the topics under "$selectedModule" in the roadmap.
- For **each topic**, write a detailed explanation using proper Markdown.
- Use relevant formatting: `##` for topic titles, bullet points, code blocks, formulas, or visuals if necessary.
- Include **subject-relevant examples** and highlight key ideas or applications.
- Do **not** include introductions, summaries, or generic overviews.
- Focus **strictly on explaining the topics** of this module in sequence.

---

**Style:** Clear, structured, and professional  
**Goal:** Teach each topic as if you're guiding a smart, curious learner.  
**Limit:** ~3000 tokens — be concise but thorough.
""";

    _streamSubscription?.cancel();
    _streamSubscription = _streamChannel
        .receiveBroadcastStream({"prompt": prompt})
        .listen((chunk) {
      if (!mounted) return;
      setState(() {
        generatedLesson += chunk;
      });
    }, onDone: () {
      if (!mounted) return;
      setState(() {
        isGenerating = false;
        _isPromptInProgress = false;
      });
    }, onError: (error) {
      debugPrint("Streaming error: $error");
      if (!mounted) return;
      setState(() {
        isGenerating = false;
        _isPromptInProgress = false;
      });
    });
  }

  Future<void> _downloadAsPdf() async {
    final pdf = pw.Document();
    final font = pw.Font.helvetica();
    final boldFont = pw.Font.helveticaBold();
    final monoFont = pw.Font.courier();

    // Parse the content into sections for PDF
    List<CourseSection> sections = _parseMarkdownIntoSections(generatedLesson);

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          theme: pw.ThemeData.withFont(base: font),
          margin: const pw.EdgeInsets.all(32),
        ),
        header: (context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(bottom: 20),
            padding: const pw.EdgeInsets.only(bottom: 10),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(width: 1, color: PdfColors.grey300),
              ),
            ),
            child: pw.Text(
              'Learning Session Notes',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
          );
        },
        footer: (context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 20),
            padding: const pw.EdgeInsets.only(top: 10),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(width: 1, color: PdfColors.grey300),
              ),
            ),
            child: pw.Text(
              'Page ${context.pageNumber}',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
          );
        },
        build: (context) {
          List<pw.Widget> pdfContent = [];

          // Title page content
          pdfContent.addAll([
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(
                    widget.course.title,
                    style: pw.TextStyle(
                      fontSize: 28,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue800,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    selectedModule ?? 'Learning Session',
                    style: pw.TextStyle(
                      fontSize: 18,
                      color: PdfColors.grey700,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 8),
                  pw.Container(
                    width: 100,
                    height: 2,
                    color: PdfColors.blue400,
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 40),
          ]);

          // Add each section to PDF
          for (int sectionIndex = 0; sectionIndex < sections.length; sectionIndex++) {
            final section = sections[sectionIndex];

            // Section header
            pdfContent.addAll([
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Container(
                    width: 30,
                    height: 30,
                    decoration: pw.BoxDecoration(
                      color: PdfColors.blue500,
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Center(
                      child: pw.Text(
                        '${sectionIndex + 1}',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 12),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          section.title,
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey800,
                          ),
                        ),
                        if (section.subtitle.isNotEmpty)
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(top: 2),
                            child: pw.Text(
                              section.subtitle,
                              style: pw.TextStyle(
                                fontSize: 12,
                                color: PdfColors.grey600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.blue50,
                      borderRadius: pw.BorderRadius.circular(8),
                      border: pw.Border.all(color: PdfColors.blue200),
                    ),
                    child: pw.Text(
                      '${section.estimatedReadTime} min',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue600,
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
            ]);

            // Section content blocks
            for (final block in section.contentBlocks) {
              pdfContent.addAll(_buildPdfContentBlock(block, font, boldFont, monoFont));
              pdfContent.add(pw.SizedBox(height: 12));
            }

            // Add spacing between sections
            if (sectionIndex < sections.length - 1) {
              pdfContent.add(pw.SizedBox(height: 20));
              pdfContent.add(
                pw.Container(
                  height: 1,
                  color: PdfColors.grey300,
                  margin: const pw.EdgeInsets.symmetric(vertical: 10),
                ),
              );
              pdfContent.add(pw.SizedBox(height: 10));
            }
          }

          return pdfContent;
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
    );
  }

  List<pw.Widget> _buildPdfContentBlock(ContentBlock block, pw.Font font, pw.Font boldFont, pw.Font monoFont) {
    List<pw.Widget> widgets = [];

    switch (block.type) {
      case ContentType.text:
        widgets.add(
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey50,
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: PdfColors.grey200),
            ),
            child: pw.Text(
              block.content,
              style: pw.TextStyle(
                fontSize: 12,
                height: 1.5,
                color: PdfColors.grey800,
                font: font,
              ),
              textAlign: pw.TextAlign.justify,
            ),
          ),
        );
        break;

      case ContentType.code:
        widgets.addAll([
          pw.Container(
            width: double.infinity,
            decoration: pw.BoxDecoration(
              color: PdfColors.grey900,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Code header
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey800,
                    borderRadius: const pw.BorderRadius.only(
                      topLeft: pw.Radius.circular(8),
                      topRight: pw.Radius.circular(8),
                    ),
                  ),
                  child: pw.Text(
                    'Code Example',
                    style: pw.TextStyle(
                      color: PdfColors.grey300,
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                // Code content
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(12),
                  child: pw.Text(
                    block.content,
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.white,
                      font: monoFont,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ]);
        break;

      case ContentType.list:
        final items = block.content.split('\n').where((item) => item.trim().isNotEmpty).toList();
        widgets.add(
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue50,
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: PdfColors.blue200),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: items.map((item) {
                final cleanItem = item.replaceAll(RegExp(r'^[-*•]\s*'), '');
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        width: 4,
                        height: 4,
                        margin: const pw.EdgeInsets.only(top: 4, right: 8),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.blue600,
                          shape: pw.BoxShape.circle,
                        ),
                      ),
                      pw.Expanded(
                        child: pw.Text(
                          cleanItem,
                          style: pw.TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: PdfColors.grey800,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        );
        break;

      case ContentType.quote:
        widgets.add(
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.amber50,
              borderRadius: pw.BorderRadius.circular(8),
              border: const pw.Border(
                left: pw.BorderSide(color: PdfColors.amber600, width: 4),
              ),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  '"',
                  style: pw.TextStyle(
                    fontSize: 20,
                    color: PdfColors.amber600,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: pw.Text(
                    block.content.replaceAll(RegExp(r'^>\s*'), ''),
                    style: pw.TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: PdfColors.grey800,
                      fontStyle: pw.FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        break;
    }

    return widgets;
  }

  List<String> _splitIntoParagraphs(String text) {
    final lines = text.split('\n\n');
    return lines
        .expand((block) => _splitIfTooLong(block))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  List<String> _splitIfTooLong(String paragraph, {int maxLength = 1000}) {
    if (paragraph.length <= maxLength) return [paragraph];

    final chunks = <String>[];
    for (int i = 0; i < paragraph.length; i += maxLength) {
      chunks.add(paragraph.substring(
          i, i + maxLength > paragraph.length ? paragraph.length : i + maxLength));
    }
    return chunks;
  }

  @override
  Widget build(BuildContext context) {
    final modules = widget.course.modules.map((m) => m?.title).toList();

    return WillPopScope(
      onWillPop: () async {
        if (isGenerating) {
          _showSnackBar("Please wait until the lesson is fully generated.");
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: _buildModernAppBar(),
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          child: _inSession
              ? _buildSessionView()
              : _buildPreSessionView(modules),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildModernAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      toolbarHeight: 70,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: Colors.grey.shade700),
          onPressed: () {
            if (isGenerating) {
              _showSnackBar("Please wait until the lesson is fully generated.");
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.course.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          Text(
            _inSession ? "Learning Session" : "Course Overview",
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      actions: _inSession ? _buildSessionActions() : null,
      bottom: _inSession && isGenerating
          ? PreferredSize(
        preferredSize: const Size.fromHeight(4),
        child: Container(
          height: 4,
          child: LinearProgressIndicator(
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple.shade400),
          ),
        ),
      )
          : null,
    );
  }

  List<Widget> _buildSessionActions() {
    return [
      Container(
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: IconButton(
          icon: Icon(Icons.close, color: Colors.red.shade600),
          tooltip: "End Session",
          onPressed: () {
            if (isGenerating) {
              _showSnackBar("Please wait until the lesson is fully generated.");
            } else {
              setState(() {
                _inSession = false;
                _slideController.reset();
              });
            }
          },
        ),
      ),
      if (!isGenerating && generatedLesson.isNotEmpty)
        Container(
          margin: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: Icon(Icons.quiz, color: Colors.green.shade600),
            tooltip: "Take Quiz",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => QuizScreen(
                    selectedModule: selectedModule ?? '',
                    roadmap: widget.course.roadmap ?? '',
                  ),
                ),
              );
            },
          ),
        ),
    ];
  }

  Widget _buildPreSessionView(List<String?> modules) {
    return FadeTransition(
      opacity: _fadeController,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildRoadmapCard(),
            const SizedBox(height: 24),
            _buildSessionSetupCard(modules),
          ],
        ),
      ),
    );
  }

  Widget _buildRoadmapCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade400, Colors.purple.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.map, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Course Roadmap",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        "Your complete learning journey",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: MarkdownBody(
              data: widget.course.roadmap ?? "No roadmap available.",
              styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                p: const TextStyle(fontSize: 16, height: 1.6, color: Colors.black87),
                h2: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepPurple.shade600),
                h3: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.deepPurple.shade500),
                listBullet: TextStyle(color: Colors.deepPurple.shade400),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionSetupCard(List<String?> modules) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.teal.shade400, Colors.green.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.play_circle_filled, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Start Learning Session",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        "AI-powered personalized lessons",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.folder_open, color: Colors.deepPurple.shade600, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      "Select Module",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: DropdownButtonFormField<String>(
                    value: selectedModule,
                    isExpanded: true,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      hintText: "Choose a module to learn",
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                      prefixIcon: Icon(Icons.school, color: Colors.deepPurple.shade400),
                    ),
                    dropdownColor: Colors.white,
                    style: const TextStyle(color: Colors.black87, fontSize: 16),
                    items: modules.map((m) {
                      return DropdownMenuItem<String>(
                        value: m,
                        child: Text(
                          m!,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => selectedModule = val),
                  ),
                ),

                const SizedBox(height: 24),

                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.pending_actions, color: Colors.orange.shade600, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      "Focus Area",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "Optional",
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: TextField(
                    onChanged: (val) => userInput = val,
                    maxLines: 3,
                    style: const TextStyle(fontSize: 16),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(20),
                      hintText: "E.g., beginner-friendly explanations, focus on practical examples, include code snippets...",
                      hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Icon(Icons.edit_note, color: Colors.orange.shade600),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                Container(
                  width: double.infinity,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: selectedModule != null
                        ? LinearGradient(
                      colors: [Colors.deepPurple.shade400, Colors.blue.shade400],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    )
                        : null,
                    color: selectedModule == null ? Colors.grey.shade300 : null,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: selectedModule != null ? [
                      BoxShadow(
                        color: Colors.deepPurple.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ] : null,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: selectedModule == null
                          ? null
                          : () {
                        setState(() {
                          _inSession = true;
                        });
                        _startSessionGeneration();
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.rocket_launch,
                              color: selectedModule != null ? Colors.white : Colors.grey.shade500,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              "Start AI Learning Session",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: selectedModule != null ? Colors.white : Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionView() {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _slideController,
        curve: Curves.easeOutCubic,
      )),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.indigo.shade400, Colors.purple.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.indigo.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Learning Session Active",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        selectedModule ?? "",
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isGenerating)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: generatedLesson.isEmpty
                  ? _buildLoadingState()
                  : _buildLessonContent(),
            ),
          ),

          if (!isGenerating) _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade100, Colors.purple.shade100],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.auto_awesome,
              size: 48,
              color: Colors.deepPurple.shade600,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            "AI is crafting your lesson...",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Personalizing content based on your focus area",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // UPDATED LESSON CONTENT METHOD WITH ENHANCED UI
  Widget _buildLessonContent() {
    // Parse the markdown content into sections
    List<CourseSection> sections = _parseMarkdownIntoSections(generatedLesson);

    return Container(
      padding: const EdgeInsets.all(8),
      child: ListView.builder(
        itemCount: sections.length,
        itemBuilder: (context, index) {
          final section = sections[index];
          return _buildSectionCard(section, index);
        },
      ),
    );
  }

  Widget _buildSectionCard(CourseSection section, int index) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
        child: ExpansionTile(
          initiallyExpanded: index == 0, // First section expanded by default
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          backgroundColor: Colors.transparent,
          collapsedBackgroundColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _getSectionGradient(index),
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: _getSectionGradient(index)[0].withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          title: Text(
            section.title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          subtitle: section.subtitle.isNotEmpty
              ? Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              section.subtitle,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          )
              : null,
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getSectionGradient(index)[0].withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${section.estimatedReadTime} min',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _getSectionGradient(index)[0],
              ),
            ),
          ),
          children: [
            _buildSectionContent(section),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionContent(CourseSection section) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 24),

        // Content blocks
        ...section.contentBlocks.asMap().entries.map((entry) {
          final blockIndex = entry.key;
          final block = entry.value;
          return _buildContentBlock(block, blockIndex);
        }).toList(),

        // Interactive elements
        if (section.hasCodeExamples || section.hasQuizQuestions)
          const SizedBox(height: 16),

        if (section.hasCodeExamples)
          _buildInteractiveElement(
            icon: Icons.code,
            title: "Code Examples Available",
            subtitle: "Tap to view interactive examples",
            color: Colors.green,
            onTap: () => _showCodeExamples(section),
          ),

        if (section.hasQuizQuestions)
          const SizedBox(height: 8),

        if (section.hasQuizQuestions)
          _buildInteractiveElement(
            icon: Icons.quiz,
            title: "Practice Questions",
            subtitle: "Test your understanding",
            color: Colors.orange,
            onTap: () => _showPracticeQuestions(section),
          ),

        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildContentBlock(ContentBlock block, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (block.type == ContentType.text)
            _buildTextBlock(block),
          if (block.type == ContentType.code)
            _buildCodeBlock(block),
          if (block.type == ContentType.list)
            _buildListBlock(block),
          if (block.type == ContentType.quote)
            _buildQuoteBlock(block),
        ],
      ),
    );
  }

  Widget _buildTextBlock(ContentBlock block) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: MarkdownBody(
        data: block.content,
        styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
          p: const TextStyle(
            fontSize: 16,
            height: 1.6,
            color: Colors.black87,
          ),
          h1: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple.shade700,
            height: 1.3,
          ),
          h2: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple.shade600,
            height: 1.3,
          ),
          h3: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.deepPurple.shade500,
            height: 1.3,
          ),
          h4: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.deepPurple.shade400,
            height: 1.3,
          ),
          h5: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.deepPurple.shade400,
            height: 1.3,
          ),
          h6: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.deepPurple.shade400,
            height: 1.3,
          ),
          strong: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
          em: const TextStyle(
            fontStyle: FontStyle.italic,
            color: Colors.black87,
          ),
          code: TextStyle(
            fontFamily: 'monospace',
            fontSize: 14,
            backgroundColor: Colors.grey.shade200,
            color: Colors.red.shade700,
          ),
          blockquote: TextStyle(
            fontSize: 16,
            height: 1.5,
            color: Colors.grey.shade700,
            fontStyle: FontStyle.italic,
          ),
          listBullet: TextStyle(
            color: Colors.deepPurple.shade400,
            fontWeight: FontWeight.bold,
          ),
          tableHead: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.deepPurple.shade600,
          ),
          tableBody: const TextStyle(
            fontSize: 15,
            color: Colors.black87,
          ),
        ),
        selectable: true,
      ),
    );
  }

  Widget _buildCodeBlock(ContentBlock block) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Code header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade800,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.yellow,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: block.content));
                    _showSnackBar("Code copied to clipboard!");
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.copy, color: Colors.grey.shade300, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'Copy',
                          style: TextStyle(
                            color: Colors.grey.shade300,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Code content
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              block.content,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                color: Colors.white,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListBlock(ContentBlock block) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: MarkdownBody(
        data: block.content,
        styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
          p: const TextStyle(
            fontSize: 16,
            height: 1.5,
            color: Colors.black87,
          ),
          listBullet: TextStyle(
            color: Colors.blue.shade600,
            fontWeight: FontWeight.bold,
          ),
          listIndent: 20,
          strong: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
          em: const TextStyle(
            fontStyle: FontStyle.italic,
            color: Colors.black87,
          ),
          code: TextStyle(
            fontFamily: 'monospace',
            fontSize: 14,
            backgroundColor: Colors.blue.shade100,
            color: Colors.blue.shade800,
          ),
        ),
        selectable: true,
      ),
    );
  }


  Widget _buildQuoteBlock(ContentBlock block) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: Colors.amber.shade600, width: 4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.format_quote,
            color: Colors.amber.shade600,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: MarkdownBody(
              data: block.content,
              styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                p: TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: Colors.grey.shade800,
                  fontStyle: FontStyle.italic,
                ),
                blockquote: TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: Colors.grey.shade800,
                  fontStyle: FontStyle.italic,
                ),
                strong: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
                em: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey.shade800,
                ),
                code: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                  backgroundColor: Colors.amber.shade100,
                  color: Colors.amber.shade800,
                ),
              ),
              selectable: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveElement({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: color,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods for parsing and data management
  List<CourseSection> _parseMarkdownIntoSections(String markdown) {
    List<CourseSection> sections = [];
    List<String> lines = markdown.split('\n');

    CourseSection? currentSection;
    List<String> currentContent = [];

    for (String line in lines) {
      if (line.trim().startsWith('##') && !line.trim().startsWith('###')) {
        // Save previous section
        if (currentSection != null) {
          currentSection.contentBlocks = _parseContentBlocks(currentContent.join('\n'));
          sections.add(currentSection);
        }

        // Start new section
        String title = line.replaceAll(RegExp(r'^#+\s*'), '').trim();
        currentSection = CourseSection(
          title: title,
          subtitle: _generateSubtitle(title),
          contentBlocks: [],
        );
        currentContent = [];
      } else if (currentSection != null) {
        currentContent.add(line);
      }
    }

    // Add last section
    if (currentSection != null) {
      currentSection.contentBlocks = _parseContentBlocks(currentContent.join('\n'));
      sections.add(currentSection);
    }

    // If no sections found, create a single section with all content
    if (sections.isEmpty) {
      sections.add(CourseSection(
        title: selectedModule ?? 'Course Content',
        subtitle: 'AI-generated learning material',
        contentBlocks: _parseContentBlocks(markdown),
      ));
    }

    return sections;
  }

  List<ContentBlock> _parseContentBlocks(String content) {
    List<ContentBlock> blocks = [];
    List<String> lines = content.split('\n');

    List<String> currentBlock = [];
    ContentType currentType = ContentType.text;

    for (String line in lines) {
      if (line.trim().isEmpty && currentBlock.isNotEmpty) {
        blocks.add(ContentBlock(
          type: currentType,
          content: currentBlock.join('\n').trim(),
        ));
        currentBlock = [];
        currentType = ContentType.text;
      } else if (line.trim().startsWith('```')) {
        if (currentType == ContentType.code) {
          blocks.add(ContentBlock(
            type: ContentType.code,
            content: currentBlock.join('\n').trim(),
          ));
          currentBlock = [];
          currentType = ContentType.text;
        } else {
          if (currentBlock.isNotEmpty) {
            blocks.add(ContentBlock(
              type: currentType,
              content: currentBlock.join('\n').trim(),
            ));
          }
          currentBlock = [];
          currentType = ContentType.code;
        }
      } else if (line.trim().startsWith('-') || line.trim().startsWith('*') || line.trim().startsWith('•')) {
        if (currentType != ContentType.list && currentBlock.isNotEmpty) {
          blocks.add(ContentBlock(
            type: currentType,
            content: currentBlock.join('\n').trim(),
          ));
          currentBlock = [];
        }
        currentType = ContentType.list;
        currentBlock.add(line);
      } else if (line.trim().startsWith('>')) {
        if (currentType != ContentType.quote && currentBlock.isNotEmpty) {
          blocks.add(ContentBlock(
            type: currentType,
            content: currentBlock.join('\n').trim(),
          ));
          currentBlock = [];
        }
        currentType = ContentType.quote;
        currentBlock.add(line);
      } else if (line.trim().isNotEmpty) {
        currentBlock.add(line);
      }
    }

    if (currentBlock.isNotEmpty) {
      blocks.add(ContentBlock(
        type: currentType,
        content: currentBlock.join('\n').trim(),
      ));
    }

    return blocks.where((block) => block.content.isNotEmpty).toList();
  }

  List<Color> _getSectionGradient(int index) {
    List<List<Color>> gradients = [
      [Colors.blue.shade400, Colors.blue.shade600],
      [Colors.green.shade400, Colors.green.shade600],
      [Colors.purple.shade400, Colors.purple.shade600],
      [Colors.orange.shade400, Colors.orange.shade600],
      [Colors.teal.shade400, Colors.teal.shade600],
      [Colors.indigo.shade400, Colors.indigo.shade600],
      [Colors.pink.shade400, Colors.pink.shade600],
      [Colors.amber.shade400, Colors.amber.shade600],
    ];
    return gradients[index % gradients.length];
  }

  String _generateSubtitle(String title) {
    // Generate a brief subtitle based on the title
    if (title.toLowerCase().contains('introduction')) {
      return 'Fundamental concepts and overview';
    } else if (title.toLowerCase().contains('basic') || title.toLowerCase().contains('fundamentals')) {
      return 'Core principles and foundations';
    } else if (title.toLowerCase().contains('advanced')) {
      return 'Complex topics and deep dive';
    } else if (title.toLowerCase().contains('example') || title.toLowerCase().contains('practice')) {
      return 'Hands-on examples and exercises';
    } else {
      return 'Key concepts and practical insights';
    }
  }

  void _showCodeExamples(CourseSection section) {
    _showSnackBar("Interactive code examples coming soon!");
  }

  void _showPracticeQuestions(CourseSection section) {
    _showSnackBar("Practice questions feature coming soon!");
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange.shade400, Colors.red.shade400],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _startSessionGeneration,
                  borderRadius: BorderRadius.circular(14),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.refresh, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        "Regenerate",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade400, Colors.teal.shade400],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _downloadAsPdf,
                  borderRadius: BorderRadius.circular(14),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.download, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        "Download PDF",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.deepPurple.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

// Data classes for structured content
class CourseSection {
  final String title;
  final String subtitle;
  List<ContentBlock> contentBlocks;

  CourseSection({
    required this.title,
    required this.subtitle,
    required this.contentBlocks,
  });

  int get estimatedReadTime {
    int totalWords = contentBlocks.fold(0, (sum, block) => sum + block.content.split(' ').length);
    return (totalWords / 200).ceil(); // Assuming 200 words per minute reading speed
  }

  bool get hasCodeExamples {
    return contentBlocks.any((block) => block.type == ContentType.code);
  }

  bool get hasQuizQuestions {
    return contentBlocks.any((block) =>
    block.content.toLowerCase().contains('question') ||
        block.content.toLowerCase().contains('quiz') ||
        block.content.toLowerCase().contains('exercise')
    );
  }
}

class ContentBlock {
  final ContentType type;
  final String content;

  ContentBlock({
    required this.type,
    required this.content,
  });
}

enum ContentType {
  text,
  code,
  list,
  quote,
}