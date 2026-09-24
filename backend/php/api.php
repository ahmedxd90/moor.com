<?php
$config = require __DIR__ . '/saki-config.php';
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Access-Token');
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(204); exit; }
function respond(array $payload, int $status = 200): never { http_response_code($status); echo json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES); exit; }
function body(): array { $raw = file_get_contents('php://input'); $data = json_decode($raw ?: '{}', true); return is_array($data) ? $data : []; }
function bearer(): ?string {
  $h = $_SERVER['HTTP_AUTHORIZATION'] ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '';
  if ($h === '' && !empty($_SERVER['HTTP_X_ACCESS_TOKEN'])) { $h = 'Bearer ' . $_SERVER['HTTP_X_ACCESS_TOKEN']; }
  if ($h === '' && function_exists('getallheaders')) { $headers = getallheaders(); $h = $headers['Authorization'] ?? $headers['authorization'] ?? ''; }
  if (preg_match('/^Bearer\s+(.+)$/i', $h, $m)) return trim($m[1]);
  $q=$_GET['access_token'] ?? '';
  return is_string($q) && $q !== '' ? trim($q) : null;
}
try { $pdo = new PDO("mysql:host={$config['db_host']};dbname={$config['db_name']};charset=utf8mb4", $config['db_user'], $config['db_password'], [PDO::ATTR_ERRMODE=>PDO::ERRMODE_EXCEPTION, PDO::ATTR_DEFAULT_FETCH_MODE=>PDO::FETCH_ASSOC]); }
catch (Throwable $e) { respond(['ok'=>false,'error'=>'database_unavailable'],503); }
function currentUser(PDO $pdo): ?array {
  $raw = bearer(); if (!$raw) return null;
  $hash = hash('sha256', $raw);
  $stmt = $pdo->prepare('SELECT a.id AS session_id, a.user_id, a.expires_at, p.id, p.username, p.display_name, p.avatar_url, p.country, p.gender, p.bio, p.saki_id, p.vip_level, p.wealth_level FROM auth_sessions a JOIN profiles p ON p.id=a.user_id JOIN auth_users u ON u.id=a.user_id WHERE a.token_hash=:hash AND a.expires_at > UTC_TIMESTAMP() AND u.is_active=1 LIMIT 1');
  $stmt->execute([':hash'=>$hash]); $user=$stmt->fetch();
  if ($user) { $pdo->prepare('UPDATE auth_sessions SET last_used_at=UTC_TIMESTAMP() WHERE id=:id')->execute([':id'=>$user['session_id']]); }
  return $user ?: null;
}
$requestBody = body();
$action = $_GET['action'] ?? ($requestBody['action'] ?? 'health');
if ($action === 'health') respond(['ok'=>true,'service'=>'saki-api','version'=>'0.2.0','mode'=>'auth_backend']);
if ($action === 'register' && $_SERVER['REQUEST_METHOD'] === 'POST') {
  $d=body(); $username=trim((string)($d['username']??'')); $email=trim((string)($d['email']??'')); $password=(string)($d['password']??'');
  if (!preg_match('/^[A-Za-z0-9_]{3,30}$/',$username)) respond(['ok'=>false,'error'=>'invalid_username'],422);
  if ($email !== '' && !filter_var($email,FILTER_VALIDATE_EMAIL)) respond(['ok'=>false,'error'=>'invalid_email'],422);
  if (strlen($password)<8 || strlen($password)>128) respond(['ok'=>false,'error'=>'password_length'],422);
  $id=bin2hex(random_bytes(16)); $sakiId=random_int(964379846,999999999); $hash=password_hash($password,PASSWORD_DEFAULT);
  try { $pdo->beginTransaction(); $pdo->prepare('INSERT INTO auth_users (id,email,username,password_hash) VALUES (:id,:email,:username,:hash)')->execute([':id'=>$id,':email'=>$email!==''?$email:null,':username'=>$username,':hash'=>$hash]); $pdo->prepare('INSERT INTO profiles (id,username,display_name,saki_id) VALUES (:id,:username,:display_name,:saki_id)')->execute([':id'=>$id,':username'=>$username,':display_name'=>$username,':saki_id'=>$sakiId]); $pdo->commit(); respond(['ok'=>true,'data'=>['id'=>$id,'username'=>$username,'saki_id'=>$sakiId]],201); }
  catch (Throwable $e) { if($pdo->inTransaction())$pdo->rollBack(); respond(['ok'=>false,'error'=>'username_or_email_exists'],409); }
}
if ($action === 'login' && $_SERVER['REQUEST_METHOD'] === 'POST') {
  $d=body(); $identity=trim((string)($d['identity']??$d['username']??$d['email']??'')); $password=(string)($d['password']??'');
  $stmt=$pdo->prepare('SELECT * FROM auth_users WHERE (username=:identity OR email=:identity) AND is_active=1 LIMIT 1'); $stmt->execute([':identity'=>$identity]); $account=$stmt->fetch();
  if (!$account || !password_verify($password,$account['password_hash'])) respond(['ok'=>false,'error'=>'invalid_credentials'],401);
  $raw=bin2hex(random_bytes(32)); $expires=(new DateTimeImmutable('now',new DateTimeZone('UTC')))->modify('+30 days')->format('Y-m-d H:i:s');
  $pdo->prepare('INSERT INTO auth_sessions (user_id,token_hash,expires_at,user_agent,ip_address) VALUES (:uid,:hash,:expires,:ua,:ip)')->execute([':uid'=>$account['id'],':hash'=>hash('sha256',$raw),':expires'=>$expires,':ua'=>substr($_SERVER['HTTP_USER_AGENT']??'',0,255),':ip'=>$_SERVER['REMOTE_ADDR']??null]);
  $p=$pdo->prepare('SELECT id,username,display_name,avatar_url,country,gender,bio,saki_id,vip_level,wealth_level,shipping_agent FROM profiles WHERE id=:id'); $p->execute([':id'=>$account['id']]); respond(['ok'=>true,'token'=>$raw,'expires_at'=>$expires,'data'=>$p->fetch()]);
}
if ($action === 'logout' && $_SERVER['REQUEST_METHOD'] === 'POST') { $raw=bearer(); if($raw) $pdo->prepare('DELETE FROM auth_sessions WHERE token_hash=:hash')->execute([':hash'=>hash('sha256',$raw)]); respond(['ok'=>true]); }
if ($action === 'me') { $u=currentUser($pdo); if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401); unset($u['session_id'],$u['user_id'],$u['expires_at']); respond(['ok'=>true,'data'=>$u]); }
if ($action === 'profile_me') {
  $u=currentUser($pdo); if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);
  unset($u['session_id'],$u['user_id'],$u['expires_at']);
  respond(['ok'=>true,'data'=>$u]);
}
if ($action === 'profile_update' && in_array($_SERVER['REQUEST_METHOD'], ['POST','PATCH'], true)) {
  $u=currentUser($pdo); if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);
  $d=body(); $updates=[]; $params=[':id'=>$u['id']];
  if(array_key_exists('display_name',$d)) { $v=trim((string)$d['display_name']); if(mb_strlen($v)>80)respond(['ok'=>false,'error'=>'display_name_too_long'],422); $updates[]='display_name=:display_name'; $params[':display_name']=$v!==''?$v:null; }
  if(array_key_exists('avatar_url',$d)) { $v=trim((string)$d['avatar_url']); if($v!=='' && !filter_var($v,FILTER_VALIDATE_URL))respond(['ok'=>false,'error'=>'invalid_avatar_url'],422); if(strlen($v)>2000)respond(['ok'=>false,'error'=>'avatar_url_too_long'],422); $updates[]='avatar_url=:avatar_url'; $params[':avatar_url']=$v!==''?$v:null; }
  if(array_key_exists('bio',$d)) { $v=trim((string)$d['bio']); if(mb_strlen($v)>500)respond(['ok'=>false,'error'=>'bio_too_long'],422); $updates[]='bio=:bio'; $params[':bio']=$v!==''?$v:null; }
  if(array_key_exists('country',$d)) { $v=trim((string)$d['country']); if(mb_strlen($v)>80)respond(['ok'=>false,'error'=>'country_too_long'],422); $updates[]='country=:country'; $params[':country']=$v!==''?$v:null; }
  if(array_key_exists('gender',$d)) { $v=trim((string)$d['gender']); if(mb_strlen($v)>30)respond(['ok'=>false,'error'=>'gender_too_long'],422); $updates[]='gender=:gender'; $params[':gender']=$v!==''?$v:null; }
  if(!$updates)respond(['ok'=>false,'error'=>'no_editable_fields'],422);
  $pdo->prepare('UPDATE profiles SET '.implode(', ',$updates).' WHERE id=:id')->execute($params);
  $fresh=currentUser($pdo); unset($fresh['session_id'],$fresh['user_id'],$fresh['expires_at']);
  respond(['ok'=>true,'data'=>$fresh]);
}
if ($action === 'avatar_upload' && $_SERVER['REQUEST_METHOD'] === 'POST') {
  $u=currentUser($pdo); if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);
  if (!isset($_FILES['avatar']) || !is_array($_FILES['avatar'])) respond(['ok'=>false,'error'=>'avatar_required'],422);
  $file=$_FILES['avatar'];
  if (($file['error'] ?? UPLOAD_ERR_NO_FILE) !== UPLOAD_ERR_OK) respond(['ok'=>false,'error'=>'upload_failed'],422);
  if (($file['size'] ?? 0) < 1 || $file['size'] > 5*1024*1024) respond(['ok'=>false,'error'=>'avatar_size_limit'],422);
  $info=@getimagesize($file['tmp_name']);
  $mime=$info['mime'] ?? '';
  $allowed=['image/jpeg'=>'jpg','image/png'=>'png','image/webp'=>'webp'];
  if (!$info || !isset($allowed[$mime])) respond(['ok'=>false,'error'=>'unsupported_image_type'],422);
  $root=__DIR__.'/uploads/avatars';
  if (!is_dir($root) && !mkdir($root,0755,true)) respond(['ok'=>false,'error'=>'upload_storage_unavailable'],503);
  $deny=$root.'/.htaccess';
  if (!is_file($deny)) file_put_contents($deny, "Options -ExecCGI\
RemoveHandler .php .phtml .php3 .php4 .php5 .php7 .php8\
<FilesMatch \\\"\\.(php|phtml|php[0-9]*)$\\\">\
  Require all denied\
</FilesMatch>\
");
  $name=bin2hex(random_bytes(24)).'.'.$allowed[$mime]; $target=$root.'/'.$name;
  if (!move_uploaded_file($file['tmp_name'],$target)) respond(['ok'=>false,'error'=>'upload_store_failed'],503);
  chmod($target,0644);
  $base=((!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http').'://'.($_SERVER['HTTP_HOST'] ?? 'sakichat.freecpanel.shop');
  $url=$base.'/uploads/avatars/'.$name;
  $pdo->prepare('UPDATE profiles SET avatar_url=:url WHERE id=:id')->execute([':url'=>$url,':id'=>$u['id']]);
  respond(['ok'=>true,'data'=>['avatar_url'=>$url]]);
}
if ($action === 'rooms') { $limit=min(max((int)($_GET['limit']??20),1),50); $s=$pdo->prepare('SELECT id,owner_id,name,description,room_id,image_url,is_active,created_at FROM rooms WHERE is_active=1 ORDER BY created_at DESC LIMIT :limit'); $s->bindValue(':limit',$limit,PDO::PARAM_INT); $s->execute(); respond(['ok'=>true,'data'=>$s->fetchAll(),'pagination'=>['limit'=>$limit]]); }
if ($action === 'profile') { $sid=trim((string)($_GET['saki_id']??'')); if($sid===''||!ctype_digit($sid))respond(['ok'=>false,'error'=>'invalid_saki_id'],422); $s=$pdo->prepare('SELECT id,username,display_name,avatar_url,country,gender,bio,saki_id,vip_level,wealth_level,created_at FROM profiles WHERE saki_id=:sid LIMIT 1'); $s->execute([':sid'=>$sid]); $p=$s->fetch(); if(!$p)respond(['ok'=>false,'error'=>'profile_not_found'],404); respond(['ok'=>true,'data'=>$p]); }

if ($action === 'posts_feed' && $_SERVER['REQUEST_METHOD'] === 'GET') {
  $limit=min(max((int)($_GET['limit']??20),1),50); $offset=max((int)($_GET['offset']??0),0);
  $sql='SELECT p.id,p.author_id,p.content,p.visibility,p.created_at,p.updated_at,
    pr.username,pr.display_name,pr.avatar_url,pr.saki_id,
    (SELECT COUNT(*) FROM post_likes l WHERE l.post_id=p.id) AS likes_count,
    (SELECT COUNT(*) FROM post_comments c WHERE c.post_id=p.id) AS comments_count,
    (SELECT COUNT(*) FROM post_shares sh WHERE sh.post_id=p.id) AS shares_count
    FROM posts p JOIN profiles pr ON pr.id=p.author_id
    WHERE p.visibility IN (\'public\',\'followers\') ORDER BY p.created_at DESC LIMIT :limit OFFSET :offset';
  $s=$pdo->prepare($sql); $s->bindValue(':limit',$limit,PDO::PARAM_INT); $s->bindValue(':offset',$offset,PDO::PARAM_INT); $s->execute(); $rows=$s->fetchAll();
  $m=$pdo->prepare('SELECT id,storage_path,sort_order FROM post_media WHERE post_id=:id ORDER BY sort_order'); foreach($rows as &$row){$row['profiles']=['id'=>$row['author_id'],'username'=>$row['username'],'display_name'=>$row['display_name'],'avatar_url'=>$row['avatar_url'],'saki_id'=>$row['saki_id']];$row['_liked']=false;$row['_likes_count']=(int)$row['likes_count'];$row['_comments_count']=(int)$row['comments_count'];$row['_shares_count']=(int)$row['shares_count'];$m->execute([':id'=>$row['id']]);$row['_media']=array_map(fn($x)=>['id'=>$x['id'],'storage_path'=>$x['storage_path'],'url'=>$x['storage_path'],'sort_order'=>(int)$x['sort_order']],$m->fetchAll());}
  respond(['ok'=>true,'data'=>$rows,'pagination'=>['limit'=>$limit,'offset'=>$offset]]);
}
if ($action === 'post_create' && $_SERVER['REQUEST_METHOD'] === 'POST') {
  $u=currentUser($pdo); if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401); $d=body();
  $content=trim((string)($d['content']??'')); $visibility=(string)($d['visibility']??'public');
  if(($content==='' && (!isset($d['media']) || !is_array($d['media']) || count($d['media'])===0)) || mb_strlen($content)>5000)respond(['ok'=>false,'error'=>'content_or_media_required'],422);
  if(!in_array($visibility,['public','followers'],true))respond(['ok'=>false,'error'=>'invalid_visibility'],422);
  $id=bin2hex(random_bytes(16)); $s=$pdo->prepare('INSERT INTO posts (id,author_id,content,visibility,created_at,updated_at) VALUES (:id,:author,:content,:visibility,UTC_TIMESTAMP(),UTC_TIMESTAMP())');
  $s->execute([':id'=>$id,':author'=>$u['id'],':content'=>$content,':visibility'=>$visibility]);
  $media=$d['media']??[]; if(is_array($media)){ $m=$pdo->prepare('INSERT INTO post_media(id,post_id,storage_path,sort_order) VALUES(:id,:post,:path,:sort)'); foreach(array_slice($media,0,10) as $i=>$url){ if(is_string($url)&&filter_var($url,FILTER_VALIDATE_URL)) $m->execute([':id'=>bin2hex(random_bytes(16)),':post'=>$id,':path'=>$url,':sort'=>$i]); } }
  respond(['ok'=>true,'data'=>['id'=>$id,'author_id'=>$u['id'],'content'=>$content,'visibility'=>$visibility]],201);
}
if ($action === 'post_like_toggle' && $_SERVER['REQUEST_METHOD'] === 'POST') {
  $u=currentUser($pdo); if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401); $d=body(); $post=trim((string)($d['post_id']??'')); if($post==='')respond(['ok'=>false,'error'=>'post_id_required'],422);
  $q=$pdo->prepare('SELECT 1 FROM post_likes WHERE post_id=:post AND user_id=:user LIMIT 1'); $q->execute([':post'=>$post,':user'=>$u['id']]);
  if($q->fetch()) { $pdo->prepare('DELETE FROM post_likes WHERE post_id=:post AND user_id=:user')->execute([':post'=>$post,':user'=>$u['id']]); $liked=false; }
  else { $pdo->prepare('INSERT INTO post_likes (post_id,user_id,created_at) VALUES (:post,:user,UTC_TIMESTAMP())')->execute([':post'=>$post,':user'=>$u['id']]); $liked=true; }
  $q=$pdo->prepare('SELECT COUNT(*) AS count FROM post_likes WHERE post_id=:post'); $q->execute([':post'=>$post]); respond(['ok'=>true,'data'=>['liked'=>$liked,'likes_count'=>(int)$q->fetchColumn()] ]);
}
if ($action === 'post_comments' && $_SERVER['REQUEST_METHOD'] === 'GET') {
  $post=trim((string)($_GET['post_id']??'')); if($post==='')respond(['ok'=>false,'error'=>'post_id_required'],422); $limit=min(max((int)($_GET['limit']??50),1),100);
  $s=$pdo->prepare('SELECT c.id,c.post_id,c.user_id,c.content,c.created_at,p.username,p.display_name,p.avatar_url FROM post_comments c JOIN profiles p ON p.id=c.user_id WHERE c.post_id=:post ORDER BY c.created_at ASC LIMIT :limit'); $s->bindValue(':post',$post); $s->bindValue(':limit',$limit,PDO::PARAM_INT); $s->execute(); respond(['ok'=>true,'data'=>$s->fetchAll()]);
}
if ($action === 'post_comment_create' && $_SERVER['REQUEST_METHOD'] === 'POST') {
  $u=currentUser($pdo); if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401); $d=body(); $post=trim((string)($d['post_id']??'')); $content=trim((string)($d['content']??'')); if($post===''||$content===''||mb_strlen($content)>2000)respond(['ok'=>false,'error'=>'invalid_comment'],422);
  $id=bin2hex(random_bytes(16)); $pdo->prepare('INSERT INTO post_comments (id,post_id,user_id,content,created_at) VALUES (:id,:post,:user,:content,UTC_TIMESTAMP())')->execute([':id'=>$id,':post'=>$post,':user'=>$u['id'],':content'=>$content]); respond(['ok'=>true,'data'=>['id'=>$id,'post_id'=>$post,'user_id'=>$u['id'],'content'=>$content]],201);
}
if ($action === 'follow_toggle' && $_SERVER['REQUEST_METHOD'] === 'POST') {
  $u=currentUser($pdo); if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401); $d=body(); $target=trim((string)($d['user_id']??'')); if($target===''||$target===$u['id'])respond(['ok'=>false,'error'=>'invalid_target'],422);
  $q=$pdo->prepare('SELECT 1 FROM follows WHERE follower_id=:f AND following_id=:t LIMIT 1'); $q->execute([':f'=>$u['id'],':t'=>$target]);
  if($q->fetch()) { $pdo->prepare('DELETE FROM follows WHERE follower_id=:f AND following_id=:t')->execute([':f'=>$u['id'],':t'=>$target]); $following=false; }
  else { $pdo->prepare('INSERT INTO follows (follower_id,following_id,created_at) VALUES (:f,:t,UTC_TIMESTAMP())')->execute([':f'=>$u['id'],':t'=>$target]); $following=true; }
  respond(['ok'=>true,'data'=>['following'=>$following]]);
}
if ($action === 'notifications' && $_SERVER['REQUEST_METHOD'] === 'GET') {
  $u=currentUser($pdo); if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401); $limit=min(max((int)($_GET['limit']??50),1),100);
  $s=$pdo->prepare('SELECT n.id,n.user_id,n.actor_id,n.type,n.entity_id,n.is_read,n.created_at,n.badge_key,n.badge_asset_path,n.data,p.username,p.display_name,p.avatar_url FROM notifications n LEFT JOIN profiles p ON p.id=n.actor_id WHERE n.user_id=:uid ORDER BY n.created_at DESC LIMIT :limit'); $s->bindValue(':uid',$u['id']); $s->bindValue(':limit',$limit,PDO::PARAM_INT); $s->execute(); respond(['ok'=>true,'data'=>$s->fetchAll()]);
}



