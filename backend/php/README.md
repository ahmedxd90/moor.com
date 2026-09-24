# Saki PHP/MySQL backend

هذا المجلد يحفظ مصدر الـ API المنشور على `https://sakichat.freecpanel.shop/` حتى تكون تحديثاته قابلة للمراجعة والاسترجاع عبر GitHub.

## الملفات

- `api.php`: نقطة API الحالية، وتستخدم جلسات JWT مخزنة كـ SHA-256 داخل MySQL.
- `saki-config.example.php`: قالب إعدادات؛ القيم الحقيقية تبقى على الخادم ولا تُرفع إلى GitHub.
- `.htaccess`: يمنع فهرسة ملفات الموقع ويمنع تشغيل PHP داخل مجلد الرفع.

## إجراءات API الحالية

المصادقة: `health`, `register`, `login`, `logout`, `me`, `profile_me`, `profile_update`, `avatar_upload`.

الغرف والدردشة: `rooms`, `room`, `room_create`, `room_join`, `room_leave`, `room_members`, `room_messages`, `room_message_send`, `room_settings_update`, `room_presence`, `seat_claim`, `seat_leave`.

المحتوى والحساب: `posts_feed`, `post_create`, `post_like_toggle`, `post_comments`, `post_comment_create`, `follow_toggle`, `wallet`, `store_products`, `store_buy`, `luck_bag_create`, `luck_bag_claim`, `agora_token`.

تُراجع أسماء الإجراءات مع طبقة Flutter قبل تحويل كل مستودع من Supabase إلى هذا الـ API.

## النشر

1. ضع `saki-config.php` في جذر `public_html` عبر cPanel، مع صلاحيات 0600 إن كانت الاستضافة تسمح.
2. لا ترفع `saki-config.php` إلى GitHub.
3. فعّل HTTPS فقط.
4. اختبر `health.php`، ثم سجّل مستخدمًا تجريبيًا، ثم اختبر `login` و`me`.
5. لا تُفعّل المدفوعات الحقيقية قبل إضافة مزود دفع موثق والتحقق من webhook.

## المصادقة

إرسال الرمز يكون عبر:

```http
Authorization: Bearer <session-token>
```

ويُحفظ الرمز محليًا في Flutter داخل تخزين آمن، ولا يُطبع في السجلات.
