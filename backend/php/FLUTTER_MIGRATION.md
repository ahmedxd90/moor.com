# Flutter migration status

تمت إضافة `SakiApiClient` وربط `AuthRepository` مع PHP/MySQL في الإصدار الحالي.

## تم تحويله

- تسجيل الدخول عبر `login`.
- إنشاء الحساب عبر `register`.
- حفظ جلسة الخادم في `SharedPreferences`.
- قراءة الملف الشخصي عبر `profile_me`.
- تحديث الملف الشخصي عبر `profile_update`.
- رفع الصورة عبر `avatar_upload`.
- تسجيل الخروج بحذف الجلسة المحلية وإبطالها في المرحلة التالية.

## ما يزال في التحويل التالي

- `RoomsRepository` و`MessagesRepository` و`WalletRepository` و`MomentsRepository` ما زالت تستخدم Supabase مؤقتًا.
- Realtime للرسائل والحضور يحتاج polling مضبوطًا أو WebSocket على الاستضافة.
- الصوت Agora ينتظر `app_id` و`app_certificate` على الخادم.
- Google OAuth وSMTP لاستعادة كلمة المرور غير مفعّلين.

لا تعتبر هذه المرحلة إصدار APK نهائيًا؛ هي طبقة انتقالية قابلة للاختبار قبل نقل كل الوحدات إلى API PHP/MySQL.
