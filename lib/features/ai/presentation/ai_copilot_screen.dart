import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../domain/ai_mock_data.dart';
import 'widgets/academic_resource_card.dart';

class AiCopilotScreen extends StatefulWidget {
  const AiCopilotScreen({super.key, this.initialPrompt});

  final String? initialPrompt;

  @override
  State<AiCopilotScreen> createState() => _AiCopilotScreenState();
}

class _AiCopilotScreenState extends State<AiCopilotScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<AiMessage> _messages = [];
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _messages.addAll(AiMockData.getInitialMessages());

    if (widget.initialPrompt != null && widget.initialPrompt!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleSubmitted(widget.initialPrompt!);
      });
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSubmitted(String text) {
    final query = text.trim();
    if (query.isEmpty || _isTyping) return;

    _textController.clear();
    setState(() {
      _messages.add(
        AiMessage(
          id: 'user_${DateTime.now().millisecondsSinceEpoch}',
          isUser: true,
          text: query,
          timestamp: DateTime.now(),
        ),
      );
      _isTyping = true;
    });
    _scrollToBottom();

    // Realistic typing / thinking delay for prototype demo
    Timer(const Duration(milliseconds: 700), () {
      if (!mounted) return;

      final lower = query.toLowerCase();
      AiMessage matchedResponse;

      if (lower.contains('hindi') || lower.contains('normaliz')) {
        matchedResponse = AiMockData.hindiNormalizationResponse;
      } else if (lower.contains('3nf') ||
          lower.contains('bcnf') ||
          lower.contains('differen')) {
        matchedResponse = AiMockData.bcnfComparisonResponse;
      } else if (lower.contains('acid') || lower.contains('transact')) {
        matchedResponse = AiMessage(
          id: 'resp_acid_${DateTime.now().millisecondsSinceEpoch}',
          isUser: false,
          timestamp: DateTime.now(),
          text: '''### 🔄 ACID Properties in DBMS (Banking Exam Model)

Database transactions में **ACID Properties** डेटा की सटीकता और विश्वसनीयता बनाए रखने के 4 मूलभूत नियम हैं:

1. **Atomicity (परमाणुता — "All or Nothing")**:
   - या तो पूरा transaction सफल होगा, या फिर zero change के साथ rollback होगा।
   - *Example*: राहुल के बैंक खाते से ₹1000 कटे, तो दूसरे खाते में जुड़ने ही चाहिए। यदि सर्वर बीच में क्रैश हुआ तो ₹1000 वापस राहुल के खाते में लौटेंगे।

2. **Consistency (संगति)**:
   - Transaction से पहले और बाद में Database Valid State में रहना चाहिए। Balance कभी negative नहीं हो सकता।

3. **Isolation (एकाकीपन)**:
   - Multiple transactions एक साथ चलें तो भी ऐसा लगना चाहिए कि वे एक के बाद एक (serially) चल रहे हैं। Concurrency Control (Locks & Timestamps) इसे संभालते हैं।

4. **Durability (स्थायित्व)**:
   - एक बार Transaction commit हो गया, तो बिजली जाने या सिस्टम क्रैश होने पर भी डेटा सुरक्षित रहेगा (Write-Ahead Logging).''',
          resources: [AiMockData.noteNormalization, AiMockData.pyqNormalization],
        );
      } else {
        // Fallback default helpful curriculum-aware answer
        matchedResponse = AiMockData.hindiNormalizationResponse;
      }

      setState(() {
        _isTyping = false;
        _messages.add(matchedResponse);
      });
      _scrollToBottom();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'AI Academic Copilot',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Color(0xFF16A34A),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  'CSE • Sem 5 • DBMS (CS501) Aligned',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.textTheme.bodySmall?.color,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Skill-Gap Analyzer',
            onPressed: () => context.push('/ai/skill-gap'),
            icon: const Icon(Icons.analytics_outlined),
          ),
          IconButton(
            tooltip: 'Reset Conversation',
            onPressed: () {
              setState(() {
                _messages.clear();
                _messages.addAll(AiMockData.getInitialMessages());
              });
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ResponsiveLayout(
        maxWidthDesktop: 880,
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            // Curriculum Context & Quick Prompts Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.05),
                border: Border(
                  bottom: BorderSide(
                    color: primaryColor.withValues(alpha: 0.15),
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        size: 14,
                        color: primaryColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Demo Quick Prompts (Tap to ask):',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: AiMockData.quickPrompts.map((prompt) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            label: Text(
                              prompt,
                              style: const TextStyle(fontSize: 12),
                            ),
                            backgroundColor: theme.colorScheme.surface,
                            side: BorderSide(
                              color: primaryColor.withValues(alpha: 0.3),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            onPressed: () => _handleSubmitted(prompt),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),

            // Chat Messages List
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length + (_isTyping ? 1 : 0),
                itemBuilder: (context, index) {
                  if (_isTyping && index == _messages.length) {
                    return _buildTypingIndicator(theme, primaryColor);
                  }
                  final msg = _messages[index];
                  return _buildMessageTile(msg, theme, primaryColor);
                },
              ),
            ),

            // Message Input Box
            _buildInputArea(theme, primaryColor),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator(ThemeData theme, Color primaryColor) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor),
          ),
          const SizedBox(width: 10),
          Text(
            'Academix AI is reviewing DBMS syllabus & lecture notes...',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageTile(AiMessage msg, ThemeData theme, Color primaryColor) {
    if (msg.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          constraints: const BoxConstraints(maxWidth: 520),
          decoration: BoxDecoration(
            color: primaryColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Text(
            msg.text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primaryColor.withValues(alpha: 0.15),
              border: Border.all(
                color: primaryColor.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Icon(Icons.auto_awesome_rounded, size: 18, color: primaryColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                  bottomRight: Radius.circular(18),
                ),
                border: Border.all(
                  color: theme.dividerColor.withValues(alpha: 0.15),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _formatAiText(msg.text, theme),

                  // Weakness identified alert card
                  if (msg.highlightGapAction) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFDC2626).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: Color(0xFFDC2626),
                                size: 18,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'AI Skill-Gap Insight Detected',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12.5,
                                  color: Color(0xFFDC2626),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Your latest assessment shows a 41% gap in Normalization candidate keys. Closing this gap is recommended for your end-sem target.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 11.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFDC2626),
                                side: const BorderSide(color: Color(0xFFDC2626)),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                              ),
                              onPressed: () => context.push('/ai/skill-gap'),
                              icon: const Icon(
                                Icons.insights_rounded,
                                size: 16,
                              ),
                              label: const Text(
                                'View Skill-Gap Diagnostics →',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Recommended Academix resources
                  if (msg.resources.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(
                          Icons.folder_special_rounded,
                          size: 16,
                          color: primaryColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Recommended Academix Resources',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ...msg.resources.map(
                      (res) => AcademicResourceCard(resource: res),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _formatAiText(String text, ThemeData theme) {
    // Clean formatted typography view for mock prototype
    return SelectableText(
      text,
      style: theme.textTheme.bodyMedium?.copyWith(
        fontSize: 13.8,
        height: 1.55,
      ),
    );
  }

  Widget _buildInputArea(ThemeData theme, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.15)),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _textController,
                textInputAction: TextInputAction.send,
                onSubmitted: _handleSubmitted,
                decoration: InputDecoration(
                  hintText: 'Ask any question in English or Hindi...',
                  hintStyle: const TextStyle(fontSize: 13.5),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                      color: primaryColor.withValues(alpha: 0.3),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                      color: primaryColor.withValues(alpha: 0.25),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: primaryColor, width: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: primaryColor,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                tooltip: 'Send question',
                icon: const Icon(
                  Icons.arrow_upward_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: () => _handleSubmitted(_textController.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
