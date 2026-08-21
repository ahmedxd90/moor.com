# Saki Chat Flutter

هذه النسخة هي إعادة بناء أولية لتطبيق Saki Chat باستخدام **Flutter/Dart** وقاعدة **Supabase جديدة**. لا تعتمد النسخة على بيانات Convex القديمة؛ تبدأ من قاعدة فارغة وتحتوي على migration منظمة للجداول الأساسية.

## ما تم بناؤه

تم إنشاء أساس قابل للتشغيل يتضمن اتجاه RTL، الثيم الداكن، لوحة الألوان المستخرجة من المشروع الأصلي، الأصول البصرية الرئيسية، تسجيل الدخول والتسجيل عبر Supabase Auth، الصفحة الرئيسية، بطاقات الغرف، الانضمام والمغادرة، شاشة الغرفة الصوتية الأساسية، رسائل الغرفة عبر Supabase Realtime، صفحة اللحظات، الرسائل الخاصة الأساسية، والملف الشخصي.

المشروع يعمل افتراضيًا بوضع معاينة عندما لا تكون بيانات Supabase موجودة. هذا يسمح بمراجعة الواجهة دون إنشاء حساب أو قاعدة بيانات. عند إضافة قيم Supabase يتحول التطبيق إلى الوضع الحقيقي تلقائيًا.

## تشغيل المعاينة

```bash
flutter pub get
flutter run -d chrome
```

## إنشاء قاعدة Supabase جديدة

أنشئ مشروعًا فارغًا من لوحة Supabase، ثم نفّذ الملف التالي من SQL Editor أو عبر Supabase CLI:

```text
supabase/migrations/0001_initial_schema.sql
```

يحتوي الملف على جداول `profiles` و`rooms` و`room_members` و`room_presence` و`room_seats` و`room_messages` و`direct_messages` و`moments` و`reels` و`stories` و`store_items` و`video_calls` وغيرها، إضافة إلى سياسات RLS وStorage buckets الأساسية.

بعد ذلك شغّل التطبيق باستخدام رابط المشروع والمفتاح العام:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

لا تضع `service_role` key داخل تطبيق الهاتف. تطبيق الهاتف يستخدم المفتاح العام فقط، بينما العمليات الإدارية أو المالية الحساسة يجب أن تُنفذ لاحقًا داخل Edge Functions أو PostgreSQL RPC محمية.

## Realtime وStorage

بعد تنفيذ الـ migration، فعّل Postgres Changes للجداول التي تحتاج تحديثًا فوريًا من لوحة Supabase أو نفّذ أوامر `alter publication` المعلّقة في نهاية ملف migration. يجب مراجعة سياسات RLS قبل استخدام التطبيق في الإنتاج، خصوصًا للجداول المالية، الهدايا، الإدارة، والبث.

## التحقق

```bash
dart format lib
flutter analyze
flutter build web --release
```

## هيكل المشروع

```text
lib/
  core/
    config/       إعدادات dart-define
    supabase/     تهيئة العميل
    theme/        الألوان والثيم
    widgets/      مكونات الواجهة المشتركة
  features/
    auth/         تسجيل الدخول والتسجيل
    home/         الحاوية الرئيسية والصفحة الرئيسية
    rooms/        الغرف والمقاعد
    messages/     رسائل الغرفة والرسائل الخاصة
    moments/      اللحظات والمنشورات
    profile/      الملف الشخصي
supabase/
  migrations/    مخطط قاعدة Supabase الجديدة وسياسات RLS
assets/
  images/        شعار وأصول عامة
  levels/        شارات المستويات
```

## النطاق اللاحق

المشروع الأصلي كبير ويحتوي على ألعاب متعددة، Agora/Zego، مكالمات فيديو، الإشعارات، المدفوعات، الهدايا، الإدارة، العائلات، VIP/PRO، والبث المباشر. هذه الوحدات تحتاج مراحل مستقلة وتكاملات Flutter أصلية، لذلك لم يتم اختصارها بواجهات وهمية داخل migration الأولى. سيتم إضافتها فوق هذا الأساس مع الحفاظ على نفس الهوية البصرية.

## مراجع تقنية

يوصى بمراجعة [دليل Supabase Flutter الرسمي][1] و[مرجع supabase_flutter][2] و[إرشادات RLS الرسمية][3] قبل نشر قاعدة البيانات. يوضح دليل Supabase أن تطبيقات Flutter تهيئ العميل باستخدام عنوان المشروع والمفتاح العام، وأن الجداول المكشوفة يجب حمايتها بسياسات RLS. كما يوضح مرجع Realtime ضرورة ضبط قنوات Realtime وسياسات `realtime.messages` عند استخدام القنوات الخاصة.

[1]: https://supabase.com/docs/guides/getting-started/quickstarts/flutter "Supabase Flutter Quickstart"
[2]: https://supabase.com/docs/reference/dart/introduction "Supabase Flutter Client Reference"
[3]: https://supabase.com/docs/guides/database/postgres/row-level-security "Supabase Row Level Security"
