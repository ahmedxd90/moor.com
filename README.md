# Saki Chat — Flutter + Supabase

تطبيق Flutter/Dart عربي باتجاه RTL. يعتمد التطبيق الآن على **Supabase** للمصادقة والملف الشخصي والوسائط والبيانات والعمليات المالية داخل التطبيق؛ ولا يستدعي PHP من مسارات Flutter. ملفات `backend/php/` باقية في المستودع كمرجع قديم فقط، ولا تُشغّل على قاعدة Supabase.

## ما هو موصول بـSupabase

- **Supabase Auth:** تسجيل البريد وكلمة المرور، تسجيل Google OAuth، استعادة كلمة المرور، ومزامنة حالة الجلسة مع التطبيق.
- **الملف الشخصي:** بيانات المستخدم في `user_profiles.data`، تخصيص `saki_id`، وصور المستخدمين في bucket `user-media` بسياسات RLS.
- **ميزات التطبيق:** الغرف والرسائل واللحظات والمحفظة والتفاعلات التي يستهلكها Flutter من جداول Supabase وRPCs القائمة.
- **الأرستقراطية:** صفحة Flutter أصلية بدلاً من WebView/PHP. يوجد 6 رتب و48 ميزة seed، وجداول للرتب والعضوية والمشتريات وسجل الذهب. شراء الرتبة يتم عبر RPC ذرية `purchase_aristocracy` تُخصم من `room_wallets` بعد فحص الرصيد والصلاحيات، مع idempotency وRLS.
- **Agora:** Edge Function باسم `agora-token` منشورة في Supabase وتتطلب JWT. شهادة Agora لا توضع في APK.

الأصول الثابتة للواجهة والخطوط والشارات تبقى ضمن `assets/` ومضمّنة في APK؛ لا يلزم رفعها إلى Storage. يُستخدم Supabase Storage لملفات المستخدمين التي يضيفها التطبيق.

## مشروع Supabase المرتبط

المشروع المرتبط هو `Saki chat`، المعرّف `faxtmvvovorxximsnxzy`. إعداد Flutter الافتراضي في `lib/core/config/app_config.dart` يستخدم URL المشروع ومفتاح publishable عام؛ لا تضف مطلقًا `service_role` أو أي سر في التطبيق أو GitHub.

تسلسل التهيئة المسجل في المشروع يتضمن migrations الأساسية للمستخدمين والغرف والتفاعلات والمحفظة واللحظات، ثم:

- `0011_restrict_sensitive_rpcs.sql` — قصر RPCs الحساسة على المستخدمين المسجلين وإبقاء دوال المحفزات داخلية.
- `0012_aristocracy_supabase.sql` — مخطط الأرستقراطية وبيانات الرتب والميزات وRLS وRPC شراء الذهب.

تأكد من تشغيل migrations بالترتيب على أي بيئة جديدة. في مشروع Supabase الحالي طُبقت migration `aristocracy_supabase_v1`، وتحققنا من وجود 6 صفوف للرتب و48 صفًا للميزات.

## إعدادات مطلوبة قبل اختبار الخدمات الخارجية

### Google OAuth والبريد

مسار OAuth الأصلي موجود. أظهر فحص إعدادات Supabase العامة أن مزوّدي البريد وGoogle مفعّلان، كما قبل endpoint التفويض رابط الرجوع وأعاد توجيهًا إلى Google. لم يُكمل تسجيل دخول مستخدم فعلي من جهاز، لذا تأكد من صلاحية OAuth Client وتهيئة شاشة الموافقة في Google Cloud. استخدم callback التالي لـGoogle Cloud وأضف مخطط التطبيق إلى قائمة Redirect URLs في Supabase:

```text
https://faxtmvvovorxximsnxzy.supabase.co/auth/v1/callback
saki.chat.co://login-callback
```

يجب كذلك إعداد قالب/بريد SMTP في Supabase لإرسال تأكيد الحساب وروابط استعادة كلمة المرور بصورة موثوقة. لا ترسل الأسرار في المحادثة ولا تضعها داخل APK.

### Agora للغرف الصوتية

الوظيفة المنشورة تحتاج ضبط الأسرار في إعدادات Supabase Edge Functions/Secrets:

```text
AGORA_APP_ID=<Agora App ID المطابق للقيمة المستخدمة في Flutter>
AGORA_APP_CERTIFICATE=<Agora App Certificate>
```

من دون `AGORA_APP_CERTIFICATE` سترجع الوظيفة `agora_server_not_configured`؛ لم نضع شهادة سرية في التطبيق. بعد ضبط الأسرار اختبر إصدار token والانضمام من جهاز Android فعلي.

### أرصدة وشحن الذهب

شراء الأرستقراطية يعمل من رصيد `room_wallets`، ويمكن اختبار الرتبة الأرخص بعد مطالبة الذهب المجاني المتاحة يوميًا. إنشاء طلبات top-up ليس بوابة دفع: لا يوجد مزود دفع أو webhook مفعل في المستودع، ولذلك لا تعتبر حزم الشحن مدفوعات حقيقية حتى إضافة مزود موثوق والتحقق من إشعاراته على الخادم.

## تشغيل وفحص التطبيق

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

تجاوز إعداد Supabase الافتراضي عند الحاجة:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

## بناء Android

```bash
flutter build apk --release
```

ملف الناتج المعتاد:

```text
build/app/outputs/flutter-apk/app-release.apk
```

إعداد release الحالي موقّع بمفتاح debug لأغراض الاختبار والتثبيت المباشر فقط. يلزم keystore release خاص وتوقيع صحيح قبل النشر في Google Play.