if ($action === 'countries' && $_SERVER['REQUEST_METHOD'] === 'GET') {
  $rows=$pdo->query("SELECT code,name_ar,flag FROM countries ORDER BY name_ar LIMIT 250")->fetchAll();
  respond(['ok'=>true,'data'=>$rows]);
}
if ($action === 'profile_complete' && $_SERVER['REQUEST_METHOD'] === 'POST') {
  $u=currentUser($pdo); if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401); $d=body();
  $username=trim((string)($d['username']??'')); $country=trim((string)($d['country']??'')); $gender=trim((string)($d['gender']??''));
  if(!preg_match('/^[A-Za-z0-9_\x{0600}-\x{06FF}]{3,30}$/u',$username))respond(['ok'=>false,'error'=>'invalid_username'],422);
  if($country===''||mb_strlen($country)>80||!in_array($gender,['ذكر','أنثى'],true))respond(['ok'=>false,'error'=>'profile_fields_invalid'],422);
  try{$q=$pdo->prepare('UPDATE profiles SET username=:username,display_name=:username,country=:country,gender=:gender,updated_at=UTC_TIMESTAMP() WHERE id=:id');$q->execute([':username'=>$username,':country'=>$country,':gender'=>$gender,':id'=>$u['id']]);}catch(Throwable $e){respond(['ok'=>false,'error'=>'username_already_exists'],409);}
  $fresh=currentUser($pdo); unset($fresh['session_id'],$fresh['user_id'],$fresh['expires_at']); respond(['ok'=>true,'data'=>$fresh]);
}


if ($action === 'countries' && $_SERVER['REQUEST_METHOD'] === 'GET') {
  $rows=$pdo->query("SELECT code,name_ar,flag FROM countries ORDER BY name_ar LIMIT 250")->fetchAll();
  respond(['ok'=>true,'data'=>$rows]);
}
if ($action === 'profile_complete' && $_SERVER['REQUEST_METHOD'] === 'POST') {
  $u=currentUser($pdo); if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401); $d=body();
  $username=trim((string)($d['username']??'')); $country=trim((string)($d['country']??'')); $gender=trim((string)($d['gender']??''));
  if(!preg_match('/^[A-Za-z0-9_\x{0600}-\x{06FF}]{3,30}$/u',$username))respond(['ok'=>false,'error'=>'invalid_username'],422);
  if($country===''||mb_strlen($country)>80||!in_array($gender,['ذكر','أنثى'],true))respond(['ok'=>false,'error'=>'profile_fields_invalid'],422);
  $avatarUrl=trim((string)($d['avatar_url']??'')); if($avatarUrl!=='' && !filter_var($avatarUrl,FILTER_VALIDATE_URL))respond(['ok'=>false,'error'=>'invalid_avatar_url'],422);
  try{$q=$pdo->prepare('UPDATE profiles SET username=:username,display_name=:username,country=:country,gender=:gender,avatar_url=COALESCE(NULLIF(:avatar_url,\'\'),avatar_url),updated_at=UTC_TIMESTAMP() WHERE id=:id');$q->execute([':username'=>$username,':country'=>$country,':gender'=>$gender,':avatar_url'=>$avatarUrl,':id'=>$u['id']]);}catch(Throwable $e){respond(['ok'=>false,'error'=>'username_already_exists'],409);}
  $fresh=currentUser($pdo); unset($fresh['session_id'],$fresh['user_id'],$fresh['expires_at']); respond(['ok'=>true,'data'=>$fresh]);
}


if ($action === 'countries' && $_SERVER['REQUEST_METHOD'] === 'GET') {
  $rows=$pdo->query("SELECT code,name_ar,flag FROM countries ORDER BY name_ar LIMIT 250")->fetchAll();
  respond(['ok'=>true,'data'=>$rows]);
}
if ($action === 'profile_complete' && $_SERVER['REQUEST_METHOD'] === 'POST') {
  $u=currentUser($pdo); if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401); $d=body();
  $username=trim((string)($d['username']??'')); $country=trim((string)($d['country']??'')); $gender=trim((string)($d['gender']??''));
  if(!preg_match('/^[A-Za-z0-9_\x{0600}-\x{06FF}]{3,30}$/u',$username))respond(['ok'=>false,'error'=>'invalid_username'],422);
  if($country===''||mb_strlen($country)>80||!in_array($gender,['ذكر','أنثى'],true))respond(['ok'=>false,'error'=>'profile_fields_invalid'],422);
  $avatarUrl=trim((string)($d['avatar_url']??'')); if($avatarUrl!=='' && !filter_var($avatarUrl,FILTER_VALIDATE_URL))respond(['ok'=>false,'error'=>'invalid_avatar_url'],422);
  try{$q=$pdo->prepare('UPDATE profiles SET username=:username,display_name=:username,country=:country,gender=:gender,avatar_url=COALESCE(NULLIF(:avatar_url,\'\'),avatar_url),updated_at=UTC_TIMESTAMP() WHERE id=:id');$q->execute([':username'=>$username,':country'=>$country,':gender'=>$gender,':avatar_url'=>$avatarUrl,':id'=>$u['id']]);}catch(Throwable $e){respond(['ok'=>false,'error'=>'username_already_exists'],409);}
  $fresh=currentUser($pdo); if(!$fresh) respond(['ok'=>false,'error'=>'profile_session_refresh_failed'],500); unset($fresh['session_id'],$fresh['user_id'],$fresh['expires_at']); respond(['ok'=>true,'data'=>$fresh]);
}


if ($action === 'profile_stats' && $_SERVER['REQUEST_METHOD'] === 'GET') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$q=$pdo->prepare('SELECT (SELECT COUNT(*) FROM posts WHERE author_id=:id) posts,(SELECT COUNT(*) FROM follows WHERE following_id=:id) followers,(SELECT COUNT(*) FROM follows WHERE follower_id=:id) following');$q->execute([':id'=>$u['id']]);$r=$q->fetch();respond(['ok'=>true,'data'=>['posts'=>(int)$r['posts'],'followers'=>(int)$r['followers'],'following'=>(int)$r['following']]]); }
if ($action === 'follow_toggle' && $_SERVER['REQUEST_METHOD'] === 'POST') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$d=body();$target=trim((string)($d['user_id']??''));if($target===''||$target===$u['id'])respond(['ok'=>false,'error'=>'invalid_target'],422);$q=$pdo->prepare('SELECT 1 FROM follows WHERE follower_id=:f AND following_id=:t');$q->execute([':f'=>$u['id'],':t'=>$target]);if($q->fetch()){$pdo->prepare('DELETE FROM follows WHERE follower_id=:f AND following_id=:t')->execute([':f'=>$u['id'],':t'=>$target]);$following=false;}else{$pdo->prepare('INSERT INTO follows(follower_id,following_id,created_at) VALUES(:f,:t,UTC_TIMESTAMP())')->execute([':f'=>$u['id'],':t'=>$target]);$following=true;}respond(['ok'=>true,'data'=>['following'=>$following]]); }
if ($action === 'following_check' && $_SERVER['REQUEST_METHOD'] === 'GET') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$target=trim((string)($_GET['user_id']??''));$q=$pdo->prepare('SELECT 1 FROM follows WHERE follower_id=:f AND following_id=:t');$q->execute([':f'=>$u['id'],':t'=>$target]);respond(['ok'=>true,'data'=>['following'=>(bool)$q->fetch()]]); }
if ($action === 'search' && $_SERVER['REQUEST_METHOD'] === 'GET') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$term=trim((string)($_GET['q']??''));if($term==='')respond(['ok'=>true,'data'=>[]]);$like='%'.$term.'%';$q=$pdo->prepare('SELECT id,username,display_name,saki_id,avatar_url,bio,country,gender FROM profiles WHERE id<>:id AND (username LIKE :q OR display_name LIKE :q OR CAST(saki_id AS CHAR)=:exact) ORDER BY username LIMIT 30');$q->execute([':id'=>$u['id'],':q'=>$like,':exact'=>$term]);$rows=$q->fetchAll();respond(['ok'=>true,'data'=>array_map(fn($r)=>$r+['_kind'=>'profile'],$rows)]); }


if ($action === 'conversations' && $_SERVER['REQUEST_METHOD'] === 'GET') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$q=$pdo->prepare("SELECT c.id,c.created_at,c.updated_at FROM conversations c JOIN conversation_members m ON m.conversation_id=c.id WHERE m.user_id=:id ORDER BY c.updated_at DESC LIMIT 100");$q->execute([':id'=>$u['id']]);$rows=$q->fetchAll();foreach($rows as &$r){$m=$pdo->prepare("SELECT p.id,p.username,p.display_name,p.avatar_url,p.saki_id FROM conversation_members cm JOIN profiles p ON p.id=cm.user_id WHERE cm.conversation_id=:cid");$m->execute([':cid'=>$r['id']]);$r['conversation_members']=$m->fetchAll();}$r=null;respond(['ok'=>true,'data'=>$rows]); }

if ($action === 'conversation_create' && $_SERVER['REQUEST_METHOD'] === 'POST') {
  $u=currentUser($pdo); if(!$u) respond(['ok'=>false,'error'=>'unauthorized'],401);
  $d=body(); $other=trim((string)($d['user_id']??''));
  if($other==='' || $other===$u['id']) respond(['ok'=>false,'error'=>'invalid_other_user'],422);
  try {
    $q=$pdo->prepare('SELECT c.id FROM conversations c JOIN conversation_members a ON a.conversation_id=c.id AND a.user_id=:u JOIN conversation_members b ON b.conversation_id=c.id AND b.user_id=:o LIMIT 1');
    $q->execute([':u'=>$u['id'],':o'=>$other]); $existing=$q->fetchColumn();
    if($existing) respond(['ok'=>true,'data'=>['id'=>$existing]]);
    $check=$pdo->prepare('SELECT id FROM profiles WHERE id=:id LIMIT 1'); $check->execute([':id'=>$other]);
    if(!$check->fetchColumn()) respond(['ok'=>false,'error'=>'user_not_found'],404);
    $id=bin2hex(random_bytes(16)); $pdo->beginTransaction();
    $pdo->prepare('INSERT INTO conversations(id,created_at,created_by,updated_at) VALUES(:id,UTC_TIMESTAMP(),:u,UTC_TIMESTAMP())')->execute([':id'=>$id,':u'=>$u['id']]);
    $m=$pdo->prepare('INSERT INTO conversation_members(conversation_id,user_id) VALUES(:c,:u)');
    $m->execute([':c'=>$id,':u'=>$u['id']]); $m->execute([':c'=>$id,':u'=>$other]);
    $pdo->commit(); respond(['ok'=>true,'data'=>['id'=>$id]],201);
  } catch(Throwable $e) { if($pdo->inTransaction())$pdo->rollBack(); respond(['ok'=>false,'error'=>'conversation_sql:'.$e->getMessage()],500); }
}
if ($action === 'messages' && $_SERVER['REQUEST_METHOD'] === 'GET') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$cid=trim((string)($_GET['conversation_id']??''));$q=$pdo->prepare('SELECT 1 FROM conversation_members WHERE conversation_id=:c AND user_id=:u');$q->execute([':c'=>$cid,':u'=>$u['id']]);if(!$q->fetch())respond(['ok'=>false,'error'=>'forbidden'],403);$q=$pdo->prepare('SELECT id,conversation_id,sender_id,body,created_at,is_read,message_type,media_url,media_name FROM messages WHERE conversation_id=:c ORDER BY created_at ASC LIMIT 200');$q->execute([':c'=>$cid]);respond(['ok'=>true,'data'=>$q->fetchAll()]); }
if ($action === 'message_send' && $_SERVER['REQUEST_METHOD'] === 'POST') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$d=body();$cid=trim((string)($d['conversation_id']??''));$q=$pdo->prepare('SELECT 1 FROM conversation_members WHERE conversation_id=:c AND user_id=:u');$q->execute([':c'=>$cid,':u'=>$u['id']]);if(!$q->fetch())respond(['ok'=>false,'error'=>'forbidden'],403);$id=str_replace('-','',uuid());$q=$pdo->prepare('INSERT INTO messages(id,conversation_id,sender_id,body,created_at,is_read,message_type,media_url,media_name) VALUES(:id,:c,:u,:b,UTC_TIMESTAMP(),0,:t,:url,:name)');$q->execute([':id'=>$id,':c'=>$cid,':u'=>$u['id'],':b'=>trim((string)($d['body']??'')),':t'=>(string)($d['message_type']??'text'),':url'=>$d['media_url']??null,':name'=>$d['media_name']??null]);$pdo->prepare('UPDATE conversations SET updated_at=UTC_TIMESTAMP() WHERE id=:id')->execute([':id'=>$cid]);respond(['ok'=>true,'data'=>['id'=>$id]]); }
if ($action === 'message_react' && $_SERVER['REQUEST_METHOD'] === 'POST') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$d=body();$id=str_replace('-','',uuid());$q=$pdo->prepare('INSERT INTO message_reactions(id,message_id,conversation_id,user_id,emoji,created_at) VALUES(:id,:m,:c,:u,:e,UTC_TIMESTAMP())');$q->execute([':id'=>$id,':m'=>$d['message_id'],':c'=>$d['conversation_id'],':u'=>$u['id'],':e'=>$d['emoji']??'❤️']);respond(['ok'=>true]); }



