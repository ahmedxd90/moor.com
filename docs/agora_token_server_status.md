# حالة خادم Agora الدائم

## الحالة الحالية

تم نشر Edge Function دائمة باسم `agora-token` في مشروع Supabase `uhaugikrudchlunaufjj`. الخادم يعمل بعنوان:

`https://uhaugikrudchlunaufjj.supabase.co/functions/v1/agora-token`

الدالة في حالة `ACTIVE`، وتطلب JWT صالحًا من Supabase قبل إصدار أي Token. تم وضع `AGORA_APP_ID` و`AGORA_APP_CERTIFICATE` كأسرار إنتاج في Supabase، ولا توجد قيمة Primary Certificate داخل Flutter أو APK أو GitHub.

## آلية العمل

عند دخول مستخدم إلى غرفة، يطلب تطبيق Flutter توكنًا جديدًا من الدالة الدائمة ويرسل اسم قناة الغرفة. يصدر الخادم AccessToken2 بصلاحية ساعة واحدة مع صلاحية الانضمام والنشر الصوتي. مدة التوكن ليست مدة الخادم؛ الخادم دائم، أما انتهاء التوكن القصير فهو إجراء أمني طبيعي.

قبل انتهاء التوكن بثلاثين ثانية يستدعي Agora callback داخل التطبيق، فيطلب Flutter توكنًا جديدًا من الخادم ويستدعي `renewToken`. كما يعالج التطبيق callback انتهاء التوكن. يبدأ المستخدم كمستمع، ولا يطلب التطبيق صلاحية الميكروفون إلا بعد أخذ مقعد، ثم يتحول إلى متحدث، ويعود إلى مستمع عند النزول من المقعد.

## التحقق

| الاختبار | النتيجة |
|---|---|
| حالة Edge Function | `ACTIVE`، الإصدار 1، وJWT verification مفعّل |
| طلب بدون Authorization | مرفوض HTTP 401 من بوابة Supabase |
| تحليل Dart | ناجح بلا أخطاء |
| اختبارات Flutter | ناجحة بالكامل |
| بناء Web | ناجح |
| بناء Android Debug | ناجح |
| اختبار صوت بين جهازين فعليين | يحتاج حسابين وجهازين متصلين في الوقت نفسه؛ لم يُنفذ تلقائيًا داخل بيئة البناء |

## التشغيل اليدوي

يجب إبقاء السرّين في Supabase فقط تحت الأسماء `AGORA_APP_ID` و`AGORA_APP_CERTIFICATE`. إذا تم تدوير Primary Certificate من Agora، يتم تحديث قيمة السرّ في Supabase فقط؛ لا يحتاج تطبيق Flutter إلى تضمين الشهادة الجديدة. يجب إعادة بناء التطبيق عند تغيير App ID، لأن App ID العام مضمّن في إعدادات العميل.

## المراجع

[1]: https://docs.agora.io/en/realtime-media/rtc/build/authenticate-users/deploy-token-server "Agora — Deploy a token server"

[2]: https://docs.agora.io/en/realtime-media/rtc/build/authenticate-users/authentication-workflow "Agora — Use tokens and renewToken"

[3]: https://supabase.com/docs/guides/functions/secrets "Supabase — Edge Function secrets"
