// Open-source code. Copyright Mohamed Zaitoon 2025-2026.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hrmstoreapp/core/app_info.dart';
import 'package:hrmstoreapp/core/tt_colors.dart';
import '../../widgets/glass_app_bar.dart';
import '../../widgets/glass_card.dart';

class PrivacyScreen extends StatelessWidget {
  // EN: Creates PrivacyScreen.
  // AR: ينشئ PrivacyScreen.
  const PrivacyScreen({super.key});


  // EN: Sends Email.
  // AR: ترسل Email.
  Future<void> _sendEmail() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'contact@mohamedzaitoon.com',
      query: 'subject=استفسار بخصوص تطبيق ${AppInfo.appName}',
    );
    try {
      await launchUrl(emailLaunchUri);
    } catch (e) {
      debugPrint("Could not launch email: $e");
    }
  }

  // EN: Builds widget UI.
  // AR: تبني واجهة الودجت.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GlassAppBar(
        title: Text("سياسة الخصوصية"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: GlassCard(
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "نحن في \"${AppInfo.appName}\" نلتزم بحماية خصوصيتك وضمان أمان بياناتك الشخصية. توضح هذه السياسة كيفية جمعنا واستخدامنا لمعلوماتك.",
                    style: TextStyle(
                      color: TTColors.textGray,
                      fontFamily: 'Cairo',
                      height: 1.6,
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(height: 25),

                  _buildSection(
                    "1. البيانات التي نقوم بجمعها",
                    "لإتمام عملية الشحن، نحتاج إلى جمع البيانات التالية:\n"
                        "• الاسم: لتعريف صاحب الطلب.\n"
                        "• رقم الواتساب: للتواصل معك في حال وجود مشكلة في الطلب أو لإرسال التحديثات.\n"
                        "• اسم مستخدم تيك توك (User/Link): لتوجيه الدعم/النقاط للحساب الصحيح.\n"
                        "• صور إيصالات التحويل: لإثبات الدفع وإتمام العملية.",
                  ),

                  _buildSection(
                    "2. كيفية استخدام البيانات",
                    "تُستخدم بياناتك حصراً للأغراض التالية:\n"
                        "• معالجة وتنفيذ طلبات الشحن الخاصة بك.\n"
                        "• التحقق من صحة عمليات الدفع (عبر صور الإيصالات).\n"
                        "• تحسين تجربتك داخل التطبيق.\n"
                        "• لن يتم استخدام رقمك لأغراض تسويقية مزعجة.",
                  ),

                  _buildSection(
                    "3. مشاركة البيانات والأمان",
                    "نحن نتعهد بعدم بيع أو تأجير أو مشاركة بياناتك الشخصية مع أي طرف ثالث، إلا في الحالات التي يقتضيها القانون. يتم تخزين البيانات بشكل آمن ومشفر باستخدام تقنيات (Google Firebase) لضمان حمايتها.",
                  ),

                  _buildSection(
                    "4. التعامل مع صور الإيصالات",
                    "صور الإيصالات التي تقوم برفعها تُحفظ في سيرفراتنا الآمنة، ويطلع عليها فقط فريق الإدارة لغرض المراجعة والمطابقة المالية، ولا يتم عرضها للعامة.",
                  ),

                  _buildSection(
                    "5. التعديلات على السياسة",
                    "نحتفظ بالحق في تعديل سياسة الخصوصية في أي وقت. سيتم إشعار المستخدمين بأي تغييرات جوهرية عبر التطبيق.",
                  ),

                  Divider(color: Theme.of(context).dividerColor, height: 40),

                  Text(
                    "هل لديك استفسار؟",
                    style: TextStyle(
                      color: TTColors.textWhite,
                      fontFamily: 'Cairo',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    "إذا كان لديك أي أسئلة حول سياسة الخصوصية أو تحتاج إلى مساعدة، يرجى التواصل معنا عبر البريد الإلكتروني:",
                    style: TextStyle(
                      color: TTColors.textGray,
                      fontFamily: 'Cairo',
                      height: 1.6,
                    ),
                  ),

                  const SizedBox(height: 15),

                  InkWell(
                    onTap: _sendEmail,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: TTColors.cardBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: TTColors.primaryCyan.withAlpha(128),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.email, color: TTColors.goldAccent),

                          const SizedBox(width: 10),

                          Expanded(
                            child: Text(
                              "contact@mohamedzaitoon.com",
                              style: TextStyle(
                                color: TTColors.textWhite,
                                fontFamily: 'Cairo',
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),

                          Icon(
                            Icons.arrow_forward_ios,
                            color: TTColors.textGray,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  Center(
                    child: Text(
                      "© 2026 Mohamed Zaitoon. جميع الحقوق محفوظة.",
                      style: TextStyle(
                        color: TTColors.textGray,
                        fontFamily: 'Cairo',
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // EN: Builds Section.
  // AR: تبني Section.
  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: TTColors.textWhite,
              fontFamily: 'Cairo',
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            content,
            style: TextStyle(
              color: TTColors.textGray,
              fontFamily: 'Cairo',
              height: 1.6,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
