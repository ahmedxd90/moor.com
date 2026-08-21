# نتائج التحقق من Agora

- وثائق Agora الرسمية: https://docs.agora.io/en/realtime-media/rtc/get-started-sdk
- حزمة Flutter الرسمية على pub.dev: https://pub.dev/packages/agora_rtc_engine
- الإصدار الظاهر وقت الفحص: agora_rtc_engine 6.6.3.
- المنصات الظاهرة للحزمة: Android وiOS وmacOS وWeb وWindows.
- تدفق التهيئة الرسمي يتطلب إنشاء RtcEngine باستخدام App ID، ثم طلب صلاحية RECORD_AUDIO، ثم الانضمام إلى channel باسم ثابت لكل غرفة مع token عند تفعيل المصادقة.
- وثائق Agora توصي باستخدام Token في بيئة الإنتاج؛ App ID وحده مناسب فقط إذا كان مشروع Agora مضبوطًا دون Token أو للاختبار وفق إعدادات المشروع.
- المستخدم قدم App ID فقط: 0d1e69abe9734f03944293c27b74365d. لم يتم تقديم App Certificate أو خدمة Token Server، لذلك سيُنفذ التطبيق Token اختياريًا عبر dart-define، مع إظهار حالة واضحة إذا رفضت Agora الانضمام بسبب Token.
- الدليل الرسمي يذكر أن دور المضيف ينشر الصوت، ودور المستمع يستقبل الصوت؛ لذلك دخول الغرفة سيظل Listener ولا يُفعّل الميكروفون أو مقعد التحدث إلا بعد اختيار مقعد.