if ($action === 'room_owned' && $_SERVER['REQUEST_METHOD'] === 'GET') {
  $u=currentUser($pdo); if(!$u) respond(['ok'=>false,'error'=>'unauthorized'],401);
  try {    $q=$pdo->prepare('SELECT r.id,r.room_id,r.owner_id,r.name,r.description,r.image_url,r.is_active,r.created_at,p.username,p.avatar_url,p.vip_level FROM rooms r LEFT JOIN profiles p ON p.id=r.owner_id WHERE r.owner_id=:u AND r.is_active=1 ORDER BY r.created_at DESC LIMIT 1');
    $q->execute([':u'=>$u['id']]); $row=$q->fetch(PDO::FETCH_ASSOC);
    if(!$row) respond(['ok'=>true,'data'=>[]]);
    $row['country']='الأردن'; $row['room_type']='audio'; $row['background_url']=null; $row['seat_count']=10; $row['announcement']=''; $row['category']='عام'; $row['theme_key']='default'; $row['mic_permission']='everyone'; $row['membership_fee']=0; $row['reward_rate']=0;
    $row['profiles']=['username'=>$row['username']??'', 'avatar_url'=>$row['avatar_url']??null, 'vip_level'=>(int)($row['vip_level']??0)];
    $row['_members_count']=1;
    respond(['ok'=>true,'data'=>[$row]]);
  } catch(Throwable $e) { respond(['ok'=>false,'error'=>'room_owned_sql:'.$e->getMessage()],500); }
}
if ($action === 'agora_token' && $_SERVER['REQUEST_METHOD'] === 'GET') {
  $u=currentUser($pdo); if(!$u) respond(['ok'=>false,'error'=>'unauthorized'],401);
  $channel=trim((string)($_GET['channel_name']??''));
  $uid=(int)($_GET['uid']??0);
  if($channel==='' || strlen($channel)>64 || !preg_match('/^[A-Za-z0-9_\-:.]+$/',$channel)) respond(['ok'=>false,'error'=>'invalid_channel_name'],422);
  if($uid<0) respond(['ok'=>false,'error'=>'invalid_uid'],422);
  try {
    $q=$pdo->prepare('SELECT id,room_id,owner_id,name FROM rooms WHERE (id=:r OR room_id=:r) AND is_active=1 LIMIT 1');
    $q->execute([':r'=>$channel]); $room=$q->fetch(PDO::FETCH_ASSOC);
    if(!$room) respond(['ok'=>false,'error'=>'room_not_found'],404);
    $lib='/home/sakich0563/AccessToken2.php'; $cfg='/home/sakich0563/agora_private.php';
    if(!is_file($lib) || !is_file($cfg)) respond(['ok'=>false,'error'=>'agora_server_not_configured'],500);
    require_once $lib; $config=require $cfg;
    $appId=(string)($config['app_id']??''); $certificate=(string)($config['app_certificate']??'');
    if(!preg_match('/^[A-Fa-f0-9]{32}$/',$appId) || !preg_match('/^[A-Fa-f0-9]{32}$/',$certificate)) respond(['ok'=>false,'error'=>'agora_server_not_configured'],500);
    $ttl=3600; $builder=new AccessToken2($appId,$certificate,$ttl);
    $service=new ServiceRtc($channel,(string)$uid); $expires=$builder->issueTs+$ttl;
    $service->addPrivilege(ServiceRtc::PRIVILEGE_JOIN_CHANNEL,$expires);
    $service->addPrivilege(ServiceRtc::PRIVILEGE_PUBLISH_AUDIO_STREAM,$expires);
    $service->addPrivilege(ServiceRtc::PRIVILEGE_PUBLISH_VIDEO_STREAM,$expires);
    $service->addPrivilege(ServiceRtc::PRIVILEGE_PUBLISH_DATA_STREAM,$expires);
    $builder->addService($service); $token=$builder->build();
    if($token==='') respond(['ok'=>false,'error'=>'agora_token_generation_failed'],500);
    respond(['ok'=>true,'data'=>['appId'=>$appId,'token'=>$token,'channelName'=>$channel,'uid'=>$uid,'expiresAt'=>$expires,'isOwner'=>$room['owner_id']===$u['id'],'roomName'=>$room['name']]]);
  } catch(Throwable $e) { respond(['ok'=>false,'error'=>'agora_token_failed:'.$e->getMessage()],500); }
}

if ($action === 'zego_token' && $_SERVER['REQUEST_METHOD'] === 'GET') {
  $u=currentUser($pdo); if(!$u) respond(['ok'=>false,'error'=>'unauthorized'],401);
  $requested=trim((string)($_GET['room_id']??''));
  if($requested==='') respond(['ok'=>false,'error'=>'room_id_required'],422);
  try {
    $q=$pdo->prepare('SELECT id,room_id,owner_id,name FROM rooms WHERE (id=:r OR room_id=:r) AND is_active=1 LIMIT 1');
    $q->execute([':r'=>$requested]); $room=$q->fetch(PDO::FETCH_ASSOC);
    if(!$room) respond(['ok'=>false,'error'=>'room_not_found'],404);
    $configFile='/home/sakich0563/zego_private.php';
    if(!is_file($configFile)) respond(['ok'=>false,'error'=>'zego_server_not_configured'],500);
    $config=require $configFile;
    $appId=(int)($config['app_id']??0); $secret=(string)($config['server_secret']??'');
    if($appId<=0 || strlen($secret)!==32) respond(['ok'=>false,'error'=>'zego_server_not_configured'],500);
    $userId=preg_replace('/[^A-Za-z0-9_]/','_', (string)$u['id']);
    if($userId==='') respond(['ok'=>false,'error'=>'invalid_user_id'],422);
    $expire=time()+3600;
    $high=intdiv($expire,4294967296); $low=$expire%4294967296;
    $expireBytes=pack('N2',$high,$low);
    $iv=substr(bin2hex(random_bytes(8)),0,16);
    $info=json_encode(['app_id'=>$appId,'user_id'=>$userId,'nonce'=>random_int(-2147483648,2147483647),'ctime'=>time(),'expire'=>$expire,'payload'=>''],JSON_UNESCAPED_SLASHES);
    $encrypted=openssl_encrypt($info,'AES-256-CBC',$secret,OPENSSL_RAW_DATA,$iv);
    if($encrypted===false) respond(['ok'=>false,'error'=>'zego_token_generation_failed'],500);
    $token='04'.base64_encode($expireBytes.pack('n',strlen($iv)).$iv.pack('n',strlen($encrypted)).$encrypted);
    respond(['ok'=>true,'data'=>['token'=>$token,'appId'=>$appId,'roomId'=>$room['room_id'],'userId'=>$userId,'userName'=>(string)($_GET['user_name']??$u['username']??'User'),'isOwner'=>$room['owner_id']===$u['id'],'roomName'=>$room['name']]]);
  } catch(Throwable $e) { respond(['ok'=>false,'error'=>'zego_token_failed:'.$e->getMessage()],500); }
}

if ($action === 'room_create' && $_SERVER['REQUEST_METHOD'] === 'POST') {
  $u=currentUser($pdo); if(!$u) respond(['ok'=>false,'error'=>'unauthorized'],401);
  $d=body(); $name=trim((string)($d['name']??''));
  if($name==='') respond(['ok'=>false,'error'=>'room_name_required'],422);
  try {
    $pdo->beginTransaction();
    $q=$pdo->query("SELECT room_id FROM rooms WHERE room_id REGEXP '^[0-9]{9}$' ORDER BY CAST(room_id AS UNSIGNED) DESC LIMIT 1 FOR UPDATE");
    $last=$q->fetchColumn(); $next=max(649874536, ((int)$last)+1);
    if($next>999999999) throw new Exception('room_id_space_exhausted');
    $code=(string)$next; $id=bin2hex(random_bytes(16));
    $q=$pdo->prepare("INSERT INTO rooms(id,room_id,owner_id,name,description,image_url,is_active,created_at) VALUES(:id,:code,:u,:n,:d,NULL,1,UTC_TIMESTAMP())");
    $q->execute([':id'=>$id,':code'=>$code,':u'=>$u['id'],':n'=>$name,':d'=>trim((string)($d['description']??''))]);
    $pdo->prepare('INSERT INTO room_members(room_id,user_id,joined_at) VALUES(:r,:u,UTC_TIMESTAMP())')->execute([':r'=>$id,':u'=>$u['id']]);
    $pdo->commit();
    respond(['ok'=>true,'data'=>['id'=>$id,'room_id'=>$code,'owner_id'=>$u['id'],'name'=>$name,'description'=>$d['description']??'','country'=>$d['country']??'الأردن','room_type'=>$d['type']??'audio','seat_count'=>10,'category'=>$d['category']??'Cp','is_active'=>1,'_members_count'=>1]],201);
  } catch(Throwable $e) { if($pdo->inTransaction()) $pdo->rollBack(); respond(['ok'=>false,'error'=>'room_create_sql:'.$e->getMessage()],500); }
}
if ($action === 'rooms_feed' && $_SERVER['REQUEST_METHOD'] === 'GET') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);try{$q=$pdo->query("SELECT r.id,r.room_id,r.owner_id,r.name,r.description,r.image_url,r.is_active,r.created_at,p.username,p.avatar_url,p.vip_level,(SELECT COUNT(*) FROM room_members rm WHERE rm.room_id=r.id) member_count FROM rooms r JOIN profiles p ON p.id=r.owner_id ORDER BY r.created_at DESC LIMIT 100");$rows=$q->fetchAll();foreach($rows as &$r)$r['profiles']=['username'=>$r['username'],'avatar_url'=>$r['avatar_url'],'vip_level'=>(int)$r['vip_level']];unset($r);respond(['ok'=>true,'data'=>$rows]);}catch(Throwable $e){respond(['ok'=>false,'error'=>'rooms_sql:'.$e->getMessage()],500);} }
if ($action === 'room_followed' && $_SERVER['REQUEST_METHOD'] === 'GET') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$q=$pdo->prepare('SELECT room_id FROM room_follows WHERE user_id=:u LIMIT 500');$q->execute([':u'=>$u['id']]);respond(['ok'=>true,'data'=>array_map(fn($r)=>$r['room_id'],$q->fetchAll())]); }
if ($action === 'room_follow_toggle' && $_SERVER['REQUEST_METHOD'] === 'POST') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$d=body();$room=trim((string)($d['room_id']??''));$q=$pdo->prepare('SELECT 1 FROM room_follows WHERE room_id=:r AND user_id=:u');$q->execute([':r'=>$room,':u'=>$u['id']]);if($q->fetch()){$pdo->prepare('DELETE FROM room_follows WHERE room_id=:r AND user_id=:u')->execute([':r'=>$room,':u'=>$u['id']]);$f=false;}else{$pdo->prepare('INSERT INTO room_follows(room_id,user_id,created_at) VALUES(:r,:u,UTC_TIMESTAMP())')->execute([':r'=>$room,':u'=>$u['id']]);$f=true;}respond(['ok'=>true,'data'=>['followed'=>$f]]); }
if ($action === 'room_join' && $_SERVER['REQUEST_METHOD'] === 'POST') {
  $u=currentUser($pdo); if(!$u) respond(['ok'=>false,'error'=>'unauthorized'],401);
  $requested=trim((string)(body()['room_id']??''));
  if($requested==='') respond(['ok'=>false,'error'=>'room_id_required'],422);
  try {
    $q=$pdo->prepare('SELECT id FROM rooms WHERE (id=:r OR room_id=:r) AND is_active=1 LIMIT 1');
    $q->execute([':r'=>$requested]); $room=$q->fetchColumn();
    if(!$room) respond(['ok'=>false,'error'=>'room_not_found'],404);
    $q=$pdo->prepare('INSERT INTO room_members(room_id,user_id,joined_at) VALUES(:r,:u,UTC_TIMESTAMP()) ON DUPLICATE KEY UPDATE joined_at=VALUES(joined_at)');
    $q->execute([':r'=>$room,':u'=>$u['id']]);
    respond(['ok'=>true,'data'=>['room_id'=>$room]]);
  } catch(Throwable $e) { respond(['ok'=>false,'error'=>'room_join_sql:'.$e->getMessage()],500); }
} 
if ($action === 'room_leave' && $_SERVER['REQUEST_METHOD'] === 'POST') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$room=(string)(body()['room_id']??'');$pdo->prepare('DELETE FROM room_members WHERE room_id=:r AND user_id=:u')->execute([':r'=>$room,':u'=>$u['id']]);respond(['ok'=>true]); }

if ($action === 'gift_catalog' && $_SERVER['REQUEST_METHOD'] === 'GET') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$q=$pdo->query('SELECT id,category,name,icon,price,sort_order,is_active,media_url,media_type FROM room_gift_catalog WHERE is_active=1 ORDER BY sort_order LIMIT 100');respond(['ok'=>true,'data'=>$q->fetchAll()]); }
if ($action === 'gift_send' && $_SERVER['REQUEST_METHOD'] === 'POST') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$d=body();$room=(string)($d['room_id']??'');$recipient=(string)($d['recipient_id']??'');$gift=(string)($d['gift_id']??'');$qty=max(1,min(100,(int)($d['quantity']??1)));$pdo->beginTransaction();try{$q=$pdo->prepare('SELECT price FROM room_gift_catalog WHERE id=:g AND is_active=1 FOR UPDATE');$q->execute([':g'=>$gift]);$price=$q->fetchColumn();if($price===false)throw new Exception('gift_not_found');$total=(int)$price*$qty;$q=$pdo->prepare('SELECT gold_coins FROM saki_account_modules WHERE user_id=:u FOR UPDATE');$q->execute([':u'=>$u['id']]);$balance=(int)$q->fetchColumn();if($balance<$total)throw new Exception('insufficient_gold_coins');$pdo->prepare('UPDATE saki_account_modules SET gold_coins=gold_coins-:n,updated_at=UTC_TIMESTAMP() WHERE user_id=:u')->execute([':n'=>$total,':u'=>$u['id']]);$id=bin2hex(random_bytes(16));$pdo->prepare('INSERT INTO room_gifts(id,room_id,sender_id,recipient_id,gift_id,quantity,total_price,created_at,recipient_diamonds) VALUES(:id,:r,:s,:to,:g,:q,:p,UTC_TIMESTAMP(),:d)')->execute([':id'=>$id,':r'=>$room,':s'=>$u['id'],':to'=>$recipient,':g'=>$gift,':q'=>$qty,':p'=>$total,':d'=>$total]);$pdo->prepare('INSERT INTO gift_announcements(id,room_id,sender_id,recipient_id,gift_id,total_price,recipient_diamonds,created_at,event_type,multiplier,reward_gold,gift_price) VALUES(:id,:r,:s,:to,:g,:p,:d,UTC_TIMESTAMP(),\'gift\',1,:p,:price)')->execute([':id'=>bin2hex(random_bytes(16)),':r'=>$room,':s'=>$u['id'],':to'=>$recipient,':g'=>$gift,':p'=>$total,':d'=>$total,':price'=>$price]);$pdo->commit();respond(['ok'=>true,'data'=>['id'=>$id,'total_price'=>$total]]);}catch(Throwable $e){if($pdo->inTransaction())$pdo->rollBack();respond(['ok'=>false,'error'=>$e->getMessage()],422);} }


