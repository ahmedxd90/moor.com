# Saki Chat Flutter

هذه النسخة هي إعادة بناء أولية لتطبيق Saki Chat باستخدام **Flutter/Dart** وقاعدة **Supabase جديدة**. لا تعتمد النسخة على بيانات Convex القديمة؛ تبدأ من قاعدة فارغة وتحتوي على migration منظمة للجداول الأساسية.

## ما تم بناؤه

تم إنشاء أساس قابل للتشغيل يتضمن اتجاه RTL، ثيمًا فاتحًا برتقاليًا وأبيض، خط Tajawal، الأصول البصرية الرئيسية، تسجيل الدخول والتسجيل عبر Supabase Auth، الصفحة الرئيسية، بطاقات الغرف، الانضمام والمغادرة، شاشة الغرفة الصوتية الأساسية، رسائل الغرفة عبر Supabase Realtime، صفحة اللحظات، الرسائل الخاصة الأساسية، والملف الشخصي.

المشروع يعمل افتراضيًا بوضع معاينة عندما لا تكون بيانات Supabase موجودة. هذا يسمح بمراجعة الواجهة دون إنشاء حساب أو قاعدة بيانات. عند إضافة قيم Supabase يتحول التطبيق إلى الوضع الحقيقي تلقائيًا. شاشة «أكمل معلوماتك» تحتوي فقط على صورة المستخدم واسم المستخدم والجنس والدولة؛ أما `saki_id` فيُولد ويحفظ في قاعدة البيانات ولا يظهر في هذه الشاشة.

## تشغيل المعاينة

```bash
flutter pub get
flutter run -d chrome
```

## مشروع Supabase المرتبط

المشروع المرتبط حاليًا هو `uhaugikrudchlunaufjj`، وتوجد فيه migrations ومخطط Saki الأساسي مسبقًا. تستخدم النسخة الحالية الجداول الموجودة مثل `user_profiles` و`voice_rooms` و`voice_room_members` و`posts` و`stories` و`conversations` و`messages`؛ لا تُشغّل migration bootstrap ثانية فوق هذا المشروع حتى لا تتكرر الجداول.

بعد ذلك شغّل التطبيق باستخدام رابط المشروع والمفتاح العام:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

لا تضع `service_role` key داخل تطبيق الهاتف. تطبيق الهاتف يستخدم المفتاح العام فقط، بينما العمليات الإدارية أو المالية الحساسة يجب أن تُنفذ لاحقًا داخل Edge Functions أو PostgreSQL RPC محمية.

Migration `0002_saki_id.sql` تضيف `saki_id` كرقم فريد من 9 أرقام يبدأ من `876431253` وتوفر RPC باسم `ensure_my_saki_id`. Migration `0003_user_media_storage.sql` تنشئ bucket باسم `user-media` وسياسات تسمح للمستخدم برفع ملفاته داخل مجلده فقط.

## المصادقة بالبريد وGoogle

المسار الحقيقي هو: تسجيل الدخول أو إنشاء حساب بالبريد وكلمة المرور، ثم فحص `user_profiles`. إذا لم يكن الملف مكتملًا تُفتح شاشة «أكمل معلوماتك»، وبعد الحفظ تُفتح الصفحة الرئيسية تلقائيًا.

لتفعيل Google Provider في Supabase، أنشئ OAuth Client من نوع Web في Google Cloud، ثم أضف Client ID وClient Secret داخل Supabase Auth > Providers > Google. أضف رابط callback الخاص بالمشروع في Google Cloud، وأضف روابط التطبيق إلى قائمة Redirect URLs في Supabase:

```text
https://uhaugikrudchlunaufjj.supabase.co/auth/v1/callback
https://8080-i4cnwrwg7od5jc89wmu3y-5b008138.sg1.manus.computer
saki.chat.co://login-callback
```

رابط اختبار الويب الحالي هو [Saki Chat Web](https://8080-i4cnwrwg7od5jc89wmu3y-5b008138.sg1.manus.computer). عند بناء نسخة أخرى استخدم `--dart-define=SUPABASE_AUTH_REDIRECT=<your-web-origin>` إذا كان رابط الويب مختلفًا.

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
    auth/         تسجيل الدخول والتسجيل وإكمال المعلومات
    home/         الحاوية الرئيسية والصفحة الرئيسية
    rooms/        الغرف والمقاعد
    messages/     رسائل الغرفة والرسائل الخاصة
    moments/      اللحظات والمنشورات
    profile/      الملف الشخصي
supabase/
  migrations/    ملاحظات التكامل؛ مخطط المشروع موجود مسبقًا على Supabase
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
[4]: https://supabase.com/docs/guides/auth/social-login/auth-google "Supabase Google OAuth"
[5]: https://supabase.com/docs/guides/auth/native-mobile-deep-linking "Supabase Native Deep Linking"
