<?php
// Copy to saki-config.php on the server and fill in server-only values.
// Never commit saki-config.php or any token/certificate to GitHub.
return [
    'db_host' => 'localhost',
    'db_name' => 'CHANGE_ME',
    'db_user' => 'CHANGE_ME',
    'db_password' => 'CHANGE_ME',
    'app_id' => 'CHANGE_ME_AGORA_APP_ID',
    'app_certificate' => 'SET_ON_SERVER_ONLY',
    'server_secret' => 'GENERATE_A_LONG_RANDOM_SECRET',
];