if ($action === 'vip_purchase' && $_SERVER['REQUEST_METHOD'] === 'POST') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$level=max(1,min(10,(int)(body()['level']??1)));$price=$level*1000;$pdo->beginTransaction();try{$q=$pdo->prepare('SELECT gold_coins FROM saki_account_modules WHERE user_id=:u FOR UPDATE');$q->execute([':u'=>$u['id']]);if((int)$q->fetchColumn()<$price)throw new Exception('insufficient_gold_coins');$pdo->prepare('UPDATE saki_account_modules SET gold_coins=gold_coins-:p,vip_level=:l,updated_at=UTC_TIMESTAMP() WHERE user_id=:u')->execute([':p'=>$price,':l'=>$level,':u'=>$u['id']]);$pdo->prepare('INSERT INTO vip_transactions(id,sender_id,recipient_id,vip_level,price,transaction_type,created_at) VALUES(:id,:s,:r,:l,:p,\'purchase\',UTC_TIMESTAMP())')->execute([':id'=>bin2hex(random_bytes(16)),':s'=>$u['id'],':r'=>$u['id'],':l'=>$level,':p'=>$price]);$pdo->commit();respond(['ok'=>true,'data'=>['vip_level'=>$level,'price'=>$price]]);}catch(Throwable $e){$pdo->rollBack();respond(['ok'=>false,'error'=>$e->getMessage()],422);} }
if ($action === 'diamonds_convert' && $_SERVER['REQUEST_METHOD'] === 'POST') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$n=max(1,(int)(body()['amount']??0));$pdo->beginTransaction();try{$q=$pdo->prepare('SELECT diamonds FROM saki_account_modules WHERE user_id=:u FOR UPDATE');$q->execute([':u'=>$u['id']]);if((int)$q->fetchColumn()<$n)throw new Exception('insufficient_diamonds');$pdo->prepare('UPDATE saki_account_modules SET diamonds=diamonds-:n,gold_coins=gold_coins+:n,updated_at=UTC_TIMESTAMP() WHERE user_id=:u')->execute([':n'=>$n,':u'=>$u['id']]);$pdo->commit();respond(['ok'=>true,'data'=>['converted'=>$n]]);}catch(Throwable $e){$pdo->rollBack();respond(['ok'=>false,'error'=>$e->getMessage()],422);} }
if ($action === 'redeem' && $_SERVER['REQUEST_METHOD'] === 'POST') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$code=strtoupper(trim((string)(body()['code']??'')));$pdo->beginTransaction();try{$q=$pdo->prepare('SELECT * FROM saki_redeem_codes WHERE code=:c AND is_active=1 AND expires_at>UTC_TIMESTAMP() AND (max_uses=0 OR used_count<max_uses) FOR UPDATE');$q->execute([':c'=>$code]);$row=$q->fetch();if(!$row)throw new Exception('invalid_or_expired_code');$q=$pdo->prepare('SELECT 1 FROM saki_redeem_code_uses WHERE code_id=:c AND user_id=:u');$q->execute([':c'=>$row['id'],':u'=>$u['id']]);if($q->fetch())throw new Exception('code_already_used');$q=$pdo->prepare('SELECT * FROM saki_redeem_code_rewards WHERE code_id=:c');$q->execute([':c'=>$row['id']]);foreach($q->fetchAll() as $rw){if($rw['reward_type']==='gold')$pdo->prepare('UPDATE saki_account_modules SET gold_coins=gold_coins+:n,updated_at=UTC_TIMESTAMP() WHERE user_id=:u')->execute([':n'=>$rw['quantity'],':u'=>$u['id']]);if($rw['reward_type']==='diamonds')$pdo->prepare('UPDATE saki_account_modules SET diamonds=diamonds+:n,updated_at=UTC_TIMESTAMP() WHERE user_id=:u')->execute([':n'=>$rw['quantity'],':u'=>$u['id']]);}$pdo->prepare('INSERT INTO saki_redeem_code_uses(id,code_id,user_id,redeemed_at) VALUES(:id,:c,:u,UTC_TIMESTAMP())')->execute([':id'=>bin2hex(random_bytes(16)),':c'=>$row['id'],':u'=>$u['id']]);$pdo->prepare('UPDATE saki_redeem_codes SET used_count=used_count+1 WHERE id=:id')->execute([':id'=>$row['id']]);$pdo->commit();respond(['ok'=>true]);}catch(Throwable $e){$pdo->rollBack();respond(['ok'=>false,'error'=>$e->getMessage()],422);} }

if ($action === 'wallet' && $_SERVER['REQUEST_METHOD'] === 'GET') {
  $u=currentUser($pdo); if(!$u) respond(['ok'=>false,'error'=>'unauthorized'],401);
  try {
    $q=$pdo->prepare('SELECT * FROM saki_account_modules WHERE user_id=:u LIMIT 1');
    $q->execute([':u'=>$u['id']]); $row=$q->fetch(PDO::FETCH_ASSOC);
    if(!$row) $row=['user_id'=>$u['id'],'wallet_balance'=>0,'gold_coins'=>0,'diamonds'=>0,'vip_level'=>(int)($u['vip_level']??0),'wealth_level'=>(int)($u['wealth_level']??0),'charm_level'=>0,'wallet_currency'=>'gold'];
    respond(['ok'=>true,'data'=>$row]);
  } catch(Throwable $e) { respond(['ok'=>false,'error'=>'wallet_sql:'.$e->getMessage()],500); }
}
if ($action === 'store_products' && $_SERVER['REQUEST_METHOD'] === 'GET') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$q=$pdo->query('SELECT * FROM saki_store_products WHERE is_active=1 ORDER BY created_at DESC LIMIT 100');respond(['ok'=>true,'data'=>$q->fetchAll()]); }
if ($action === 'store_buy' && $_SERVER['REQUEST_METHOD'] === 'POST') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$id=(string)(body()['product_id']??'');$pdo->beginTransaction();try{$q=$pdo->prepare('SELECT * FROM saki_store_products WHERE id=:id AND is_active=1 FOR UPDATE');$q->execute([':id'=>$id]);$p=$q->fetch();if(!$p)throw new Exception('product_not_found');$q=$pdo->prepare('SELECT gold_coins FROM saki_account_modules WHERE user_id=:u FOR UPDATE');$q->execute([':u'=>$u['id']]);if((int)$q->fetchColumn()<(int)$p['price'])throw new Exception('insufficient_gold_coins');$pdo->prepare('UPDATE saki_account_modules SET gold_coins=gold_coins-:p,updated_at=UTC_TIMESTAMP() WHERE user_id=:u')->execute([':p'=>$p['price'],':u'=>$u['id']]);$pdo->prepare('INSERT INTO saki_store_inventory(user_id,product_id,quantity,equipped,purchased_at,expires_at) VALUES(:u,:p,1,0,UTC_TIMESTAMP(),NULL) ON DUPLICATE KEY UPDATE quantity=quantity+1')->execute([':u'=>$u['id'],':p'=>$id]);$pdo->commit();respond(['ok'=>true]);}catch(Throwable $e){$pdo->rollBack();respond(['ok'=>false,'error'=>$e->getMessage()],422);} }
if ($action === 'admin_add_gold' && $_SERVER['REQUEST_METHOD'] === 'POST') { $u=currentUser($pdo);if(!$u||empty($u['is_super_admin']))respond(['ok'=>false,'error'=>'forbidden'],403);$d=body();$q=$pdo->prepare('UPDATE saki_account_modules SET gold_coins=gold_coins+:n,updated_at=UTC_TIMESTAMP() WHERE user_id=:u');$q->execute([':n'=>(int)$d['amount'],':u'=>$d['user_id']]);respond(['ok'=>true]); }
if ($action === 'recharge_intent' && $_SERVER['REQUEST_METHOD'] === 'POST') { respond(['ok'=>false,'error'=>'payment_provider_not_configured','message'=>'حدد مزود الدفع ومفاتيح API قبل تفعيل الشحن الحقيقي'],501); }


if ($action === 'luck_bag_create' && $_SERVER['REQUEST_METHOD'] === 'POST') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$d=body();$total=max(1,(int)($d['total_gold']??0));$limit=max(1,min(100,(int)($d['recipient_limit']??1)));$pdo->beginTransaction();try{$q=$pdo->prepare('SELECT gold_coins FROM saki_account_modules WHERE user_id=:u FOR UPDATE');$q->execute([':u'=>$u['id']]);if((int)$q->fetchColumn()<$total)throw new Exception('insufficient_gold_coins');$pdo->prepare('UPDATE saki_account_modules SET gold_coins=gold_coins-:n,updated_at=UTC_TIMESTAMP() WHERE user_id=:u')->execute([':n'=>$total,':u'=>$u['id']]);$id=bin2hex(random_bytes(16));$pdo->prepare('INSERT INTO room_luck_bags(id,room_id,sender_id,total_gold,recipient_limit,claimed_count,remaining_gold,status,created_at,expires_at) VALUES(:id,:r,:u,:t,:l,0,:t,\'open\',UTC_TIMESTAMP(),DATE_ADD(UTC_TIMESTAMP(),INTERVAL 24 HOUR))')->execute([':id'=>$id,':r'=>$d['room_id'],':u'=>$u['id'],':t'=>$total,':l'=>$limit]);$pdo->commit();respond(['ok'=>true,'data'=>['id'=>$id,'total_gold'=>$total]]);}catch(Throwable $e){$pdo->rollBack();respond(['ok'=>false,'error'=>$e->getMessage()],422);} }
if ($action === 'luck_bag_claim' && $_SERVER['REQUEST_METHOD'] === 'POST') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$id=(string)(body()['bag_id']??'');$pdo->beginTransaction();try{$q=$pdo->prepare('SELECT * FROM room_luck_bags WHERE id=:id FOR UPDATE');$q->execute([':id'=>$id]);$b=$q->fetch();if(!$b||$b['status']!=='open'||strtotime($b['expires_at'])<time()||$b['remaining_gold']<=0||$b['claimed_count']>=$b['recipient_limit'])throw new Exception('luck_bag_unavailable');$q=$pdo->prepare('SELECT 1 FROM room_luck_bag_claims WHERE bag_id=:b AND user_id=:u');$q->execute([':b'=>$id,':u'=>$u['id']]);if($q->fetch())throw new Exception('already_claimed');$amount=max(1,(int)floor($b['remaining_gold']/($b['recipient_limit']-$b['claimed_count'])));$pdo->prepare('INSERT INTO room_luck_bag_claims(id,bag_id,user_id,amount_gold,claimed_at) VALUES(:id,:b,:u,:n,UTC_TIMESTAMP())')->execute([':id'=>bin2hex(random_bytes(16)),':b'=>$id,':u'=>$u['id'],':n'=>$amount]);$pdo->prepare('UPDATE room_luck_bags SET remaining_gold=remaining_gold-:n,claimed_count=claimed_count+1,status=IF(remaining_gold-:n<=0 OR claimed_count+1>=recipient_limit,\'closed\',\'open\') WHERE id=:id')->execute([':n'=>$amount,':id'=>$id]);$pdo->prepare('UPDATE saki_account_modules SET gold_coins=gold_coins+:n,updated_at=UTC_TIMESTAMP() WHERE user_id=:u')->execute([':n'=>$amount,':u'=>$u['id']]);$pdo->commit();respond(['ok'=>true,'data'=>['amount_gold'=>$amount]]);}catch(Throwable $e){$pdo->rollBack();respond(['ok'=>false,'error'=>$e->getMessage()],422);} }
if ($action === 'room_ban_check' && $_SERVER['REQUEST_METHOD'] === 'GET') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$q=$pdo->prepare('SELECT expires_at FROM room_bans WHERE room_id=:r AND user_id=:u LIMIT 1');$q->execute([':r'=>$_GET['room_id']??' ',':u'=>$u['id']]);$x=$q->fetch();$banned=$x&&(!$x['expires_at']||strtotime($x['expires_at'])>time());respond(['ok'=>true,'data'=>[['banned'=>$banned,'expires_at'=>$x['expires_at']??null]]]); }
if ($action === 'room_presence' && $_SERVER['REQUEST_METHOD'] === 'POST') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$requested=trim((string)(body()['room_id']??''));$q=$pdo->prepare('SELECT id FROM rooms WHERE (id=:r OR room_id=:r) LIMIT 1');$q->execute([':r'=>$requested]);$room=$q->fetchColumn();if(!$room)respond(['ok'=>false,'error'=>'room_not_found'],404);$pdo->prepare('UPDATE room_members SET joined_at=UTC_TIMESTAMP() WHERE room_id=:r AND user_id=:u')->execute([':r'=>$room,':u'=>$u['id']]);respond(['ok'=>true]); }
if ($action === 'seat_claim' && $_SERVER['REQUEST_METHOD'] === 'POST') {
  $u=currentUser($pdo); if(!$u) respond(['ok'=>false,'error'=>'unauthorized'],401); $d=body(); $requested=trim((string)($d['room_id']??''));
  $q=$pdo->prepare('SELECT id FROM rooms WHERE (id=:r OR room_id=:r) AND is_active=1 LIMIT 1'); $q->execute([':r'=>$requested]); $room=$q->fetchColumn(); if(!$room) respond(['ok'=>false,'error'=>'room_not_found'],404);
  $q=$pdo->prepare('SELECT user_id FROM room_seats WHERE room_id=:r AND seat_no=:s'); $q->execute([':r'=>$room,':s'=>(int)($d['seat_no']??0)]); $x=$q->fetch(); if($x&&$x['user_id']!==$u['id']) respond(['ok'=>false,'error'=>'seat_taken'],409);
  $pdo->prepare('DELETE FROM room_seats WHERE room_id=:r AND user_id=:u')->execute([':r'=>$room,':u'=>$u['id']]); $pdo->prepare('INSERT INTO room_seats(room_id,seat_no,user_id,joined_at,is_speaking) VALUES(:r,:s,:u,UTC_TIMESTAMP(),0) ON DUPLICATE KEY UPDATE user_id=:u,joined_at=UTC_TIMESTAMP()')->execute([':r'=>$room,':s'=>(int)($d['seat_no']??0),':u'=>$u['id']]); respond(['ok'=>true]);
}

if ($action === 'seat_leave' && $_SERVER['REQUEST_METHOD'] === 'POST') {
  $u=currentUser($pdo); if(!$u) respond(['ok'=>false,'error'=>'unauthorized'],401); $requested=trim((string)(body()['room_id']??'')); $q=$pdo->prepare('SELECT id FROM rooms WHERE (id=:r OR room_id=:r) LIMIT 1'); $q->execute([':r'=>$requested]); $room=$q->fetchColumn(); if(!$room) respond(['ok'=>false,'error'=>'room_not_found'],404); $pdo->prepare('DELETE FROM room_seats WHERE room_id=:r AND user_id=:u')->execute([':r'=>$room,':u'=>$u['id']]); respond(['ok'=>true]);
}

