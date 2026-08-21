
## نتائج Agora الرسمية — 21 أغسطس 2026

- Agora توصي بخادم Token داخل البنية الأمنية، ولا يجوز وضع App Certificate داخل تطبيق العميل.
- AccessToken2 ديناميكي وصالح لمدة أقصاها 24 ساعة، ويمكن للخادم إصدار صلاحية أقصر حسب الغرفة والمستخدم.
- العميل يطلب Token من الخادم عند محاولة دخول القناة.
- يستدعي SDK حدث `onTokenPrivilegeWillExpire` قبل انتهاء التوكن بـ 30 ثانية، ويجب عندها طلب Token جديد من الخادم ثم استدعاء `renewToken`.
- عند انتهاء التوكن يمكن أن يظهر `onRequestToken`، ويجب تجديده أو إعادة الانضمام.
- دليل Agora يذكر App ID وApp Certificate الناتج بعد تفعيل Primary Certificate كمتطلبات للخادم.
- خياران بنيويان مناسبان: Supabase Edge Function دائمة كعنوان API مُدار دون خادم يُدار يدويًا، أو خدمة Node/Go دائمة على استضافة 24/7. الخادم المحجوز المُدار يعمل 24/7 لكنه محدود بـ 1 vCPU و512 MB وتكلفته القصوى النظرية نحو 37.50 دولارًا شهريًا قبل رصيد الاستخدام البالغ 10 دولارات، إضافة إلى نقل البيانات.

المراجع:
- https://docs.agora.io/en/realtime-media/rtc/build/authenticate-users/deploy-token-server
- https://docs.agora.io/en/realtime-media/rtc/build/authenticate-users/authentication-workflow
- https://docs.agora.io/en/realtime-media/rtc/build/authenticate-users/integrate-token-generation
