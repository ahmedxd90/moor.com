-- SAKI Aristocracy membership: execute once on the cPanel MySQL database.
CREATE TABLE IF NOT EXISTS aristocracy_levels (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  slug VARCHAR(40) NOT NULL UNIQUE,
  name_ar VARCHAR(80) NOT NULL,
  color_primary CHAR(7) NOT NULL DEFAULT '#E9B949',
  color_secondary CHAR(7) NOT NULL DEFAULT '#6B3D12',
  icon_url VARCHAR(500) NULL,
  price_gold BIGINT UNSIGNED NOT NULL,
  duration_days SMALLINT UNSIGNED NOT NULL DEFAULT 30,
  sort_order SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS aristocracy_features (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  level_id INT UNSIGNED NOT NULL,
  feature_key VARCHAR(80) NOT NULL,
  name_ar VARCHAR(120) NOT NULL,
  description_ar VARCHAR(255) NOT NULL DEFAULT '',
  icon VARCHAR(40) NOT NULL DEFAULT '✦',
  sort_order SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  CONSTRAINT fk_aristocracy_features_level FOREIGN KEY (level_id) REFERENCES aristocracy_levels(id) ON DELETE CASCADE,
  UNIQUE KEY uq_aristocracy_feature (level_id, feature_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS user_aristocracy (
  user_id VARCHAR(64) NOT NULL PRIMARY KEY,
  level_id INT UNSIGNED NOT NULL,
  started_at DATETIME NOT NULL,
  expires_at DATETIME NOT NULL,
  purchase_id CHAR(32) NOT NULL,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT fk_user_aristocracy_level FOREIGN KEY (level_id) REFERENCES aristocracy_levels(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS aristocracy_purchases (
  id CHAR(32) NOT NULL PRIMARY KEY,
  request_id CHAR(64) NOT NULL UNIQUE,
  user_id VARCHAR(64) NOT NULL,
  level_id INT UNSIGNED NOT NULL,
  price_gold BIGINT UNSIGNED NOT NULL,
  duration_days SMALLINT UNSIGNED NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_aristocracy_purchase_level FOREIGN KEY (level_id) REFERENCES aristocracy_levels(id),
  INDEX idx_aristocracy_purchase_user (user_id, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS saki_gold_ledger (
  id CHAR(32) NOT NULL PRIMARY KEY,
  user_id VARCHAR(64) NOT NULL,
  amount BIGINT NOT NULL,
  balance_after BIGINT UNSIGNED NOT NULL,
  reason VARCHAR(80) NOT NULL,
  reference_id CHAR(32) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_gold_ledger_user (user_id, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO aristocracy_levels (slug,name_ar,color_primary,color_secondary,price_gold,duration_days,sort_order)
VALUES
 ('knight','الفارس','#8ED8FF','#315B91',30000,30,1),
 ('commander','القائد','#FF9A58','#8E3319',60000,30,2),
 ('prince','الأمير','#B69CFF','#4D2D9A',120000,30,3),
 ('legend','الأسطورة','#FF8AD8','#841F6D',240000,30,4),
 ('emperor','الإمبراطور','#FFD978','#7C4B17',500000,30,5),
 ('king','الملك','#FFE9A6','#A35B00',1000000,30,6)
ON DUPLICATE KEY UPDATE name_ar=VALUES(name_ar),price_gold=VALUES(price_gold),duration_days=VALUES(duration_days),is_active=1;

INSERT INTO aristocracy_features (level_id,feature_key,name_ar,description_ar,icon,sort_order)
SELECT l.id, f.feature_key, f.name_ar, f.description_ar, f.icon, f.sort_order
FROM aristocracy_levels l
JOIN (SELECT 'medal' feature_key,'وسام بجانب الاسم' name_ar,'يظهر بجانب اسمك في التطبيق' description_ar,'✦' icon,1 sort_order UNION ALL
      SELECT 'frame','إطار صورة شخصية','إطار فاخر لصورتك في البروفايل','◈',2 UNION ALL
      SELECT 'colored_name','اسم ملون','اسمك يظهر بلون الرتبة','A',3 UNION ALL
      SELECT 'profile_card','بطاقة بروفايل خاصة','خلفية وبطاقة تعريف حصرية','▣',4 UNION ALL
      SELECT 'chat_bubble','فقاعة دردشة','نمط خاص للرسائل داخل الغرف','◌',5 UNION ALL
      SELECT 'room_entry','دخول الغرفة','تأثير دخول يظهر للمستخدمين','↗',6 UNION ALL
      SELECT 'exclusive_gifts','هدايا حصرية','الوصول إلى هدايا الرتبة','◇',7 UNION ALL
      SELECT 'bullet_screen','تعليقات طائرة','تأثير تعليقات مميز','≋',8) f
WHERE l.slug IN ('knight','commander','prince','legend','emperor','king')
ON DUPLICATE KEY UPDATE name_ar=VALUES(name_ar),description_ar=VALUES(description_ar),icon=VALUES(icon);