if ($action === 'profile_update' && $_SERVER['REQUEST_METHOD'] === 'POST') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$d=body();$q=$pdo->prepare('UPDATE profiles SET username=:n,display_name=:n,bio=:b,country=COALESCE(NULLIF(:c,\'\'),country),country_code=COALESCE(NULLIF(:cc,\'\'),country_code),avatar_url=COALESCE(NULLIF(:a,\'\'),avatar_url),updated_at=UTC_TIMESTAMP() WHERE id=:u');$q->execute([':n'=>trim((string)($d['username']??$u['username'])),':b'=>trim((string)($d['bio']??'')),':c'=>trim((string)($d['country']??'')),':cc'=>trim((string)($d['country_code']??'')),':a'=>trim((string)($d['avatar_url']??'')),':u'=>$u['id']]);respond(['ok'=>true]); }
if ($action === 'country_flag' && $_SERVER['REQUEST_METHOD'] === 'GET') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$v=trim((string)($_GET['value']??''));$q=$pdo->prepare('SELECT flag FROM countries WHERE name_ar=:v OR code=:c LIMIT 1');$q->execute([':v'=>$v,':c'=>strtoupper($v)]);respond(['ok'=>true,'data'=>[['flag'=>$q->fetchColumn()?:'🌍']]]); }
if ($action === 'content_share' && $_SERVER['REQUEST_METHOD'] === 'POST') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$d=body();$table=($d['type']??'post')==='reel'?'reel_shares':'post_shares';$column=$table==='reel_shares'?'reel_id':'post_id';$pdo->prepare("INSERT INTO $table($column,user_id,created_at) VALUES(:id,:u,UTC_TIMESTAMP()) ON DUPLICATE KEY UPDATE user_id=user_id")->execute([':id'=>$d['id']??' ',':u'=>$u['id']]);respond(['ok'=>true]); }
if ($action === 'room_banners' && $_SERVER['REQUEST_METHOD'] === 'GET') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$q=$pdo->query("SELECT id,image_url,title,sort_order,target_type,target_user_id,target_room_id FROM room_banners WHERE is_active=1 ORDER BY sort_order LIMIT 50");respond(['ok'=>true,'data'=>$q->fetchAll()]); }
if ($action === 'user_profile_stats' && $_SERVER['REQUEST_METHOD'] === 'GET') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$id=trim((string)($_GET['user_id']??''));$q=$pdo->prepare('SELECT (SELECT COUNT(*) FROM posts WHERE author_id=:id) posts,(SELECT COUNT(*) FROM follows WHERE following_id=:id) followers,(SELECT COUNT(*) FROM follows WHERE follower_id=:id) following');$q->execute([':id'=>$id]);$r=$q->fetch();respond(['ok'=>true,'data'=>[['posts'=>(int)$r['posts'],'followers'=>(int)$r['followers'],'following'=>(int)$r['following']]]]); }
if ($action === 'user_profile' && $_SERVER['REQUEST_METHOD'] === 'GET') {
  $u=currentUser($pdo); if(!$u) respond(['ok'=>false,'error'=>'unauthorized'],401);
  $id=trim((string)($_GET['user_id']??''));
  if($id==='') respond(['ok'=>false,'error'=>'user_id_required'],422);
  try {
    $q=$pdo->prepare('SELECT id,username,display_name,avatar_url,bio,saki_id,vip_level,wealth_level FROM profiles WHERE id=:id LIMIT 1');
    $q->execute([':id'=>$id]);
    $row=$q->fetch(PDO::FETCH_ASSOC);
    respond(['ok'=>true,'data'=>$row ? [$row] : []]);
  } catch(Throwable $e) {
    respond(['ok'=>false,'error'=>'user_profile_sql:'.$e->getMessage()],500);
  }
}
if ($action === 'room_ban_check' && $_SERVER['REQUEST_METHOD'] === 'GET') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$q=$pdo->prepare('SELECT expires_at FROM room_bans WHERE room_id=:r AND user_id=:u LIMIT 1');$q->execute([':r'=>$_GET['room_id']??' ',':u'=>$u['id']]);$x=$q->fetch();$banned=$x&&(!$x['expires_at']||strtotime($x['expires_at'])>time());respond(['ok'=>true,'data'=>[['banned'=>$banned,'expires_at'=>$x['expires_at']??null]]]); }
if ($action === 'room_presence' && $_SERVER['REQUEST_METHOD'] === 'POST') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$requested=trim((string)(body()['room_id']??''));$q=$pdo->prepare('SELECT id FROM rooms WHERE (id=:r OR room_id=:r) LIMIT 1');$q->execute([':r'=>$requested]);$room=$q->fetchColumn();if(!$room)respond(['ok'=>false,'error'=>'room_not_found'],404);$pdo->prepare('UPDATE room_members SET joined_at=UTC_TIMESTAMP() WHERE room_id=:r AND user_id=:u')->execute([':r'=>$room,':u'=>$u['id']]);respond(['ok'=>true]); }
if ($action === 'seat_claim' && $_SERVER['REQUEST_METHOD'] === 'POST') {
  $u=currentUser($pdo); if(!$u) respond(['ok'=>false,'error'=>'unauthorized'],401); $d=body(); $requested=trim((string)($d['room_id']??''));
  $q=$pdo->prepare('SELECT id FROM rooms WHERE (id=:r OR room_id=:r) AND is_active=1 LIMIT 1'); $q->execute([':r'=>$requested]); $room=$q->fetchColumn(); if(!$room) respond(['ok'=>false,'error'=>'room_not_found'],404);
  $q=$pdo->prepare('SELECT user_id FROM room_seats WHERE room_id=:r AND seat_no=:s'); $q->execute([':r'=>$room,':s'=>(int)($d['seat_no']??0)]); $x=$q->fetch(); if($x&&$x['user_id']!==$u['id']) respond(['ok'=>false,'error'=>'seat_taken'],409);
  $pdo->prepare('DELETE FROM room_seats WHERE room_id=:r AND user_id=:u')->execute([':r'=>$room,':u'=>$u['id']]); $pdo->prepare('INSERT INTO room_seats(room_id,seat_no,user_id,joined_at,is_speaking) VALUES(:r,:s,:u,UTC_TIMESTAMP(),0) ON DUPLICATE KEY UPDATE user_id=:u,joined_at=UTC_TIMESTAMP()')->execute([':r'=>$room,':s'=>(int)($d['seat_no']??0),':u'=>$u['id']]); respond(['ok'=>true]);
}

if ($action === 'seat_leave' && $_SERVER['REQUEST_METHOD'] === 'POST') {
  $u=currentUser($pdo); if(!$u) respond(['ok'=>false,'error'=>'unauthorized'],401); $requested=trim((string)(body()['room_id']??'')); $q=$pdo->prepare('SELECT id FROM rooms WHERE (id=:r OR room_id=:r) LIMIT 1'); $q->execute([':r'=>$requested]); $room=$q->fetchColumn(); if(!$room) respond(['ok'=>false,'error'=>'room_not_found'],404); $pdo->prepare('DELETE FROM room_seats WHERE room_id=:r AND user_id=:u')->execute([':r'=>$room,':u'=>$u['id']]); respond(['ok'=>true]);
}

if ($action === 'profile_update' && $_SERVER['REQUEST_METHOD'] === 'POST') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$d=body();$q=$pdo->prepare('UPDATE profiles SET username=:n,display_name=:n,bio=:b,country=COALESCE(NULLIF(:c,\'\'),country),country_code=COALESCE(NULLIF(:cc,\'\'),country_code),avatar_url=COALESCE(NULLIF(:a,\'\'),avatar_url),updated_at=UTC_TIMESTAMP() WHERE id=:u');$q->execute([':n'=>trim((string)($d['username']??$u['username'])),':b'=>trim((string)($d['bio']??'')),':c'=>trim((string)($d['country']??'')),':cc'=>trim((string)($d['country_code']??'')),':a'=>trim((string)($d['avatar_url']??'')),':u'=>$u['id']]);respond(['ok'=>true]); }
if ($action === 'country_flag' && $_SERVER['REQUEST_METHOD'] === 'GET') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$v=trim((string)($_GET['value']??''));$q=$pdo->prepare('SELECT flag FROM countries WHERE name_ar=:v OR code=:c LIMIT 1');$q->execute([':v'=>$v,':c'=>strtoupper($v)]);respond(['ok'=>true,'data'=>[['flag'=>$q->fetchColumn()?:'🌍']]]); }
if ($action === 'content_share' && $_SERVER['REQUEST_METHOD'] === 'POST') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$d=body();$table=($d['type']??'post')==='reel'?'reel_shares':'post_shares';$column=$table==='reel_shares'?'reel_id':'post_id';$pdo->prepare("INSERT INTO $table($column,user_id,created_at) VALUES(:id,:u,UTC_TIMESTAMP()) ON DUPLICATE KEY UPDATE user_id=user_id")->execute([':id'=>$d['id']??' ',':u'=>$u['id']]);respond(['ok'=>true]); }
if ($action === 'room_banners' && $_SERVER['REQUEST_METHOD'] === 'GET') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$q=$pdo->query("SELECT id,image_url,title,sort_order,target_type,target_user_id,target_room_id FROM room_banners WHERE is_active=1 ORDER BY sort_order LIMIT 50");respond(['ok'=>true,'data'=>$q->fetchAll()]); }
if ($action === 'family_me' && $_SERVER['REQUEST_METHOD'] === 'GET') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$q=$pdo->prepare('SELECT f.*,fm.role FROM family_members fm JOIN families f ON f.id=fm.family_id WHERE fm.user_id=:u AND fm.status=\'active\' LIMIT 1');$q->execute([':u'=>$u['id']]);$row=$q->fetch();respond(['ok'=>true,'data'=>$row?[$row]:[]]); }
if ($action === 'family_update' && $_SERVER['REQUEST_METHOD'] === 'POST') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$d=body();$q=$pdo->prepare('UPDATE families f JOIN family_members fm ON fm.family_id=f.id SET f.name=:n,f.family_alias=:a,f.avatar_url=:av,f.announcement=:an,f.updated_at=UTC_TIMESTAMP() WHERE f.id=:f AND fm.user_id=:u AND fm.role IN (\'owner\',\'admin\')');$q->execute([':n'=>trim((string)($d['name']??'')),':a'=>trim((string)($d['alias']??'')),':av'=>$d['avatar_url']??null,':an'=>$d['announcement']??'',':f'=>$d['family_id']??' ',':u'=>$u['id']]);respond(['ok'=>true]); }
if ($action === 'family_request_decide' && $_SERVER['REQUEST_METHOD'] === 'POST') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$d=body();$status=($d['decision']??'reject')==='approve'?'approved':'rejected';$q=$pdo->prepare('SELECT family_id,user_id FROM family_join_requests WHERE id=:id LIMIT 1');$q->execute([':id'=>$d['request_id']??'']);$r=$q->fetch();if(!$r)respond(['ok'=>false,'error'=>'request_not_found'],404);$pdo->beginTransaction();try{$pdo->prepare('UPDATE family_join_requests SET status=:s WHERE id=:id')->execute([':s'=>$status,':id'=>$d['request_id']]);if($status==='approved')$pdo->prepare('INSERT INTO family_members(family_id,user_id,role,status,joined_at) VALUES(:f,:u,\'member\',\'active\',UTC_TIMESTAMP()) ON DUPLICATE KEY UPDATE status=\'active\'')->execute([':f'=>$r['family_id'],':u'=>$r['user_id']]);$pdo->commit();respond(['ok'=>true]);}catch(Throwable $e){$pdo->rollBack();respond(['ok'=>false,'error'=>'family_decision_failed'],422);} }
if ($action === 'family_members' && $_SERVER['REQUEST_METHOD'] === 'GET') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$q=$pdo->prepare('SELECT fm.user_id,fm.role,fm.joined_at,p.id,p.username,p.display_name,p.avatar_url,p.saki_id FROM family_members fm JOIN profiles p ON p.id=fm.user_id WHERE fm.family_id=:f AND fm.status=\'active\' ORDER BY fm.joined_at LIMIT 200');$q->execute([':f'=>$_GET['family_id']??'']);respond(['ok'=>true,'data'=>$q->fetchAll()]); }
if ($action === 'family_tasks' && $_SERVER['REQUEST_METHOD'] === 'GET') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$q=$pdo->prepare('SELECT * FROM family_tasks WHERE family_id=:f ORDER BY created_at LIMIT 30');$q->execute([':f'=>$_GET['family_id']??'']);respond(['ok'=>true,'data'=>$q->fetchAll()]); }
if ($action === 'family_task_complete' && $_SERVER['REQUEST_METHOD'] === 'POST') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$d=body();$inc=max(1,min(100,(int)($d['increment']??1)));$q=$pdo->prepare('UPDATE family_tasks ft JOIN family_members fm ON fm.family_id=ft.family_id SET ft.progress=LEAST(ft.target,ft.progress+:i) WHERE ft.family_id=:f AND ft.task_key=:k AND fm.user_id=:u AND fm.status=\'active\'');$q->execute([':i'=>$inc,':f'=>$d['family_id']??' ',':k'=>$d['task_key']??' ',':u'=>$u['id']]);$q=$pdo->prepare('SELECT * FROM family_tasks WHERE family_id=:f AND task_key=:k LIMIT 1');$q->execute([':f'=>$d['family_id']??' ',':k'=>$d['task_key']??' ']);respond(['ok'=>true,'data'=>[$q->fetch()?:[]]]); }
if ($action === 'user_badges' && $_SERVER['REQUEST_METHOD'] === 'GET') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$q=$pdo->prepare('SELECT ub.badge_key,ub.earned_at,bc.name,bc.description,bc.asset_path,bc.sort_order FROM user_badges ub LEFT JOIN badge_catalog bc ON bc.badge_key=ub.badge_key WHERE ub.user_id=:id ORDER BY bc.sort_order,ub.earned_at DESC LIMIT 100');$q->execute([':id'=>$_GET['user_id']??'']);respond(['ok'=>true,'data'=>$q->fetchAll()]); }
if ($action === 'user_vehicles' && $_SERVER['REQUEST_METHOD'] === 'GET') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$q=$pdo->prepare('SELECT i.item_id,i.purchased_at,i.expires_at,i.is_active,c.id,c.name,c.asset_key,c.price_gold_coins,c.duration_days,c.category FROM trace_store_inventory i JOIN trace_store_catalog c ON c.id=i.item_id WHERE i.user_id=:id AND i.is_active=1 ORDER BY i.purchased_at DESC LIMIT 100');$q->execute([':id'=>$_GET['user_id']??'']);respond(['ok'=>true,'data'=>$q->fetchAll()]); }
if ($action === 'user_received_gifts' && $_SERVER['REQUEST_METHOD'] === 'GET') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$q=$pdo->prepare('SELECT rg.gift_id id,g.name,g.icon,g.price,SUM(rg.quantity) received_count,SUM(rg.total_price) received_value,MAX(rg.created_at) last_received_at,MAX(r.name) room_name FROM room_gifts rg JOIN room_gift_catalog g ON g.id=rg.gift_id LEFT JOIN rooms r ON r.id=rg.room_id WHERE rg.recipient_id=:id GROUP BY rg.gift_id,g.name,g.icon,g.price ORDER BY received_value DESC LIMIT 100');$q->execute([':id'=>$_GET['user_id']??'']);respond(['ok'=>true,'data'=>$q->fetchAll()]); }
if ($action === 'user_profile_stats' && $_SERVER['REQUEST_METHOD'] === 'GET') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$id=trim((string)($_GET['user_id']??''));$q=$pdo->prepare('SELECT (SELECT COUNT(*) FROM posts WHERE author_id=:id) posts,(SELECT COUNT(*) FROM follows WHERE following_id=:id) followers,(SELECT COUNT(*) FROM follows WHERE follower_id=:id) following');$q->execute([':id'=>$id]);$r=$q->fetch();respond(['ok'=>true,'data'=>[['posts'=>(int)$r['posts'],'followers'=>(int)$r['followers'],'following'=>(int)$r['following']]]]); }
if ($action === 'user_profile' && $_SERVER['REQUEST_METHOD'] === 'GET') {
  $u=currentUser($pdo); if(!$u) respond(['ok'=>false,'error'=>'unauthorized'],401);
  $id=trim((string)($_GET['user_id']??''));
  if($id==='') respond(['ok'=>false,'error'=>'user_id_required'],422);
  try {
    $q=$pdo->prepare('SELECT id,username,display_name,avatar_url,bio,saki_id,vip_level,wealth_level FROM profiles WHERE id=:id LIMIT 1');
    $q->execute([':id'=>$id]);
    $row=$q->fetch(PDO::FETCH_ASSOC);
    respond(['ok'=>true,'data'=>$row ? [$row] : []]);
  } catch(Throwable $e) {
    respond(['ok'=>false,'error'=>'user_profile_sql:'.$e->getMessage()],500);
  }
}
if ($action === 'room_ban_check' && $_SERVER['REQUEST_METHOD'] === 'GET') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$q=$pdo->prepare('SELECT expires_at FROM room_bans WHERE room_id=:r AND user_id=:u LIMIT 1');$q->execute([':r'=>$_GET['room_id']??' ',':u'=>$u['id']]);$x=$q->fetch();$banned=$x&&(!$x['expires_at']||strtotime($x['expires_at'])>time());respond(['ok'=>true,'data'=>[['banned'=>$banned,'expires_at'=>$x['expires_at']??null]]]); }
if ($action === 'room_presence' && $_SERVER['REQUEST_METHOD'] === 'POST') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$requested=trim((string)(body()['room_id']??''));$q=$pdo->prepare('SELECT id FROM rooms WHERE (id=:r OR room_id=:r) LIMIT 1');$q->execute([':r'=>$requested]);$room=$q->fetchColumn();if(!$room)respond(['ok'=>false,'error'=>'room_not_found'],404);$pdo->prepare('UPDATE room_members SET joined_at=UTC_TIMESTAMP() WHERE room_id=:r AND user_id=:u')->execute([':r'=>$room,':u'=>$u['id']]);respond(['ok'=>true]); }
if ($action === 'seat_claim' && $_SERVER['REQUEST_METHOD'] === 'POST') {
  $u=currentUser($pdo); if(!$u) respond(['ok'=>false,'error'=>'unauthorized'],401); $d=body(); $requested=trim((string)($d['room_id']??''));
  $q=$pdo->prepare('SELECT id FROM rooms WHERE (id=:r OR room_id=:r) AND is_active=1 LIMIT 1'); $q->execute([':r'=>$requested]); $room=$q->fetchColumn(); if(!$room) respond(['ok'=>false,'error'=>'room_not_found'],404);
  $q=$pdo->prepare('SELECT user_id FROM room_seats WHERE room_id=:r AND seat_no=:s'); $q->execute([':r'=>$room,':s'=>(int)($d['seat_no']??0)]); $x=$q->fetch(); if($x&&$x['user_id']!==$u['id']) respond(['ok'=>false,'error'=>'seat_taken'],409);
  $pdo->prepare('DELETE FROM room_seats WHERE room_id=:r AND user_id=:u')->execute([':r'=>$room,':u'=>$u['id']]); $pdo->prepare('INSERT INTO room_seats(room_id,seat_no,user_id,joined_at,is_speaking) VALUES(:r,:s,:u,UTC_TIMESTAMP(),0) ON DUPLICATE KEY UPDATE user_id=:u,joined_at=UTC_TIMESTAMP()')->execute([':r'=>$room,':s'=>(int)($d['seat_no']??0),':u'=>$u['id']]); respond(['ok'=>true]);
}

if ($action === 'seat_leave' && $_SERVER['REQUEST_METHOD'] === 'POST') {
  $u=currentUser($pdo); if(!$u) respond(['ok'=>false,'error'=>'unauthorized'],401); $requested=trim((string)(body()['room_id']??'')); $q=$pdo->prepare('SELECT id FROM rooms WHERE (id=:r OR room_id=:r) LIMIT 1'); $q->execute([':r'=>$requested]); $room=$q->fetchColumn(); if(!$room) respond(['ok'=>false,'error'=>'room_not_found'],404); $pdo->prepare('DELETE FROM room_seats WHERE room_id=:r AND user_id=:u')->execute([':r'=>$room,':u'=>$u['id']]); respond(['ok'=>true]);
}

if ($action === 'profile_update' && $_SERVER['REQUEST_METHOD'] === 'POST') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$d=body();$q=$pdo->prepare('UPDATE profiles SET username=:n,display_name=:n,bio=:b,country=COALESCE(NULLIF(:c,\'\'),country),country_code=COALESCE(NULLIF(:cc,\'\'),country_code),avatar_url=COALESCE(NULLIF(:a,\'\'),avatar_url),updated_at=UTC_TIMESTAMP() WHERE id=:u');$q->execute([':n'=>trim((string)($d['username']??$u['username'])),':b'=>trim((string)($d['bio']??'')),':c'=>trim((string)($d['country']??'')),':cc'=>trim((string)($d['country_code']??'')),':a'=>trim((string)($d['avatar_url']??'')),':u'=>$u['id']]);respond(['ok'=>true]); }
if ($action === 'country_flag' && $_SERVER['REQUEST_METHOD'] === 'GET') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$v=trim((string)($_GET['value']??''));$q=$pdo->prepare('SELECT flag FROM countries WHERE name_ar=:v OR code=:c LIMIT 1');$q->execute([':v'=>$v,':c'=>strtoupper($v)]);respond(['ok'=>true,'data'=>[['flag'=>$q->fetchColumn()?:'🌍']]]); }
if ($action === 'content_share' && $_SERVER['REQUEST_METHOD'] === 'POST') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$d=body();$table=($d['type']??'post')==='reel'?'reel_shares':'post_shares';$column=$table==='reel_shares'?'reel_id':'post_id';$pdo->prepare("INSERT INTO $table($column,user_id,created_at) VALUES(:id,:u,UTC_TIMESTAMP()) ON DUPLICATE KEY UPDATE user_id=user_id")->execute([':id'=>$d['id']??' ',':u'=>$u['id']]);respond(['ok'=>true]); }
if ($action === 'room_banners' && $_SERVER['REQUEST_METHOD'] === 'GET') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$q=$pdo->query("SELECT id,image_url,title,sort_order,target_type,target_user_id,target_room_id FROM room_banners WHERE is_active=1 ORDER BY sort_order LIMIT 50");respond(['ok'=>true,'data'=>$q->fetchAll()]); }
if ($action === 'family_me' && $_SERVER['REQUEST_METHOD'] === 'GET') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$q=$pdo->prepare('SELECT f.*,fm.role FROM family_members fm JOIN families f ON f.id=fm.family_id WHERE fm.user_id=:u AND fm.status=\'active\' LIMIT 1');$q->execute([':u'=>$u['id']]);$row=$q->fetch();respond(['ok'=>true,'data'=>$row?[$row]:[]]); }
if ($action === 'family_update' && $_SERVER['REQUEST_METHOD'] === 'POST') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$d=body();$q=$pdo->prepare('UPDATE families f JOIN family_members fm ON fm.family_id=f.id SET f.name=:n,f.family_alias=:a,f.avatar_url=:av,f.announcement=:an,f.updated_at=UTC_TIMESTAMP() WHERE f.id=:f AND fm.user_id=:u AND fm.role IN (\'owner\',\'admin\')');$q->execute([':n'=>trim((string)($d['name']??'')),':a'=>trim((string)($d['alias']??'')),':av'=>$d['avatar_url']??null,':an'=>$d['announcement']??'',':f'=>$d['family_id']??' ',':u'=>$u['id']]);respond(['ok'=>true]); }
if ($action === 'family_request_decide' && $_SERVER['REQUEST_METHOD'] === 'POST') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$d=body();$status=($d['decision']??'reject')==='approve'?'approved':'rejected';$q=$pdo->prepare('SELECT family_id,user_id FROM family_join_requests WHERE id=:id LIMIT 1');$q->execute([':id'=>$d['request_id']??'']);$r=$q->fetch();if(!$r)respond(['ok'=>false,'error'=>'request_not_found'],404);$pdo->beginTransaction();try{$pdo->prepare('UPDATE family_join_requests SET status=:s WHERE id=:id')->execute([':s'=>$status,':id'=>$d['request_id']]);if($status==='approved')$pdo->prepare('INSERT INTO family_members(family_id,user_id,role,status,joined_at) VALUES(:f,:u,\'member\',\'active\',UTC_TIMESTAMP()) ON DUPLICATE KEY UPDATE status=\'active\'')->execute([':f'=>$r['family_id'],':u'=>$r['user_id']]);$pdo->commit();respond(['ok'=>true]);}catch(Throwable $e){$pdo->rollBack();respond(['ok'=>false,'error'=>'family_decision_failed'],422);} }
if ($action === 'family_members' && $_SERVER['REQUEST_METHOD'] === 'GET') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$q=$pdo->prepare('SELECT fm.user_id,fm.role,fm.joined_at,p.id,p.username,p.display_name,p.avatar_url,p.saki_id FROM family_members fm JOIN profiles p ON p.id=fm.user_id WHERE fm.family_id=:f AND fm.status=\'active\' ORDER BY fm.joined_at LIMIT 200');$q->execute([':f'=>$_GET['family_id']??'']);respond(['ok'=>true,'data'=>$q->fetchAll()]); }
if ($action === 'family_tasks' && $_SERVER['REQUEST_METHOD'] === 'GET') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$q=$pdo->prepare('SELECT * FROM family_tasks WHERE family_id=:f ORDER BY created_at LIMIT 30');$q->execute([':f'=>$_GET['family_id']??'']);respond(['ok'=>true,'data'=>$q->fetchAll()]); }
if ($action === 'family_task_complete' && $_SERVER['REQUEST_METHOD'] === 'POST') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$d=body();$inc=max(1,min(100,(int)($d['increment']??1)));$q=$pdo->prepare('UPDATE family_tasks ft JOIN family_members fm ON fm.family_id=ft.family_id SET ft.progress=LEAST(ft.target,ft.progress+:i) WHERE ft.family_id=:f AND ft.task_key=:k AND fm.user_id=:u AND fm.status=\'active\'');$q->execute([':i'=>$inc,':f'=>$d['family_id']??' ',':k'=>$d['task_key']??' ',':u'=>$u['id']]);$q=$pdo->prepare('SELECT * FROM family_tasks WHERE family_id=:f AND task_key=:k LIMIT 1');$q->execute([':f'=>$d['family_id']??' ',':k'=>$d['task_key']??' ']);respond(['ok'=>true,'data'=>$q->fetch()?:[]]); }
if ($action === 'user_badges' && $_SERVER['REQUEST_METHOD'] === 'GET') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$q=$pdo->prepare('SELECT ub.badge_key,ub.earned_at,bc.name,bc.description,bc.asset_path,bc.sort_order FROM user_badges ub LEFT JOIN badge_catalog bc ON bc.badge_key=ub.badge_key WHERE ub.user_id=:id ORDER BY bc.sort_order,ub.earned_at DESC LIMIT 100');$q->execute([':id'=>$_GET['user_id']??'']);respond(['ok'=>true,'data'=>$q->fetchAll()]); }
if ($action === 'user_vehicles' && $_SERVER['REQUEST_METHOD'] === 'GET') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$q=$pdo->prepare('SELECT i.item_id,i.purchased_at,i.expires_at,i.is_active,c.id,c.name,c.asset_key,c.price_gold_coins,c.duration_days,c.category FROM trace_store_inventory i JOIN trace_store_catalog c ON c.id=i.item_id WHERE i.user_id=:id AND i.is_active=1 ORDER BY i.purchased_at DESC LIMIT 100');$q->execute([':id'=>$_GET['user_id']??'']);respond(['ok'=>true,'data'=>$q->fetchAll()]); }
if ($action === 'user_received_gifts' && $_SERVER['REQUEST_METHOD'] === 'GET') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$q=$pdo->prepare('SELECT rg.gift_id id,g.name,g.icon,g.price,SUM(rg.quantity) received_count,SUM(rg.total_price) received_value,MAX(rg.created_at) last_received_at,MAX(r.name) room_name FROM room_gifts rg JOIN room_gift_catalog g ON g.id=rg.gift_id LEFT JOIN rooms r ON r.id=rg.room_id WHERE rg.recipient_id=:id GROUP BY rg.gift_id,g.name,g.icon,g.price ORDER BY received_value DESC LIMIT 100');$q->execute([':id'=>$_GET['user_id']??'']);respond(['ok'=>true,'data'=>$q->fetchAll()]); }
if ($action === 'user_profile_stats' && $_SERVER['REQUEST_METHOD'] === 'GET') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$id=trim((string)($_GET['user_id']??''));$q=$pdo->prepare('SELECT (SELECT COUNT(*) FROM posts WHERE author_id=:id) posts,(SELECT COUNT(*) FROM follows WHERE following_id=:id) followers,(SELECT COUNT(*) FROM follows WHERE follower_id=:id) following');$q->execute([':id'=>$id]);$r=$q->fetch();respond(['ok'=>true,'data'=>[['posts'=>(int)$r['posts'],'followers'=>(int)$r['followers'],'following'=>(int)$r['following']]]]); }
if ($action === 'user_profile' && $_SERVER['REQUEST_METHOD'] === 'GET') {
  $u=currentUser($pdo); if(!$u) respond(['ok'=>false,'error'=>'unauthorized'],401);
  $id=trim((string)($_GET['user_id']??''));
  if($id==='') respond(['ok'=>false,'error'=>'user_id_required'],422);
  try {
    $q=$pdo->prepare('SELECT id,username,display_name,avatar_url,bio,saki_id,vip_level,wealth_level FROM profiles WHERE id=:id LIMIT 1');
    $q->execute([':id'=>$id]);
    $row=$q->fetch(PDO::FETCH_ASSOC);
    respond(['ok'=>true,'data'=>$row ? [$row] : []]);
  } catch(Throwable $e) {
    respond(['ok'=>false,'error'=>'user_profile_sql:'.$e->getMessage()],500);
  }
}
if ($action === 'room_ban_check' && $_SERVER['REQUEST_METHOD'] === 'GET') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$q=$pdo->prepare('SELECT expires_at FROM room_bans WHERE room_id=:r AND user_id=:u LIMIT 1');$q->execute([':r'=>$_GET['room_id']??' ',':u'=>$u['id']]);$x=$q->fetch();$banned=$x&&(!$x['expires_at']||strtotime($x['expires_at'])>time());respond(['ok'=>true,'data'=>[['banned'=>$banned,'expires_at'=>$x['expires_at']??null]]]); }
if ($action === 'room_presence' && $_SERVER['REQUEST_METHOD'] === 'POST') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$requested=trim((string)(body()['room_id']??''));$q=$pdo->prepare('SELECT id FROM rooms WHERE (id=:r OR room_id=:r) LIMIT 1');$q->execute([':r'=>$requested]);$room=$q->fetchColumn();if(!$room)respond(['ok'=>false,'error'=>'room_not_found'],404);$pdo->prepare('UPDATE room_members SET joined_at=UTC_TIMESTAMP() WHERE room_id=:r AND user_id=:u')->execute([':r'=>$room,':u'=>$u['id']]);respond(['ok'=>true]); }
if ($action === 'seat_claim' && $_SERVER['REQUEST_METHOD'] === 'POST') {
  $u=currentUser($pdo); if(!$u) respond(['ok'=>false,'error'=>'unauthorized'],401); $d=body(); $requested=trim((string)($d['room_id']??''));
  $q=$pdo->prepare('SELECT id FROM rooms WHERE (id=:r OR room_id=:r) AND is_active=1 LIMIT 1'); $q->execute([':r'=>$requested]); $room=$q->fetchColumn(); if(!$room) respond(['ok'=>false,'error'=>'room_not_found'],404);
  $q=$pdo->prepare('SELECT user_id FROM room_seats WHERE room_id=:r AND seat_no=:s'); $q->execute([':r'=>$room,':s'=>(int)($d['seat_no']??0)]); $x=$q->fetch(); if($x&&$x['user_id']!==$u['id']) respond(['ok'=>false,'error'=>'seat_taken'],409);
  $pdo->prepare('DELETE FROM room_seats WHERE room_id=:r AND user_id=:u')->execute([':r'=>$room,':u'=>$u['id']]); $pdo->prepare('INSERT INTO room_seats(room_id,seat_no,user_id,joined_at,is_speaking) VALUES(:r,:s,:u,UTC_TIMESTAMP(),0) ON DUPLICATE KEY UPDATE user_id=:u,joined_at=UTC_TIMESTAMP()')->execute([':r'=>$room,':s'=>(int)($d['seat_no']??0),':u'=>$u['id']]); respond(['ok'=>true]);
}

if ($action === 'seat_leave' && $_SERVER['REQUEST_METHOD'] === 'POST') {
  $u=currentUser($pdo); if(!$u) respond(['ok'=>false,'error'=>'unauthorized'],401); $requested=trim((string)(body()['room_id']??'')); $q=$pdo->prepare('SELECT id FROM rooms WHERE (id=:r OR room_id=:r) LIMIT 1'); $q->execute([':r'=>$requested]); $room=$q->fetchColumn(); if(!$room) respond(['ok'=>false,'error'=>'room_not_found'],404); $pdo->prepare('DELETE FROM room_seats WHERE room_id=:r AND user_id=:u')->execute([':r'=>$room,':u'=>$u['id']]); respond(['ok'=>true]);
}

if ($action === 'profile_update' && $_SERVER['REQUEST_METHOD'] === 'POST') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$d=body();$q=$pdo->prepare('UPDATE profiles SET username=:n,display_name=:n,bio=:b,country=COALESCE(NULLIF(:c,\'\'),country),country_code=COALESCE(NULLIF(:cc,\'\'),country_code),avatar_url=COALESCE(NULLIF(:a,\'\'),avatar_url),updated_at=UTC_TIMESTAMP() WHERE id=:u');$q->execute([':n'=>trim((string)($d['username']??$u['username'])),':b'=>trim((string)($d['bio']??'')),':c'=>trim((string)($d['country']??'')),':cc'=>trim((string)($d['country_code']??'')),':a'=>trim((string)($d['avatar_url']??'')),':u'=>$u['id']]);respond(['ok'=>true]); }
if ($action === 'country_flag' && $_SERVER['REQUEST_METHOD'] === 'GET') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$v=trim((string)($_GET['value']??''));$q=$pdo->prepare('SELECT flag FROM countries WHERE name_ar=:v OR code=:c LIMIT 1');$q->execute([':v'=>$v,':c'=>strtoupper($v)]);respond(['ok'=>true,'data'=>[['flag'=>$q->fetchColumn()?:'🌍']]]); }
if ($action === 'content_share' && $_SERVER['REQUEST_METHOD'] === 'POST') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$d=body();$table=($d['type']??'post')==='reel'?'reel_shares':'post_shares';$column=$table==='reel_shares'?'reel_id':'post_id';$pdo->prepare("INSERT INTO $table($column,user_id,created_at) VALUES(:id,:u,UTC_TIMESTAMP()) ON DUPLICATE KEY UPDATE user_id=user_id")->execute([':id'=>$d['id']??' ',':u'=>$u['id']]);respond(['ok'=>true]); }
if ($action === 'room_banners' && $_SERVER['REQUEST_METHOD'] === 'GET') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$q=$pdo->query("SELECT id,image_url,title,sort_order,target_type,target_user_id,target_room_id FROM room_banners WHERE is_active=1 ORDER BY sort_order LIMIT 50");respond(['ok'=>true,'data'=>$q->fetchAll()]); }
if ($action === 'room_members' && $_SERVER['REQUEST_METHOD'] === 'GET') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$room=trim((string)($_GET['room_id']??''));$q=$pdo->prepare("SELECT rm.user_id,rm.joined_at,pr.id,pr.username,pr.display_name,pr.avatar_url,pr.vip_level,pr.vip_expires_at FROM room_members rm JOIN profiles pr ON pr.id=rm.user_id WHERE rm.room_id=:r ORDER BY rm.joined_at DESC LIMIT 100");$q->execute([':r'=>$room]);respond(['ok'=>true,'data'=>$q->fetchAll()]); }
if ($action === 'room_seats' && $_SERVER['REQUEST_METHOD'] === 'GET') {
  $u=currentUser($pdo); if(!$u) respond(['ok'=>false,'error'=>'unauthorized'],401); $requested=trim((string)($_GET['room_id']??''));
  $q=$pdo->prepare('SELECT id FROM rooms WHERE (id=:r OR room_id=:r) AND is_active=1 LIMIT 1'); $q->execute([':r'=>$requested]); $room=$q->fetchColumn(); if(!$room) respond(['ok'=>false,'error'=>'room_not_found'],404);
  $q=$pdo->prepare("SELECT rs.seat_no,rs.user_id,rs.joined_at,rs.is_speaking,pr.id,pr.username,pr.display_name,pr.avatar_url,pr.vip_level FROM room_seats rs LEFT JOIN profiles pr ON pr.id=rs.user_id WHERE rs.room_id=:r ORDER BY rs.seat_no"); $q->execute([':r'=>$room]); respond(['ok'=>true,'data'=>$q->fetchAll()]);
}

if ($action === 'global_gifts' && $_SERVER['REQUEST_METHOD'] === 'GET') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$q=$pdo->query("SELECT ga.*,s.username sender_username,s.display_name sender_display_name,s.avatar_url sender_avatar,r.username recipient_username,r.display_name recipient_display_name,r.avatar_url recipient_avatar,g.name gift_name,g.icon gift_icon,rm.name room_name,rm.room_id room_code FROM gift_announcements ga LEFT JOIN profiles s ON s.id=ga.sender_id LEFT JOIN profiles r ON r.id=ga.recipient_id LEFT JOIN room_gift_catalog g ON g.id=ga.gift_id LEFT JOIN rooms rm ON rm.id=ga.room_id ORDER BY ga.created_at DESC LIMIT 100");respond(['ok'=>true,'data'=>$q->fetchAll()]); }
if ($action === 'admin_set_vip' && $_SERVER['REQUEST_METHOD'] === 'POST') { $u=currentUser($pdo);if(!$u||empty($u['is_super_admin']))respond(['ok'=>false,'error'=>'forbidden'],403);$d=body();$q=$pdo->prepare('UPDATE saki_account_modules SET vip_level=:l,updated_at=UTC_TIMESTAMP() WHERE user_id=:u');$q->execute([':l'=>(int)$d['level'],':u'=>$d['user_id']]);respond(['ok'=>true]); }
if ($action === 'admin_add_diamonds' && $_SERVER['REQUEST_METHOD'] === 'POST') { $u=currentUser($pdo);if(!$u||empty($u['is_super_admin']))respond(['ok'=>false,'error'=>'forbidden'],403);$d=body();$q=$pdo->prepare('UPDATE saki_account_modules SET diamonds=diamonds+:n,updated_at=UTC_TIMESTAMP() WHERE user_id=:u');$q->execute([':n'=>(int)$d['amount'],':u'=>$d['user_id']]);respond(['ok'=>true]); }
if ($action === 'store_equip' && $_SERVER['REQUEST_METHOD'] === 'POST') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$d=body();$pdo->prepare("UPDATE saki_store_inventory i JOIN saki_store_products p ON p.id=i.product_id SET i.equipped=0 WHERE i.user_id=:u AND p.category=:cat")->execute([':u'=>$u['id'],':cat'=>$d['category']??'frame']);$q=$pdo->prepare('UPDATE saki_store_inventory SET equipped=:e WHERE user_id=:u AND product_id=:p');$q->execute([':e'=>!empty($d['equipped'])?1:0,':u'=>$u['id'],':p'=>$d['product_id']]);respond(['ok'=>true]); }

if ($action === 'global_rank' && $_SERVER['REQUEST_METHOD'] === 'GET') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$mode=$_GET['mode']??'room';$q=$mode==='wealth'?$pdo->query("SELECT sender_id user_id,SUM(total_price) total_gold,COUNT(*) gifts_sent FROM gift_announcements WHERE created_at>=DATE_SUB(UTC_TIMESTAMP(),INTERVAL 30 DAY) GROUP BY sender_id ORDER BY total_gold DESC LIMIT 50"): $pdo->query("SELECT room_id,SUM(total_price) total_gold,COUNT(*) gifts_sent FROM gift_announcements WHERE created_at>=DATE_SUB(UTC_TIMESTAMP(),INTERVAL 30 DAY) GROUP BY room_id ORDER BY total_gold DESC LIMIT 50");respond(['ok'=>true,'data'=>$q->fetchAll()]); }

if ($action === 'upload_asset' && $_SERVER['REQUEST_METHOD'] === 'POST') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);if(empty($_FILES['file'])||$_FILES['file']['error']!==UPLOAD_ERR_OK)respond(['ok'=>false,'error'=>'file_missing'],422);$kind=preg_replace('/[^a-z0-9_-]/i','',$_POST['kind']??'asset');$ext=strtolower(pathinfo($_FILES['file']['name'],PATHINFO_EXTENSION));if(!in_array($ext,['png','jpg','jpeg','gif','webp','mp4','svga'],true))respond(['ok'=>false,'error'=>'file_type_not_allowed'],422);$dir=__DIR__.'/uploads/'.$kind;if(!is_dir($dir))mkdir($dir,0755,true);$name=$u['id'].'-'.bin2hex(random_bytes(8)).'.'.$ext;$dest=$dir.'/'.$name;if(!move_uploaded_file($_FILES['file']['tmp_name'],$dest))respond(['ok'=>false,'error'=>'file_save_failed'],500);$scheme=(!empty($_SERVER['HTTPS'])&&$_SERVER['HTTPS']!=='off')?'https':'http';respond(['ok'=>true,'data'=>['url'=>$scheme.'://'.$_SERVER['HTTP_HOST'].'/uploads/'.$kind.'/'.$name]]); }

if ($action === 'reels_feed' && $_SERVER['REQUEST_METHOD'] === 'GET') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$q=$pdo->query("SELECT r.id,r.author_id,r.video_url,r.description,r.visibility,r.created_at,p.username,p.avatar_url,p.saki_id,p.vip_level,p.wealth_level,(SELECT COUNT(*) FROM reel_likes l WHERE l.reel_id=r.id) likes_count,(SELECT COUNT(*) FROM reel_comments c WHERE c.reel_id=r.id) comments_count FROM reels r JOIN profiles p ON p.id=r.author_id ORDER BY r.created_at DESC LIMIT 50");$rows=$q->fetchAll();foreach($rows as &$row){$row['_liked']=false;$row['_likes_count']=(int)$row['likes_count'];$row['_comments_count']=(int)$row['comments_count'];}respond(['ok'=>true,'data'=>$rows]); }
if ($action === 'reel_create' && $_SERVER['REQUEST_METHOD'] === 'POST') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$d=body();$url=trim((string)($d['video_url']??''));if($url===''||!filter_var($url,FILTER_VALIDATE_URL))respond(['ok'=>false,'error'=>'video_url_required'],422);$id=bin2hex(random_bytes(16));$pdo->prepare('INSERT INTO reels(id,author_id,video_url,description,visibility,created_at,updated_at,video_path) VALUES(:id,:u,:url,:d,:v,UTC_TIMESTAMP(),UTC_TIMESTAMP(),:path)')->execute([':id'=>$id,':u'=>$u['id'],':url'=>$url,':d'=>trim((string)($d['description']??'')),':v'=>in_array($d['visibility']??'public',['public','followers'],true)?$d['visibility']:'public',':path'=>$url]);respond(['ok'=>true,'data'=>['id'=>$id,'video_url'=>$url]]); }
if ($action === 'reel_like_toggle' && $_SERVER['REQUEST_METHOD'] === 'POST') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$id=(string)(body()['reel_id']??'');$q=$pdo->prepare('SELECT 1 FROM reel_likes WHERE reel_id=:r AND user_id=:u');$q->execute([':r'=>$id,':u'=>$u['id']]);if($q->fetch()){$pdo->prepare('DELETE FROM reel_likes WHERE reel_id=:r AND user_id=:u')->execute([':r'=>$id,':u'=>$u['id']]);$liked=false;}else{$pdo->prepare('INSERT INTO reel_likes(reel_id,user_id,created_at) VALUES(:r,:u,UTC_TIMESTAMP())')->execute([':r'=>$id,':u'=>$u['id']]);$liked=true;}respond(['ok'=>true,'data'=>['liked'=>$liked]]); }
if ($action === 'reel_comments' && $_SERVER['REQUEST_METHOD'] === 'GET') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$q=$pdo->prepare('SELECT c.id,c.content,c.created_at,c.user_id,p.username,p.avatar_url,p.vip_level FROM reel_comments c JOIN profiles p ON p.id=c.user_id WHERE c.reel_id=:r ORDER BY c.created_at LIMIT 200');$q->execute([':r'=>$_GET['reel_id']??'']);respond(['ok'=>true,'data'=>$q->fetchAll()]); }
if ($action === 'reel_comment_create' && $_SERVER['REQUEST_METHOD'] === 'POST') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$d=body();$q=$pdo->prepare('INSERT INTO reel_comments(id,reel_id,user_id,content,created_at) VALUES(:id,:r,:u,:c,UTC_TIMESTAMP())');$q->execute([':id'=>bin2hex(random_bytes(16)),':r'=>$d['reel_id']??'',':u'=>$u['id'],':c'=>trim((string)($d['content']??''))]);respond(['ok'=>true]); }

if ($action === 'notifications' && $_SERVER['REQUEST_METHOD'] === 'GET') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$q=$pdo->prepare('SELECT n.*,p.username,p.display_name,p.avatar_url,p.saki_id,p.vip_level FROM notifications n LEFT JOIN profiles p ON p.id=n.actor_id WHERE n.user_id=:u ORDER BY n.created_at DESC LIMIT 200');$q->execute([':u'=>$u['id']]);respond(['ok'=>true,'data'=>$q->fetchAll()]); }
if ($action === 'notifications_read' && $_SERVER['REQUEST_METHOD'] === 'POST') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$type=body()['type']??null;$sql='UPDATE notifications SET is_read=1 WHERE user_id=:u';$params=[':u'=>$u['id']];if($type){$sql.=' AND type=:t';$params[':t']=$type;}$pdo->prepare($sql)->execute($params);respond(['ok'=>true]); }
if ($action === 'room_details' && $_SERVER['REQUEST_METHOD'] === 'GET') {
  $u=currentUser($pdo); if(!$u) respond(['ok'=>false,'error'=>'unauthorized'],401); $requested=trim((string)($_GET['room_id']??'')); $q=$pdo->prepare('SELECT r.id,r.room_id,r.owner_id,r.name,r.description,r.country,r.room_type,r.image_url,r.background_url,r.seat_count,r.announcement,r.category,r.theme_key,r.membership_fee,r.reward_rate,r.mic_permission,r.is_active,r.created_at,p.username,p.display_name,p.avatar_url,p.vip_level FROM rooms r LEFT JOIN profiles p ON p.id=r.owner_id WHERE (r.id=:r OR r.room_id=:r) AND r.is_active=1 LIMIT 1'); $q->execute([':r'=>$requested]); $row=$q->fetch(PDO::FETCH_ASSOC); if(!$row) respond(['ok'=>false,'error'=>'room_not_found'],404); respond(['ok'=>true,'data'=>$row]);
}
if ($action === 'room_message_send' && $_SERVER['REQUEST_METHOD'] === 'POST') {
  $u=currentUser($pdo); if(!$u) respond(['ok'=>false,'error'=>'unauthorized'],401); $d=body(); $requested=trim((string)($d['room_id']??'')); $message=trim((string)($d['body']??'')); if($requested==='') respond(['ok'=>false,'error'=>'room_id_required'],422); if($message==='') respond(['ok'=>false,'error'=>'message_body_required'],422);
  $q=$pdo->prepare('SELECT id FROM rooms WHERE (id=:r OR room_id=:r) AND is_active=1 LIMIT 1'); $q->execute([':r'=>$requested]); $room=$q->fetchColumn(); if(!$room) respond(['ok'=>false,'error'=>'room_not_found'],404);
  $q=$pdo->prepare('SELECT 1 FROM room_members WHERE room_id=:r AND user_id=:u LIMIT 1'); $q->execute([':r'=>$room,':u'=>$u['id']]); if(!$q->fetch()) respond(['ok'=>false,'error'=>'room_membership_required'],403);
  $type=trim((string)($d['type']??'chat')); $payload=json_encode($d['payload']??new stdClass(),JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES); $id=bin2hex(random_bytes(16));
  $pdo->prepare('INSERT INTO room_messages(id,room_id,sender_id,body,created_at,message_type,payload) VALUES(:id,:r,:u,:b,UTC_TIMESTAMP(),:t,:p)')->execute([':id'=>$id,':r'=>$room,':u'=>$u['id'],':b'=>$message,':t'=>$type!==''?$type:'chat',':p'=>$payload]); respond(['ok'=>true,'data'=>['id'=>$id,'room_id'=>$room,'sender_id'=>$u['id'],'body'=>$message,'message_type'=>$type,'payload'=>$d['payload']??new stdClass()] ]);
}
if ($action === 'room_settings_update' && $_SERVER['REQUEST_METHOD'] === 'POST') {
  $u=currentUser($pdo); if(!$u) respond(['ok'=>false,'error'=>'unauthorized'],401); $d=body(); $requested=trim((string)($d['room_id']??''));
  $q=$pdo->prepare('SELECT id FROM rooms WHERE (id=:r OR room_id=:r) AND owner_id=:u AND is_active=1 LIMIT 1'); $q->execute([':r'=>$requested,':u'=>$u['id']]); $room=$q->fetchColumn(); if(!$room) respond(['ok'=>false,'error'=>'room_owner_required'],403);
  $allowed=['seat_count','image_url','background_url','name','announcement','category','theme_key','membership_fee','reward_rate','mic_permission']; $set=[]; $params=[':r'=>$room]; foreach($allowed as $key){ if(array_key_exists($key,$d)){ $set[]="`$key`=:$key"; $params[":$key"]=$d[$key]; }} if(!$set) respond(['ok'=>false,'error'=>'no_settings'],422); $pdo->prepare('UPDATE rooms SET '.implode(',',$set).' WHERE id=:r')->execute($params); respond(['ok'=>true,'data'=>['room_id'=>$room]]);
}
if ($action === 'room_backgrounds' && $_SERVER['REQUEST_METHOD'] === 'GET') {
  $u=currentUser($pdo); if(!$u) respond(['ok'=>false,'error'=>'unauthorized'],401); $requested=trim((string)($_GET['room_id']??'')); $q=$pdo->prepare('SELECT id FROM rooms WHERE (id=:r OR room_id=:r) LIMIT 1'); $q->execute([':r'=>$requested]); $room=$q->fetchColumn(); if(!$room) respond(['ok'=>false,'error'=>'room_not_found'],404); $q=$pdo->prepare('SELECT id,image_url,created_at FROM room_backgrounds WHERE room_id=:r AND owner_id=:u ORDER BY created_at DESC LIMIT 100'); $q->execute([':r'=>$room,':u'=>$u['id']]); respond(['ok'=>true,'data'=>$q->fetchAll()]);
}
if ($action === 'room_background_save' && $_SERVER['REQUEST_METHOD'] === 'POST') {
  $u=currentUser($pdo); if(!$u) respond(['ok'=>false,'error'=>'unauthorized'],401); $d=body(); $requested=trim((string)($d['room_id']??'')); $url=trim((string)($d['image_url']??'')); if($url==='') respond(['ok'=>false,'error'=>'image_url_required'],422); $q=$pdo->prepare('SELECT id FROM rooms WHERE (id=:r OR room_id=:r) AND owner_id=:u LIMIT 1'); $q->execute([':r'=>$requested,':u'=>$u['id']]); $room=$q->fetchColumn(); if(!$room) respond(['ok'=>false,'error'=>'room_owner_required'],403); $pdo->prepare('INSERT INTO room_backgrounds(id,room_id,owner_id,image_url,created_at) VALUES(:id,:r,:u,:url,UTC_TIMESTAMP())')->execute([':id'=>bin2hex(random_bytes(16)),':r'=>$room,':u'=>$u['id'],':url'=>$url]); respond(['ok'=>true]);
}
if ($action === 'room_messages' && $_SERVER['REQUEST_METHOD'] === 'GET') {
  $u=currentUser($pdo); if(!$u) respond(['ok'=>false,'error'=>'unauthorized'],401); $requested=trim((string)($_GET['room_id']??''));
  $q=$pdo->prepare('SELECT id FROM rooms WHERE (id=:r OR room_id=:r) AND is_active=1 LIMIT 1'); $q->execute([':r'=>$requested]); $room=$q->fetchColumn(); if(!$room) respond(['ok'=>false,'error'=>'room_not_found'],404);
  $q=$pdo->prepare('SELECT m.*,p.username,p.display_name,p.avatar_url,p.vip_level FROM room_messages m LEFT JOIN profiles p ON p.id=m.sender_id WHERE m.room_id=:r ORDER BY m.created_at DESC LIMIT 100'); $q->execute([':r'=>$room]); $rows=array_reverse($q->fetchAll()); respond(['ok'=>true,'data'=>$rows]);
}
if ($action === 'families' && $_SERVER['REQUEST_METHOD'] === 'GET') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$q=$pdo->query('SELECT f.*,p.username owner_username,p.avatar_url owner_avatar,(SELECT COUNT(*) FROM family_members fm WHERE fm.family_id=f.id AND fm.status=\'active\') members_count FROM families f JOIN profiles p ON p.id=f.owner_id ORDER BY f.stars DESC LIMIT 100');respond(['ok'=>true,'data'=>$q->fetchAll()]); }
if ($action === 'family_create' && $_SERVER['REQUEST_METHOD'] === 'POST') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$d=body();$id=bin2hex(random_bytes(16));$pdo->beginTransaction();try{$pdo->prepare("INSERT INTO families(id,owner_id,name,family_alias,description,avatar_url,created_at,announcement,weekly_starts_at,updated_at) VALUES(:id,:u,:n,:a,:d,:av,UTC_TIMESTAMP(),' ',UTC_TIMESTAMP(),UTC_TIMESTAMP())")->execute([':id'=>$id,':u'=>$u['id'],':n'=>trim($d['name']??''),':a'=>trim($d['alias']??''),':d'=>trim($d['description']??''),':av'=>$d['avatar_url']??null]);$pdo->prepare("INSERT INTO family_members(family_id,user_id,role,status,joined_at) VALUES(:f,:u,'owner','active',UTC_TIMESTAMP())")->execute([':f'=>$id,':u'=>$u['id']]);$pdo->commit();respond(['ok'=>true,'data'=>['id'=>$id,'name'=>$d['name']??'','family_alias'=>$d['alias']??'']]);}catch(Throwable $e){$pdo->rollBack();respond(['ok'=>false,'error'=>$e->getMessage()],422);} }
if ($action === 'family_join' && $_SERVER['REQUEST_METHOD'] === 'POST') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$d=body();$pdo->prepare("INSERT INTO family_join_requests(id,family_id,user_id,status,created_at) VALUES(:id,:f,:u,'pending',UTC_TIMESTAMP())")->execute([':id'=>bin2hex(random_bytes(16)),':f'=>$d['family_id']??'',':u'=>$u['id']]);respond(['ok'=>true]); }
if ($action === 'family_leave' && $_SERVER['REQUEST_METHOD'] === 'POST') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$pdo->prepare("UPDATE family_members SET status='left' WHERE family_id=:f AND user_id=:u")->execute([':f'=>body()['family_id']??' ',':u'=>$u['id']]);respond(['ok'=>true]); }
if ($action === 'family_requests' && $_SERVER['REQUEST_METHOD'] === 'GET') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$q=$pdo->prepare("SELECT r.*,p.username,p.avatar_url,p.saki_id FROM family_join_requests r JOIN profiles p ON p.id=r.user_id WHERE r.family_id=:f AND r.status='pending' ORDER BY r.created_at LIMIT 100");$q->execute([':f'=>$_GET['family_id']??'']);respond(['ok'=>true,'data'=>$q->fetchAll()]); }


if ($action === 'countries' && $_SERVER['REQUEST_METHOD'] === 'GET') {
  $rows=$pdo->query("SELECT code,name_ar,flag FROM countries ORDER BY name_ar LIMIT 250")->fetchAll();
  respond(['ok'=>true,'data'=>$rows]);
}
if ($action === 'profile_complete' && $_SERVER['REQUEST_METHOD'] === 'POST') {
  $u=currentUser($pdo); if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401); $d=body();
  $username=trim((string)($d['username']??'')); $country=trim((string)($d['country']??'')); $gender=trim((string)($d['gender']??''));
  if(!preg_match('/^[A-Za-z0-9_\x{0600}-\x{06FF}]{3,30}$/u',$username))respond(['ok'=>false,'error'=>'invalid_username'],422);
  if($country===''||mb_strlen($country)>80||!in_array($gender,['ذكر','أنثى'],true))respond(['ok'=>false,'error'=>'profile_fields_invalid'],422);
  $avatarUrl=trim((string)($d['avatar_url']??'')); if($avatarUrl!=='' && !filter_var($avatarUrl,FILTER_VALIDATE_URL))respond(['ok'=>false,'error'=>'invalid_avatar_url'],422);
  try{$q=$pdo->prepare('UPDATE profiles SET username=:username,display_name=:username,country=:country,gender=:gender,avatar_url=COALESCE(NULLIF(:avatar_url,\'\'),avatar_url),updated_at=UTC_TIMESTAMP() WHERE id=:id');$q->execute([':username'=>$username,':country'=>$country,':gender'=>$gender,':avatar_url'=>$avatarUrl,':id'=>$u['id']]);}catch(Throwable $e){respond(['ok'=>false,'error'=>'username_already_exists'],409);}
  $fresh=currentUser($pdo); if(!$fresh) respond(['ok'=>false,'error'=>'profile_session_refresh_failed'],500); unset($fresh['session_id'],$fresh['user_id'],$fresh['expires_at']); respond(['ok'=>true,'data'=>$fresh]);
}

if ($action === 'profile_posts' && $_SERVER['REQUEST_METHOD'] === 'GET') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$id=trim((string)($_GET['user_id']??$u['id']));$q=$pdo->prepare("SELECT p.id,p.author_id,p.content,p.visibility,p.created_at,pr.username,pr.display_name,pr.avatar_url,pr.saki_id,pr.vip_level,pr.wealth_level,(SELECT COUNT(*) FROM post_likes l WHERE l.post_id=p.id) likes_count,(SELECT COUNT(*) FROM post_comments c WHERE c.post_id=p.id) comments_count,(SELECT COUNT(*) FROM post_shares sh WHERE sh.post_id=p.id) shares_count FROM posts p JOIN profiles pr ON pr.id=p.author_id WHERE p.author_id=:id ORDER BY p.created_at DESC LIMIT 60");$q->execute([':id'=>$id]);$rows=$q->fetchAll();$m=$pdo->prepare('SELECT id,storage_path,sort_order FROM post_media WHERE post_id=:id ORDER BY sort_order');foreach($rows as &$row){$row['profiles']=['id'=>$row['author_id'],'username'=>$row['username'],'display_name'=>$row['display_name'],'avatar_url'=>$row['avatar_url'],'saki_id'=>$row['saki_id']];$m->execute([':id'=>$row['id']]);$row['_media']=array_map(fn($x)=>['id'=>$x['id'],'storage_path'=>$x['storage_path'],'url'=>$x['storage_path'],'sort_order'=>(int)$x['sort_order']],$m->fetchAll());$row['_liked']=false;$row['_likes_count']=(int)$row['likes_count'];$row['_comments_count']=(int)$row['comments_count'];$row['_shares_count']=(int)$row['shares_count'];}respond(['ok'=>true,'data'=>$rows]); }
if ($action === 'profile_reels' && $_SERVER['REQUEST_METHOD'] === 'GET') { $u=currentUser($pdo);if(!$u)respond(['ok'=>false,'error'=>'unauthorized'],401);$id=trim((string)($_GET['user_id']??$u['id']));$q=$pdo->prepare("SELECT r.id,r.author_id,r.video_url,r.description,r.visibility,r.created_at,p.username,p.avatar_url,p.saki_id,p.vip_level,p.wealth_level,(SELECT COUNT(*) FROM reel_likes l WHERE l.reel_id=r.id) likes_count,(SELECT COUNT(*) FROM reel_comments c WHERE c.reel_id=r.id) comments_count FROM reels r JOIN profiles p ON p.id=r.author_id WHERE r.author_id=:id ORDER BY r.created_at DESC LIMIT 60");$q->execute([':id'=>$id]);$rows=$q->fetchAll();foreach($rows as &$row){$row['_liked']=false;$row['_likes_count']=(int)$row['likes_count'];$row['_comments_count']=(int)$row['comments_count'];}respond(['ok'=>true,'data'=>$rows]); }
if ($action === 'google_login' && $_SERVER['REQUEST_METHOD'] === 'POST') {
  $d=body(); $idToken=trim((string)($d['id_token']??''));
  if($idToken==='')respond(['ok'=>false,'error'=>'id_token_required'],422);
  $googleClientId='164807497226-k7h6m36u5rphd0th08em1u233nu1hfhq.apps.googleusercontent.com';
  $ctx=stream_context_create(['http'=>['method'=>'GET','timeout'=>10,'ignore_errors'=>true]]);
  $raw=@file_get_contents('https://oauth2.googleapis.com/tokeninfo?id_token='.rawurlencode($idToken),false,$ctx);
  $claims=json_decode($raw?:'',true);
  if(!is_array($claims) || ($claims['aud']??'')!==$googleClientId || empty($claims['sub']) || ($claims['email_verified']??'false')!=='true') respond(['ok'=>false,'error'=>'google_token_invalid'],401);
  $sub=trim((string)$claims['sub']); $email=trim((string)($claims['email']??'')); $name=trim((string)($claims['name']??'')); $picture=trim((string)($claims['picture']??''));
  $q=$pdo->prepare('SELECT * FROM auth_users WHERE google_subject=:sub OR (email=:email AND :email<>\'\') LIMIT 1'); $q->execute([':sub'=>$sub,':email'=>$email]); $account=$q->fetch();
  try {
    $pdo->beginTransaction();
    if($account) {
      $pdo->prepare('UPDATE auth_users SET google_subject=:sub,google_email=:email WHERE id=:id')->execute([':sub'=>$sub,':email'=>$email!==''?$email:null,':id'=>$account['id']]); $uid=$account['id'];
      $pdo->prepare('UPDATE profiles SET display_name=COALESCE(NULLIF(display_name,\'\'),:name),avatar_url=COALESCE(NULLIF(avatar_url,\'\'),:picture) WHERE id=:id')->execute([':name'=>$name!==''?$name:null,':picture'=>$picture!==''?$picture:null,':id'=>$uid]);
    } else {
      $base='google_'.substr(preg_replace('/[^a-zA-Z0-9_]/','',$sub),0,20); $username=$base; $n=0;
      while(true){$c=$pdo->prepare('SELECT 1 FROM auth_users WHERE username=:u LIMIT 1');$c->execute([':u'=>$username]);if(!$c->fetch())break;$n++;$username=$base.'_'.$n;}
      $uid=bin2hex(random_bytes(16)); $sakiId=random_int(964379846,999999999);
      $pdo->prepare('INSERT INTO auth_users (id,email,username,password_hash,google_subject,google_email) VALUES (:id,:email,:username,:hash,:sub,:gemail)')->execute([':id'=>$uid,':email'=>$email!==''?$email:null,':username'=>$username,':hash'=>password_hash(bin2hex(random_bytes(32)),PASSWORD_DEFAULT),':sub'=>$sub,':gemail'=>$email!==''?$email:null]);
      $pdo->prepare('INSERT INTO profiles (id,username,display_name,avatar_url,saki_id) VALUES (:id,:username,:name,:picture,:saki_id)')->execute([':id'=>$uid,':username'=>$username,':name'=>$name!==''?$name:$username,':picture'=>$picture!==''?$picture:null,':saki_id'=>$sakiId]);
    }
    $pdo->commit();
  } catch(Throwable $e) { if($pdo->inTransaction())$pdo->rollBack(); respond(['ok'=>false,'error'=>'google_account_save_failed'],500); }
  $rawToken=bin2hex(random_bytes(32)); $expires=(new DateTimeImmutable('now',new DateTimeZone('UTC')))->modify('+30 days')->format('Y-m-d H:i:s');
  $pdo->prepare('INSERT INTO auth_sessions (user_id,token_hash,expires_at,user_agent,ip_address) VALUES (:uid,:hash,:expires,:ua,:ip)')->execute([':uid'=>$uid,':hash'=>hash('sha256',$rawToken),':expires'=>$expires,':ua'=>substr($_SERVER['HTTP_USER_AGENT']??'',0,255),':ip'=>$_SERVER['REMOTE_ADDR']??null]);
  $p=$pdo->prepare('SELECT id,username,display_name,avatar_url,country,gender,bio,saki_id,vip_level,wealth_level,shipping_agent FROM profiles WHERE id=:id LIMIT 1');$p->execute([':id'=>$uid]); respond(['ok'=>true,'token'=>$rawToken,'expires_at'=>$expires,'data'=>$p->fetch()]);
}

respond(['ok'=>false,'error'=>'unknown_action'],404);


